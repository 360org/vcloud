import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/api/mobile_attachment_repository.dart';
import '../../../../core/api/odoo_api_client.dart';
import '../../../../core/utils/file_download.dart';
import '../../../../core/utils/local_attachment_cache.dart';
import '../../data/models/chat_v2_message.dart';
import '../screens/chat_v2_image_viewer_screen.dart';
import 'chat_v2_location_card.dart';
import 'chat_v2_poll_card.dart';

final RegExp _attachmentIdPattern =
    RegExp(r'/(?:attachments|image|content)/(\d+)');

class ChatV2MessageItem extends StatelessWidget {
  const ChatV2MessageItem({
    super.key,
    required this.message,
    this.showSenderName = false,
    this.showAvatar = false,
    this.isGroup = false,
    this.onLongPress,
    this.onReplyTap,
    this.onReactionTap,
    this.isHighlighted = false,
  });

  final ChatV2Message message;
  final bool showSenderName;
  final bool showAvatar;
  final bool isGroup;
  final VoidCallback? onLongPress;
  final ValueChanged<String?>? onReplyTap;
  final ValueChanged<String>? onReactionTap;
  final bool isHighlighted;

  static final DateFormat _timeFormatter = DateFormat('HH:mm');

  static const _authorColors = [
    Color(0xFF0284C7), // Sky blue
    Color(0xFF7C3AED), // Violet
    Color(0xFF059669), // Emerald
    Color(0xFFD97706), // Amber
    Color(0xFFDC2626), // Rose
    Color(0xFF0891B2), // Cyan
    Color(0xFFEA580C), // Orange
    Color(0xFF4F46E5), // Indigo
    Color(0xFFDB2777), // Pink
    Color(0xFF0D9488), // Teal
  ];

  static Color getAuthorColor(String name) {
    if (name.isEmpty) return _authorColors[0];
    final hash = name.codeUnits.fold(0, (acc, c) => acc + c);
    return _authorColors[hash % _authorColors.length];
  }

  @override
  Widget build(BuildContext context) {
    final isMine = message.isMine;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authorColor = getAuthorColor(message.authorName);
    final avatarCacheSize = (28 * MediaQuery.devicePixelRatioOf(context)).round();
    final timeStr = message.createdAt != null
        ? _timeFormatter.format(message.createdAt!)
        : '';

    final imageAttachments = message.attachments.where((a) => a.isImage).toList();
    final docAttachments = message.attachments.where((a) => !a.isImage).toList();
    final hasImages = imageAttachments.isNotEmpty;
    final hasDocs = docAttachments.isNotEmpty;
    final isHistoricalImage = message.isImageFilename && !hasImages;
    final hasAnyImage = hasImages || isHistoricalImage;

    final cleanContent = message.content.trim();
    final isFileNameContent = cleanContent.isEmpty ||
        cleanContent == 'Sent attachment' ||
        cleanContent == '[Hình ảnh]' ||
        cleanContent == '[Tập tin]' ||
        imageAttachments.any((a) => a.name.trim() == cleanContent);

    final hasRealCaption = hasAnyImage && !isFileNameContent;
    final isPureImage = hasAnyImage && !hasRealCaption && !hasDocs;

    final isPureText = message.content.isNotEmpty &&
        (!message.isImageFilename || hasImages) &&
        !message.isDocumentFilename &&
        !hasImages &&
        !hasDocs &&
        message.parentId == null &&
        message.parentBody == null;

    final timeAndStatus = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          timeStr,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: isMine
                ? (isDark ? const Color(0xFF8696A0) : const Color(0xFF667781))
                : (isDark ? const Color(0xFF8696A0) : const Color(0xFF667781)),
          ),
        ),
        if (isMine) ...[
          const SizedBox(width: 4),
          _buildStatusIcon(message.status),
        ],
      ],
    );

    return GestureDetector(
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
        color: isHighlighted
            ? (isDark
                ? const Color(0xFF00C83A).withValues(alpha: 0.18)
                : const Color(0xFF00C83A).withValues(alpha: 0.15))
            : Colors.transparent,
        padding: EdgeInsets.symmetric(
          horizontal: 14,
          vertical: showSenderName ? 4 : 2,
        ),
        child: Row(
          mainAxisAlignment:
              isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMine && isGroup) ...[
              if (showAvatar)
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        authorColor.withValues(alpha: 0.85),
                        authorColor,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: authorColor.withValues(alpha: 0.25),
                        blurRadius: 3,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  alignment: Alignment.center,
                  child: ClipOval(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Center(
                          child: Text(
                            message.authorName.isNotEmpty
                                ? message.authorName[0].toUpperCase()
                                : 'U',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        if (message.authorAvatar != null &&
                            message.authorAvatar!.isNotEmpty)
                          Image.network(
                            message.authorAvatar!,
                            width: 28,
                            height: 28,
                            fit: BoxFit.cover,
                            cacheWidth: avatarCacheSize,
                            cacheHeight: avatarCacheSize,
                            gaplessPlayback: true,
                            errorBuilder: (context, error, stackTrace) =>
                                const SizedBox.shrink(),
                          ),
                      ],
                    ),
                  ),
                )
              else
                const SizedBox(width: 28),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  (message.isPollMessage && message.poll != null)
                      ? ChatV2PollCard(
                          message: message,
                          poll: message.poll!,
                          isMine: isMine,
                          timeStr: timeStr,
                        )
                      : (message.isLocationMessage && message.locationCoordinates != null)
                          ? Column(
                              crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                              children: [
                                if (!isMine && showSenderName) ...[
                                  Text(
                                    message.authorName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: authorColor,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                ],
                                ChatV2LocationCard(
                                  message: message,
                                  isMine: isMine,
                                ),
                                const SizedBox(height: 2),
                                timeAndStatus,
                              ],
                            )
                      : isPureImage
                          ? _buildPureImageBubble(context, imageAttachments, isMine, timeStr)
                          : Container(
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.72,
                          ),
                      decoration: BoxDecoration(
                        color: isMine
                            ? (isDark
                                ? const Color(0xFF005C4B)
                                : const Color(0xFFD9FDD3))
                            : (isDark
                                ? const Color(0xFF202C33)
                                : Colors.white),
                        border: isMine || isDark || hasAnyImage
                            ? null
                            : Border.all(
                                color: const Color(0xFFE2E8F0),
                                width: 0.8,
                              ),
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(16),
                          topRight: const Radius.circular(16),
                          bottomLeft: Radius.circular(isMine ? 16 : 4),
                          bottomRight: Radius.circular(isMine ? 4 : 16),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(16),
                          topRight: const Radius.circular(16),
                          bottomLeft: Radius.circular(isMine ? 16 : 4),
                          bottomRight: Radius.circular(isMine ? 4 : 16),
                        ),
                        child: Padding(
                          padding: hasAnyImage
                              ? EdgeInsets.zero
                              : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!isMine && showSenderName) ...[
                                Text(
                                  message.authorName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: authorColor,
                                  ),
                                ),
                                const SizedBox(height: 3),
                              ],
                              // 0. Render Reply Quote Card if this message is a reply
                              if (message.parentId != null || message.parentBody != null)
                                _buildReplyQuoteCard(context, isMine, isDark),
                              // 1. Render actual image attachments with caption
                              if (hasImages) ...[
                                for (final att in imageAttachments) ...[
                                  _buildImageAttachment(context, att, isMine),
                                  if (imageAttachments.length > 1) const SizedBox(height: 2),
                                ],
                              ] else if (message.isImageFilename) ...[
                            // 2. Render image filename card for historical messages
                            _buildImageFilenameCard(context, isMine),
                          ],
                          // 3. Render actual document attachments
                          if (hasDocs) ...[
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                for (final att in docAttachments) ...[
                                  _buildDocumentAttachment(context, att, isMine),
                                  const SizedBox(height: 4),
                                ],
                              ],
                            ),
                          ] else if (message.isDocumentFilename) ...[
                            // 4. Render document filename card
                            _buildDocumentFilenameCard(context, isMine),
                          ],
                          // 5. Render message text & time
                          if (isPureText) ...[
                            Wrap(
                              alignment: WrapAlignment.end,
                              crossAxisAlignment: WrapCrossAlignment.end,
                              spacing: 8,
                              runSpacing: 2,
                              children: [
                                _buildParsedMessageText(
                                  context: context,
                                  rawText: message.content,
                                  isMine: isMine,
                                  isDark: isDark,
                                  textColor: isDark ? const Color(0xFFE9EDEF) : const Color(0xFF111B21),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 1),
                                  child: timeAndStatus,
                                ),
                              ],
                            ),
                          ] else ...[
                            if (message.content.isNotEmpty &&
                                !message.isImageFilename &&
                                !message.isDocumentFilename &&
                                (!hasImages || !isFileNameContent))
                              Padding(
                                padding: hasAnyImage
                                    ? const EdgeInsets.only(top: 8, left: 12, right: 12, bottom: 4)
                                    : EdgeInsets.zero,
                                child: _buildParsedMessageText(
                                  context: context,
                                  rawText: message.content,
                                  isMine: isMine,
                                  isDark: isDark,
                                  textColor: isDark ? const Color(0xFFE9EDEF) : const Color(0xFF111B21),
                                ),
                              ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: Padding(
                                padding: hasAnyImage
                                    ? const EdgeInsets.only(bottom: 6, right: 10, left: 10)
                                    : const EdgeInsets.only(top: 3),
                                child: timeAndStatus,
                              ),
                            ),
                          ],
                        ],
                      ),
                  ),
                  if (message.reactions.isNotEmpty)
                    _buildReactionBadges(context, isMine),
                ],
              ),
            ),
          ),
        ],
      ),
    ));
  }

  Widget _buildPureImageBubble(
    BuildContext context,
    List<ChatV2Attachment> imageAttachments,
    bool isMine,
    String timeStr,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: const BoxConstraints(
        maxWidth: 290,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(isMine ? 18 : 4),
          bottomRight: Radius.circular(isMine ? 4 : 18),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(isMine ? 18 : 4),
          bottomRight: Radius.circular(isMine ? 4 : 18),
        ),
        child: Stack(
          alignment: Alignment.bottomRight,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (imageAttachments.isNotEmpty)
                  for (final att in imageAttachments)
                    _buildImageAttachment(context, att, isMine)
                else if (message.isImageFilename)
                  _buildImageFilenameCard(context, isMine),
              ],
            ),
            if (message.status == 'pending')
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.35),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF00C83A),
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Đang tải lên...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            Positioned(
              right: 8,
              bottom: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 7.5, vertical: 3.5),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      timeStr,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    if (isMine) ...[
                      const SizedBox(width: 4),
                      _buildStatusIcon(message.status, iconSize: 11),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageAttachment(BuildContext context, ChatV2Attachment att, bool isMine) {
    final fullUrl = att.resolveFullUrl(odooApiClient.absoluteUrl(''));
    final fallbackCard = _buildSimpleFilenameCard(context, isMine, att.name);

    return ChatV2AttachmentImage(
      attachment: att,
      fallback: fallbackCard,
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatV2ImageViewerScreen(
              imageUrl: fullUrl,
              title: att.name,
              bytes: att.bytes,
              attachmentId: att.id,
            ),
          ),
        );
      },
    );
  }

  Widget _buildSimpleFilenameCard(BuildContext context, bool isMine, String fileName) {
    return _buildFileAttachmentCard(
      context: context,
      isMine: isMine,
      filename: fileName,
      fileSize: null,
      downloadUrl: null,
      directBytes: null,
      isImage: true,
    );
  }

  Widget _buildReplyQuoteCard(BuildContext context, bool isMine, bool isDark) {
    final author = (message.parentAuthorName != null && message.parentAuthorName!.isNotEmpty)
        ? message.parentAuthorName!
        : 'Tin nhắn';
    final body = (message.parentBody != null && message.parentBody!.isNotEmpty)
        ? message.parentBody!
        : '...';

    final barColor = isMine
        ? (isDark ? const Color(0xFF00C83A) : const Color(0xFF00A82D))
        : (isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB));

    final bgColor = isDark
        ? Colors.black.withValues(alpha: 0.25)
        : Colors.black.withValues(alpha: 0.05);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (message.parentId != null && onReplyTap != null) {
          onReplyTap!(message.parentId);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(
              color: barColor,
              width: 3.5,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  LucideIcons.reply,
                  size: 11,
                  color: barColor,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    author,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: barColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              body,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageFilenameCard(BuildContext context, bool isMine) {
    final cleanName = message.content.trim();
    final memoryBytes = ChatV2AttachmentImage.imageCache[cleanName] ??
        ChatV2AttachmentImage.imageCache[message.id] ??
        LocalAttachmentCache.get(null, altKey: cleanName);

    if (memoryBytes != null && memoryBytes.isNotEmpty) {
      return _buildImageAttachment(
        context,
        ChatV2Attachment(
          id: message.id,
          name: cleanName,
          bytes: memoryBytes,
          mimetype: 'image/jpeg',
        ),
        isMine,
      );
    }

    return _buildSimpleFilenameCard(context, isMine, cleanName);
  }

  Widget _buildDocumentAttachment(BuildContext context, ChatV2Attachment att, bool isMine) {
    return _buildFileAttachmentCard(
      context: context,
      isMine: isMine,
      filename: att.name,
      fileSize: att.fileSize,
      downloadUrl: att.downloadUrl ?? att.url,
      directBytes: att.bytes,
      isImage: false,
    );
  }

  Widget _buildDocumentFilenameCard(BuildContext context, bool isMine) {
    final cleanName = message.content.trim();
    final fileSize = message.attachments.isNotEmpty ? message.attachments.first.fileSize : null;
    final downloadUrl = message.attachments.isNotEmpty ? message.attachments.first.downloadUrl : null;
    final directBytes = message.attachments.isNotEmpty ? message.attachments.first.bytes : null;

    return _buildFileAttachmentCard(
      context: context,
      isMine: isMine,
      filename: cleanName,
      fileSize: fileSize,
      downloadUrl: downloadUrl,
      directBytes: directBytes,
      isImage: false,
    );
  }

  /// Thẻ tệp tin chuẩn Zalo (Flat, Borderless, Folded Corner Page Icon)
  Widget _buildFileAttachmentCard({
    required BuildContext context,
    required bool isMine,
    required String filename,
    int? fileSize,
    String? downloadUrl,
    Uint8List? directBytes,
    required bool isImage,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cleanName = filename.trim();
    final ext = cleanName.contains('.')
        ? cleanName.split('.').last.toUpperCase()
        : (isImage ? 'PNG' : 'FILE');

    final fileColor = _getFileAccentColor(ext);

    final cachedBytes = directBytes ??
        (isImage ? ChatV2AttachmentImage.imageCache[cleanName] : null) ??
        LocalAttachmentCache.get(null, altKey: cleanName);

    final resolvedSize = fileSize ?? cachedBytes?.lengthInBytes;
    final sizeStr = resolvedSize != null ? _formatFileSize(resolvedSize) : null;
    final metaText = sizeStr != null
        ? '$sizeStr • Nhấn để xem trước'
        : (isImage ? 'Hình ảnh • $ext' : 'Tài liệu • $ext');

    final titleColor = isDark ? const Color(0xFFE9EDEF) : const Color(0xFF111B21);
    final subtitleColor = isDark ? const Color(0xFF8696A0) : const Color(0xFF667781);

    return InkWell(
      onTap: () async {
        if (cachedBytes != null && cachedBytes.isNotEmpty) {
          await saveBytesToFile(cachedBytes, cleanName);
          return;
        }
        if (downloadUrl != null && downloadUrl.isNotEmpty) {
          final full = odooApiClient.authenticatedUrl(downloadUrl);
          openDownloadUrl(full);
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 255,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Icon tài liệu gấp góc Zalo sắc nét
            FoldedPageIcon(
              ext: ext,
              color: fileColor,
              width: 36,
              height: 44,
            ),
            const SizedBox(width: 10),

            // Tiêu đề tệp và Phụ đề dung lượng
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    cleanName,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: titleColor,
                      height: 1.25,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(
                        LucideIcons.clock,
                        size: 12,
                        color: Color(0xFF2563EB),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          metaText,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w400,
                            color: subtitleColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),

            // Nút tải về hình vuông bo góc tối giản chuẩn Zalo
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isDark
                      ? Colors.white24
                      : const Color(0xFF64748B).withValues(alpha: 0.35),
                  width: 1.0,
                ),
              ),
              alignment: Alignment.center,
              child: Icon(
                LucideIcons.download,
                size: 15,
                color: isDark ? Colors.white70 : const Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getFileAccentColor(String ext) {
    switch (ext.toUpperCase()) {
      case 'PDF':
        return const Color(0xFFEF4444); // Đỏ Zalo
      case 'DOC':
      case 'DOCX':
        return const Color(0xFF2563EB); // Xanh Zalo
      case 'XLS':
      case 'XLSX':
      case 'CSV':
        return const Color(0xFF10B981); // Xanh lá Zalo
      case 'PPT':
      case 'PPTX':
        return const Color(0xFFF97316); // Cam Zalo
      case 'ZIP':
      case 'RAR':
      case '7Z':
      case 'TAR':
      case 'GZ':
        return const Color(0xFF8B5CF6); // Tím Zalo
      case 'PNG':
      case 'JPG':
      case 'JPEG':
      case 'WEBP':
      case 'GIF':
      case 'SVG':
        return const Color(0xFF059669); // Xanh mint
      case 'TXT':
      case 'LOG':
      case 'JSON':
      case 'XML':
      default:
        return const Color(0xFFF59E0B); // Vàng Zalo
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Widget _buildStatusIcon(String status, {double iconSize = 13}) {
    switch (status) {
      case 'pending':
        return SizedBox(
          width: iconSize,
          height: iconSize,
          child: const CircularProgressIndicator(
            strokeWidth: 1.5,
            color: Color(0xFF8696A0),
          ),
        );
      case 'read':
        return Icon(
          LucideIcons.checkCheck,
          size: iconSize,
          color: const Color(0xFF53BDEB),
        );
      case 'error':
        return Icon(
          LucideIcons.alertCircle,
          size: iconSize,
          color: Colors.redAccent,
        );
      case 'sent':
      default:
        return Icon(
          LucideIcons.check,
          size: iconSize,
          color: const Color(0xFF8696A0),
        );
    }
  }

  // Parse and build message text
  Widget _buildParsedMessageText({
    required BuildContext context,
    required String rawText,
    required bool isMine,
    required bool isDark,
    required Color textColor,
  }) {
    final linkColor = isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB);

    final urlRegex = RegExp(
      r'((?:https?:\/\/|www\.)[^\s<]+|(?:[a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}(?:\/[^\s<]*)?)',
      caseSensitive: false,
    );

    final matches = urlRegex.allMatches(rawText);
    if (matches.isEmpty) {
      return Text(
        rawText,
        style: TextStyle(
          fontSize: 15,
          height: 1.38,
          color: textColor,
        ),
        overflow: TextOverflow.visible,
      );
    }

    final spans = <InlineSpan>[];
    int lastMatchEnd = 0;

    for (final match in matches) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(
          text: rawText.substring(lastMatchEnd, match.start),
          style: TextStyle(color: textColor, fontSize: 15, height: 1.38),
        ));
      }

      var rawLink = rawText.substring(match.start, match.end);
      String trailingPunctuation = '';
      final punctRegex = RegExp(r'[.,!?:;)"\x27\]]+$');
      final punctMatch = punctRegex.firstMatch(rawLink);
      if (punctMatch != null) {
        trailingPunctuation = punctMatch.group(0)!;
        rawLink = rawLink.substring(0, rawLink.length - trailingPunctuation.length);
      }

      var targetUrl = rawLink.trim();
      if (!targetUrl.contains('://')) {
        targetUrl = 'https://$targetUrl';
      }

      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: GestureDetector(
            onTap: () => _handleLinkClick(context, targetUrl),
            child: Text(
              rawLink,
              style: TextStyle(
                color: linkColor,
                fontSize: 15,
                height: 1.38,
                fontWeight: FontWeight.w600,
                decoration: TextDecoration.underline,
                decorationColor: linkColor,
                decorationThickness: 1.2,
              ),
            ),
          ),
        ),
      );

      if (trailingPunctuation.isNotEmpty) {
        spans.add(TextSpan(
          text: trailingPunctuation,
          style: TextStyle(color: textColor, fontSize: 15, height: 1.38),
        ));
      }

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < rawText.length) {
      spans.add(TextSpan(
        text: rawText.substring(lastMatchEnd),
        style: TextStyle(color: textColor, fontSize: 15, height: 1.38),
      ));
    }

    return Text.rich(
      TextSpan(children: spans),
      overflow: TextOverflow.visible,
    );
  }

  void _handleLinkClick(BuildContext context, String targetUrl) async {
    HapticFeedback.lightImpact();
    final cleanUrl = targetUrl.trim();
    final uri = Uri.tryParse(cleanUrl.contains('://') ? cleanUrl : 'https://$cleanUrl');
    if (uri == null) return;

    // 1. Phân tích điều hướng liên kết nội bộ hệ thống (Smart In-App Navigation)
    final pathSegments = uri.pathSegments;

    // Kênh chat nội bộ: e.g. vuahethong.net/chat/4128, /chat/4128, vcloud://chat/4128
    if ((uri.scheme == 'vcloud' && uri.host == 'chat') || uri.path.contains('/chat/')) {
      String? targetChannelId;
      if (uri.scheme == 'vcloud' && uri.host == 'chat') {
        targetChannelId = pathSegments.isNotEmpty ? pathSegments.first : null;
      } else {
        final chatIdx = pathSegments.indexOf('chat');
        if (chatIdx >= 0 && chatIdx + 1 < pathSegments.length) {
          targetChannelId = pathSegments[chatIdx + 1];
        }
      }

      if (targetChannelId != null && targetChannelId.isNotEmpty) {
        if (targetChannelId == message.channelId) {
          // Đang ở chính kênh hiện tại -> Không push đè để chống lặp và đơ màn hình
          return;
        }
        if (context.mounted) {
          context.push('/chat/$targetChannelId');
        }
        return;
      }
    }

    // Phiếu hỗ trợ / Ticket nội bộ: e.g. vuahethong.net/tickets/123, /tickets/123
    if (uri.path.contains('/tickets/')) {
      final ticketIdx = pathSegments.indexOf('tickets');
      if (ticketIdx >= 0 && ticketIdx + 1 < pathSegments.length) {
        final ticketId = pathSegments[ticketIdx + 1];
        if (ticketId.isNotEmpty && context.mounted) {
          context.push('/tickets/$ticketId');
          return;
        }
      }
    }

    // Timesheets nội bộ: e.g. vuahethong.net/timesheet
    if (uri.path == '/timesheet' || uri.path.startsWith('/timesheet')) {
      if (context.mounted) {
        context.push('/timesheet');
        return;
      }
    }

    // 2. Mở liên kết Web bên ngoài an toàn với In-App Browser (có sẵn nút Xong/Done để đóng)
    final messenger = ScaffoldMessenger.of(context);
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.inAppBrowserView,
      );
      if (!launched) {
        final fallbackLaunched = await launchUrl(uri, mode: LaunchMode.platformDefault);
        if (!fallbackLaunched) {
          await Clipboard.setData(ClipboardData(text: cleanUrl));
          messenger.showSnackBar(
            SnackBar(
              content: Text('Đã sao chép liên kết: $cleanUrl'),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: cleanUrl));
      messenger.showSnackBar(
        SnackBar(
          content: Text('Đã sao chép liên kết: $cleanUrl'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildReactionBadges(BuildContext context, bool isMine) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Padding(
      padding: EdgeInsets.only(
        top: 2,
        left: isMine ? 0 : 4,
        right: isMine ? 4 : 0,
      ),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        alignment: isMine ? WrapAlignment.end : WrapAlignment.start,
        children: message.reactions.map((reaction) {
          return GestureDetector(
            onTap: onReactionTap != null ? () => onReactionTap!(reaction.content) : null,
            behavior: HitTestBehavior.opaque,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
              color: reaction.hasMe
                  ? (isDark ? const Color(0xFF005C4B) : const Color(0xFFD9FDD3))
                  : (isDark ? const Color(0xFF202C33) : const Color(0xFFF0F2F5)),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: reaction.hasMe
                    ? (isDark ? const Color(0xFF00C83A).withValues(alpha: 0.3) : const Color(0xFF00C83A).withValues(alpha: 0.3))
                    : (isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB)),
                width: 0.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  reaction.content,
                  style: const TextStyle(fontSize: 12),
                ),
                if (reaction.count > 1) ...[
                  const SizedBox(width: 4),
                  Text(
                    '${reaction.count}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: reaction.hasMe
                          ? (isDark ? const Color(0xFFE9EDEF) : const Color(0xFF111B21))
                          : (isDark ? const Color(0xFF8696A0) : const Color(0xFF667781)),
                    ),
                  ),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class ChatV2AttachmentImage extends StatefulWidget {
  const ChatV2AttachmentImage({
    super.key,
    required this.attachment,
    required this.fallback,
    required this.onTap,
  });

  final ChatV2Attachment attachment;
  final Widget fallback;
  final VoidCallback onTap;

  static final Map<String, Uint8List> imageCache = {};

  static void cacheBytes(String key, Uint8List bytes) {
    if (key.isNotEmpty && bytes.isNotEmpty && !LocalAttachmentCache.isGenericKey(key)) {
      imageCache[key] = bytes;
    }
  }

  @override
  State<ChatV2AttachmentImage> createState() => _ChatV2AttachmentImageState();
}

class _ChatV2AttachmentImageState extends State<ChatV2AttachmentImage> {
  Uint8List? _bytes;
  bool _loading = true;

  String get _uniqueKey {
    if (widget.attachment.id.isNotEmpty && widget.attachment.id != '0') {
      return 'att_${widget.attachment.id}';
    }
    if (widget.attachment.url != null && widget.attachment.url!.isNotEmpty) {
      return 'url_${widget.attachment.url!}';
    }
    return 'att_hash_${widget.attachment.hashCode}';
  }

  @override
  void initState() {
    super.initState();
    _initBytesSync();
  }

  void _initBytesSync() {
    final key = _uniqueKey;

    // 1. Synchronously grab bytes if present on attachment
    if (widget.attachment.bytes != null && widget.attachment.bytes!.isNotEmpty) {
      _bytes = widget.attachment.bytes;
      _loading = false;
      ChatV2AttachmentImage.cacheBytes(key, widget.attachment.bytes!);
      LocalAttachmentCache.save(key, widget.attachment.bytes!);
      return;
    }

    // 2. Synchronously check in-memory RAM cache with unique key
    final inMemory = ChatV2AttachmentImage.imageCache[key];
    if (inMemory != null && inMemory.isNotEmpty) {
      _bytes = inMemory;
      _loading = false;
      return;
    }

    // 3. Otherwise start async fetch
    _loadImage();
  }

  @override
  void didUpdateWidget(ChatV2AttachmentImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.attachment.id != oldWidget.attachment.id ||
        widget.attachment.url != oldWidget.attachment.url) {
      _initBytesSync();
    } else if (widget.attachment.bytes != null && widget.attachment.bytes!.isNotEmpty) {
      if (_bytes != widget.attachment.bytes) {
        _bytes = widget.attachment.bytes;
        _loading = false;
      }
    }
  }

  Future<void> _loadImage() async {
    final key = _uniqueKey;

    // 1. Cache lookup from disk/storage using unique key, then fallback by id and name
    final cached = await LocalAttachmentCache.getAsync(key) ??
        ChatV2AttachmentImage.imageCache[key] ??
        (widget.attachment.id.isNotEmpty ? await LocalAttachmentCache.getAsync(widget.attachment.id) : null) ??
        (widget.attachment.id.isNotEmpty ? ChatV2AttachmentImage.imageCache[widget.attachment.id] : null) ??
        (widget.attachment.name.isNotEmpty ? await LocalAttachmentCache.getAsync(null, altKey: widget.attachment.name) : null) ??
        (widget.attachment.name.isNotEmpty ? ChatV2AttachmentImage.imageCache[widget.attachment.name] : null);

    if (cached != null && cached.isNotEmpty) {
      if (mounted) {
        setState(() {
          _bytes = cached;
          _loading = false;
        });
      }
      return;
    }

    // 2. Resolve attachment ID (either directly or extracted from URL)
    int? attId = int.tryParse(widget.attachment.id);
    if (attId == null && widget.attachment.url != null) {
      final match = _attachmentIdPattern.firstMatch(widget.attachment.url!);
      if (match != null) {
        attId = int.tryParse(match.group(1)!);
      }
    }

    if (attId != null) {
      try {
        final bytes = await MobileAttachmentRepository().fetchBytes(
          attId,
          accessToken: widget.attachment.accessToken,
        );
        if (bytes.isNotEmpty) {
          ChatV2AttachmentImage.cacheBytes(key, bytes);
          LocalAttachmentCache.save(key, bytes);
          if (mounted) {
            setState(() {
              _bytes = bytes;
              _loading = false;
            });
          }
          return;
        }
      } catch (_) {}
    } else if (widget.attachment.url != null && widget.attachment.url!.isNotEmpty) {
      try {
        final bytes = await odooApiClient.fetchBytes(widget.attachment.url!);
        if (bytes.isNotEmpty) {
          ChatV2AttachmentImage.cacheBytes(key, bytes);
          LocalAttachmentCache.save(key, bytes);
          if (mounted) {
            setState(() {
              _bytes = bytes;
              _loading = false;
            });
          }
          return;
        }
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_bytes != null && _bytes!.isNotEmpty) {
      return GestureDetector(
        onTap: widget.onTap,
        child: Container(
          constraints: const BoxConstraints(
            maxWidth: 290,
            maxHeight: 340,
          ),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(16),
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.memory(
            _bytes!,
            fit: BoxFit.contain,
            cacheWidth: 600,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => widget.fallback,
          ),
        ),
      );
    }

    if (_loading) {
      return Container(
        height: 160,
        width: 220,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(14),
        ),
        alignment: Alignment.center,
        child: const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFF00C83A),
          ),
        ),
      );
    }

    return widget.fallback;
  }
}

/// Icon tài liệu góc gấp phong cách Zalo
class FoldedPageIcon extends StatelessWidget {
  final String ext;
  final Color color;
  final double width;
  final double height;

  const FoldedPageIcon({
    super.key,
    required this.ext,
    required this.color,
    this.width = 36,
    this.height = 44,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(width, height),
      painter: _FoldedPagePainter(color: color),
      child: SizedBox(
        width: width,
        height: height,
        child: Align(
          alignment: const Alignment(0, 0.35),
          child: Text(
            ext.length > 4 ? ext.substring(0, 4) : ext,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}

class _FoldedPagePainter extends CustomPainter {
  final Color color;
  const _FoldedPagePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final fold = size.width * 0.30;
    const r = 4.0;

    // Body with folded top-right corner
    final path = Path()
      ..moveTo(r, 0)
      ..lineTo(size.width - fold, 0)
      ..lineTo(size.width, fold)
      ..lineTo(size.width, size.height - r)
      ..quadraticBezierTo(size.width, size.height, size.width - r, size.height)
      ..lineTo(r, size.height)
      ..quadraticBezierTo(0, size.height, 0, size.height - r)
      ..lineTo(0, r)
      ..quadraticBezierTo(0, 0, r, 0)
      ..close();

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, paint);

    // Fold flap (triangle on top-right)
    final foldPath = Path()
      ..moveTo(size.width - fold, 0)
      ..lineTo(size.width - fold, fold - 1.5)
      ..quadraticBezierTo(
          size.width - fold, fold, size.width - fold + 1.5, fold)
      ..lineTo(size.width, fold)
      ..close();

    final foldPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.40)
      ..style = PaintingStyle.fill;
    canvas.drawPath(foldPath, foldPaint);
  }

  @override
  bool shouldRepaint(covariant _FoldedPagePainter oldDelegate) =>
      oldDelegate.color != color;
}


