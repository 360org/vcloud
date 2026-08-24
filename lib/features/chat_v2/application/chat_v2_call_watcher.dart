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

  void _startWatching() {
    _scheduleNextCheck(const Duration(milliseconds: 1500));
  }

  void _scheduleNextCheck(Duration delay) {
    if (_isDisposed || !isLoggedIn) return;
    _watchTimer?.cancel();
    _watchTimer = Timer(delay, _checkActiveCall);
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
        // Nếu server không còn active call nào nhưng máy nhận vẫn đang đổ chuông incomingRinging -> reset
        if (currentCallState != null &&
            currentCallState.state == ChatV2CallState.incomingRinging &&
            !currentCallState.isCaller) {
          debugPrint('📵 [CALL_WATCHER] Không còn active call trên server -> Reset incoming call dialog');
          ref.read(chatV2CallControllerProvider.notifier).reset();
        } else if (currentCallState != null &&
            (currentCallState.state == ChatV2CallState.ended ||
             currentCallState.state == ChatV2CallState.rejected ||
             currentCallState.state == ChatV2CallState.missed ||
             currentCallState.state == ChatV2CallState.cancelled ||
             currentCallState.state == ChatV2CallState.failed)) {
          // Cleanup trạng thái kẹt
          ref.read(chatV2CallControllerProvider.notifier).reset();
        }
      }
    } catch (e) {
      debugPrint('⚠️ [CALL_WATCHER] Error checking active call: $e');
    } finally {
      _isChecking = false;
      _scheduleNextCheck(const Duration(milliseconds: 2000));
    }
  }

  void dispose() {
    _isDisposed = true;
    _watchTimer?.cancel();
    _watchTimer = null;
  }
}
