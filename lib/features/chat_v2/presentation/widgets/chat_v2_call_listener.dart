import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/router/app_router.dart';
import '../../application/chat_v2_call_controller.dart';
import '../../application/chat_v2_callkit_service.dart';
import '../../application/chat_v2_call_watcher.dart';
import '../../domain/models/chat_v2_call_session.dart';
import '../screens/chat_v2_call_screen.dart';
import 'chat_v2_incoming_call_dialog.dart';
import 'chat_v2_in_app_banner.dart';

/// Widget bao bọc toàn ứng dụng (Global Call Overlay Listener)
/// Tự động hiển thị popup cuộc gọi đến và xử lý chuyển tiếp màn hình đàm thoại
class ChatV2CallListener extends ConsumerStatefulWidget {
  const ChatV2CallListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ChatV2CallListener> createState() => _ChatV2CallListenerState();
}

class _ChatV2CallListenerState extends ConsumerState<ChatV2CallListener> {
  bool _isHandlingAction = false;
  int? _handlingCallId;

  @override
  Widget build(BuildContext context) {
    // Kích hoạt Call Watcher để định kỳ thăm dò active call từ server
    ref.watch(chatV2CallWatcherProvider);

    final callSession = ref.watch(chatV2CallControllerProvider);

    // Reset trạng thái xử lý khi cuộc gọi kết thúc hoặc đổi ID phiên
    if (callSession == null ||
        callSession.state != ChatV2CallState.incomingRinging ||
        (_handlingCallId != null && callSession.id != _handlingCallId)) {
      _isHandlingAction = false;
      _handlingCallId = null;
    }

    final isIncoming = !_isHandlingAction &&
        callSession != null &&
        callSession.state == ChatV2CallState.incomingRinging &&
        !callSession.isCaller &&
        !ChatV2CallKitService.instance.hasActiveIncomingCall;

    return Stack(
      children: [
        widget.child,
        const InAppNotificationBanner(),
        if (isIncoming)
          Positioned.fill(
            child: Material(
              color: Colors.black54,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: ChatV2IncomingCallDialog(
                    session: callSession,
                    onAccept: () async {
                      if (_isHandlingAction) return;
                      setState(() {
                        _isHandlingAction = true;
                        _handlingCallId = callSession.id;
                      });

                      // Đóng CallKit an toàn khi bấm Chấp nhận cuộc gọi (Chống Deadly Loop)
                      await ChatV2CallKitService.instance.dismissCallKitOnAccept();

                      final nav = ref.read(routerProvider).routerDelegate.navigatorKey.currentState;

                      // Mở màn hình đàm thoại toàn màn hình
                      nav?.push(
                        MaterialPageRoute(
                          fullscreenDialog: true,
                          builder: (_) => const ChatV2CallScreen(),
                        ),
                      );

                      await ref.read(chatV2CallControllerProvider.notifier).acceptCall();
                    },
                    onReject: () async {
                      if (_isHandlingAction) return;
                      setState(() {
                        _isHandlingAction = true;
                        _handlingCallId = callSession.id;
                      });

                      // Đóng CallKit banner thông báo
                      await ChatV2CallKitService.instance.endAllCalls();

                      await ref.read(chatV2CallControllerProvider.notifier).rejectCall();
                    },
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
