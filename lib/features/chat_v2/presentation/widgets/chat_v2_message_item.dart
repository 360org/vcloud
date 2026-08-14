import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../../../core/api/odoo_api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/chat_v2_message.dart';
import '../screens/chat_v2_image_viewer_screen.dart';

class ChatV2MessageItem extends StatelessWidget {
  const ChatV2MessageItem({
    super.key,
    required this.message,
    this.showSenderName = false,
  });

  final ChatV2Message message;
  final bool showSenderName;

  @override
  Widget build(BuildContext context) {
    final isMine = message.isMine;
    final timeStr = message.createdAt != null
        ? DateFormat('HH:mm').format(message.createdAt!)
        : '';

    final imageAttachments = message.attachments.where((a) => a.isImage).toList();
    final hasImages = imageAttachments.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment:
            isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine && message.authorAvatar != null) ...[
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.1),
              ),
              child: ClipOval(
                child: Image.network(
                  message.authorAvatar!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Center(
                    child: Text(
                      message.authorName.isNotEmpty
                          ? message.authorName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isMine
                    ? AppColors.primary
                    : Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF2C2C2E)
                        : const Color(0xFFF2F2F7),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMine ? 16 : 4),
                  bottomRight: Radius.circular(isMine ? 4 : 16),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment:
                    isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isMine && showSenderName && message.authorName.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        message.authorName,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  if (hasImages) ...[
                    for (final att in imageAttachments) ...[
                      _buildImageAttachment(context, att),
                      const SizedBox(height: 4),
                    ],
                  ],
                  if (message.content.isNotEmpty &&
                      (!hasImages || message.content != 'Sent attachment')) ...[
                    SelectableText(
                      message.content,
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.35,
                        color: isMine
                            ? Colors.white
                            : Theme.of(context).brightness == Brightness.dark
                                ? Colors.white
                                : const Color(0xFF1C1C1E),
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 11,
                          color: isMine
                              ? Colors.white.withValues(alpha: 0.7)
                              : Colors.grey.shade600,
                        ),
                      ),
                      if (isMine) ...[
                        const SizedBox(width: 4),
                        _buildStatusIcon(message.status),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageAttachment(BuildContext context, ChatV2Attachment att) {
    final fullUrl = att.resolveFullUrl(odooApiClient.absoluteUrl(''));

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatV2ImageViewerScreen(
              imageUrl: fullUrl,
              title: att.name,
            ),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(
            maxHeight: 240,
            maxWidth: 280,
          ),
          color: Colors.black12,
          child: Image.network(
            fullUrl,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return Container(
                height: 160,
                width: 220,
                alignment: Alignment.center,
                child: const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Container(
                height: 120,
                width: 200,
                color: Colors.black26,
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(LucideIcons.imageOff, color: Colors.white70, size: 28),
                    const SizedBox(height: 6),
                    Text(
                      att.name,
                      style: const TextStyle(color: Colors.white70, fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon(String status) {
    switch (status) {
      case 'pending':
        return const SizedBox(
          width: 10,
          height: 10,
          child: CircularProgressIndicator(
            strokeWidth: 1.5,
            color: Colors.white70,
          ),
        );
      case 'read':
        return const Icon(
          LucideIcons.checkCheck,
          size: 13,
          color: Colors.white,
        );
      case 'error':
        return const Icon(
          LucideIcons.alertCircle,
          size: 13,
          color: Colors.redAccent,
        );
      case 'sent':
      default:
        return const Icon(
          LucideIcons.check,
          size: 13,
          color: Colors.white70,
        );
    }
  }
}
