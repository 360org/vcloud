import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../../../core/api/odoo_api_client.dart';
import '../../../../core/utils/local_attachment_cache.dart';
import '../../data/models/chat_v2_message.dart';
import '../screens/chat_v2_video_player_screen.dart';

/// Widget hiển thị tin nhắn Video dạng Card bo góc 12dp chuẩn thiết kế Refined Tech Luxury
/// Có nút Play hình tròn nổi bật ở giữa, overlay tối mờ 30%, và badge dung lượng tệp.
class ChatV2VideoBubble extends StatelessWidget {
  final ChatV2Attachment attachment;
  final bool isMine;
  final Widget? timeAndStatus;

  const ChatV2VideoBubble({
    super.key,
    required this.attachment,
    required this.isMine,
    this.timeAndStatus,
  });

  String _formatFileSize(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else if (bytes >= 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '$bytes B';
  }

  void _openPlayer(BuildContext context) {
    HapticFeedback.lightImpact();
    final fullUrl = attachment.resolveFullUrl(odooApiClient.absoluteUrl(''));
    final cachedBytes = attachment.bytes ??
        LocalAttachmentCache.get(null, altKey: attachment.name);

    Navigator.of(context).push(
      ChatV2VideoPlayerScreen.route(
        videoUrl: fullUrl,
        title: attachment.name.isNotEmpty ? attachment.name : 'Video',
        headers: odooApiClient.authHeaders,
        bytes: cachedBytes,
        attachmentId: attachment.id.isNotEmpty ? attachment.id : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cachedBytes = attachment.bytes ??
        LocalAttachmentCache.get(null, altKey: attachment.name);
    final size = attachment.fileSize ?? cachedBytes?.lengthInBytes;
    final sizeStr = size != null ? _formatFileSize(size) : null;

    const bubbleWidth = 260.0;
    const bubbleHeight = 160.0;

    return GestureDetector(
      onTap: () => _openPlayer(context),
      child: Container(
        width: bubbleWidth,
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              // 1. Nền video (Gradient sang trọng công nghệ với placeholder)
              Container(
                width: bubbleWidth,
                height: bubbleHeight,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? const [
                            Color(0xFF1E293B),
                            Color(0xFF0F172A),
                          ]
                        : const [
                            Color(0xFF334155),
                            Color(0xFF1E293B),
                          ],
                  ),
                ),
                child: Center(
                  child: Icon(
                    LucideIcons.film,
                    size: 48,
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
              ),

              // 2. Overlay màu tối mờ 30% (Black opacity 30%)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.30),
                ),
              ),

              // 3. Tiêu đề tên tệp video ở góc trên
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.65),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        LucideIcons.video,
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          attachment.name.isNotEmpty
                              ? attachment.name
                              : 'Video',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 4. Nút Play hình tròn nổi bật ở chính giữa
              Positioned.fill(
                child: Center(
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.85),
                        width: 2.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.45),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Padding(
                      padding: EdgeInsets.only(left: 3), // Cân quang học icon Play
                      child: Icon(
                        LucideIcons.play,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ),

              // 5. Badge thời lượng / dung lượng tệp ở góc dưới bên trái
              Positioned(
                bottom: 8,
                left: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.15),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        LucideIcons.film,
                        size: 11,
                        color: Color(0xFF60A5FA),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        sizeStr != null ? 'Video • $sizeStr' : 'Video',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 6. Time and Status ở góc dưới bên phải (nếu có)
              if (timeAndStatus != null)
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: timeAndStatus!,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
