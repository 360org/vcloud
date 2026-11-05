import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../../../core/api/odoo_api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_format.dart';
import '../../../chat_v2/presentation/screens/chat_v2_image_viewer_screen.dart';
import '../../../chat_v2/presentation/widgets/chat_v2_attachment_viewer.dart';
import '../../../chat_v2/presentation/widgets/chat_v2_message_item.dart';
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
    this.myPartnerId,
    this.myName,
    this.pending = false,
    this.isTechnician = false,
  });

  final TicketComment comment;
  final String myId;
  final String? myPartnerId;
  final String? myName;
  final bool pending;
  final bool isTechnician;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final normMyName = myName?.trim().toLowerCase();
    final normAuthorName = comment.authorName?.trim().toLowerCase();
    final isMe = comment.authorId == myId ||
        (myPartnerId != null && myPartnerId!.isNotEmpty && comment.authorId == myPartnerId) ||
        (normMyName != null && normMyName.isNotEmpty && normAuthorName == normMyName);

    // Tác giả là chính mình -> Tuyệt đối không hiển thị nhãn "Chuyên viên hỗ trợ"
    final effectiveIsTechnician = !isMe && isTechnician;
    // Strict isolation: chỉ lấy tên tác giả từ comment, không fallback về ticket creator
    final name = isMe ? 'Bạn' : (comment.authorName ?? 'Người dùng');

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
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              name,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isDark ? Colors.white : AppColors.textPrimary,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          if (effectiveIsTechnician) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.success.withValues(alpha: isDark ? 0.22 : 0.1),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: AppColors.success.withValues(alpha: isDark ? 0.45 : 0.3),
                                  width: 0.8,
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(LucideIcons.shieldCheck, size: 10, color: AppColors.success),
                                  SizedBox(width: 3),
                                  Text(
                                    'Chuyên viên hỗ trợ',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.success,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
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
                final hasImages = comment.attachments.any((a) {
                  final ext = a.name.contains('.') ? a.name.split('.').last.toLowerCase() : '';
                  return switch (ext) {
                    'jpg' || 'jpeg' || 'png' || 'gif' || 'webp' => true,
                    _ => (a.mimetype?.startsWith('image/') ?? false),
                  };
                });
                // Nếu người dùng chỉ gửi hình ảnh kèm thông báo tự động "Đã gửi tệp đính kèm: ...",
                // ẩn dòng chữ này để chỉ hiển thị ảnh inline trực quan như chat ứng dụng hiện đại.
                final isAutoAttachmentText = rawContent.startsWith('Đã gửi tệp đính kèm:') ||
                    (rawContent.startsWith('Đã gửi ') && rawContent.contains('tệp đính kèm'));
                if (hasImages && isAutoAttachmentText) {
                  return const SizedBox.shrink();
                }

                // ponytail: Tránh ngộ nhận sai tác giả đã tạo ticket
                final displayContent = rawContent.isNotEmpty
                    ? rawContent
                    : (comment.attachments.isNotEmpty ? '' : '$name đã gửi một cập nhật.');
                if (displayContent.isEmpty) return const SizedBox.shrink();

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
            if (comment.attachments.isNotEmpty) ...[
              const SizedBox(height: 8),
              Builder(
                builder: (context) {
                  final imageAttachments = comment.attachments.where((a) {
                    final ext = a.name.contains('.') ? a.name.split('.').last.toLowerCase() : '';
                    return switch (ext) {
                      'jpg' || 'jpeg' || 'png' || 'gif' || 'webp' => true,
                      _ => (a.mimetype?.startsWith('image/') ?? false),
                    };
                  }).toList();

                  final fileAttachments = comment.attachments.where((a) => !imageAttachments.contains(a)).toList();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (imageAttachments.length == 1) ...[
                        Builder(
                          builder: (context) {
                            final img = imageAttachments.first;
                            final key = 'att_${img.id}';
                            final memBytes = ChatV2AttachmentImage.imageCache[key] ??
                                ChatV2AttachmentImage.imageCache[img.name];
                            final fullUrl = odooApiClient.authenticatedUrl(
                              img.downloadUrl ?? '/api/v1/mobile/attachments/${img.id}/download',
                              accessToken: img.accessToken,
                            );
                            return GestureDetector(
                              onTap: () {
                                Navigator.of(context).push(
                                  ChatV2ImageViewerScreen.route(
                                    imageUrl: fullUrl,
                                    title: img.name,
                                    attachmentId: img.id.toString(),
                                  ),
                                );
                              },
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  constraints: const BoxConstraints(maxHeight: 220, maxWidth: 280),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white10 : Colors.black12,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: memBytes != null && memBytes.isNotEmpty
                                      ? Image.memory(memBytes, fit: BoxFit.cover)
                                      : (fullUrl.isNotEmpty
                                          ? Image.network(
                                              fullUrl,
                                              headers: odooApiClient.authHeaders,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) => Container(
                                                height: 100,
                                                width: 140,
                                                alignment: Alignment.center,
                                                child: const Icon(LucideIcons.imageOff, size: 24, color: Colors.grey),
                                              ),
                                            )
                                          : const SizedBox.shrink()),
                                ),
                              ),
                            );
                          },
                        ),
                      ] else if (imageAttachments.length > 1) ...[
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final img in imageAttachments) ...[
                              Builder(
                                builder: (context) {
                                  final key = 'att_${img.id}';
                                  final memBytes = ChatV2AttachmentImage.imageCache[key] ??
                                      ChatV2AttachmentImage.imageCache[img.name];
                                  final fullUrl = odooApiClient.authenticatedUrl(
                                    img.downloadUrl ?? '/api/v1/mobile/attachments/${img.id}/download',
                                    accessToken: img.accessToken,
                                  );
                                  return GestureDetector(
                                    onTap: () {
                                      Navigator.of(context).push(
                                        ChatV2ImageViewerScreen.route(
                                          imageUrl: fullUrl,
                                          title: img.name,
                                          attachmentId: img.id.toString(),
                                        ),
                                      );
                                    },
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Container(
                                        width: 84,
                                        height: 84,
                                        color: isDark ? Colors.white10 : Colors.black12,
                                        child: memBytes != null && memBytes.isNotEmpty
                                            ? Image.memory(memBytes, fit: BoxFit.cover)
                                            : (fullUrl.isNotEmpty
                                                ? Image.network(
                                                    fullUrl,
                                                    headers: odooApiClient.authHeaders,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (context, error, stackTrace) => const Center(
                                                      child: Icon(LucideIcons.imageOff, size: 20, color: Colors.grey),
                                                    ),
                                                  )
                                                : const SizedBox.shrink()),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                      ],
                      if (fileAttachments.isNotEmpty) ...[
                        if (imageAttachments.isNotEmpty) const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            for (final file in fileAttachments) ...[
                              InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () async {
                                  final effectiveUrl = odooApiClient.authenticatedUrl(
                                    file.downloadUrl ?? '/api/v1/mobile/attachments/${file.id}/download',
                                    accessToken: file.accessToken,
                                  );
                                  await ChatV2AttachmentViewer.open(
                                    context: context,
                                    filename: file.name,
                                    attachmentId: file.id,
                                    downloadUrl: effectiveUrl,
                                    accessToken: file.accessToken,
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isDark ? Colors.white12 : const Color(0xFFCBD5E1),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(LucideIcons.paperclip, size: 14, color: AppColors.primary),
                                      const SizedBox(width: 6),
                                      ConstrainedBox(
                                        constraints: const BoxConstraints(maxWidth: 200),
                                        child: Text(
                                          file.name,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? Colors.white : AppColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ],
                  );
                },
              ),
            ],
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
    this.onAttach,
    this.onPickImage,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSubmit;
  final VoidCallback? onAttach;
  final VoidCallback? onPickImage;

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
            if (onPickImage != null) ...[
              IconButton(
                icon: const Icon(LucideIcons.image, size: 20),
                color: isDark ? Colors.white60 : AppColors.textSecondary,
                onPressed: sending ? null : onPickImage,
                tooltip: 'Gửi ảnh',
              ),
            ],
            if (onAttach != null) ...[
              IconButton(
                icon: const Icon(LucideIcons.paperclip, size: 20),
                color: isDark ? Colors.white60 : AppColors.textSecondary,
                onPressed: sending ? null : onAttach,
                tooltip: 'Đính kèm tệp',
              ),
              const SizedBox(width: 4),
            ],
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
