import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:vcloud/core/api/odoo_api_client.dart';
import 'package:vcloud/core/theme/app_theme.dart';
import 'package:vcloud/shared/models/conversation.dart';
import 'package:vcloud/shared/models/message.dart';
import 'package:vcloud/shared/models/profile.dart';
import 'package:vcloud/shared/widgets/app_scaffold.dart';
import 'package:vcloud/shared/widgets/ui_kit.dart';

import 'chat_bubbles.dart';
import 'chat_helpers.dart';
import 'chat_wallpaper.dart';

class FloatingChatHeader extends StatelessWidget {
  const FloatingChatHeader({
    super.key,
    required this.conversationId,
    required this.title,
    required this.conversation,
    required this.currentIdentityIds,
    required this.fallbackAvatarUrl,
    required this.onOpenInfo,
  });

  final String conversationId;
  final String title;
  final Conversation? conversation;
  final Set<String> currentIdentityIds;
  final String? fallbackAvatarUrl;
  final VoidCallback onOpenInfo;

  @override
  Widget build(BuildContext context) {
    final other = _otherProfile();
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      child: Row(
        children: [
          RoundIconButton(
            tooltip: 'Quay lại',
            icon: LucideIcons.chevronLeft,
            onTap: () => Navigator.maybePop(context),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: PressableScale(
              onTap: onOpenInfo,
              scale: 0.99,
              child: FrostedSurface(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                radius: 999,
                child: Row(
                  children: [
                    HeaderAvatar(
                      conversation: conversation,
                      title: title,
                      other: other,
                      fallbackAvatarUrl: fallbackAvatarUrl,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Hero(
                            tag: 'chat-title-$conversationId',
                            child: Material(
                              color: Colors.transparent,
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 1),
                          Builder(
                            builder: (_) {
                              final String statusText;
                              final Color statusDotColor;
                              if (conversation?.isGroup == true) {
                                statusText = 'Nhóm trò chuyện';
                                statusDotColor = Colors.transparent;
                              } else {
                                final imStatus = other?.imStatus ?? 'offline';
                                switch (imStatus) {
                                  case 'online':
                                    statusText = 'Đang hoạt động';
                                    statusDotColor = const Color(0xFF22C55E);
                                    break;
                                  case 'away':
                                    statusText = 'Vắng mặt';
                                    statusDotColor = const Color(0xFFF59E0B);
                                    break;
                                  case 'offline':
                                  default:
                                    statusText = 'Ngoại tuyến';
                                    statusDotColor = const Color(0xFF94A3B8);
                                    break;
                                }
                              }
                              return Row(
                                children: [
                                  if (statusDotColor != Colors.transparent) ...[
                                    Container(
                                      width: 7,
                                      height: 7,
                                      decoration: BoxDecoration(
                                        color: statusDotColor,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                  ],
                                  Text(
                                    statusText,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.caption.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      LucideIcons.chevronRight,
                      color: AppColors.textSecondary,
                      size: 17,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Profile? _otherProfile() {
    final current = conversation;
    if (current == null || current.isGroup) return null;
    for (final member in current.members) {
      if (!isCurrentProfile(member.profile, currentIdentityIds)) {
        return member.profile;
      }
    }
    return null;
  }
}

class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: PressableScale(
        onTap: onTap,
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.62),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
              ),
              child: Icon(icon, color: AppColors.textPrimary, size: 24),
            ),
          ),
        ),
      ),
    );
  }
}

class HeaderAvatar extends StatelessWidget {
  const HeaderAvatar({
    super.key,
    required this.conversation,
    required this.title,
    required this.other,
    required this.fallbackAvatarUrl,
  });

  final Conversation? conversation;
  final String title;
  final Profile? other;
  final String? fallbackAvatarUrl;

  @override
  Widget build(BuildContext context) {
    final isGroup = conversation?.isGroup == true;
    final avatar =
        (fallbackAvatarUrl != null && fallbackAvatarUrl!.trim().isNotEmpty)
            ? fallbackAvatarUrl
            : (isGroup ? null : other?.avatarUrl);
    return UserAvatar(
      userId: isGroup ? (conversation?.id ?? title) : (other?.id ?? title),
      displayName: isGroup ? title : (other?.displayName ?? title),
      email: other?.email,
      avatarUrl: avatar,
      isGroup: isGroup,
      size: 34,
    );
  }
}

class PinnedMessageBanner extends StatelessWidget {
  const PinnedMessageBanner({super.key, required this.message});

  final Message message;

  @override
  Widget build(BuildContext context) {
    final preview = message.attachmentIds.isNotEmpty
        ? attachmentFileName(message)
        : message.content.trim();
    final media = MediaInfo.fromContent(preview);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: FrostedSurface(
        height: 64,
        padding: const EdgeInsets.fromLTRB(12, 8, 14, 8),
        radius: 28,
        child: Row(
          children: [
            Container(
              width: 3,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.soft(AppColors.chat),
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: media?.isImage == true
                  ? Image.network(
                      odooApiClient.authenticatedUrl(media!.url),
                      fit: BoxFit.cover,
                      headers: odooApiClient.authHeaders,
                      errorBuilder: (_, _, _) => const Icon(
                        LucideIcons.image,
                        color: AppColors.chat,
                        size: 22,
                      ),
                    )
                  : Icon(
                      media?.isVideo == true
                          ? LucideIcons.video
                          : LucideIcons.messageCircle,
                      color: AppColors.chat,
                      size: 22,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tin nhắn ghim',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    media == null ? preview : media.displayLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(LucideIcons.pin, color: AppColors.textPrimary, size: 22),
          ],
        ),
      ),
    );
  }
}
