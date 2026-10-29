import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/router/app_router.dart';
import '../../application/chat_v2_call_controller.dart';
import '../../application/chat_v2_callkit_service.dart';
import '../../domain/models/chat_v2_call_session.dart';
import '../screens/chat_v2_call_screen.dart';
import 'chat_v2_in_app_banner.dart';

/// Widget bao bọc toàn ứng dụng (Global Call Overlay Listener)
/// Lắng nghe CallKit events khi user bấm Accept để mở màn hình đàm thoại ChatV2CallScreen
class ChatV2CallListener extends ConsumerStatefulWidget {
  const ChatV2CallListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<ChatV2CallListener> createState() => _ChatV2CallListenerState();
}

class _ChatV2CallListenerState extends ConsumerState<ChatV2CallListener> {
  @override
  void initState() {
    super.initState();
    _setupCallKitListener();
  }

  void _setupCallKitListener() {
    ChatV2CallKitService.instance.initialize(
      onAccept: (extra) async {
        final channelId = int.tryParse(extra['channel_id']?.toString() ?? '0') ?? 0;
        final callerId = int.tryParse(extra['caller_id']?.toString() ?? '0') ?? 0;
        final callerName = extra['caller_name']?.toString() ?? 'Đồng nghiệp';
        final callId = int.tryParse(extra['call_id']?.toString() ?? '0') ?? 0;

        if (channelId > 0) {
          final incomingSession = ChatV2CallSession(
            id: callId,
            channelId: channelId,
            callerId: callerId,
            callerName: callerName,
            receiverId: 0,
            receiverName: 'Tôi',
            state: ChatV2CallState.incomingRinging,
            isCaller: false,
          );
          ref.read(chatV2CallControllerProvider.notifier).setIncomingCall(incomingSession);
        }

        await ChatV2CallKitService.instance.dismissCallKitOnAccept();

        final nav = ref.read(routerProvider).routerDelegate.navigatorKey.currentState;
        nav?.push(
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (_) => const ChatV2CallScreen(),
          ),
        );

        await ref.read(chatV2CallControllerProvider.notifier).acceptCall();
      },
      onDecline: (extra) async {
        await ref.read(chatV2CallControllerProvider.notifier).rejectCall();
      },
      onEnd: (extra) async {
        final current = ref.read(chatV2CallControllerProvider);
        if (current != null &&
            (current.state == ChatV2CallState.connecting ||
                current.state == ChatV2CallState.connected)) {
          return;
        }
        await ref.read(chatV2CallControllerProvider.notifier).endCall();
      },
      onTimeout: (extra) async {
        ref.read(chatV2CallControllerProvider.notifier).reset();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        const InAppNotificationBanner(),
      ],
    );
  }
}
