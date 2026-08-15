import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/api/mobile_attachment_repository.dart';
import '../../../../core/api/odoo_api_client.dart';
import '../../../../core/utils/file_download.dart';
import '../../../../core/utils/local_attachment_cache.dart';
import '../../data/models/chat_v2_message.dart';
import '../screens/chat_v2_image_viewer_screen.dart';

class ChatV2MessageItem extends StatelessWidget {
  const ChatV2MessageItem({
    super.key,
    required this.message,
    this.showSenderName = false,
    this.onLongPress,
  });

  final ChatV2Message message;
  final bool showSenderName;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final isMine = message.isMine;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final timeStr = message.createdAt != null
        ? DateFormat('HH:mm').format(message.createdAt!)
        : '';

    final imageAttachments = message.attachments.where((a) => a.isImage).toList();
    final docAttachments = message.attachments.where((a) => !a.isImage).toList();
    final hasImages = imageAttachments.isNotEmpty;
    final hasDocs = docAttachments.isNotEmpty;
    final isHistoricalImage = message.isImageFilename && !hasImages;
    final hasAnyImage = hasImages || isHistoricalImage;

    final cleanContent = message.content.trim();
    final isFileNameContent = cleanContent.isEmpty ||
        message.isImageFilename ||
        cleanContent == 'Sent attachment' ||
        imageAttachments.any((a) => a.name.trim() == cleanContent || cleanContent.contains(a.name.trim()));

    final hasRealCaption = hasAnyImage && !isFileNameContent;
    final isPureImage = hasAnyImage && !hasRealCaption && !hasDocs;

    return GestureDetector(
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
        child: Row(
          mainAxisAlignment:
              isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFE2E8F0), Color(0xFFCBD5E1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                message.authorName.isNotEmpty
                    ? message.authorName[0].toUpperCase()
                    : 'U',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF334155),
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: isPureImage
                ? _buildPureImageBubble(context, imageAttachments, isMine, timeStr)
                : Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.76,
                    ),
                    padding: hasAnyImage
                        ? EdgeInsets.zero
                        : const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
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
                          color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                          blurRadius: 4,
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
                      child: Column(
                        crossAxisAlignment:
                            isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!isMine && showSenderName)
                            Padding(
                              padding: const EdgeInsets.only(top: 8, left: 12, right: 12, bottom: 4),
                              child: Text(
                                message.authorName,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF00C83A),
                                ),
                              ),
                            ),
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
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (final att in docAttachments) ...[
                                    _buildDocumentAttachment(context, att, isMine),
                                    const SizedBox(height: 4),
                                  ],
                                ],
                              ),
                            ),
                          ] else if (message.isDocumentFilename) ...[
                            // 4. Render document filename card
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              child: _buildDocumentFilenameCard(context, isMine),
                            ),
                          ],
                          // 5. Render message text/caption if applicable
                          if (message.content.isNotEmpty &&
                              !message.isImageFilename &&
                              !message.isDocumentFilename &&
                              (!hasImages || !isFileNameContent)) ...[
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
                          ],
                          Padding(
                            padding: hasAnyImage
                                ? const EdgeInsets.only(bottom: 6, right: 10, left: 10)
                                : const EdgeInsets.only(top: 3),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.end,
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
                            ),
                          ),
                        ],
                      ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isMine
        ? Colors.white
        : isDark
            ? Colors.white
            : const Color(0xFF0F172A);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: isMine
            ? Colors.white.withValues(alpha: 0.16)
            : isDark
                ? Colors.white.withValues(alpha: 0.08)
                : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: isMine
                  ? Colors.white.withValues(alpha: 0.25)
                  : const Color(0xFF00C83A).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              LucideIcons.image,
              size: 16,
              color: isMine ? Colors.white : const Color(0xFF00C83A),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Hình ảnh',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: textColor.withValues(alpha: 0.75),
                  ),
                ),
                Text(
                  fileName,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageFilenameCard(BuildContext context, bool isMine) {
    final cleanName = message.content.trim();
    final localBytes = LocalAttachmentCache.get(null, altKey: cleanName) ??
        ChatV2AttachmentImage.imageCache[cleanName] ??
        ChatV2AttachmentImage.imageCache[message.id];

    if (localBytes != null && localBytes.isNotEmpty) {
      return _buildImageAttachment(
        context,
        ChatV2Attachment(
          id: message.id,
          name: cleanName,
          bytes: localBytes,
          mimetype: 'image/png',
        ),
        isMine,
      );
    }

    return _buildSimpleFilenameCard(context, isMine, cleanName);
  }

  Widget _buildDocumentAttachment(BuildContext context, ChatV2Attachment att, bool isMine) {
    final fullUrl = att.resolveFullUrl(odooApiClient.absoluteUrl(''));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isMine
        ? Colors.white
        : isDark
            ? Colors.white
            : const Color(0xFF0F172A);

    final ext = att.name.contains('.') ? att.name.split('.').last.toUpperCase() : 'DOC';
    final badgeColor = _getFileBadgeColor(ext);

    return InkWell(
      onTap: () {
        if (fullUrl.isNotEmpty) {
          openDownloadUrl(fullUrl);
        }
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        margin: const EdgeInsets.only(bottom: 2),
        decoration: BoxDecoration(
          color: isMine
              ? Colors.white.withValues(alpha: 0.16)
              : isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: isMine ? Colors.white.withValues(alpha: 0.25) : badgeColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                ext.length > 4 ? ext.substring(0, 4) : ext,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isMine ? Colors.white : badgeColor,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Tài liệu đính kèm',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: textColor.withValues(alpha: 0.75),
                    ),
                  ),
                  Text(
                    att.name,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (att.fileSize != null)
                    Text(
                      _formatFileSize(att.fileSize!),
                      style: TextStyle(
                        fontSize: 11,
                        color: textColor.withValues(alpha: 0.75),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isMine ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                LucideIcons.download,
                size: 14,
                color: isMine ? Colors.white : const Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentFilenameCard(BuildContext context, bool isMine) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isMine
        ? Colors.white
        : isDark
            ? Colors.white
            : const Color(0xFF0F172A);

    final ext = message.content.contains('.') ? message.content.split('.').last.toUpperCase() : 'DOC';
    final badgeColor = _getFileBadgeColor(ext);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: isMine
            ? Colors.white.withValues(alpha: 0.16)
            : isDark
                ? Colors.white.withValues(alpha: 0.08)
                : const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: isMine ? Colors.white.withValues(alpha: 0.25) : badgeColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              ext.length > 4 ? ext.substring(0, 4) : ext,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isMine ? Colors.white : badgeColor,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message.content,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getFileBadgeColor(String ext) {
    switch (ext) {
      case 'PDF':
        return Colors.redAccent;
      case 'DOC':
      case 'DOCX':
        return Colors.blueAccent;
      case 'XLS':
      case 'XLSX':
        return const Color(0xFF10B981);
      case 'ZIP':
      case 'RAR':
        return Colors.purpleAccent;
      default:
        return Colors.orangeAccent;
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
      return SelectableText(
        rawText,
        style: TextStyle(
          fontSize: 15,
          height: 1.38,
          color: textColor,
        ),
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
        TextSpan(
          text: rawLink,
          style: TextStyle(
            color: linkColor,
            fontSize: 15,
            height: 1.38,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.underline,
            decorationColor: linkColor,
            decorationThickness: 1.2,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () => _handleLinkClick(context, targetUrl),
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

    return SelectableText.rich(
      TextSpan(children: spans),
    );
  }

  void _handleLinkClick(BuildContext context, String targetUrl) async {
    HapticFeedback.lightImpact();
    final uri = Uri.tryParse(targetUrl);
    final messenger = ScaffoldMessenger.of(context);
    if (uri != null) {
      try {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (!launched) {
          await Clipboard.setData(ClipboardData(text: targetUrl));
          messenger.showSnackBar(
            SnackBar(
              content: Text('Đã sao chép liên kết: $targetUrl'),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } catch (_) {
        await Clipboard.setData(ClipboardData(text: targetUrl));
        messenger.showSnackBar(
          SnackBar(
            content: Text('Đã sao chép liên kết: $targetUrl'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
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
    if (key.isNotEmpty && bytes.isNotEmpty) {
      imageCache[key] = bytes;
    }
  }

  @override
  State<ChatV2AttachmentImage> createState() => _ChatV2AttachmentImageState();
}

class _ChatV2AttachmentImageState extends State<ChatV2AttachmentImage> {
  Uint8List? _bytes;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    // 1. Direct in-memory bytes if provided on attachment
    if (widget.attachment.bytes != null && widget.attachment.bytes!.isNotEmpty) {
      ChatV2AttachmentImage.cacheBytes(widget.attachment.id, widget.attachment.bytes!);
      LocalAttachmentCache.save(widget.attachment.name, widget.attachment.bytes!);
      if (mounted) {
        setState(() {
          _bytes = widget.attachment.bytes;
          _loading = false;
        });
      }
      return;
    }

    // 2. Cache lookup (LocalAttachmentCache & imageCache)
    final cached = LocalAttachmentCache.get(
      widget.attachment.id,
      altKey: widget.attachment.name,
    ) ?? ChatV2AttachmentImage.imageCache[widget.attachment.id] ?? ChatV2AttachmentImage.imageCache[widget.attachment.name];

    if (cached != null && cached.isNotEmpty) {
      if (mounted) {
        setState(() {
          _bytes = cached;
          _loading = false;
        });
      }
      return;
    }

    // 3. Network fetch via MobileAttachmentRepository
    final attId = int.tryParse(widget.attachment.id);
    if (attId != null) {
      try {
        final bytes = await MobileAttachmentRepository().fetchBytes(
          attId,
          accessToken: widget.attachment.accessToken,
        );
        if (bytes.isNotEmpty) {
          ChatV2AttachmentImage.cacheBytes(widget.attachment.id, bytes);
          LocalAttachmentCache.save(widget.attachment.id, bytes);
          LocalAttachmentCache.save(widget.attachment.name, bytes);
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

    if (_bytes != null) {
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
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => widget.fallback,
          ),
        ),
      );
    }

    return widget.fallback;
  }
}

