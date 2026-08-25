import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/api/odoo_api_client.dart';
import '../../application/chat_v2_call_controller.dart';
import '../../domain/models/chat_v2_call_session.dart';

class ChatV2CallScreen extends ConsumerStatefulWidget {
  const ChatV2CallScreen({super.key});

  @override
  ConsumerState<ChatV2CallScreen> createState() => _ChatV2CallScreenState();
}

class _ChatV2CallScreenState extends ConsumerState<ChatV2CallScreen> {
  @override
  Widget build(BuildContext context) {
    final session = ref.watch(chatV2CallControllerProvider);
    final controller = ref.read(chatV2CallControllerProvider.notifier);

    // Tự động đóng màn hình sau 1.2s nếu cuộc gọi kết thúc/bị từ chối
    ref.listen<ChatV2CallSession?>(chatV2CallControllerProvider, (prev, next) {
      if (next != null) {
        if (next.state == ChatV2CallState.ended ||
            next.state == ChatV2CallState.rejected ||
            next.state == ChatV2CallState.missed ||
            next.state == ChatV2CallState.cancelled ||
            next.state == ChatV2CallState.failed) {
          final nav = Navigator.of(context);
          Future.delayed(const Duration(milliseconds: 1200), () {
            if (mounted && nav.canPop()) {
              nav.pop();
            }
            controller.reset();
          });
        }
      }
    });

    final isCaller = session?.isCaller ?? true;
    final displayName = isCaller
        ? (session?.receiverName ?? 'Người nhận')
        : (session?.callerName ?? 'Người gọi');
    final avatarUrl = isCaller ? session?.receiverAvatar : session?.callerAvatar;

    String statusText = 'Đang gọi...';
    Color statusColor = Colors.white70;

    if (session != null) {
      switch (session.state) {
        case ChatV2CallState.outgoingRinging:
          statusText = 'Đang đổ chuông...';
          break;
        case ChatV2CallState.incomingRinging:
          statusText = 'Cuộc gọi đến...';
          break;
        case ChatV2CallState.connecting:
          statusText = 'Đang kết nối...';
          break;
        case ChatV2CallState.connected:
          statusText = session.formattedDuration;
          statusColor = const Color(0xFF10B981); // Emerald green
          break;
        case ChatV2CallState.ended:
          statusText = 'Cuộc gọi đã kết thúc (${session.formattedDuration})';
          break;
        case ChatV2CallState.rejected:
          statusText = 'Cuộc gọi bị từ chối';
          statusColor = const Color(0xFFEF4444);
          break;
        case ChatV2CallState.missed:
          statusText = 'Không có phản hồi';
          statusColor = const Color(0xFFEF4444);
          break;
        case ChatV2CallState.cancelled:
          statusText = 'Đã hủy cuộc gọi';
          break;
        case ChatV2CallState.failed:
          statusText = 'Lỗi kết nối';
          statusColor = const Color(0xFFEF4444);
          break;
        default:
          statusText = 'Đang kết nối...';
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Slate 900
      body: SafeArea(
        child: Stack(
          children: [
            // Nội dung chính
            Center(
              child: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top - MediaQuery.of(context).padding.bottom,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 24),

                        // Avatar đập nhịp tỏa sóng
                        _buildPulsingAvatar(avatarUrl, displayName, session?.state),

                        const SizedBox(height: 28),

                        // Tên người nhận
                        Text(
                          displayName,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),

                        const SizedBox(height: 10),

                        // Trạng thái / Đồng hồ đếm giờ
                        Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: statusColor,
                          ),
                        ),

                        const Spacer(),

                        // Bảng điều khiển cuộc gọi
                        _buildCallControls(context, session, controller),

                        const SizedBox(height: 48),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPulsingAvatar(String? avatarUrl, String displayName, ChatV2CallState? state) {
    final isRinging = state == ChatV2CallState.outgoingRinging ||
        state == ChatV2CallState.incomingRinging;

    final Widget avatarWidget = Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF1E293B),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            spreadRadius: 4,
          ),
        ],
      ),
      child: ClipOval(
        child: _buildAvatarImage(avatarUrl, displayName),
      ),
    );

    if (isRinging) {
      return avatarWidget
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scale(
            begin: const Offset(1.0, 1.0),
            end: const Offset(1.08, 1.08),
            duration: 900.ms,
            curve: Curves.easeInOut,
          );
    }

    return avatarWidget;
  }

  Widget _buildAvatarImage(String? avatarUrl, String displayName) {
    if (avatarUrl == null || avatarUrl.trim().isEmpty) {
      return _buildInitials(displayName);
    }
    final trimmed = avatarUrl.trim();
    if (trimmed.startsWith('data:image') || (!trimmed.contains('/') && trimmed.length > 80)) {
      try {
        final comma = trimmed.indexOf(',');
        final b64 = comma != -1 ? trimmed.substring(comma + 1) : trimmed;
        return Image.memory(
          base64Decode(b64),
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, _, _) => _buildInitials(displayName),
        );
      } catch (_) {
        return _buildInitials(displayName);
      }
    }
    final resolvedUrl = odooApiClient.resolveAvatarUrl(trimmed);
    if (resolvedUrl == null || resolvedUrl.isEmpty) {
      return _buildInitials(displayName);
    }

    // Gắn session_id để tải ảnh có yêu cầu đăng nhập trên Odoo
    final token = odooApiClient.session?.accessToken;
    final headers = <String, String>{};
    if (token != null && token.isNotEmpty) {
      headers['Cookie'] = 'session_id=$token';
    }

    return Image.network(
      resolvedUrl,
      headers: headers,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => _buildInitials(displayName),
    );
  }

  Widget _buildInitials(String name) {
    final initials = name.trim().isNotEmpty
        ? name.trim().split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join()
        : 'U';
    return Container(
      color: const Color(0xFF334155),
      alignment: Alignment.center,
      child: Text(
        initials.toUpperCase(),
        style: const TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildCallControls(
    BuildContext context,
    ChatV2CallSession? session,
    ChatV2CallController controller,
  ) {
    final isConnected = session?.state == ChatV2CallState.connected;
    final isOutgoing = session?.state == ChatV2CallState.outgoingRinging;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Nút Mute
          _buildCircleButton(
            icon: controller.isMuted ? LucideIcons.micOff : LucideIcons.mic,
            label: controller.isMuted ? 'Bật mic' : 'Tắt mic',
            isActive: controller.isMuted,
            onPressed: isConnected ? controller.toggleMute : null,
          ),

          // Nút Gác máy / Hủy cuộc gọi (Màu đỏ lớn)
          _buildHangupButton(
            onPressed: () {
              if (isOutgoing) {
                controller.cancelCall();
              } else {
                controller.endCall();
              }
            },
          ),

          // Nút Loa ngoài
          _buildCircleButton(
            icon: controller.isSpeaker ? LucideIcons.volume2 : LucideIcons.volumeX,
            label: controller.isSpeaker ? 'Loa trong' : 'Loa ngoài',
            isActive: controller.isSpeaker,
            onPressed: isConnected ? controller.toggleSpeaker : null,
          ),
        ],
      ),
    );
  }

  Widget _buildCircleButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback? onPressed,
  }) {
    final isEnabled = onPressed != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(32),
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive
                    ? Colors.white
                    : (isEnabled ? const Color(0xFF334155) : const Color(0xFF1E293B)),
                border: Border.all(
                  color: Colors.white.withValues(alpha: isEnabled ? 0.15 : 0.05),
                ),
              ),
              child: Icon(
                icon,
                size: 24,
                color: isActive
                    ? const Color(0xFF0F172A)
                    : (isEnabled ? Colors.white : Colors.white38),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isEnabled ? Colors.white70 : Colors.white30,
          ),
        ),
      ],
    );
  }

  Widget _buildHangupButton({required VoidCallback onPressed}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(36),
            child: Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFEF4444), // Red 500
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                LucideIcons.phoneOff,
                size: 30,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Kết thúc',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFFFCA5A5),
          ),
        ),
      ],
    );
  }
}
