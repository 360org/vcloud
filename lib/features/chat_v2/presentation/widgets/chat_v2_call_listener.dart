import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/api/odoo_api_client.dart';
import '../../../../core/router/app_router.dart';
import '../../application/chat_v2_call_controller.dart';
import '../../application/chat_v2_callkit_service.dart';
import '../../domain/models/chat_v2_call_session.dart';
import '../screens/chat_v2_call_screen.dart';
import 'chat_v2_in_app_banner.dart';

/// Widget bao bọc toàn ứng dụng (Global Call Overlay Listener)
/// Lắng nghe CallKit events khi user bấm Accept để mở màn hình đàm thoại ChatV2CallScreen
/// và hiển thị In-App Incoming Call Banner khi app đang mở ở Foreground
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

  void _navigateToCallScreen() {
    final nav = ref.read(routerProvider).routerDelegate.navigatorKey.currentState;
    nav?.push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const ChatV2CallScreen(),
      ),
    );
  }

  Widget _buildAvatar(String? avatarUrl, String displayName) {
    if (avatarUrl == null || avatarUrl.trim().isEmpty) {
      return _buildInitials(displayName);
    }
    final trimmed = avatarUrl.trim();
    final resolvedUrl = odooApiClient.resolveAvatarUrl(trimmed);
    if (resolvedUrl == null || resolvedUrl.isEmpty) {
      return _buildInitials(displayName);
    }

    final token = odooApiClient.session?.accessToken;
    final headers = <String, String>{};
    if (token != null && token.isNotEmpty) {
      headers['Cookie'] = 'session_id=$token';
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Image.network(
        resolvedUrl,
        headers: headers,
        width: 48,
        height: 48,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _buildInitials(displayName),
      ),
    );
  }

  Widget _buildInitials(String name) {
    final initials = name.trim().isNotEmpty
        ? name.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join()
        : 'U';
    return Container(
      width: 48,
      height: 48,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFF334155),
      ),
      alignment: Alignment.center,
      child: Text(
        initials.toUpperCase(),
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildInAppIncomingCallBanner(BuildContext context, ChatV2CallSession session) {
    final topPadding = MediaQuery.paddingOf(context).top + 8;

    return Positioned(
      top: topPadding,
      left: 12,
      right: 12,
      child: Material(
        type: MaterialType.transparency,
        child: GestureDetector(
          onTap: _navigateToCallScreen,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B).withValues(alpha: 0.97),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFF10B981).withValues(alpha: 0.5),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  blurRadius: 16,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // Avatar người gọi
                _buildAvatar(session.callerAvatar, session.callerName),
                const SizedBox(width: 12),

                // Tên & trạng thái cuộc gọi đến
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.callerName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      const Row(
                        children: [
                          Icon(
                            LucideIcons.phoneIncoming,
                            size: 13,
                            color: Color(0xFF34D399),
                          ),
                          SizedBox(width: 5),
                          Text(
                            'Cuộc gọi thoại đến...',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF34D399),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Nút Từ chối (Đỏ)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      ref.read(chatV2CallControllerProvider.notifier).rejectCall();
                    },
                    borderRadius: BorderRadius.circular(22),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        LucideIcons.phoneOff,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Nút Trả lời (Xanh lá)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      _navigateToCallScreen();
                      ref.read(chatV2CallControllerProvider.notifier).acceptCall();
                    },
                    borderRadius: BorderRadius.circular(22),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        LucideIcons.phoneCall,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      )
          .animate()
          .slideY(begin: -1.2, end: 0, duration: 350.ms, curve: Curves.easeOutBack)
          .fade(duration: 250.ms),
    );
  }

  @override
  Widget build(BuildContext context) {
    final callSession = ref.watch(chatV2CallControllerProvider);
    final isIncomingRinging = callSession?.state == ChatV2CallState.incomingRinging;

    return Stack(
      children: [
        widget.child,
        const InAppNotificationBanner(),
        if (isIncomingRinging && callSession != null)
          _buildInAppIncomingCallBanner(context, callSession),
      ],
    );
  }
}
