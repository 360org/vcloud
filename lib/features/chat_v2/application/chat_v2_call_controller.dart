import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../data/chat_v2_call_repository.dart';
import '../data/odoo_bus_service.dart';
import '../domain/models/chat_v2_call_session.dart';
import 'chat_v2_callkit_service.dart';
import 'chat_v2_channels_controller.dart';
import 'chat_v2_webrtc_engine.dart';

final chatV2CallControllerProvider =
    StateNotifierProvider<ChatV2CallController, ChatV2CallSession?>((ref) {
  final repo = ref.watch(chatV2CallRepositoryProvider);
  final bus = ref.watch(odooBusServiceProvider);
  return ChatV2CallController(repo: repo, bus: bus);
});

class ChatV2CallController extends StateNotifier<ChatV2CallSession?> {
  final ChatV2CallRepository repo;
  final OdooBusService? bus;
  final ChatV2WebRtcEngine? webrtcEngine;

  ChatV2WebRtcEngine? _webrtc;
  StreamSubscription? _busPeerSub;
  StreamSubscription? _busEndedSub;
  StreamSubscription? _busIncomingCallSub;
  StreamSubscription? _busAcceptedSub;
  StreamSubscription? _busPeerJoinedSub;

  Timer? _durationTimer;
  Timer? _ringingTimeoutTimer;
  Timer? _disconnectTimer;
  Timer? _autoResetTimer;
  Timer? _pollingFallbackTimer;
  AudioPlayer? _audioPlayer;

  bool _isDisposed = false;
  bool _isMuted = false;
  bool _isSpeaker = false;

  bool get isMuted => _webrtc?.isMuted ?? _isMuted;
  bool get isSpeaker => _webrtc?.isSpeaker ?? _isSpeaker;
  ChatV2CallSession? get currentSession => state;

  ChatV2CallController({
    required this.repo,
    this.bus,
    this.webrtcEngine,
  }) : super(null) {
    if (webrtcEngine != null) {
      _webrtc = webrtcEngine;
      _webrtc!.onConnectionState = _handleWebrtcConnectionState;
    }
    if (bus != null) {
      _initBusListeners();
    }
  }

  void _initBusListeners() {
    bus?.connect();

    // 1. Lắng nghe Signaling SDP / ICE từ Odoo Bus WebSocket
    _busPeerSub = bus?.onPeerNotification.listen((data) {
      _handlePeerNotification(data);
    });

    // 2. Lắng nghe sự kiện đối phương gác máy hoặc từ chối (Odoo 19 Core & VMobile)
    _busEndedSub = bus?.onCallEnded.listen((data) {
      final channelId = int.tryParse(data['channel_id']?.toString() ?? '0') ?? 0;
      final sessionId = int.tryParse(data['sessionId']?.toString() ?? '0') ?? 0;
      final callId = int.tryParse(data['call_id']?.toString() ?? '0') ?? 0;
      final endState = data['state']?.toString();
      final reason = data['reason']?.toString();

      final matchChannel = (channelId > 0 && state != null && state!.channelId == channelId);
      final matchSession = (sessionId > 0 && state != null && state!.id == sessionId);
      final matchCall = (callId > 0 && state != null && state!.id == callId);

      if (matchChannel || matchSession || matchCall) {
        debugPrint('[RTC_CALL_LOG][END] Bus onCallEnded: channel=$channelId, session=$sessionId, callId=$callId, state=$endState, reason=$reason');
        _handleRemoteHangup(endState: endState, reason: reason);
      }
    });

    // 3. Lắng nghe sự kiện Odoo Bus mời tham gia cuộc gọi (RTC Invite Callee)
    _busIncomingCallSub = bus?.onIncomingCall.listen((data) {
      final channelId = int.tryParse(data['channel_id']?.toString() ?? '0') ?? 0;
      final callerId = int.tryParse(data['caller_id']?.toString() ?? '0') ?? 0;
      final callerName = data['caller_name']?.toString() ?? 'Đồng nghiệp';
      final callerAvatar = data['caller_avatar']?.toString();
      final callId = int.tryParse(
            data['call_id']?.toString() ??
            data['rtc_inviting_session_id']?.toString() ??
            data['id']?.toString() ??
            '0',
          ) ??
          0;

      debugPrint('[RTC_CALL_LOG][SIGNAL] Bus onIncomingCall: channelId=$channelId, callId=$callId, caller=$callerName');

      if (channelId > 0) {
        final incomingSession = ChatV2CallSession(
          id: callId,
          channelId: channelId,
          callerId: callerId,
          callerName: callerName,
          callerAvatar: callerAvatar,
          receiverId: 0,
          receiverName: 'Tôi',
          state: ChatV2CallState.incomingRinging,
          isCaller: false,
          startedAt: DateTime.now(),
        );
        setIncomingCall(incomingSession);
      }
    });

    // 4. Lắng nghe Callee chấp nhận cuộc gọi (Callee accepted call)
    _busAcceptedSub = bus?.onCallAccepted.listen((data) async {
      final channelId = int.tryParse(data['channel_id']?.toString() ?? '0') ?? 0;
      final matchChannel = channelId == 0 || (state != null && state!.channelId == channelId);
      final isCaller = state?.isCaller ?? false;

      if (matchChannel && isCaller) {
        debugPrint('[RTC_CALL_LOG][ACCEPT] Bus onCallAccepted: kênh $channelId');
        _pollingFallbackTimer?.cancel();
        _pollingFallbackTimer = null;
        final sdpAnswer = data['sdp_answer'] ?? data['answer'];
        if (sdpAnswer is Map) {
          await _webrtc?.handleAnswer(Map<String, dynamic>.from(sdpAnswer));
        } else if (sdpAnswer is String && sdpAnswer.isNotEmpty) {
          await _webrtc?.handleAnswer({'type': 'answer', 'sdp': sdpAnswer});
        }
        state = state?.copyWith(state: ChatV2CallState.connected);
        _onCallConnected();
      }
    });

    // 5. Lắng nghe peer tham gia phòng RTC (Callee join RTC session)
    _busPeerJoinedSub = bus?.onPeerJoined.listen((data) async {
      final channelId = int.tryParse(data['channel_id']?.toString() ?? '0') ?? 0;
      final sessionId = int.tryParse(data['sessionId']?.toString() ?? data['session_id']?.toString() ?? '0') ?? 0;
      final isCaller = state?.isCaller ?? false;
      final isRingingOrConnecting = state?.state == ChatV2CallState.outgoingRinging ||
          state?.state == ChatV2CallState.connecting;

      final matchChannel = channelId == 0 || (state != null && state!.channelId == channelId);

      if (isCaller && isRingingOrConnecting && sessionId > 0 && matchChannel) {
        debugPrint('[RTC_CALL_LOG][SIGNAL] Peer joined session $sessionId trên kênh $channelId');
        _webrtc?.updateTargetSessionIds([sessionId]);
        await _webrtc?.createAndSendOffer();
        state = state?.copyWith(state: ChatV2CallState.connecting);
      }
    });
  }

  /// Cập nhật Session ID khi server đồng bộ (hoặc Watcher tìm thấy active call)
  void updateSessionId(int id) {
    if (state != null && (state!.id == 0 || state!.id != id) && id > 0) {
      debugPrint('[RTC_CALL_LOG][SIGNAL] Đồng bộ Session ID: ${state!.id} -> $id');
      state = state!.copyWith(id: id);
    }
  }

  /// Khởi tạo cuộc gọi mới từ phía Caller (Gọi vào Odoo 19 /mail/rtc/channel/join_call hoặc legacy)
  Future<bool> startCall({
    required int channelId,
    required String callerName,
    String? callerAvatar,
    required int receiverId,
    required String receiverName,
    String? receiverAvatar,
  }) async {
    try {
      debugPrint('[RTC_CALL_LOG][INIT] Khởi tạo cuộc gọi đi: channelId=$channelId, caller=$callerName, receiverId=$receiverId, receiver=$receiverName');

      if (state != null && state!.state != ChatV2CallState.idle) {
        debugPrint('[RTC_CALL_LOG][INIT] ⚠️ Đang trong cuộc gọi (${state!.state}), từ chối khởi tạo mới.');
        return false;
      }

      _stopAudio();
      _stopTimers();

      // Thiết lập trạng thái Dialing / Outgoing Ringing ban đầu
      state = ChatV2CallSession(
        id: 0,
        channelId: channelId,
        callerId: 0,
        callerName: callerName,
        callerAvatar: callerAvatar,
        receiverId: receiverId,
        receiverName: receiverName,
        receiverAvatar: receiverAvatar,
        state: ChatV2CallState.outgoingRinging,
        duration: 0,
        isCaller: true,
        iceCandidates: const [],
        startedAt: DateTime.now(),
      );

      bus?.subscribeChannel(channelId);
      _playDialingTone();

      // 1. Luôn tạo phiên gọi trên server (mobile.api.call.session)
      // để rung chuông thiết bị người nhận, gửi Push FCM và lấy Call ID chính xác
      debugPrint('[RTC_CALL_LOG][INIT] Gọi API initiateCall: channelId=$channelId, receiverId=$receiverId');
      final session = await repo.initiateCall(
        channelId: channelId,
        receiverId: receiverId,
      );
      if (_isDisposed) return false;

      if (session == null) {
        debugPrint('[RTC_CALL_LOG][INIT] ❌ Không thể tạo cuộc gọi trên server');
        state = state?.copyWith(state: ChatV2CallState.failed);
        _stopAudio();
        return false;
      }

      debugPrint('[RTC_CALL_LOG][INIT] initiateCall thành công: callId=${session.id}');
      state = session.copyWith(
        isCaller: true,
        callerName: (callerName.isNotEmpty && callerName != 'Người gọi')
            ? callerName
            : session.callerName,
        callerAvatar: (callerAvatar != null && callerAvatar.isNotEmpty)
            ? callerAvatar
            : session.callerAvatar,
        receiverName: (receiverName.isNotEmpty && receiverName != 'Người nhận')
            ? receiverName
            : session.receiverName,
        receiverAvatar: (receiverAvatar != null && receiverAvatar.isNotEmpty)
            ? receiverAvatar
            : session.receiverAvatar,
      );

      // Timeout 45s đổ chuông nếu đối phương không nghe máy
      debugPrint('[RTC_CALL_LOG][SIGNAL] Bắt đầu đổ chuông outgoingRinging, timeout 45s (Kênh: $channelId, Call ID: ${session.id})');
      _startRingingTimeout();
      _startPollingFallback(channelId, session.id);

      // 2. Khởi tạo WebRTC Engine và thử tham gia phòng RTC Odoo nếu có
      OdooRtcJoinResult? joinResult;
      try {
        joinResult = await repo.joinCall(channelId: channelId);
      } catch (e) {
        debugPrint('[RTC_CALL_LOG][INIT] joinCall Odoo RTC info: $e');
      }

      try {
        _webrtc ??= webrtcEngine ?? ChatV2WebRtcEngine(repo: repo);
        _webrtc!.onConnectionState = _handleWebrtcConnectionState;
        await _webrtc!.initialize(
          localSessionId: joinResult?.localSessionId ?? session.id,
          targetSessionIds: joinResult?.currentRtcSessionIds ?? [],
          iceServersData: joinResult?.iceServers ?? const [],
        );

        if (joinResult != null && joinResult.currentRtcSessionIds.isNotEmpty) {
          debugPrint('[RTC_CALL_LOG][SIGNAL] Gửi SDP Offer sang peer');
          await _webrtc!.createAndSendOffer();
        }
      } catch (e) {
        debugPrint('[RTC_CALL_LOG][MEDIA] ⚠️ Khởi tạo WebRTC Caller: $e');
      }

      return true;
    } catch (e, st) {
      debugPrint('[RTC_CALL_LOG][INIT] ❌ Lỗi ngoại lệ trong startCall: $e\n$st');
      state = state?.copyWith(state: ChatV2CallState.failed);
      _stopAudio();
      return false;
    }
  }

  /// Khi nhận thông báo FCM Wake-up có cuộc gọi đến (Callee)
  void setIncomingCall(ChatV2CallSession incomingSession) {
    debugPrint('[RTC_CALL_LOG][INIT] Nhận cuộc gọi đến: id=${incomingSession.id}, channelId=${incomingSession.channelId}, caller=${incomingSession.callerName}');

    // 0. Bỏ qua nếu là thông báo lặp lại của chính cuộc gọi đang tham gia
    if (state != null && state!.state != ChatV2CallState.idle) {
      if (incomingSession.id == state!.id ||
          (state!.channelId > 0 && incomingSession.channelId == state!.channelId)) {
        debugPrint('[RTC_CALL_LOG][INIT] Bỏ qua thông báo cuộc gọi trùng lặp cho phiên hiện tại (callId=${incomingSession.id}, channelId=${incomingSession.channelId})');
        return;
      }
    }

    // Fast-Busy Signal: Nếu đang bận trong cuộc đàm thoại (connected) của kênh khác
    if (state != null && state!.state == ChatV2CallState.connected) {
      debugPrint('[RTC_CALL_LOG][SIGNAL] 📞 Fast-Busy: Đang connected -> Tự động từ chối cuộc gọi đến từ kênh ${incomingSession.channelId}');
      if (incomingSession.id > 0) {
        repo.rejectCall(incomingSession.id, reason: 'busy').catchError((_) => false);
      }
      repo.leaveCall(
        channelId: incomingSession.channelId,
        sessionId: incomingSession.id > 0 ? incomingSession.id : null,
        reason: 'busy',
      ).catchError((_) => false);
      return;
    }

    if (state != null && state!.state != ChatV2CallState.idle) {
      debugPrint('[RTC_CALL_LOG][INIT] ⚠️ Controller đang ở phase ${state!.state}, bỏ qua setIncomingCall mới');
      return; // Đang quay số hoặc xử lý cuộc gọi khác
    }

    bus?.subscribeChannel(incomingSession.channelId);
    state = incomingSession.copyWith(
      state: ChatV2CallState.incomingRinging,
      isCaller: false,
      startedAt: DateTime.now(),
    );

    _playRingtone();
    _startRingingTimeout();
  }

  /// Callee bấm Trả lời cuộc gọi
  Future<void> acceptCall() async {
    final current = state;
    if (current == null) {
      debugPrint('[RTC_CALL_LOG][ACCEPT] ⚠️ acceptCall gọi khi state == null');
      return;
    }

    try {
      debugPrint('[RTC_CALL_LOG][ACCEPT] Bắt đầu chấp nhận cuộc gọi: callId=${current.id}, channelId=${current.channelId}');
      _stopAudio();
      _ringingTimeoutTimer?.cancel();
      state = current.copyWith(state: ChatV2CallState.connecting);

      // 1. Phân giải callId nếu session ban đầu chưa có ID (từ FCM wake-up)
      int effectiveCallId = current.id;
      if (effectiveCallId == 0) {
        try {
          final activeCall = await repo.getActiveCall();
          if (activeCall != null && activeCall.id > 0 &&
              (activeCall.channelId == current.channelId || current.channelId == 0)) {
            effectiveCallId = activeCall.id;
            debugPrint('[RTC_CALL_LOG][ACCEPT] Đã phân giải effectiveCallId: $effectiveCallId');
          }
        } catch (e) {
          debugPrint('[RTC_CALL_LOG][ACCEPT] ⚠️ Không lấy được activeCall: $e');
        }
      }

      // 2. Luôn gọi API acceptCall để cập nhật trạng thái connected trên server
      // Truyền channelId để backend fallback tìm session khi effectiveCallId == 0
      ChatV2CallSession? updated;
      try {
        debugPrint('[RTC_CALL_LOG][ACCEPT] Gọi API acceptCall: callId=$effectiveCallId, channelId=${current.channelId}');
        updated = await repo.acceptCall(
          effectiveCallId,
          channelId: current.channelId > 0 ? current.channelId : null,
        );
      } catch (e) {
        debugPrint('[RTC_CALL_LOG][ACCEPT] ⚠️ API acceptCall error: $e');
      }
      if (_isDisposed) return;

      // 🛑 CHỐNG ẢO GIÁC OPTIMISTIC UI: Chỉ chuyển connected & chạy timer khi server xác nhận thành công!
      if (updated == null || updated.state != ChatV2CallState.connected) {
        debugPrint('[RTC_CALL_LOG][ACCEPT] ❌ Server chưa xác nhận trạng thái connected (updated: $updated). Dừng handshake, chuyển failed.');
        state = current.copyWith(state: ChatV2CallState.failed);
        _stopAudio();
        _cleanupWebrtc();
        ChatV2CallKitService.instance.endAllCalls();
        _autoResetTimer?.cancel();
        _autoResetTimer = Timer(const Duration(milliseconds: 1500), () {
          if (!_isDisposed && mounted && state?.state == ChatV2CallState.failed) {
            reset();
          }
        });
        return;
      }

      state = updated.copyWith(
        id: updated.id > 0 ? updated.id : (effectiveCallId > 0 ? effectiveCallId : current.id),
        state: ChatV2CallState.connected,
        duration: current.duration > 0 ? current.duration : updated.duration,
        connectedAt: updated.connectedAt ?? DateTime.now(),
        isCaller: false,
      );
      _startDurationTimer();

      // 2. Thử tham gia phòng RTC Odoo nếu có
      OdooRtcJoinResult? joinResult;
      try {
        joinResult = await repo.joinCall(channelId: current.channelId);
      } catch (e) {
        debugPrint('[RTC_CALL_LOG][ACCEPT] joinCall Odoo info: $e');
      }

      // 3. Khởi tạo WebRTC Engine
      try {
        _webrtc ??= webrtcEngine ?? ChatV2WebRtcEngine(repo: repo);
        _webrtc!.onConnectionState = _handleWebrtcConnectionState;

        await _webrtc!.initialize(
          localSessionId: joinResult?.localSessionId ?? current.id,
          targetSessionIds: joinResult?.currentRtcSessionIds ?? [],
          iceServersData: joinResult?.iceServers ?? const [],
        );
      } catch (e) {
        debugPrint('[RTC_CALL_LOG][MEDIA] ⚠️ Khởi tạo WebRTC Callee: $e');
      }
    } catch (e, st) {
      debugPrint('[RTC_CALL_LOG][ACCEPT] ❌ Lỗi ngoại lệ trong acceptCall: $e\n$st');
      state = current.copyWith(state: ChatV2CallState.failed);
    }
  }

  /// Callee bấm Từ chối cuộc gọi
  Future<void> rejectCall() async {
    final current = state;
    try {
      debugPrint('[RTC_CALL_LOG][ACCEPT] Callee bấm từ chối cuộc gọi: callId=${current?.id}, channelId=${current?.channelId}');
      _stopAudio();
      _stopTimers();

      if (current != null) {
        if (current.id != 0) {
          if (current.isCaller) {
            await repo.cancelCall(current.id).catchError((_) => false);
          } else {
            await repo.rejectCall(
              current.id,
              channelId: current.channelId > 0 ? current.channelId : null,
            ).catchError((_) => false);
          }
        } else if (!current.isCaller && current.channelId > 0) {
          await repo.rejectCall(
            0,
            channelId: current.channelId,
          ).catchError((_) => false);
        }
        await repo.leaveCall(channelId: current.channelId, sessionId: current.id).catchError((_) => false);
        if (current.channelId > 0) {
          ChatV2ChannelLocalCache.updateChannelLastMessage(
            current.channelId.toString(),
            lastMessage: '🚫 [Cuộc gọi bị từ chối]',
            lastMessageDate: DateTime.now(),
          );
        }
      }
      state = current?.copyWith(state: ChatV2CallState.rejected);
      _cleanupWebrtc();
      ChatV2CallKitService.instance.endAllCalls();

      _autoResetTimer?.cancel();
      _autoResetTimer = Timer(const Duration(milliseconds: 500), () {
        if (!_isDisposed && mounted && state?.state == ChatV2CallState.rejected) {
          reset();
        }
      });
    } catch (e) {
      debugPrint('[RTC_CALL_LOG][ACCEPT] ⚠️ Lỗi trong rejectCall: $e');
      reset();
    }
  }

  /// Caller chủ động Hủy trước khi Callee nghe máy
  Future<void> cancelCall() async {
    final current = state;
    try {
      debugPrint('[RTC_CALL_LOG][END] Caller chủ động hủy cuộc gọi: callId=${current?.id}, channelId=${current?.channelId}');
      _stopAudio();
      _stopTimers();

      if (current != null) {
        if (current.id != 0) {
          await repo.cancelCall(current.id).catchError((_) => false);
        }
        await repo.cancelCallInvitation(channelId: current.channelId).catchError((_) => false);
        await repo.leaveCall(channelId: current.channelId, sessionId: current.id).catchError((_) => false);
        if (current.channelId > 0) {
          ChatV2ChannelLocalCache.updateChannelLastMessage(
            current.channelId.toString(),
            lastMessage: '📵 [Cuộc gọi đã hủy]',
            lastMessageDate: DateTime.now(),
          );
        }
      }
      state = current?.copyWith(state: ChatV2CallState.cancelled);
      _cleanupWebrtc();
      ChatV2CallKitService.instance.endAllCalls();

      _autoResetTimer?.cancel();
      _autoResetTimer = Timer(const Duration(milliseconds: 500), () {
        if (!_isDisposed && mounted && state?.state == ChatV2CallState.cancelled) {
          reset();
        }
      });
    } catch (e) {
      debugPrint('[RTC_CALL_LOG][END] ⚠️ Lỗi trong cancelCall: $e');
      reset();
    }
  }

  /// Gác máy khi đang đàm thoại
  Future<void> endCall() async {
    final current = state;
    try {
      debugPrint('[RTC_CALL_LOG][END] Kết thúc cuộc gọi: callId=${current?.id}, channelId=${current?.channelId}, duration=${current?.duration}s');
      _stopAudio();
      _stopTimers();

      if (current != null) {
        if (current.id != 0) {
          await repo.endCall(current.id, duration: current.duration).catchError((_) => false);
        }
        await repo.leaveCall(channelId: current.channelId, sessionId: current.id).catchError((_) => false);
        if (current.channelId > 0) {
          final durationStr = current.duration > 0 ? ' (${current.formattedDuration})' : '';
          ChatV2ChannelLocalCache.updateChannelLastMessage(
            current.channelId.toString(),
            lastMessage: '📞 Cuộc gọi thoại$durationStr',
            lastMessageDate: DateTime.now(),
          );
        }
      }
      state = current?.copyWith(state: ChatV2CallState.ended);
      _cleanupWebrtc();
      ChatV2CallKitService.instance.endAllCalls();
    } catch (e) {
      debugPrint('[RTC_CALL_LOG][END] ⚠️ Lỗi trong endCall: $e');
      reset();
    }
  }

  /// Xử lý bản tin WebRTC Signaling nhận từ Odoo Bus
  void _handlePeerNotification(Map<String, dynamic> data) async {
    if (_webrtc == null || state == null) return;

    try {
      final senderSessionId = int.tryParse(data['sender']?.toString() ?? '0') ?? 0;
      if (senderSessionId > 0) {
        _webrtc!.updateTargetSessionIds([senderSessionId]);
      }

      final notifications = data['notifications'];
      if (notifications is! List) return;

      for (final rawNotif in notifications) {
        final notifObj = rawNotif is String ? jsonDecode(rawNotif) : rawNotif;
        if (notifObj is! Map) continue;

        final event = notifObj['event']?.toString();
        final payload = notifObj['payload'];
        if (payload is! Map) continue;

        debugPrint('[RTC_CALL_LOG][SIGNAL] WebRTC Signaling event: $event (sender: $senderSessionId)');

        if (event == 'offer') {
          final sdp = payload['sdp'];
          if (sdp is Map) {
            debugPrint('[RTC_CALL_LOG][SIGNAL] Nhận SDP Offer -> Tạo và gửi SDP Answer');
            await _webrtc!.handleOfferAndSendAnswer(
              Map<String, dynamic>.from(sdp),
              targetSessionId: senderSessionId > 0 ? senderSessionId : null,
            );
          }
        } else if (event == 'answer') {
          final sdp = payload['sdp'];
          if (sdp is Map) {
            debugPrint('[RTC_CALL_LOG][SIGNAL] Nhận SDP Answer -> Cập nhật Remote Description');
            await _webrtc!.handleAnswer(Map<String, dynamic>.from(sdp));
          }
        } else if (event == 'ice-candidate') {
          final candidate = payload['candidate'];
          if (candidate is Map) {
            debugPrint('[RTC_CALL_LOG][SIGNAL] Nhận Remote ICE Candidate');
            await _webrtc!.handleRemoteCandidate(Map<String, dynamic>.from(candidate));
          }
        }
      }
    } catch (e, st) {
      debugPrint('[RTC_CALL_LOG][SIGNAL] ⚠️ Lỗi xử lý peer notification: $e\n$st');
    }
  }

  void _handleWebrtcConnectionState(RTCPeerConnectionState connState) {
    debugPrint('[RTC_CALL_LOG][MEDIA] WebRTC connection state đổi sang: $connState');
    if (connState == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
      _disconnectTimer?.cancel();
      _disconnectTimer = null;
      _onCallConnected();
    } else if (connState == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
        connState == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
      // Grace period 10s cho ICE restart / hồi phục kết nối mạng
      if (_disconnectTimer == null) {
        debugPrint('[RTC_CALL_LOG][MEDIA] WebRTC disconnected/failed -> Bắt đầu đếm ngược 10 giây chờ hồi phục...');
        _disconnectTimer = Timer(const Duration(seconds: 10), () {
          debugPrint('[RTC_CALL_LOG][MEDIA] ❌ Mất kết nối WebRTC quá 10 giây -> Tự động kết thúc cuộc gọi');
          _handleRemoteHangup(endState: 'ended', reason: 'network_lost');
        });
      }
    } else if (connState == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
      _disconnectTimer?.cancel();
      _disconnectTimer = null;
      _handleRemoteHangup();
    }
  }

  void _onCallConnected() {
    debugPrint('[RTC_CALL_LOG][MEDIA] Cuộc gọi thoại đã kết nối thông suốt (Connected)');
    _stopAudio();
    _ringingTimeoutTimer?.cancel();
    _pollingFallbackTimer?.cancel();
    _pollingFallbackTimer = null;
    _disconnectTimer?.cancel();
    _disconnectTimer = null;
    state = state?.copyWith(
      state: ChatV2CallState.connected,
      connectedAt: state?.connectedAt ?? DateTime.now(),
    );
    _startDurationTimer();
    if (state != null && state!.id > 0) {
      ChatV2CallKitService.instance.setCallConnected(state!.id.toString());
    }
  }

  void handleRemoteHangup({String? endState, String? reason}) {
    _handleRemoteHangup(endState: endState, reason: reason);
  }

  void _handleRemoteHangup({String? endState, String? reason}) {
    final current = state;
    _stopAudio();
    _stopTimers();
    ChatV2CallState targetState = ChatV2CallState.ended;
    if (endState == 'rejected' || reason == 'busy') {
      targetState = ChatV2CallState.rejected;
    } else if (endState == 'cancelled') {
      targetState = ChatV2CallState.cancelled;
    } else if (endState == 'missed' || reason == 'timeout') {
      targetState = ChatV2CallState.missed;
    }
    debugPrint('[RTC_CALL_LOG][END] Đối phương ngắt máy: endState=$endState, reason=$reason -> targetState=$targetState');
    state = state?.copyWith(
      state: targetState,
      endReason: reason,
    );
    _cleanupWebrtc();
    ChatV2CallKitService.instance.endAllCalls();

    if (current != null && current.channelId > 0) {
      String callSnippet;
      if (targetState == ChatV2CallState.rejected) {
        callSnippet = '🚫 [Cuộc gọi bị từ chối]';
      } else if (targetState == ChatV2CallState.cancelled) {
        callSnippet = '📵 [Cuộc gọi đã hủy]';
      } else if (targetState == ChatV2CallState.missed) {
        callSnippet = '❌ [Cuộc gọi nhỡ]';
      } else {
        final durationStr = current.duration > 0 ? ' (${current.formattedDuration})' : '';
        callSnippet = '📞 Cuộc gọi thoại$durationStr';
      }
      ChatV2ChannelLocalCache.updateChannelLastMessage(
        current.channelId.toString(),
        lastMessage: callSnippet,
        lastMessageDate: DateTime.now(),
      );
    }

    // Tự động dọn dẹp state sau 1.2s nếu bận hoặc nhỡ, 2.2s nếu mất mạng để kịp đọc thông báo, 1.5s nếu gác máy bình thường
    final cleanupDelay = (reason == 'busy' || targetState == ChatV2CallState.missed)
        ? const Duration(milliseconds: 1200)
        : ((reason == 'network_lost')
            ? const Duration(milliseconds: 2200)
            : const Duration(milliseconds: 1500));

    _autoResetTimer?.cancel();
    _autoResetTimer = Timer(cleanupDelay, () {
      if (!_isDisposed && mounted && state?.state == targetState) {
        reset();
      }
    });
  }

  /// Bật/Tắt Micro
  void toggleMute() {
    _isMuted = !_isMuted;
    debugPrint('[RTC_CALL_LOG][MEDIA] Toggle Mute: $_isMuted');
    _webrtc?.toggleMute();
    if (state != null) {
      state = state!.copyWith(); // re-render
    }
  }

  /// Bật/Tắt Loa ngoài
  void toggleSpeaker() {
    _isSpeaker = !_isSpeaker;
    debugPrint('[RTC_CALL_LOG][MEDIA] Toggle Speaker: $_isSpeaker');
    _webrtc?.toggleSpeaker();
    if (state != null) {
      state = state!.copyWith(); // re-render
    }
  }

  void reset() {
    if (_isDisposed || !mounted) return;
    debugPrint('[RTC_CALL_LOG][END] Reset Call Controller state về null');
    _stopAudio();
    _stopTimers();
    _cleanupWebrtc();
    _isMuted = false;
    _isSpeaker = false;
    state = null;
  }

  void _cleanupWebrtc() {
    _webrtc?.dispose();
    _webrtc = null;
  }

  void _startDurationTimer() {
    if (_durationTimer != null && _durationTimer!.isActive) return;
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isDisposed || state == null || state!.state != ChatV2CallState.connected) {
        timer.cancel();
        return;
      }
      state = state!.copyWith(duration: (state!.duration) + 1);
    });
  }

  void _startRingingTimeout() {
    _ringingTimeoutTimer?.cancel();
    _ringingTimeoutTimer = Timer(const Duration(seconds: 45), () {
      if (state != null &&
          (state!.state == ChatV2CallState.outgoingRinging ||
              state!.state == ChatV2CallState.incomingRinging)) {
        debugPrint('[RTC_CALL_LOG][SIGNAL] ⏱️ Timeout 45s không có phản hồi -> Chuyển sang missed call');
        final currentSession = state;
        _stopAudio();
        state = state!.copyWith(state: ChatV2CallState.missed);
        _cleanupWebrtc();
        ChatV2CallKitService.instance.endAllCalls();

        // Đồng bộ timeout 45s xuống Database Backend Odoo & phát bus notification
        if (currentSession != null) {
          if (currentSession.id > 0) {
            repo.rejectCall(currentSession.id, reason: 'timeout').catchError((_) => false);
          }
          repo.leaveCall(
            channelId: currentSession.channelId,
            sessionId: currentSession.id > 0 ? currentSession.id : null,
            reason: 'timeout',
          ).catchError((_) => false);
        }

        _autoResetTimer?.cancel();
        _autoResetTimer = Timer(const Duration(milliseconds: 1500), () {
          if (!_isDisposed && mounted && state?.state == ChatV2CallState.missed) {
            reset();
          }
        });
      }
    });
  }

  void _startPollingFallback(int channelId, [int? callId]) {
    _pollingFallbackTimer?.cancel();
    _pollingFallbackTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) async {
      if (_isDisposed || !mounted) {
        timer.cancel();
        return;
      }
      if (state == null || !state!.isCaller) {
        timer.cancel();
        return;
      }
      if (state!.state != ChatV2CallState.outgoingRinging &&
          state!.state != ChatV2CallState.connecting) {
        timer.cancel();
        return;
      }

      final activeCallId = (callId != null && callId > 0) ? callId : state!.id;
      debugPrint('[RTC_CALL_LOG][SIGNAL] Polling fallback (callId=$activeCallId, channelId=$channelId)...');
      try {
        final latestSession = await repo.getCallStatus(
          callId: activeCallId > 0 ? activeCallId : null,
          channelId: channelId,
        );

        if (_isDisposed || !mounted || state == null) return;
        if (latestSession != null) {
          // Bỏ qua nếu server trả về call ID không khớp
          if (activeCallId > 0 && latestSession.id != activeCallId) {
            debugPrint('[RTC_CALL_LOG][SIGNAL] Bỏ qua kết quả polling vì Call ID không khớp: hiện tại=$activeCallId, server=${latestSession.id}');
            return;
          }

          debugPrint('[RTC_CALL_LOG][SIGNAL] Polling fallback kết quả: state=${latestSession.state}');
          if (latestSession.state == ChatV2CallState.connected) {
            timer.cancel();
            debugPrint('[RTC_CALL_LOG][ACCEPT] Polling phát hiện Callee đã accept (state=connected)');
            if (latestSession.sdpAnswer != null && latestSession.sdpAnswer!.isNotEmpty) {
              await _webrtc?.handleAnswer({
                'type': 'answer',
                'sdp': latestSession.sdpAnswer,
              });
            } else if (_webrtc != null) {
              try {
                debugPrint('[RTC_CALL_LOG][SIGNAL] Polling kích hoạt Offer cho Caller');
                await _webrtc!.createAndSendOffer();
              } catch (e) {
                debugPrint('[RTC_CALL_LOG][SIGNAL] ⚠️ Error sending offer from polling: $e');
              }
            }
            state = state?.copyWith(
              state: ChatV2CallState.connected,
              connectedAt: latestSession.connectedAt ?? DateTime.now(),
            );
            _onCallConnected();
          } else if (latestSession.state == ChatV2CallState.rejected ||
              latestSession.state == ChatV2CallState.cancelled ||
              latestSession.state == ChatV2CallState.ended ||
              latestSession.state == ChatV2CallState.missed) {
            timer.cancel();
            _handleRemoteHangup(
              endState: latestSession.state.name,
              reason: latestSession.endReason,
            );
          }
        }
      } catch (e) {
        debugPrint('[RTC_CALL_LOG][SIGNAL] ⚠️ Polling fallback error: $e');
      }
    });
  }

  void _playDialingTone() {
    _stopAudio();
    try {
      final player = AudioPlayer();
      _audioPlayer = player;
      player.setReleaseMode(ReleaseMode.loop).catchError((_) {});
      player.play(AssetSource('audio/dialing_tone.mp3')).catchError((_) {});
    } catch (_) {}
  }

  void _playRingtone() {
    _stopAudio();
    try {
      final player = AudioPlayer();
      _audioPlayer = player;
      player.setReleaseMode(ReleaseMode.loop).catchError((_) {});
      player.play(AssetSource('audio/ringtone.mp3')).catchError((_) {});
    } catch (_) {}
  }

  void _stopAudio() {
    try {
      _audioPlayer?.stop();
      _audioPlayer?.dispose();
      _audioPlayer = null;
    } catch (_) {}
  }

  void _stopTimers() {
    _durationTimer?.cancel();
    _durationTimer = null;
    _ringingTimeoutTimer?.cancel();
    _ringingTimeoutTimer = null;
    _pollingFallbackTimer?.cancel();
    _pollingFallbackTimer = null;
    _disconnectTimer?.cancel();
    _disconnectTimer = null;
    _autoResetTimer?.cancel();
    _autoResetTimer = null;
  }

  @override
  void dispose() {
    _isDisposed = true;
    _busPeerSub?.cancel();
    _busEndedSub?.cancel();
    _busIncomingCallSub?.cancel();
    _busAcceptedSub?.cancel();
    _busPeerJoinedSub?.cancel();
    _stopAudio();
    _stopTimers();
    _cleanupWebrtc();
    super.dispose();
  }
}
