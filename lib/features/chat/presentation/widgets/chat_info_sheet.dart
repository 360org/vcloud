import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:vcloud/core/config/env.dart';
import 'package:vcloud/core/theme/app_theme.dart';
import 'package:vcloud/core/utils/file_download.dart';
import 'package:vcloud/features/chat/application/messages_controller.dart';
import 'package:vcloud/features/chat/presentation/forward_conversation_sheet.dart';
import 'package:vcloud/features/chat/presentation/image_viewer_screen.dart';
import 'package:vcloud/shared/models/conversation.dart';
import 'package:vcloud/shared/models/message.dart';
import 'package:vcloud/shared/models/profile.dart';
import 'package:vcloud/shared/widgets/app_scaffold.dart';
import 'package:vcloud/shared/widgets/ui_kit.dart';

import 'chat_bubbles.dart';
import 'chat_helpers.dart';
import 'chat_wallpaper.dart';

class ChatInfoSheet extends ConsumerStatefulWidget {
  const ChatInfoSheet({
    super.key,
    required this.title,
    required this.conversation,
    required this.currentIdentityIds,
    required this.messages,
  });

  final String title;
  final Conversation? conversation;
  final Set<String> currentIdentityIds;
  final List<Message> messages;

  @override
  ConsumerState<ChatInfoSheet> createState() => _ChatInfoSheetState();
}

class _ChatInfoSheetState extends ConsumerState<ChatInfoSheet> {
  int _tab = 0;

  Profile? get _otherProfile {
    final conversation = widget.conversation;
    if (conversation == null || conversation.isGroup) return null;
    for (final member in conversation.members) {
      if (!isCurrentProfile(member.profile, widget.currentIdentityIds)) {
        return member.profile;
      }
    }
    return null;
  }

  List<MediaInfo> get _mediaItems {
    final items = <MediaInfo>[];
    final seen = <String>{};
    for (final message in widget.messages) {
      if (message.attachmentIds.isNotEmpty) {
        final fileName = attachmentFileName(message);
        if (isImageAttachment(message, fileName)) {
          for (final attachmentId in message.attachmentIds) {
            if (seen.add('att_$attachmentId')) {
              items.add(
                MediaInfo(
                  url: ref
                      .read(downloadAttachmentActionProvider)
                      .contentUrl(attachmentId, url: message.attachmentUrl),
                  isImage: true,
                  isVideo: false,
                  label: fileName,
                  attachmentId: attachmentId,
                ),
              );
            }
          }
          continue;
        }
      } else if (message.attachmentUrl != null && message.attachmentUrl!.isNotEmpty) {
        final fileName = attachmentFileName(message);
        if (isImageAttachment(message, fileName)) {
          if (seen.add('url_${message.attachmentUrl}')) {
            items.add(
              MediaInfo(
                url: message.attachmentUrl!,
                isImage: true,
                isVideo: false,
                label: fileName,
              ),
            );
          }
          continue;
        }
      }

      final mediaList = MediaInfo.extractAllFromContent(message.content);
      for (final media in mediaList) {
        if (seen.add('content_${media.url}')) {
          items.add(media);
        }
      }
    }
    return items.reversed.toList();
  }

  List<String> get _links {
    final links = <String>{};
    final pattern = RegExp(r'https?:\/\/[^\s<>"{}|\^~\[\]`\\]+');
    for (final message in widget.messages) {
      final rawText = stripHtml(message.content);
      final matches = pattern.allMatches(rawText);
      for (final match in matches) {
        var url = match.group(0)!;
        while (url.endsWith('.') || url.endsWith(',') || url.endsWith(')') || url.endsWith(';') || url.endsWith('>')) {
          url = url.substring(0, url.length - 1);
        }
        if (url.length > 8 && !url.contains('/api/v1/mobile/attachments')) {
          links.add(url);
        }
      }
    }
    return links.toList().reversed.toList();
  }

  List<FileInfo> get _files {
    final files = <FileInfo>[];
    final seen = <String>{};
    for (final message in widget.messages) {
      if (message.attachmentIds.isEmpty) continue;
      final fileName = attachmentFileName(message);
      if (isImageAttachment(message, fileName)) continue;

      for (final attachmentId in message.attachmentIds) {
        if (!seen.add(attachmentId)) continue;
        files.add(
          FileInfo(
            attachmentId: attachmentId,
            name: fileName,
            sizeLabel: formatFileSize(message.attachmentSize),
          ),
        );
      }
    }
    return files.reversed.toList();
  }

  @override
  Widget build(BuildContext context) {
    final other = _otherProfile;
    final shareLink =
        '${Env.odooApiBaseUrl}/chat/${widget.conversation?.id ?? 'direct'}';
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: context.isDarkMode ? AppColors.darkSurface : const Color(0xFFF6F6FA),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(34)),
          ),
          clipBehavior: Clip.antiAlias,
          child: CustomScrollView(
            controller: scrollController,
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
                  child: Column(
                    children: [
                      Container(
                        width: 46,
                        height: 5,
                        decoration: BoxDecoration(
                          color: context.borderColor,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                      const SizedBox(height: 22),
                      LargeChatAvatar(
                        title: widget.title,
                        conversation: widget.conversation,
                        other: other,
                      ),
                      const SizedBox(height: 18),
                      Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: context.textColor,
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Row(
                        children: [
                          Expanded(
                            child: InfoActionTile(
                              icon: LucideIcons.bellOff,
                              label: 'Tắt thông báo',
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: InfoActionTile(
                              icon: LucideIcons.search,
                              label: 'Tìm kiếm',
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: InfoActionTile(
                              icon: LucideIcons.moreHorizontal,
                              label: 'Thêm',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      ShareLinkCard(link: shareLink),
                      const SizedBox(height: 18),
                      InfoSegmentedTabs(
                        selected: _tab,
                        onChanged: (value) => setState(() => _tab = value),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                sliver: _buildTabContent(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTabContent() {
    return switch (_tab) {
      0 => MediaGrid(items: _mediaItems),
      1 => SimpleInfoList(
        icon: LucideIcons.link,
        emptyText: 'Chưa có liên kết',
        items: _links,
      ),
      _ => FileInfoList(items: _files),
    };
  }
}

class LargeChatAvatar extends StatelessWidget {
  const LargeChatAvatar({
    super.key,
    required this.title,
    required this.conversation,
    required this.other,
  });

  final String title;
  final Conversation? conversation;
  final Profile? other;

  @override
  Widget build(BuildContext context) {
    final isGroup = conversation?.isGroup == true;
    return UserAvatar(
      userId: isGroup ? (conversation?.id ?? title) : (other?.id ?? title),
      displayName: isGroup ? title : (other?.displayName ?? title),
      email: other?.email,
      avatarUrl: isGroup ? null : other?.avatarUrl,
      isGroup: isGroup,
      size: 112,
    );
  }
}

class InfoActionTile extends StatelessWidget {
  const InfoActionTile({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 78,
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: context.isDarkMode
                ? const Color(0x33000000)
                : const Color(0x0F0F172A),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.primary, size: 24),
          const SizedBox(height: 7),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class ShareLinkCard extends StatelessWidget {
  const ShareLinkCard({super.key, required this.link});

  final String link;

  Future<void> _copyLink(BuildContext context) async {
    HapticFeedback.lightImpact();
    await Clipboard.setData(ClipboardData(text: link));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã sao chép liên kết chia sẻ: $link'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _openShareOptions(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => ShareLinkSheet(link: link),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: () => _copyLink(context),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 14, 12, 14),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: context.isDarkMode
                  ? const Color(0x33000000)
                  : const Color(0x0F0F172A),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Liên kết chia sẻ',
                        style: TextStyle(
                          color: context.textColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        LucideIcons.copy,
                        color: context.textSecondary,
                        size: 14,
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    link,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              tooltip: 'Tùy chọn chia sẻ & Mã QR',
              onPressed: () => _openShareOptions(context),
              icon: const Icon(
                LucideIcons.qrCode,
                color: AppColors.primary,
                size: 26,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ShareLinkSheet extends ConsumerWidget {
  const ShareLinkSheet({super.key, required this.link});

  final String link;

  Future<void> _copy(BuildContext context) async {
    HapticFeedback.lightImpact();
    await Clipboard.setData(ClipboardData(text: link));
    if (!context.mounted) return;
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Đã sao chép liên kết chia sẻ: $link')),
    );
  }

  Future<void> _forward(BuildContext context, WidgetRef ref) async {
    HapticFeedback.lightImpact();
    Navigator.pop(context);
    final target = await showForwardConversationPicker(context);
    if (target == null || !context.mounted) return;
    try {
      await ref
          .read(sendMessageActionProvider)
          .send(target.id, 'Tham gia trò chuyện: $link');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đã chia sẻ liên kết đến ${target.title}')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Chia sẻ thất bại: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: context.isDarkMode
                  ? const Color(0x4D000000)
                  : const Color(0x260F172A),
              blurRadius: 20,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: context.borderColor,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Tùy chọn chia sẻ',
              style: TextStyle(
                color: context.textColor,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  const Icon(LucideIcons.link, color: AppColors.primary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SelectableText(
                      link,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.copy, color: AppColors.primary, size: 20),
              ),
              title: Text('Sao chép liên kết', style: TextStyle(color: context.textColor, fontWeight: FontWeight.w700)),
              subtitle: Text('Lưu liên kết vào bộ nhớ tạm', style: TextStyle(color: context.textSecondary)),
              onTap: () => _copy(context),
            ),
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.send, color: Color(0xFF10B981), size: 20),
              ),
              title: Text('Gửi đến cuộc trò chuyện khác', style: TextStyle(color: context.textColor, fontWeight: FontWeight.w700)),
              subtitle: Text('Chuyển tiếp liên kết cho người dùng khác', style: TextStyle(color: context.textSecondary)),
              onTap: () => _forward(context, ref),
            ),
          ],
        ),
      ),
    );
  }
}

class InfoSegmentedTabs extends StatelessWidget {
  const InfoSegmentedTabs({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final int selected;
  final ValueChanged<int> onChanged;

  static const _labels = ['Media', 'Links', 'File'];

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: context.isDarkMode
              ? context.cardColor
              : Colors.white.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: context.isDarkMode
                  ? const Color(0x33000000)
                  : const Color(0x120F172A),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < _labels.length; index++)
              PressableScale(
                onTap: () => onChanged(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: selected == index
                        ? (context.isDarkMode
                            ? AppColors.darkSurface
                            : const Color(0xFFE6E7EB))
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _labels[index],
                    style: TextStyle(
                      color: selected == index
                          ? (context.isDarkMode ? Colors.white : AppColors.textPrimary)
                          : context.textSecondary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class MediaGrid extends StatelessWidget {
  const MediaGrid({super.key, required this.items});

  final List<MediaInfo> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SliverToBoxAdapter(
        child: InfoEmptyState(icon: LucideIcons.image, text: 'Chưa có media'),
      );
    }
    return SliverGrid.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return PressableScale(
          onTap: item.isImage
              ? () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ImageViewerScreen(
                        imageUrl: item.url,
                        fileName: item.displayLabel,
                        attachmentId: item.attachmentIntId,
                      ),
                    ),
                  );
                }
              : null,
          child: ClipRect(
            child: item.isImage
                ? ColoredBox(
                    color: AppColors.soft(AppColors.chat),
                    child: NetworkPreviewImage(
                      url: item.url,
                      fit: BoxFit.cover,
                      fallback: MediaFallback(media: item),
                      attachmentId: item.attachmentId,
                    ),
                  )
                : const ColoredBox(
                    color: Color(0x1434D399),
                    child: Center(
                      child: Icon(
                        LucideIcons.video,
                        color: AppColors.textSecondary,
                        size: 32,
                      ),
                    ),
                  ),
          ),
        );
      },
    );
  }
}

class FileInfoList extends ConsumerWidget {
  const FileInfoList({super.key, required this.items});

  final List<FileInfo> items;

  Future<void> _download(
    BuildContext context,
    WidgetRef ref,
    FileInfo item,
  ) async {
    try {
      final bytes = await ref
          .read(downloadAttachmentActionProvider)
          .bytes(item.attachmentId);
      final saved = await saveBytesToFile(bytes, item.name);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            saved
                ? 'Đã tải tệp ${item.name} thành công'
                : 'Hủy tải tệp ${item.name}',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không thể tải tệp: $e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      return const SliverToBoxAdapter(
        child: InfoEmptyState(icon: LucideIcons.fileText, text: 'Chưa có tệp'),
      );
    }
    return SliverList.separated(
      itemCount: items.length,
      separatorBuilder: (_, _) => Divider(height: 1, color: context.borderColor),
      itemBuilder: (context, index) {
        final item = items[index];
        final accent = fileAccentColor(item.name);
        return Material(
          color: context.cardColor,
          child: InkWell(
            onTap: () => _download(context, ref, item),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.soft(accent),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(LucideIcons.fileText, color: accent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: context.textColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.sizeLabel,
                          style: TextStyle(
                            color: context.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    LucideIcons.download,
                    color: context.textSecondary,
                    size: 19,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class SimpleInfoList extends StatelessWidget {
  const SimpleInfoList({
    super.key,
    required this.icon,
    required this.emptyText,
    required this.items,
  });

  final IconData icon;
  final String emptyText;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return SliverToBoxAdapter(
        child: InfoEmptyState(icon: icon, text: emptyText),
      );
    }
    return SliverList.separated(
      itemCount: items.length,
      separatorBuilder: (_, _) => Divider(height: 1, color: context.borderColor),
      itemBuilder: (context, index) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          color: context.cardColor,
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  items[index],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class InfoEmptyState extends StatelessWidget {
  const InfoEmptyState({super.key, required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 26),
      child: Column(
        children: [
          Icon(icon, color: context.textSecondary, size: 34),
          const SizedBox(height: 10),
          Text(
            text,
            style: TextStyle(
              color: context.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
