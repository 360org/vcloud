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

  Timer? _durationTimer;
  Timer? _ringingTimeoutTimer;
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

    // 2. Lắng nghe sự kiện đối phương gác máy
    _busEndedSub = bus?.onCallEnded.listen((channelId) {
      if (state != null && state!.channelId == channelId) {
        _handleRemoteHangup();
      }
    });
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

    _playDialingTone();

    // Timeout 30s đổ chuông nếu đối phương không nghe máy
    _startRingingTimeout();

    try {
      // 1. Thử tham gia phòng RTC Call Odoo 19 Core
      final joinResult = await repo.joinCall(channelId: channelId);
      if (_isDisposed) return false;

      if (joinResult != null && joinResult.localSessionId > 0) {
        state = state?.copyWith(id: joinResult.localSessionId);

        // 2. Khởi tạo WebRTC Engine
        _webrtc ??= webrtcEngine ?? ChatV2WebRtcEngine(repo: repo);
        _webrtc!.onConnectionState = (connState) {
          if (connState == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
            _onCallConnected();
          } else if (connState == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
              connState == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
            _handleRemoteHangup();
          }
        };

        await _webrtc!.initialize(
          localSessionId: joinResult.localSessionId,
          targetSessionIds: joinResult.currentRtcSessionIds,
          iceServersData: joinResult.iceServers,
        );

        // 3. Nếu trong phòng đã có Callee, bắt đầu gửi SDP Offer ngay
        if (joinResult.currentRtcSessionIds.isNotEmpty) {
          await _webrtc!.createAndSendOffer();
        }

        return true;
      }

      // Fallback: Odoo 17 / legacy API / unit test fake client
      final session = await repo.initiateCall(
        channelId: channelId,
        receiverId: receiverId,
      );
      if (_isDisposed) return false;

      if (session != null) {
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
        return true;
      }

      state = state?.copyWith(state: ChatV2CallState.failed);
      _stopAudio();
      return false;
    } catch (e) {
      debugPrint('⚠️ Lỗi startCall: $e');
      state = state?.copyWith(state: ChatV2CallState.failed);
      _stopAudio();
      return false;
    }
  }

  /// Khi nhận thông báo FCM Wake-up có cuộc gọi đến (Callee)
  void setIncomingCall(ChatV2CallSession incomingSession) {
    if (state != null && state!.state == ChatV2CallState.connected) {
      return; // Đang bận cuộc gọi khác
    }

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
    if (current == null) return;

    _stopAudio();
    _ringingTimeoutTimer?.cancel();
    state = current.copyWith(state: ChatV2CallState.connecting);

    try {
      // 1. Thử tham gia phòng RTC Odoo 19
      final joinResult = await repo.joinCall(channelId: current.channelId);
      if (_isDisposed) return;

      if (joinResult != null && joinResult.localSessionId > 0) {
        state = current.copyWith(id: joinResult.localSessionId);

        // 2. Khởi tạo WebRTC Engine
        _webrtc ??= webrtcEngine ?? ChatV2WebRtcEngine(repo: repo);
        _webrtc!.onConnectionState = (connState) {
          if (connState == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
            _onCallConnected();
          }
        };

        await _webrtc!.initialize(
          localSessionId: joinResult.localSessionId,
          targetSessionIds: joinResult.currentRtcSessionIds,
          iceServersData: joinResult.iceServers,
        );
        return;
      }

      // Fallback: Odoo 17 / legacy API
      if (current.id != 0) {
        final updated = await repo.acceptCall(current.id);
        if (_isDisposed) return;
        state = (updated ?? current).copyWith(
          state: ChatV2CallState.connected,
          connectedAt: DateTime.now(),
          isCaller: false,
        );
        _startDurationTimer();
        return;
      }

      state = current.copyWith(
        state: ChatV2CallState.connected,
        connectedAt: DateTime.now(),
        isCaller: false,
      );
      _startDurationTimer();
    } catch (e) {
      debugPrint('⚠️ Lỗi acceptCall: $e');
      state = current.copyWith(state: ChatV2CallState.failed);
    }
  }

  /// Callee bấm Từ chối cuộc gọi
  Future<void> rejectCall() async {
    final current = state;
    _stopAudio();
    _stopTimers();

    if (current != null) {
      if (current.id != 0) {
        await repo.rejectCall(current.id);
      }
      await repo.leaveCall(channelId: current.channelId, sessionId: current.id);
    }
    state = current?.copyWith(state: ChatV2CallState.rejected);
    _cleanupWebrtc();
    ChatV2CallKitService.instance.endAllCalls();

    Future.delayed(const Duration(milliseconds: 500), () {
      if (state?.state == ChatV2CallState.rejected) {
        reset();
      }
    });
  }

  /// Caller chủ động Hủy trước khi Callee nghe máy
  Future<void> cancelCall() async {
    final current = state;
    _stopAudio();
    _stopTimers();

    if (current != null) {
      if (current.id != 0) {
        await repo.cancelCall(current.id);
      }
      await repo.cancelCallInvitation(channelId: current.channelId);
      await repo.leaveCall(channelId: current.channelId, sessionId: current.id);
    }
    state = current?.copyWith(state: ChatV2CallState.cancelled);
    _cleanupWebrtc();
    ChatV2CallKitService.instance.endAllCalls();

    Future.delayed(const Duration(milliseconds: 500), () {
      if (state?.state == ChatV2CallState.cancelled) {
        reset();
      }
    });
  }

  /// Gác máy khi đang đàm thoại
  Future<void> endCall() async {
    final current = state;
    _stopAudio();
    _stopTimers();

    if (current != null) {
      if (current.id != 0) {
        await repo.endCall(current.id, duration: current.duration);
      }
      await repo.leaveCall(channelId: current.channelId, sessionId: current.id);
    }
    state = current?.copyWith(state: ChatV2CallState.ended);
    _cleanupWebrtc();
    ChatV2CallKitService.instance.endAllCalls();
  }

  /// Xử lý bản tin WebRTC Signaling nhận từ Odoo Bus
  void _handlePeerNotification(Map<String, dynamic> data) async {
    if (_webrtc == null || state == null) return;

    try {
      final notifications = data['notifications'];
      if (notifications is! List) return;

      for (final rawNotif in notifications) {
        final notifObj = rawNotif is String ? jsonDecode(rawNotif) : rawNotif;
        if (notifObj is! Map) continue;

        final event = notifObj['event']?.toString();
        final payload = notifObj['payload'];
        if (payload is! Map) continue;

        if (event == 'offer') {
          final sdp = payload['sdp'];
          if (sdp is Map) {
            await _webrtc!.handleOfferAndSendAnswer(Map<String, dynamic>.from(sdp));
          }
        } else if (event == 'answer') {
          final sdp = payload['sdp'];
          if (sdp is Map) {
            await _webrtc!.handleAnswer(Map<String, dynamic>.from(sdp));
          }
        } else if (event == 'ice-candidate') {
          final candidate = payload['candidate'];
          if (candidate is Map) {
            await _webrtc!.handleRemoteCandidate(Map<String, dynamic>.from(candidate));
          }
        }
      }
    } catch (e) {
      debugPrint('[CallController] Error processing peer notification: $e');
    }
  }

  void _onCallConnected() {
    _stopAudio();
    _ringingTimeoutTimer?.cancel();
    state = state?.copyWith(
      state: ChatV2CallState.connected,
      connectedAt: DateTime.now(),
    );
    _startDurationTimer();
  }

  void _handleRemoteHangup() {
    _stopAudio();
    _stopTimers();
    state = state?.copyWith(state: ChatV2CallState.ended);
    _cleanupWebrtc();
    ChatV2CallKitService.instance.endAllCalls();
  }

  /// Bật/Tắt Micro
  void toggleMute() {
    _isMuted = !_isMuted;
    _webrtc?.toggleMute();
    if (state != null) {
      state = state!.copyWith(); // re-render
    }
  }

  /// Bật/Tắt Loa ngoài
  void toggleSpeaker() {
    _isSpeaker = !_isSpeaker;
    _webrtc?.toggleSpeaker();
    if (state != null) {
      state = state!.copyWith(); // re-render
    }
  }

  void reset() {
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
    _ringingTimeoutTimer = Timer(const Duration(seconds: 30), () {
      if (state != null &&
          (state!.state == ChatV2CallState.outgoingRinging ||
              state!.state == ChatV2CallState.incomingRinging)) {
        _stopAudio();
        state = state!.copyWith(state: ChatV2CallState.missed);
        _cleanupWebrtc();
        ChatV2CallKitService.instance.endAllCalls();
      }
    });
  }

  void _playDialingTone() {
    _stopAudio();
    try {
      final player = AudioPlayer();
      _audioPlayer = player;
      player.setReleaseMode(ReleaseMode.loop).catchError((_) {});
    } catch (_) {}
  }

  void _playRingtone() {
    _stopAudio();
    try {
      final player = AudioPlayer();
      _audioPlayer = player;
      player.setReleaseMode(ReleaseMode.loop).catchError((_) {});
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
  }

  @override
  void dispose() {
    _isDisposed = true;
    _busPeerSub?.cancel();
    _busEndedSub?.cancel();
    _stopAudio();
    _stopTimers();
    _cleanupWebrtc();
    super.dispose();
  }
}
