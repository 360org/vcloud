import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/router/app_router.dart';

import '../../application/chat_v2_call_controller.dart';
import '../../application/chat_v2_call_watcher.dart';
import '../../domain/models/chat_v2_call_session.dart';
import '../screens/chat_v2_call_screen.dart';
import 'chat_v2_incoming_call_dialog.dart';

/// Widget bao bọc toàn ứng dụng (Global Call Overlay Listener)
/// Tự động hiển thị popup cuộc gọi đến và xử lý chuyển tiếp màn hình đàm thoại
class ChatV2CallListener extends ConsumerWidget {
  const ChatV2CallListener({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Kích hoạt Call Watcher để định kỳ thăm dò active call từ server
    ref.watch(chatV2CallWatcherProvider);

    final callSession = ref.watch(chatV2CallControllerProvider);
    final isIncoming = callSession != null &&
        callSession.state == ChatV2CallState.incomingRinging &&
        !callSession.isCaller;

    return Stack(
      children: [
        child,
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
                      // Lưu navigatorKey trước khi await để tránh lỗi context.mounted khi dialog bị gỡ khỏi cây widget
                      final nav = ref.read(routerProvider).routerDelegate.navigatorKey.currentState;
                      
                      await ref.read(chatV2CallControllerProvider.notifier).acceptCall();
                      
                      nav?.push(
                        MaterialPageRoute(
                          fullscreenDialog: true,
                          builder: (_) => const ChatV2CallScreen(),
                        ),
                      );
                    },
                    onReject: () async {
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
