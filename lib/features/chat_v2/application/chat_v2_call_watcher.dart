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
    if (kIsWeb) return;
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
        if (currentCallState != null &&
            currentCallState.id != active.id &&
            currentCallState.state != ChatV2CallState.idle) {
          // Nếu cùng channel hoặc id = 0: cập nhật Session ID thay vì reset
          if (currentCallState.channelId == active.channelId || currentCallState.id == 0) {
            debugPrint('[RTC_CALL_LOG][SIGNAL] Watcher: Đồng bộ Call ID server (${active.id}) cho session hiện tại');
            ref.read(chatV2CallControllerProvider.notifier).updateSessionId(active.id);
            return;
          }

          if (currentCallState.state == ChatV2CallState.connected) {
            debugPrint('[RTC_CALL_LOG][SIGNAL] Đang connected mà server có cuộc gọi khác (ID: ${active.id}) -> Kích hoạt Fast-Busy');
            ref.read(chatV2CallControllerProvider.notifier).setIncomingCall(active);
            return;
          }

          final isRingingOrConnecting = currentCallState.state == ChatV2CallState.outgoingRinging ||
              currentCallState.state == ChatV2CallState.incomingRinging ||
              currentCallState.state == ChatV2CallState.connecting;
          if (!isRingingOrConnecting) {
            debugPrint('[RTC_CALL_LOG][END] Watcher: Phát hiện server đổi Call ID (cũ: ${currentCallState.id}, mới: ${active.id}) -> Reset state cũ');
            ref.read(chatV2CallControllerProvider.notifier).reset();
            return;
          }
        }

        // Nếu có cuộc gọi đến và controller đang rảnh
        if (active.state == ChatV2CallState.incomingRinging &&
            !active.isCaller &&
            (currentCallState == null || currentCallState.state == ChatV2CallState.idle)) {
          debugPrint('[RTC_CALL_LOG][INIT] Watcher phát hiện cuộc gọi đến từ ${active.callerName} (ID: ${active.id}, Kênh: ${active.channelId})');
          ref.read(chatV2CallControllerProvider.notifier).setIncomingCall(active);
        } else if (currentCallState != null &&
            (currentCallState.id == active.id || (currentCallState.id == 0 && currentCallState.channelId == active.channelId))) {
          // Nếu cuộc gọi phía người gọi đã bị hủy/kết thúc trong lúc chuông đang reo
          if (active.state == ChatV2CallState.cancelled ||
              active.state == ChatV2CallState.missed ||
              active.state == ChatV2CallState.ended ||
              active.state == ChatV2CallState.rejected) {
            debugPrint('[RTC_CALL_LOG][END] Watcher: Cuộc gọi ${active.id} đã kết thúc từ phía người gọi: ${active.state}');
            ref.read(chatV2CallControllerProvider.notifier).handleRemoteHangup(
                  endState: active.state.name,
                  reason: active.endReason,
                );
          }
        }
      } else {
        // Nếu server không còn active call nào:
        if (currentCallState != null) {
          final isCallActive = currentCallState.state == ChatV2CallState.outgoingRinging ||
              currentCallState.state == ChatV2CallState.incomingRinging ||
              currentCallState.state == ChatV2CallState.connecting ||
              currentCallState.state == ChatV2CallState.connected;

          if (!isCallActive) {
            // Chỉ cleanup khi cuộc gọi đã ở trạng thái kết thúc (ended, rejected, missed, cancelled, failed)
            debugPrint('[RTC_CALL_LOG][END] Watcher cleanup: Không còn active call trên server -> Reset state ${currentCallState.state}');
            ref.read(chatV2CallControllerProvider.notifier).reset();
          } else if (currentCallState.state == ChatV2CallState.outgoingRinging ||
              currentCallState.state == ChatV2CallState.incomingRinging) {
            // Tra cứu trạng thái thực tế từ endpoint /status để cập nhật kịp thời khi đối phương từ chối hoặc hủy
            try {
              final status = await repo.getCallStatus(
                callId: currentCallState.id > 0 ? currentCallState.id : null,
                channelId: currentCallState.channelId > 0 ? currentCallState.channelId : null,
              );
              if (status != null &&
                  (status.state == ChatV2CallState.rejected ||
                      status.state == ChatV2CallState.cancelled ||
                      status.state == ChatV2CallState.ended ||
                      status.state == ChatV2CallState.missed)) {
                debugPrint('[RTC_CALL_LOG][END] Watcher: /status báo cuộc gọi đã kết thúc: ${status.state}');
                ref.read(chatV2CallControllerProvider.notifier).handleRemoteHangup(
                      endState: status.state.name,
                      reason: status.endReason,
                    );
              }
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      debugPrint('[RTC_CALL_LOG][SIGNAL] ⚠️ Watcher error checking active call: $e');
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
