import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audioplayers/audioplayers.dart';

import '../data/chat_v2_call_repository.dart';
import '../domain/models/chat_v2_call_session.dart';

final chatV2CallControllerProvider =
    StateNotifierProvider<ChatV2CallController, ChatV2CallSession?>((ref) {
  final repo = ref.watch(chatV2CallRepositoryProvider);
  return ChatV2CallController(repo: repo);
});

class ChatV2CallController extends StateNotifier<ChatV2CallSession?> {
  final ChatV2CallRepository repo;

  Timer? _pollTimer;
  Timer? _durationTimer;
  AudioPlayer? _audioPlayer;

  bool _isMuted = false;
  bool _isSpeaker = false;
  bool _isDisposed = false;
  bool _isPollingInFlight = false;

  bool get isMuted => _isMuted;
  bool get isSpeaker => _isSpeaker;
  ChatV2CallSession? get currentSession => state;

  ChatV2CallController({required this.repo}) : super(null);

  /// Khởi tạo cuộc gọi mới từ phía Caller
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

    // Khởi tạo state tạm thời
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
    );

    try {
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
        _playDialingTone();
        _startSignalingPolling();
        return true;
      } else {
        state = state?.copyWith(state: ChatV2CallState.failed);
        return false;
      }
    } catch (e) {
      debugPrint('⚠️ Lỗi initiateCall: $e');
      state = state?.copyWith(state: ChatV2CallState.failed);
      return false;
    }
  }

  /// Khi nhận được tín hiệu có cuộc gọi đến (Callee)
  void setIncomingCall(ChatV2CallSession incomingSession) {
    if (state != null && state!.state == ChatV2CallState.connected) {
      return; // Đang bận cuộc gọi khác
    }

    state = incomingSession.copyWith(
      state: ChatV2CallState.incomingRinging,
      isCaller: false,
    );

    _playRingtone();
    _startSignalingPolling();
  }

  /// Callee bấm Trả lời
  Future<void> acceptCall() async {
    final current = state;
    if (current == null || current.id == 0) return;

    _stopAudio();
    state = current.copyWith(state: ChatV2CallState.connecting);

    final updated = await repo.acceptCall(current.id);
    if (_isDisposed) return;

    if (updated != null) {
      state = updated.copyWith(
        state: ChatV2CallState.connected,
        connectedAt: DateTime.now(),
        isCaller: false,
      );
      _startDurationTimer();
    } else {
      state = current.copyWith(
        state: ChatV2CallState.connected,
        connectedAt: DateTime.now(),
        isCaller: false,
      );
      _startDurationTimer();
    }
  }

  /// Callee bấm Từ chối
  Future<void> rejectCall() async {
    final current = state;
    _stopAudio();
    _stopTimers();

    if (current != null && current.id != 0) {
      await repo.rejectCall(current.id);
    }
    state = current?.copyWith(state: ChatV2CallState.rejected);

    // Tự động reset state sau 1 khoảng ngắn để sẵn sàng nhận cuộc gọi mới
    Future.delayed(const Duration(milliseconds: 500), () {
      if (state?.state == ChatV2CallState.rejected) {
        reset();
      }
    });
  }

  /// Caller chủ động Hủy
  Future<void> cancelCall() async {
    final current = state;
    _stopAudio();
    _stopTimers();

    if (current != null && current.id != 0) {
      await repo.cancelCall(current.id);
    }
    state = current?.copyWith(state: ChatV2CallState.cancelled);
  }

  /// Gác máy khi đang trong cuộc đàm thoại
  Future<void> endCall() async {
    final current = state;
    _stopAudio();
    _stopTimers();

    if (current != null && current.id != 0) {
      await repo.endCall(current.id, duration: current.duration);
    }
    state = current?.copyWith(state: ChatV2CallState.ended);
  }

  /// Bật/Tắt Micro
  void toggleMute() {
    _isMuted = !_isMuted;
    if (state != null) {
      state = state!.copyWith(); // trigger re-render
    }
  }

  /// Bật/Tắt Loa ngoài
  void toggleSpeaker() {
    _isSpeaker = !_isSpeaker;
    if (state != null) {
      state = state!.copyWith(); // trigger re-render
    }
  }

  /// Đặt lại trạng thái về ban đầu
  void reset() {
    _stopAudio();
    _stopTimers();
    _isMuted = false;
    _isSpeaker = false;
    state = null;
  }

  // ================= PRIVATE HELPERS & TIMERS =================

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

  void _startSignalingPolling() {
    _pollTimer?.cancel();
    _scheduleNextPoll();
  }

  void _scheduleNextPoll() {
    if (_isDisposed || state == null) return;

    final currentState = state!.state;
    if (currentState == ChatV2CallState.ended ||
        currentState == ChatV2CallState.rejected ||
        currentState == ChatV2CallState.missed ||
        currentState == ChatV2CallState.cancelled ||
        currentState == ChatV2CallState.failed) {
      return;
    }

    // Fast polling 1s khi chuông reo/kết nối; 5s khi đã kết nối
    final interval = (currentState == ChatV2CallState.connected)
        ? const Duration(seconds: 5)
        : const Duration(seconds: 1);

    _pollTimer = Timer(interval, () async {
      if (_isDisposed || state == null || _isPollingInFlight) return;

      _isPollingInFlight = true;
      try {
        if (state!.id != 0) {
          final updated = await repo.getCallSession(state!.id);
          if (!_isDisposed && updated != null && state != null) {
            _handleSessionUpdate(updated);
          }
        }
      } catch (_) {
      } finally {
        _isPollingInFlight = false;
        if (!_isDisposed) {
          _scheduleNextPoll();
        }
      }
    });
  }

  void _handleSessionUpdate(ChatV2CallSession updated) {
    if (state == null) return;

    final localState = state!;

    // Luôn ưu tiên thông tin local (Tên/Avatar) đã có sẵn để tránh bị server đè mất
    // (VD: Server đôi khi trả về null avatar hoặc tên mặc định)
    final safeUpdated = updated.copyWith(
      callerName: (localState.callerName != 'Người gọi' && localState.callerName.isNotEmpty)
          ? localState.callerName
          : updated.callerName,
      callerAvatar: (localState.callerAvatar != null && localState.callerAvatar!.isNotEmpty)
          ? localState.callerAvatar
          : updated.callerAvatar,
      receiverName: (localState.receiverName != 'Người nhận' && localState.receiverName.isNotEmpty)
          ? localState.receiverName
          : updated.receiverName,
      receiverAvatar: (localState.receiverAvatar != null && localState.receiverAvatar!.isNotEmpty)
          ? localState.receiverAvatar
          : updated.receiverAvatar,
    );

    // Nếu trạng thái đổi sang connected từ phía người nhận
    if (localState.state == ChatV2CallState.outgoingRinging &&
        safeUpdated.state == ChatV2CallState.connected) {
      _stopAudio();
      state = safeUpdated.copyWith(
        state: ChatV2CallState.connected,
        connectedAt: DateTime.now(),
        isCaller: true,
      );
      _startDurationTimer();
      return;
    }

    // Nếu bị từ chối / hủy / kết thúc
    if (updated.state == ChatV2CallState.rejected ||
        updated.state == ChatV2CallState.cancelled ||
        updated.state == ChatV2CallState.missed ||
        updated.state == ChatV2CallState.ended) {
      _stopAudio();
      _stopTimers();
      state = state!.copyWith(state: updated.state, duration: updated.duration);
    }
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
    _pollTimer?.cancel();
    _pollTimer = null;
    _durationTimer?.cancel();
    _durationTimer = null;
  }

  @override
  void dispose() {
    _isDisposed = true;
    _stopAudio();
    _stopTimers();
    super.dispose();
  }
}
