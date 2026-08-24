import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/api/odoo_api_client.dart';
import '../../application/chat_v2_call_controller.dart';
import '../../domain/models/chat_v2_call_session.dart';
import '../screens/chat_v2_call_screen.dart';

class ChatV2IncomingCallDialog extends ConsumerWidget {
  final ChatV2CallSession session;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;

  const ChatV2IncomingCallDialog({
    super.key,
    required this.session,
    this.onAccept,
    this.onReject,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(chatV2CallControllerProvider.notifier);

    // Tự động đóng nếu session không còn incomingRinging
    // Widget này nằm trong Stack của ChatV2CallListener, khi state đổi nó sẽ tự biến mất khỏi cây widget.
    // KHÔNG dùng Navigator.pop ở đây vì nó sẽ pop màn hình chat ở dưới.
    ref.listen<ChatV2CallSession?>(chatV2CallControllerProvider, (prev, next) {
      // Không làm gì, ChatV2CallListener sẽ tự unmount widget này
    });

    final callerName = session.callerName;
    final callerAvatar = session.callerAvatar;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 24),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A), // Slate 900
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.6),
              blurRadius: 30,
              spreadRadius: 8,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Avatar đập nhịp
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1E293B),
                border: Border.all(color: const Color(0xFF10B981), width: 2.5),
              ),
              child: ClipOval(
                child: _buildAvatarImage(callerAvatar, callerName),
              ),
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(
                  begin: const Offset(1.0, 1.0),
                  end: const Offset(1.1, 1.1),
                  duration: 800.ms,
                  curve: Curves.easeInOut,
                ),

            const SizedBox(height: 18),

            // Tên người gọi đến
            Text(
              callerName,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.3,
              ),
            ),

            const SizedBox(height: 6),

            // Tiêu đề
            const Text(
              'Cuộc gọi thoại đến...',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Color(0xFF10B981),
              ),
            ),

            const SizedBox(height: 28),

            // Bộ đôi nút bấm Nhận / Từ chối
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Nút Từ chối 🔴
                _buildActionButton(
                  icon: LucideIcons.phoneOff,
                  label: 'Từ chối',
                  color: const Color(0xFFEF4444),
                  onPressed: onReject ?? () {
                    controller.rejectCall();
                  },
                ),

                // Nút Trả lời 🟢
                _buildActionButton(
                  icon: LucideIcons.phone,
                  label: 'Trả lời',
                  color: const Color(0xFF10B981),
                  onPressed: onAccept ?? () async {
                    await controller.acceptCall();
                    if (context.mounted) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          fullscreenDialog: true,
                          builder: (_) => const ChatV2CallScreen(),
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            splashFactory: InkRipple.splashFactory,
            borderRadius: BorderRadius.circular(30),
            child: Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Icon(icon, size: 26, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }
}
