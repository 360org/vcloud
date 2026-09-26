import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../data/chat_v2_call_repository.dart';
import '../domain/models/chat_v2_call_session.dart';
import 'chat_v2_call_controller.dart';

/// Provider tự động theo dõi và lắng nghe cuộc gọi đến trên toàn ứng dụng (Foreground In-App Call Watcher)
final chatV2CallWatcherProvider = Provider<ChatV2CallWatcher>((ref) {
  final repo = ref.watch(chatV2CallRepositoryProvider);
  final user = ref.watch(authControllerProvider).valueOrNull;

  final watcher = ChatV2CallWatcher(ref: ref, repo: repo, isLoggedIn: user != null);
  ref.onDispose(() {
    watcher.dispose();
  });
  return watcher;
});

class ChatV2CallWatcher {
  ChatV2CallWatcher({
    required this.ref,
    required this.repo,
    required this.isLoggedIn,
  }) {
    if (isLoggedIn) {
      _startWatching();
    }
  }

  final Ref ref;
  final ChatV2CallRepository repo;
  final bool isLoggedIn;

  Timer? _watchTimer;
  bool _isDisposed = false;
  bool _isChecking = false;
  bool _isAppForegrounded = true;

  void _startWatching() {
    _checkActiveCall();
    _scheduleNextCheck(const Duration(seconds: 4));
  }

  void _scheduleNextCheck(Duration delay) {
    if (_isDisposed || !isLoggedIn || !_isAppForegrounded) return;
    _watchTimer?.cancel();
    _watchTimer = Timer(delay, _checkActiveCall);
  }

  /// Gọi khi app quay trở lại foreground
  void onAppResumed() {
    _isAppForegrounded = true;
    _checkActiveCall();
    _scheduleNextCheck(const Duration(seconds: 4));
  }

  /// Gọi khi app bị thu nhỏ / vào background
  void onAppPaused() {
    _isAppForegrounded = false;
    _watchTimer?.cancel();
    _watchTimer = null;
  }

  Future<void> _checkActiveCall() async {
    if (_isDisposed || !isLoggedIn || _isChecking) return;
    _isChecking = true;

    try {
      final active = await repo.getActiveCall();
      if (_isDisposed) return;

      final currentCallState = ref.read(chatV2CallControllerProvider);

      if (active != null) {
        if (currentCallState != null && currentCallState.id != active.id && currentCallState.state != ChatV2CallState.idle) {
          if (currentCallState.state == ChatV2CallState.connected) {
            debugPrint('⚠️ [CALL_WATCHER] Đang connected mà server có cuộc gọi khác (ID: ${active.id}) -> Kích hoạt Fast-Busy');
            ref.read(chatV2CallControllerProvider.notifier).setIncomingCall(active);
            return;
          }
          debugPrint('⚠️ [CALL_WATCHER] Phát hiện server đổi Call ID (cũ: ${currentCallState.id}, mới: ${active.id}) -> Reset state cũ bị kẹt');
          ref.read(chatV2CallControllerProvider.notifier).reset();
          return;
        }

        // Nếu có cuộc gọi đến và controller đang rảnh
        if (active.state == ChatV2CallState.incomingRinging &&
            !active.isCaller &&
            (currentCallState == null || currentCallState.state == ChatV2CallState.idle)) {
          debugPrint('📞 [CALL_WATCHER] Phát hiện cuộc gọi đến từ ${active.callerName} (ID: ${active.id})');
          ref.read(chatV2CallControllerProvider.notifier).setIncomingCall(active);
        } else if (currentCallState != null &&
            currentCallState.id == active.id &&
            currentCallState.state == ChatV2CallState.incomingRinging) {
          // Nếu cuộc gọi phía người gọi đã bị hủy/kết thúc trong lúc chuông đang reo
          if (active.state == ChatV2CallState.cancelled ||
              active.state == ChatV2CallState.missed ||
              active.state == ChatV2CallState.ended ||
              active.state == ChatV2CallState.rejected) {
            debugPrint('📵 [CALL_WATCHER] Cuộc gọi ${active.id} đã kết thúc từ phía người gọi: ${active.state}');
            ref.read(chatV2CallControllerProvider.notifier).reset();
          }
        }
      } else {
        // Nếu server không còn active call nào:
        if (currentCallState != null) {
          // 1. Máy nhận vẫn đang đổ chuông incomingRinging -> reset
          if (currentCallState.state == ChatV2CallState.incomingRinging && !currentCallState.isCaller) {
            debugPrint('📵 [CALL_WATCHER] Không còn active call trên server -> Reset incoming call dialog');
            ref.read(chatV2CallControllerProvider.notifier).reset();
          }
          // 2. Máy gọi đang đổ chuông (outgoingRinging) nhưng server không còn active call
          // -> Tra cứu nhanh session xem đã bị rejected/cancelled chưa để cập nhật ngay
          else if (currentCallState.state == ChatV2CallState.outgoingRinging && currentCallState.isCaller && currentCallState.id > 0) {
            final endedSession = await repo.getCallSession(currentCallState.id);
            if (_isDisposed) return;
            if (endedSession != null &&
                (endedSession.state == ChatV2CallState.rejected ||
                 endedSession.state == ChatV2CallState.cancelled ||
                 endedSession.state == ChatV2CallState.ended ||
                 endedSession.state == ChatV2CallState.missed)) {
              debugPrint('📵 [CALL_WATCHER] Cuộc gọi đi ${currentCallState.id} đã kết thúc từ server: ${endedSession.state}');
              ref.read(chatV2CallControllerProvider.notifier).setIncomingCall(endedSession);
            }
          }
          // 3. Cleanup trạng thái kẹt
          else if (currentCallState.state == ChatV2CallState.ended ||
                   currentCallState.state == ChatV2CallState.rejected ||
                   currentCallState.state == ChatV2CallState.missed ||
                   currentCallState.state == ChatV2CallState.cancelled ||
                   currentCallState.state == ChatV2CallState.failed) {
            ref.read(chatV2CallControllerProvider.notifier).reset();
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ [CALL_WATCHER] Error checking active call: $e');
    } finally {
      _isChecking = false;
      _scheduleNextCheck(const Duration(seconds: 4));
    }
  }

  void dispose() {
    _isDisposed = true;
    _watchTimer?.cancel();
    _watchTimer = null;
  }
}
