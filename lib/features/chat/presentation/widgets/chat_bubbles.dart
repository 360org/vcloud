import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:vcloud/core/api/odoo_api_client.dart';
import 'package:vcloud/core/theme/app_theme.dart';
import 'package:vcloud/core/utils/date_format.dart';
import 'package:vcloud/core/utils/file_download.dart';
import 'package:vcloud/core/utils/local_attachment_cache.dart';
import 'package:vcloud/core/utils/magic_bytes_validator.dart';
import 'package:vcloud/features/chat/application/messages_controller.dart';
import 'package:vcloud/features/chat/presentation/forward_conversation_sheet.dart';
import 'package:vcloud/features/chat/presentation/image_viewer_screen.dart';
import 'package:vcloud/shared/models/message.dart';
import 'package:vcloud/shared/models/profile.dart';
import 'package:vcloud/shared/widgets/app_scaffold.dart';
import 'package:vcloud/shared/widgets/html_network_image.dart';
import 'package:vcloud/shared/widgets/ui_kit.dart';

import 'chat_helpers.dart';
import 'chat_sheets.dart';

Color getIncomingBubbleColor(BuildContext context) =>
    context.isDarkMode ? AppColors.darkSurface : const Color(0xFFE7F8E7);
Color getIncomingBubbleBorder(BuildContext context) =>
    context.isDarkMode ? AppColors.darkBorder : const Color(0xFFC8EFD0);

class EmptyConversation extends StatelessWidget {
  const EmptyConversation({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: context.cardColor.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: context.borderColor),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: context.softColor(AppColors.chat),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.messageCircle,
                color: AppColors.chat,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Chưa có tin nhắn nào',
              style: TextStyle(
                color: context.textColor,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Gửi lời chào để bắt đầu trao đổi.',
              style: TextStyle(color: context.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class DateSeparator extends StatelessWidget {
  const DateSeparator({super.key, required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.midnight.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            Dates.dateVi(date),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class Bubble extends ConsumerWidget {
  const Bubble({
    super.key,
    required this.message,
    required this.mine,
    required this.sender,
    required this.showAvatar,
    required this.readBy,
    this.topSpacing = 8.0,
  });

  final Message message;
  final bool mine;
  final Profile? sender;
  final bool showAvatar;
  final List<Profile> readBy;
  final double topSpacing;

  void _openImageViewer(BuildContext context, String url) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ImageViewerScreen(
          imageUrl: url,
          fileName: attachmentFileName(message),
          attachmentId: message.attachmentIds.isEmpty
              ? null
              : int.tryParse(message.attachmentIds.first),
        ),
      ),
    );
  }

  Future<void> _forwardAttachment(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final target = await showForwardConversationPicker(context);
    if (target == null) return;
    try {
      await ref
          .read(forwardAttachmentActionProvider)
          .forward(target.id, message.attachmentIds.first);
      messenger.showSnackBar(
        SnackBar(content: Text('Đã chuyển tiếp đến ${target.title}')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Chuyển tiếp thất bại: $e')),
      );
    }
  }

  Future<void> _togglePin(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final pinned = message.pinnedAt != null;
    try {
      if (pinned) {
        await ref
            .read(pinMessageActionProvider)
            .unpin(message.conversationId, message.id);
        messenger.showSnackBar(
          const SnackBar(content: Text('Đã bỏ ghim tin nhắn')),
        );
      } else {
        await ref
            .read(pinMessageActionProvider)
            .pin(message.conversationId, message.id);
        messenger.showSnackBar(
          const SnackBar(content: Text('Đã ghim tin nhắn')),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Không thể cập nhật ghim: $e')),
      );
    }
  }

  String? _imagePreviewUrl(WidgetRef ref, MediaInfo? media) {
    if (message.attachmentIds.isNotEmpty) {
      final fileName = attachmentFileName(message);
      if (!isImageAttachment(message, fileName)) return null;
      final id = message.attachmentIds.first;
      return ref
          .read(downloadAttachmentActionProvider)
          .contentUrl(id, url: message.attachmentUrl);
    }
    if (media == null || !media.isImage) return null;
    return media.url;
  }

  void _showContextMenu(BuildContext context, WidgetRef ref) {
    HapticFeedback.mediumImpact();
    final canForwardAttachment = message.attachmentIds.isNotEmpty;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          elevation: 12,
          shadowColor: const Color(0x220F172A),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    leading: const Icon(LucideIcons.copy),
                    title: const Text('Sao chép'),
                    onTap: () {
                      Navigator.pop(context);
                      Clipboard.setData(ClipboardData(text: message.content));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Đã sao chép tin nhắn')),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(LucideIcons.pin),
                    title: Text(
                      message.pinnedAt == null
                          ? 'Ghim tin nhắn'
                          : 'Bỏ ghim tin nhắn',
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _togglePin(context, ref);
                    },
                  ),
                  ListTile(
                    leading: const Icon(LucideIcons.forward),
                    title: const Text('Chuyển tiếp'),
                    onTap: () {
                      Navigator.pop(context);
                      if (!canForwardAttachment) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Chuyển tiếp tin nhắn sắp có'),
                          ),
                        );
                        return;
                      }
                      _forwardAttachment(context, ref);
                    },
                  ),
                  if (mine)
                    ListTile(
                      leading: const Icon(
                        LucideIcons.trash2,
                        color: AppColors.danger,
                      ),
                      title: const Text(
                        'Xóa',
                        style: TextStyle(color: AppColors.danger),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Xóa tin nhắn sắp có')),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media = MediaInfo.fromContent(message.content);
    final maxWidth = MediaQuery.of(context).size.width * 0.72;
    final imagePreviewUrl = _imagePreviewUrl(ref, media);

    return Padding(
      padding: EdgeInsets.only(
        top: topSpacing,
        bottom: readBy.isNotEmpty ? 2 : 0,
      ),
      child: Column(
        crossAxisAlignment: mine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: mine
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!mine) ...[
                SizedBox(
                  width: 34,
                  child: showAvatar
                      ? UserAvatar(
                          userId: sender?.id ?? message.senderId,
                          displayName: (sender?.displayName.isNotEmpty == true)
                              ? sender!.displayName
                              : ((message.senderName?.isNotEmpty == true)
                                  ? message.senderName!
                                  : 'User'),
                          email: sender?.email,
                          avatarUrl:
                              sender?.avatarUrl ?? message.senderAvatarUrl,
                          size: 30,
                        )
                      : const SizedBox(width: 30),
                ),
                const SizedBox(width: 6),
              ],
              GestureDetector(
                onTap: imagePreviewUrl == null
                    ? null
                    : () => _openImageViewer(context, imagePreviewUrl),
                onLongPress: () => _showContextMenu(context, ref),
                child: Builder(builder: (context) {
                  final senderName = (sender?.displayName.isNotEmpty == true)
                      ? sender!.displayName
                      : ((message.senderName?.isNotEmpty == true)
                          ? message.senderName
                          : null);
                  return hasAttachmentOrDocument(message)
                      ? AttachmentBubble(
                          message: message,
                          mine: mine,
                          maxWidth: maxWidth,
                        )
                      : isPollMessage(message)
                          ? PollCardBubble(
                              message: message,
                              mine: mine,
                              maxWidth: maxWidth,
                              senderName: senderName,
                            )
                          : media == null
                              ? TextBubble(
                                  message: message,
                                  mine: mine,
                                  maxWidth: maxWidth,
                                  senderName: senderName,
                                )
                              : MediaBubble(
                                  message: message,
                                  media: media,
                                  mine: mine,
                                  maxWidth: maxWidth,
                                );
                }),
              ),
            ],
          ),
          if (readBy.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 3, right: 8),
              child: ReadAvatars(readers: readBy),
            ),
        ],
      ),
    );
  }
}

Color senderNameColor(String name) {
  const colors = [
    Color(0xFF0D9488), // Teal
    Color(0xFF2563EB), // Blue
    Color(0xFFD97706), // Amber
    Color(0xFF7C3AED), // Purple
    Color(0xFF059669), // Emerald
    Color(0xFFDC2626), // Rose
  ];
  final hash = name.codeUnits.fold(0, (prev, elem) => prev + elem);
  return colors[hash.abs() % colors.length];
}

bool isPollMessage(Message message) {
  if (message.attachmentIds.isNotEmpty) return false;
  final clean = stripHtml(message.content).trim();
  return clean.contains('BÌNH CHỌN:') || clean.startsWith('📊');
}

class PollData {
  PollData({
    required this.question,
    required this.options,
    required this.isMultiple,
    required this.isAnonymous,
  });

  factory PollData.fromContent(String rawContent) {
    final text = stripHtml(rawContent).trim();
    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();

    String question = '';
    final options = <String>[];
    bool isMultiple = false;
    bool isAnonymous = false;

    for (final line in lines) {
      if (line.contains('BÌNH CHỌN:')) {
        question = line.substring(line.indexOf('BÌNH CHỌN:') + 10).trim();
      } else if (line.startsWith('📊')) {
        question = line.replaceAll('📊', '').replaceAll('BÌNH CHỌN:', '').trim();
      } else if (line.startsWith('(') && line.endsWith(')')) {
        if (line.contains('Nhiều đáp án')) isMultiple = true;
        if (line.contains('Ẩn danh')) isAnonymous = true;
      } else {
        final cleaned = line
            .replaceAll(RegExp(r'^[0-9️⃣1️⃣2️⃣3️⃣4️⃣5️⃣6️⃣7️⃣8️⃣9️⃣\.\-\s]+'), '')
            .trim();
        if (cleaned.isNotEmpty) {
          options.add(cleaned);
        }
      }
    }

    if (question.isEmpty) question = 'Bình chọn';
    if (options.isEmpty) {
      options.addAll(['Đồng ý', 'Không đồng ý']);
    }

    return PollData(
      question: question,
      options: options,
      isMultiple: isMultiple,
      isAnonymous: isAnonymous,
    );
  }

  final String question;
  final List<String> options;
  final bool isMultiple;
  final bool isAnonymous;
}

class PollCardBubble extends StatefulWidget {
  const PollCardBubble({
    super.key,
    required this.message,
    required this.mine,
    required this.maxWidth,
    this.senderName,
  });

  final Message message;
  final bool mine;
  final double maxWidth;
  final String? senderName;

  @override
  State<PollCardBubble> createState() => _PollCardBubbleState();
}

class _PollCardBubbleState extends State<PollCardBubble> {
  final Set<int> _votedIndices = {};

  void _toggleVote(int index, bool isMultiple) {
    HapticFeedback.selectionClick();
    setState(() {
      if (_votedIndices.contains(index)) {
        _votedIndices.remove(index);
      } else {
        if (!isMultiple) _votedIndices.clear();
        _votedIndices.add(index);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final poll = PollData.fromContent(widget.message.content);
    final mine = widget.mine;
    final bubbleColor = mine ? AppColors.primary : getIncomingBubbleColor(context);
    final textColor = mine ? Colors.white : context.textColor;
    final mutedColor = textColor.withValues(alpha: mine ? 0.76 : 0.62);
    final totalVotes = _votedIndices.length;

    return Container(
      width: widget.maxWidth.clamp(280.0, 340.0),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        color: bubbleColor,
        border: mine
            ? null
            : Border.all(color: getIncomingBubbleBorder(context).withValues(alpha: 0.7)),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(mine ? 20 : 7),
          topRight: Radius.circular(mine ? 7 : 20),
          bottomLeft: const Radius.circular(20),
          bottomRight: const Radius.circular(20),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x160F172A),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: mine
                      ? Colors.white.withValues(alpha: 0.2)
                      : AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  LucideIcons.barChart3,
                  size: 18,
                  color: mine ? Colors.white : AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      poll.question,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${poll.isMultiple ? "Chọn nhiều" : "Chọn một"} • ${poll.isAnonymous ? "Ẩn danh" : "Công khai"}',
                      style: TextStyle(
                        color: mutedColor,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < poll.options.length; i++) ...[
            Builder(builder: (context) {
              final isSelected = _votedIndices.contains(i);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: PressableScale(
                  onTap: () => _toggleVote(i, poll.isMultiple),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (mine
                              ? Colors.white.withValues(alpha: 0.28)
                              : AppColors.primary.withValues(alpha: 0.15))
                          : (mine
                              ? Colors.white.withValues(alpha: 0.12)
                              : AppColors.surface),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? (mine ? Colors.white : AppColors.primary)
                            : (mine
                                ? Colors.white.withValues(alpha: 0.1)
                                : AppColors.border),
                        width: isSelected ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isSelected
                              ? (poll.isMultiple
                                  ? LucideIcons.checkSquare
                                  : LucideIcons.checkCircle2)
                              : (poll.isMultiple
                                  ? LucideIcons.square
                                  : LucideIcons.circle),
                          size: 18,
                          color: isSelected
                              ? (mine ? Colors.white : AppColors.primary)
                              : mutedColor,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            poll.options[i],
                            style: TextStyle(
                              color: textColor,
                              fontSize: 14,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ),
                        if (isSelected)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: mine
                                  ? Colors.white.withValues(alpha: 0.25)
                                  : AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Đã chọn',
                              style: TextStyle(
                                color: mine ? Colors.white : AppColors.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$totalVotes lượt bình chọn',
                style: TextStyle(
                  color: mutedColor,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Timestamp(
                message: widget.message,
                mine: mine,
                color: mutedColor,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class TextBubble extends StatelessWidget {
  const TextBubble({
    super.key,
    required this.message,
    required this.mine,
    required this.maxWidth,
    this.senderName,
  });

  final Message message;
  final bool mine;
  final double maxWidth;
  final String? senderName;

  @override
  Widget build(BuildContext context) {
    final bubbleColor = mine ? AppColors.primary : getIncomingBubbleColor(context);
    final textColor = mine ? Colors.white : context.textColor;
    final hasSenderName =
        !mine && senderName != null && senderName!.trim().isNotEmpty;

    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.fromLTRB(13, 9, 10, 7),
      decoration: BoxDecoration(
        color: bubbleColor,
        border: mine
            ? null
            : Border.all(color: getIncomingBubbleBorder(context).withValues(alpha: 0.7)),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(mine ? 18 : 6),
          topRight: Radius.circular(mine ? 6 : 18),
          bottomLeft: const Radius.circular(18),
          bottomRight: const Radius.circular(18),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F172A),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasSenderName) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                senderName!.trim(),
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: senderNameColor(senderName!),
                ),
              ),
            ),
          ],
          Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8, bottom: 2),
                child: _buildParsedMessageText(
                  context: context,
                  rawText: message.content,
                  mine: mine,
                  textColor: textColor,
                ),
              ),
              Timestamp(
                message: message,
                mine: mine,
                color: textColor.withValues(alpha: 0.62),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildParsedMessageText({
    required BuildContext context,
    required String rawText,
    required bool mine,
    required Color textColor,
  }) {
    final cleanText = stripHtml(rawText);
    final linkColor = mine ? Colors.white : const Color(0xFF1D4ED8);

    final urlRegex = RegExp(
      r'((?:https?:\/\/|vcloud:\/\/|www\.)[^\s<]+|(?:[a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}(?:\/[^\s<]*)?)',
      caseSensitive: false,
    );

    final matches = urlRegex.allMatches(cleanText);
    if (matches.isEmpty) {
      return Text(
        cleanText,
        style: TextStyle(color: textColor, fontSize: 15, height: 1.35),
      );
    }

    final spans = <InlineSpan>[];
    int lastMatchEnd = 0;

    for (final match in matches) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(
          text: cleanText.substring(lastMatchEnd, match.start),
          style: TextStyle(color: textColor, fontSize: 15, height: 1.35),
        ));
      }

      final linkText = cleanText.substring(match.start, match.end);
      var targetUrl = linkText;
      if (linkText.startsWith('www.')) {
        targetUrl = 'https://$linkText';
      }

      spans.add(
        TextSpan(
          text: linkText,
          style: TextStyle(
            color: linkColor,
            fontSize: 15,
            height: 1.35,
            decoration: TextDecoration.underline,
            decorationColor: linkColor,
            decorationThickness: 1.5,
            fontWeight: FontWeight.w600,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () => _handleLinkClick(context, targetUrl),
        ),
      );

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < cleanText.length) {
      spans.add(TextSpan(
        text: cleanText.substring(lastMatchEnd),
        style: TextStyle(color: textColor, fontSize: 15, height: 1.35),
      ));
    }

    return SelectableText.rich(
      TextSpan(children: spans),
    );
  }

  void _handleLinkClick(BuildContext context, String rawUrl) async {
    HapticFeedback.mediumImpact();
    final url = rawUrl.trim();

    final uri = Uri.tryParse(url);
    if (uri != null) {
      if (uri.scheme == 'vcloud' && uri.host == 'chat') {
        final channelId =
            uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
        if (channelId != null && channelId.isNotEmpty) {
          context.push('/chat/$channelId');
          return;
        }
      } else if (uri.path.contains('/chat/')) {
        final segments = uri.pathSegments;
        final chatIdx = segments.indexOf('chat');
        if (chatIdx >= 0 && chatIdx + 1 < segments.length) {
          final channelId = segments[chatIdx + 1];
          context.push('/chat/$channelId');
          return;
        }
      }
    }

    final parsedUri = Uri.tryParse(url.contains('://') ? url : 'https://$url');
    if (parsedUri != null) {
      try {
        final launched = await launchUrl(
          parsedUri,
          mode: LaunchMode.externalApplication,
        );
        if (!launched && context.mounted) {
          Clipboard.setData(ClipboardData(text: url));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Đã sao chép liên kết: $url')),
          );
        }
      } catch (_) {
        if (context.mounted) {
          Clipboard.setData(ClipboardData(text: url));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Đã sao chép liên kết: $url')),
          );
        }
      }
    }
  }
}

class AttachmentBubble extends ConsumerStatefulWidget {
  const AttachmentBubble({
    super.key,
    required this.message,
    required this.mine,
    required this.maxWidth,
  });

  final Message message;
  final bool mine;
  final double maxWidth;

  @override
  ConsumerState<AttachmentBubble> createState() => _AttachmentBubbleState();
}

class _AttachmentBubbleState extends ConsumerState<AttachmentBubble> {
  bool _downloading = false;

  Future<void> _download() async {
    if (_downloading) return;
    final attachmentId = widget.message.attachmentIds.isNotEmpty
        ? widget.message.attachmentIds.first
        : null;
    final fileName = attachmentFileName(widget.message);
    final ext = fileExtension(fileName).toLowerCase();

    Uint8List? bytes = LocalAttachmentCache.get(
      attachmentId,
      altKey: fileName,
    );

    if (bytes == null || bytes.isEmpty) {
      if (attachmentId == null) return;
      setState(() => _downloading = true);
      try {
        bytes = await ref
            .read(downloadAttachmentActionProvider)
            .bytes(attachmentId);

        if (MagicBytesValidator.isErrorPayload(bytes)) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Tải tệp thất bại. Vui lòng kiểm tra lại kết nối hoặc quyền truy cập.',
              ),
            ),
          );
          return;
        }

        if (ext == 'zip' && !MagicBytesValidator.isValidZipBytes(bytes)) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Tải tệp nén thất bại. Vui lòng kiểm tra lại kết nối hoặc quyền truy cập.',
              ),
            ),
          );
          return;
        }

        LocalAttachmentCache.save(attachmentId, bytes);
        LocalAttachmentCache.save(fileName, bytes);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Không thể tải tệp: $e')));
        }
        return;
      } finally {
        if (mounted) setState(() => _downloading = false);
      }
    }

    final nonNullBytes = bytes;
    if (nonNullBytes.isEmpty) return;

    if (ext == 'txt') {
      final textContent = utf8.decode(nonNullBytes, allowMalformed: true);
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => TxtReaderSheet(
          fileName: fileName,
          content: textContent,
          bytes: nonNullBytes,
        ),
      );
      return;
    }

    if (ext == 'pdf' && kIsWeb) {
      openPdfBlobPreview(nonNullBytes);
      return;
    }

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => DocumentActionSheet(
        fileName: fileName,
        ext: ext,
        bytes: nonNullBytes,
        previewUrl: attachmentId != null
            ? odooApiClient.authenticatedUrl('/api/v1/mobile/attachments/$attachmentId/download')
            : widget.message.attachmentUrl,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mine = widget.mine;
    final message = widget.message;
    final bubbleColor = mine ? AppColors.primary : getIncomingBubbleColor(context);
    final textColor = mine ? Colors.white : context.textColor;
    final mutedColor = textColor.withValues(alpha: mine ? 0.76 : 0.62);
    final fileName = attachmentFileName(message);
    final extension = fileExtension(fileName).toUpperCase();
    final iconColor = fileAccentColor(fileName);
    final innerColor = mine
        ? Colors.white.withValues(alpha: 0.15)
        : AppColors.primary.withValues(alpha: 0.10);
    final attachmentId = message.attachmentIds.isEmpty
        ? null
        : message.attachmentIds.first;
    final previewUrl = attachmentId == null
        ? (message.attachmentUrl != null && message.attachmentUrl!.isNotEmpty
            ? odooApiClient.authenticatedUrl(message.attachmentUrl!)
            : null)
        : ref
              .read(downloadAttachmentActionProvider)
              .contentUrl(attachmentId, url: message.attachmentUrl);

    if (isImageAttachment(message, fileName)) {
      return ImageAttachmentBubble(
        message: message,
        mine: mine,
        maxWidth: widget.maxWidth,
        imageUrl: previewUrl ?? '',
      );
    }

    return Container(
      width: widget.maxWidth.clamp(270.0, 340.0),
      padding: const EdgeInsets.fromLTRB(9, 9, 10, 7),
      decoration: BoxDecoration(
        color: bubbleColor,
        border: mine
            ? null
            : Border.all(color: getIncomingBubbleBorder(context).withValues(alpha: 0.7)),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(mine ? 20 : 7),
          topRight: Radius.circular(mine ? 7 : 20),
          bottomLeft: const Radius.circular(20),
          bottomRight: const Radius.circular(20),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x160F172A),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          PressableScale(
            onTap: _downloading ? null : _download,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: innerColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: mine
                      ? Colors.white.withValues(alpha: 0.08)
                      : AppColors.primary.withValues(alpha: 0.10),
                ),
              ),
              child: Row(
                children: [
                  DocumentPreviewThumb(
                    label: extension,
                    color: iconColor,
                    previewUrl: documentThumbnailUrl(message),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fileName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 15,
                            height: 1.18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          message.attachmentIds.length == 1
                              ? formatFileSize(message.attachmentSize)
                              : '${message.attachmentIds.length} tệp đính kèm',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: mutedColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Tooltip(
                    message: 'Tải xuống',
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: mine
                            ? Colors.white.withValues(alpha: 0.20)
                            : AppColors.primary.withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                      ),
                      child: _downloading
                          ? Padding(
                              padding: const EdgeInsets.all(10),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: mine ? Colors.white : AppColors.primary,
                              ),
                            )
                          : Icon(
                              LucideIcons.download,
                              color: mine ? Colors.white : AppColors.primary,
                              size: 20,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 5),
          Timestamp(message: message, mine: mine, color: mutedColor),
        ],
      ),
    );
  }
}

class ImageAttachmentBubble extends StatelessWidget {
  const ImageAttachmentBubble({
    super.key,
    required this.message,
    required this.mine,
    required this.maxWidth,
    required this.imageUrl,
  });

  final Message message;
  final bool mine;
  final double maxWidth;
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final maxBubbleWidth = (maxWidth * 0.72).clamp(200.0, 300.0);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: maxBubbleWidth,
        maxHeight: 320.0,
        minWidth: 140.0,
        minHeight: 120.0,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: mine ? AppColors.primary : getIncomingBubbleColor(context),
          border: mine
              ? null
              : Border.all(color: getIncomingBubbleBorder(context).withValues(alpha: 0.7)),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(mine ? 20 : 7),
            topRight: Radius.circular(mine ? 7 : 20),
            bottomLeft: const Radius.circular(20),
            bottomRight: const Radius.circular(20),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x160F172A),
              blurRadius: 12,
              offset: Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          alignment: Alignment.bottomRight,
          children: [
            NetworkPreviewImage(
              url: imageUrl,
              fit: BoxFit.cover,
              attachmentId: message.attachmentIds.isEmpty
                  ? null
                  : message.attachmentIds.first,
              fallback: ImageAttachmentFallback(
                fileName: attachmentFileName(message),
              ),
            ),
            Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.50),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Timestamp(
                message: message,
                mine: mine,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ImageAttachmentFallback extends StatelessWidget {
  const ImageAttachmentFallback({super.key, required this.fileName});

  final String fileName;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primary.withValues(alpha: 0.10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(LucideIcons.image, color: AppColors.primary, size: 36),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Text(
              fileName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ImageAttachmentError extends StatelessWidget {
  const ImageAttachmentError({super.key, this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.red.withValues(alpha: 0.08),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(LucideIcons.alertTriangle, color: Colors.orange, size: 28),
          const SizedBox(height: 6),
          const Text(
            'Lỗi tải ảnh',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 6),
            InkWell(
              onTap: onRetry,
              borderRadius: BorderRadius.circular(4),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.refreshCw, size: 12, color: AppColors.primary),
                    SizedBox(width: 4),
                    Text(
                      'Thử lại',
                      style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class NetworkPreviewImage extends ConsumerStatefulWidget {
  const NetworkPreviewImage({
    super.key,
    required this.url,
    required this.fallback,
    this.attachmentId,
    this.fit = BoxFit.cover,
  });

  final String url;
  final Widget fallback;
  final String? attachmentId;
  final BoxFit fit;

  @override
  ConsumerState<NetworkPreviewImage> createState() =>
      _NetworkPreviewImageState();
}

class _NetworkPreviewImageState extends ConsumerState<NetworkPreviewImage> {
  int _retryCount = 0;

  void _retry() {
    setState(() {
      _retryCount++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final heroTag = widget.attachmentId != null
        ? 'hero_image_${widget.attachmentId}'
        : 'hero_image_${widget.url.hashCode}';

    final fileName = widget.fallback is ImageAttachmentFallback
        ? (widget.fallback as ImageAttachmentFallback).fileName
        : null;

    final localBytes = LocalAttachmentCache.get(
      widget.attachmentId,
      altKey: fileName ?? widget.url,
    );

    if (localBytes != null && localBytes.isNotEmpty) {
      final heroTag =
          'image-preview-${widget.attachmentId ?? widget.url}-${localBytes.length}';

      return GestureDetector(
        onTap: () {
          Navigator.of(context).push(
            PageRouteBuilder<void>(
              opaque: false,
              barrierDismissible: true,
              pageBuilder: (_, _, _) => ImageViewerScreen(
                imageUrl: widget.url,
                fileName: fileName ?? 'Image',
                attachmentId: widget.attachmentId == null
                    ? null
                    : int.tryParse(widget.attachmentId!),
              ),
            ),
          );
        },
        child: Hero(
          tag: heroTag,
          child: Image.memory(
            localBytes,
            fit: widget.fit,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => ImageAttachmentError(onRetry: _retry),
          ),
        ),
      );
    }

    final id = widget.attachmentId;
    if (id != null && id.trim().isNotEmpty && int.tryParse(id) != null) {
      return FutureBuilder<Uint8List>(
        future: ref.read(downloadAttachmentActionProvider).bytes(id),
        builder: (context, snapshot) {
          final bytes = snapshot.data;
          if (bytes != null && bytes.isNotEmpty) {
            LocalAttachmentCache.save(id, bytes);
            if (fileName != null) LocalAttachmentCache.save(fileName, bytes);
            return GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  PageRouteBuilder<void>(
                    opaque: false,
                    barrierDismissible: true,
                    pageBuilder: (_, _, _) => ImageViewerScreen(
                      imageUrl: widget.url,
                      fileName: fileName ?? 'Image',
                      attachmentId: int.tryParse(id),
                    ),
                  ),
                );
              },
              child: Image.memory(
                bytes,
                fit: widget.fit,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => ImageAttachmentError(onRetry: _retry),
              ),
            );
          }
          if (snapshot.hasError) {
            return GestureDetector(
              onTap: _retry,
              child: widget.fallback,
            );
          }
          return Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary.withValues(alpha: 0.6),
              ),
            ),
          );
        },
      );
    }

    final rawUrl = (widget.attachmentId != null && widget.attachmentId!.trim().isNotEmpty)
        ? '/api/v1/mobile/attachments/${widget.attachmentId}/download'
        : (widget.url.trim().isNotEmpty ? widget.url.trim() : '');

    if (rawUrl.isEmpty) {
      return widget.fallback;
    }

    final authUrl = odooApiClient.authenticatedUrl(
      _retryCount > 0 ? '$rawUrl${rawUrl.contains('?') ? '&' : '?'}retry=$_retryCount' : rawUrl,
    );

    Widget imageWidget;
    if (kIsWeb) {
      final htmlWidget = buildHtmlNetworkImage(url: authUrl, fit: widget.fit);
      imageWidget = htmlWidget ??
          Image.network(
            authUrl,
            fit: widget.fit,
            headers: odooApiClient.authHeaders,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => ImageAttachmentError(onRetry: _retry),
          );
    } else {
      imageWidget = Image.network(
        authUrl,
        fit: widget.fit,
        headers: odooApiClient.authHeaders,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => widget.fallback,
      );
    }

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          PageRouteBuilder<void>(
            opaque: false,
            barrierDismissible: true,
            barrierColor: Colors.black.withValues(alpha: 0.9),
            pageBuilder: (context, animation, secondaryAnimation) {
              return FadeTransition(
                opacity: animation,
                child: ImageViewerScreen(
                  imageUrl: authUrl,
                  fileName: fileName ?? 'Image',
                  attachmentId: widget.attachmentId == null
                      ? null
                      : int.tryParse(widget.attachmentId!),
                ),
              );
            },
          ),
        );
      },
      child: Hero(
        tag: heroTag,
        child: imageWidget,
      ),
    );
  }
}

class DocumentPreviewThumb extends StatelessWidget {
  const DocumentPreviewThumb({
    super.key,
    required this.label,
    required this.color,
    required this.previewUrl,
  });

  final String label;
  final Color color;
  final String? previewUrl;

  @override
  Widget build(BuildContext context) {
    final url = previewUrl;
    return Container(
      width: 88,
      height: 78,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F172A),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: url == null
                ? DocumentPreviewLines(color: color, label: label)
                : NetworkPreviewImage(
                    url: url,
                    fit: BoxFit.cover,
                    attachmentId: null,
                    fallback: DocumentPreviewLines(color: color, label: label),
                  ),
          ),
          Positioned(
            left: 7,
            bottom: 7,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                label.isEmpty ? 'FILE' : label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DocumentPreviewLines extends StatelessWidget {
  const DocumentPreviewLines({super.key, required this.color, this.label = ''});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(width: 42, height: 5, color: color.withValues(alpha: 0.22)),
              const SizedBox(height: 7),
              for (final width in const [64.0, 58.0, 68.0, 52.0, 61.0]) ...[
                Container(
                  width: width,
                  height: 3,
                  decoration: BoxDecoration(
                    color: AppColors.textMuted.withValues(alpha: 0.24),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 5),
              ],
            ],
          ),
          Positioned(
            right: 2,
            top: 2,
            child: Icon(
              fileIcon(label),
              color: color.withValues(alpha: 0.35),
              size: 26,
            ),
          ),
        ],
      ),
    );
  }
}

class MediaBubble extends StatelessWidget {
  const MediaBubble({
    super.key,
    required this.message,
    required this.media,
    required this.mine,
    required this.maxWidth,
  });

  final Message message;
  final MediaInfo media;
  final bool mine;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      decoration: BoxDecoration(
        color: mine ? AppColors.primary : getIncomingBubbleColor(context),
        border: mine
            ? null
            : Border.all(color: getIncomingBubbleBorder(context).withValues(alpha: 0.7)),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(mine ? 18 : 6),
          topRight: Radius.circular(mine ? 6 : 18),
          bottomLeft: const Radius.circular(18),
          bottomRight: const Radius.circular(18),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x160F172A),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: media.isImage
                ? NetworkPreviewImage(
                    url: media.url,
                    fit: BoxFit.cover,
                    fallback: MediaFallback(media: media),
                    attachmentId: media.attachmentId,
                  )
                : MediaFallback(media: media),
          ),
          if (media.isVideo)
            const Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0x99000000),
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Icon(LucideIcons.play, color: Colors.white, size: 26),
                ),
              ),
            ),
          Container(
            margin: const EdgeInsets.all(7),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.48),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Timestamp(
              message: message,
              mine: mine,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class MediaFallback extends StatelessWidget {
  const MediaFallback({super.key, required this.media});

  final MediaInfo media;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.soft(AppColors.chat),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            media.isVideo ? LucideIcons.video : LucideIcons.image,
            color: AppColors.chat,
            size: 34,
          ),
          const SizedBox(height: 8),
          Text(
            media.displayLabel,
            style: const TextStyle(
              color: AppColors.chat,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class Timestamp extends StatelessWidget {
  const Timestamp({
    super.key,
    required this.message,
    required this.mine,
    required this.color,
  });

  final Message message;
  final bool mine;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          Dates.time(message.createdAt),
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (mine) ...[
          const SizedBox(width: 4),
          MessageStatusIcon(status: message.status, size: 14, color: color),
        ],
      ],
    );
  }
}

class MediaInfo {
  const MediaInfo({
    required this.url,
    required this.isImage,
    required this.isVideo,
    this.label,
    this.attachmentId,
  });

  final String url;
  final bool isImage;
  final bool isVideo;
  final String? label;
  final String? attachmentId;

  String get displayLabel => label ?? (isVideo ? 'Video' : 'Ảnh');
  int? get attachmentIntId =>
      attachmentId == null ? null : int.tryParse(attachmentId!);

  static MediaInfo? fromContent(String content) {
    final clean = stripHtml(content).trim();
    final uri = Uri.tryParse(clean);
    if (uri == null || !uri.hasAbsolutePath) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    final path = uri.path.toLowerCase();
    final isImage =
        path.endsWith('.jpg') ||
        path.endsWith('.jpeg') ||
        path.endsWith('.png') ||
        path.endsWith('.gif') ||
        path.endsWith('.webp');
    final isVideo =
        path.endsWith('.mp4') ||
        path.endsWith('.mov') ||
        path.endsWith('.m4v') ||
        path.endsWith('.webm');
    if (!isImage && !isVideo) return null;
    return MediaInfo(url: clean, isImage: isImage, isVideo: isVideo);
  }

  static List<MediaInfo> extractAllFromContent(String content) {
    final results = <MediaInfo>[];
    final single = fromContent(content);
    if (single != null) {
      results.add(single);
      return results;
    }
    final rawText = stripHtml(content);
    final pattern = RegExp(r'https?:\/\/[^\s<>"{}|\^~\[\]`\\]+');
    final matches = pattern.allMatches(rawText);
    for (final match in matches) {
      var url = match.group(0)!;
      while (url.endsWith('.') || url.endsWith(',') || url.endsWith(')') || url.endsWith(';') || url.endsWith('>')) {
        url = url.substring(0, url.length - 1);
      }
      final media = fromContent(url);
      if (media != null) {
        results.add(media);
      }
    }
    return results;
  }
}

class FileInfo {
  const FileInfo({
    required this.attachmentId,
    required this.name,
    required this.sizeLabel,
  });

  final String attachmentId;
  final String name;
  final String sizeLabel;
}

class ReadAvatars extends StatelessWidget {
  const ReadAvatars({super.key, required this.readers});

  final List<Profile> readers;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final reader in readers)
          Padding(
            padding: const EdgeInsets.only(left: 3),
            child: Container(
              width: 19,
              height: 19,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.surface, width: 1.5),
              ),
              child: ClipOval(
                child: UserAvatar(
                  userId: reader.id,
                  displayName: reader.displayName,
                  email: reader.email,
                  avatarUrl: reader.avatarUrl,
                  size: 19,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
