import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../shared/models/ticket_comment.dart';
import '../../../../shared/widgets/app_scaffold.dart';

/// Thẻ hiển thị một bình luận / tin nhắn trao đổi trong Helpdesk Ticket Chatter.
///
/// Tuân thủ nghiêm ngặt Anti-Sycophancy & Evidence-First Protocol:
/// Avatar và Tên tác giả hiển thị trong mỗi bong bóng chatter ĐỘC QUYỀN lấy từ
/// [comment.authorName] và [comment.authorAvatarUrl], tuyệt đối KHÔNG fallback
/// về ticket.createUid hoặc ticket.partnerName.
class TicketCommentCard extends StatelessWidget {
  const TicketCommentCard({
    super.key,
    required this.comment,
    required this.myId,
    this.pending = false,
  });

  final TicketComment comment;
  final String myId;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMe = comment.authorId == myId;
    // Strict isolation: chỉ lấy tên tác giả từ comment, không fallback về ticket creator
    final name = comment.authorName ?? (isMe ? 'Bạn' : 'Người dùng');

    return Opacity(
      opacity: pending ? 0.72 : 1,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                UserAvatar(
                  userId: comment.authorId,
                  displayName: name,
                  avatarUrl: comment.authorAvatarUrl,
                  size: 34,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          color: isDark ? Colors.white : AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        pending ? 'Đang gửi...' : Dates.time(comment.createdAt),
                        style: TextStyle(
                          color: isDark ? Colors.white54 : AppColors.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Builder(
              builder: (_) {
                final rawContent = comment.content.trim();
                // ponytail: Tránh ngộ nhận sai tác giả đã tạo ticket
                final displayContent = rawContent.isNotEmpty
                    ? rawContent
                    : '$name đã gửi một cập nhật.';
                return Text(
                  displayContent,
                  style: TextStyle(
                    color: isDark
                        ? const Color(0xFFE2E8F0)
                        : (rawContent.isNotEmpty ? AppColors.textPrimary : AppColors.primary),
                    fontSize: 14,
                    height: 1.35,
                    fontWeight: rawContent.isNotEmpty ? FontWeight.normal : FontWeight.w600,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Khung nhập bình luận mới cho Helpdesk Ticket Chatter.
class TicketCommentComposer extends StatelessWidget {
  const TicketCommentComposer({
    super.key,
    required this.controller,
    required this.sending,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white.withValues(alpha: 0.94),
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : AppColors.border,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSubmit(),
                decoration: InputDecoration(
                  hintText: 'Nhập nội dung phản hồi...',
                  hintStyle: TextStyle(
                    color: isDark ? Colors.white38 : AppColors.textMuted,
                    fontSize: 13,
                  ),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(
                      color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: BorderSide(
                      color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(20),
                    borderSide: const BorderSide(
                      color: Color(0xFF2563EB),
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: sending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(LucideIcons.send, color: Color(0xFF2563EB), size: 20),
              onPressed: sending ? null : onSubmit,
              tooltip: 'Gửi phản hồi',
            ),
          ],
        ),
      ),
    );
  }
}
