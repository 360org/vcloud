import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../../../core/utils/date_format.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../application/chat_v2_inbox_controller.dart';
import '../../domain/models/chat_v2_inbox_item.dart';

class ChatV2InboxTab extends ConsumerWidget {
  const ChatV2InboxTab({
    super.key,
    required this.tabType,
  });

  final ChatV2InboxTabType tabType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inboxState = ref.watch(chatV2InboxControllerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final items = switch (tabType) {
      ChatV2InboxTabType.inbox => inboxState.inboxItems,
      ChatV2InboxTabType.starred => inboxState.starredItems,
      ChatV2InboxTabType.history => inboxState.historyItems,
    };

    if (inboxState.isLoading && items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00C83A)),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Đang tải thư...',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (inboxState.error != null && items.isEmpty) {
      return _buildErrorState(context, ref, isDark, inboxState.error!);
    }

    if (items.isEmpty) {
      return _buildEmptyState(context, isDark);
    }

    return RefreshIndicator(
      color: const Color(0xFF00C83A),
      onRefresh: () async {
        await ref
            .read(chatV2InboxControllerProvider.notifier)
            .loadActiveTab(refresh: true);
      },
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        itemCount: items.length + (tabType == ChatV2InboxTabType.inbox ? 1 : 0),
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (tabType == ChatV2InboxTabType.inbox) {
            if (index == 0) {
              return _buildMarkAllDoneHeader(context, ref, isDark, items.length);
            }
            final item = items[index - 1];
            return _InboxMessageCard(
              key: ValueKey('inbox_item_${item.id}'),
              item: item,
              tabType: tabType,
              isDark: isDark,
            );
          }
          final item = items[index];
          return _InboxMessageCard(
            key: ValueKey('inbox_item_${item.id}'),
            item: item,
            tabType: tabType,
            isDark: isDark,
          );
        },
      ),
    );
  }

  Widget _buildMarkAllDoneHeader(
    BuildContext context,
    WidgetRef ref,
    bool isDark,
    int count,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                LucideIcons.inbox,
                size: 16,
                color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
              ),
              const SizedBox(width: 8),
              Text(
                'Cần xử lý ($count)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Đánh dấu tất cả là xong?'),
                  content: const Text(
                    'Tất cả tin nhắn trong Hộp thư đến sẽ được chuyển sang phần Lịch sử.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Hủy'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00C83A),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Đồng ý'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await ref
                    .read(chatV2InboxControllerProvider.notifier)
                    .markAllDone();
              }
            },
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    LucideIcons.checkCheck,
                    size: 15,
                    color: Color(0xFF00C83A),
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Đánh dấu tất cả',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF00C83A),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    final (icon, title, subtitle) = switch (tabType) {
      ChatV2InboxTabType.inbox => (
          LucideIcons.inbox,
          'Hộp thư đến trống',
          'Bạn đã hoàn thành và xử lý hết tất cả tin nhắn!',
        ),
      ChatV2InboxTabType.starred => (
          LucideIcons.star,
          'Chưa có tin nhắn gắn sao',
          'Gắn sao các thông báo hoặc tin nhắn quan trọng để lưu trữ tại đây.',
        ),
      ChatV2InboxTabType.history => (
          LucideIcons.history,
          'Lịch sử trống',
          'Các tin nhắn sau khi bạn đánh dấu hoàn thành sẽ xuất hiện tại đây.',
        ),
    };

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 30,
                color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white60 : const Color(0xFF64748B),
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, WidgetRef ref, bool isDark, String errorMsg) {
    final isNotSupported = errorMsg.contains('405') ||
        errorMsg.contains('404') ||
        errorMsg.contains('Method Not Allowed');

    final title = isNotSupported
        ? 'Máy chủ chưa nâng cấp tính năng'
        : 'Không thể tải Hộp thư đến';

    final subtitle = isNotSupported
        ? 'Máy chủ Odoo hiện tại chưa hỗ trợ Hộp thư đến Discuss (cần nâng cấp module v_mobile lên v19.0.1.2.70).'
        : 'Đã có lỗi xảy ra khi tải dữ liệu từ máy chủ. Vui lòng kiểm tra lại kết nối mạng.';

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFFEF4444).withValues(alpha: 0.15)
                    : const Color(0xFFFEE2E2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isNotSupported ? LucideIcons.cloudAlert : LucideIcons.alertCircle,
                size: 32,
                color: const Color(0xFFEF4444),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white60 : const Color(0xFF64748B),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                ref
                    .read(chatV2InboxControllerProvider.notifier)
                    .loadActiveTab(refresh: true);
              },
              icon: const Icon(LucideIcons.rotateCw, size: 16),
              label: const Text('Thử lại'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00C83A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InboxMessageCard extends ConsumerWidget {
  const _InboxMessageCard({
    super.key,
    required this.item,
    required this.tabType,
    required this.isDark,
  });

  final ChatV2InboxItem item;
  final ChatV2InboxTabType tabType;
  final bool isDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isStarred = item.isStarred;
    final snippet = item.plainSnippet;
    final hasSubject = item.subject.isNotEmpty;
    final hasRecordName = item.recordName.isNotEmpty;

    return Material(
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          // Bấm vào thẻ: Nếu là discuss.channel thì mở phòng chat tương ứng
          if (item.channelId != null && item.channelId! > 0) {
            context.push('/chat_v2/${item.channelId}');
          } else {
            // Mở dialog xem nội dung chi tiết
            _showDetailDialog(context, ref);
          }
        },
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : const Color(0xFFE2E8F0),
              width: 0.8,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Avatar + Author + Record Chip + Time
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  UserAvatar(
                    userId: item.authorId?.toString() ?? '',
                    displayName: item.authorName,
                    avatarUrl: item.authorAvatar,
                    size: 32,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.authorName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        if (hasRecordName)
                          Container(
                            margin: const EdgeInsets.only(top: 2),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF0077CD).withValues(alpha: 0.18)
                                  : const Color(0xFFE0F2FE),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              item.recordName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? const Color(0xFF38BDF8)
                                    : const Color(0xFF0284C7),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (item.date != null)
                    Text(
                      Dates.dateVi(item.date!),
                      style: TextStyle(
                        fontSize: 11.5,
                        color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                      ),
                    ),
                ],
              ),

              if (hasSubject) ...[
                const SizedBox(height: 8),
                Text(
                  item.subject,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
              ],

              // Message Body Snippet
              if (snippet.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  snippet,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                    height: 1.35,
                  ),
                ),
              ],

              // Attachments row (nếu có)
              if (item.attachments.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: item.attachments.map((att) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            LucideIcons.paperclip,
                            size: 12,
                            color: isDark ? Colors.white60 : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 4),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 160),
                            child: Text(
                              att.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.white70 : const Color(0xFF475569),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],

              const SizedBox(height: 10),
              // Bottom Action Row: [Star Button] [Mark Done Button] [Open Channel]
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Nút Gắn sao ⭐
                  Material(
                    color: Colors.transparent,
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: IconButton(
                      icon: Icon(
                        isStarred ? Icons.star_rounded : Icons.star_outline_rounded,
                        size: 21,
                        color: isStarred
                            ? const Color(0xFFF59E0B)
                            : (isDark ? Colors.white38 : const Color(0xFF94A3B8)),
                      ),
                      tooltip: isStarred ? 'Bỏ gắn sao' : 'Gắn sao',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      splashRadius: 18,
                      onPressed: () {
                        ref
                            .read(chatV2InboxControllerProvider.notifier)
                            .toggleStar(item);
                      },
                    ),
                  ),

                  // Nút Đánh dấu đã xong ✔️ (chỉ hiển thị khi đang trong Inbox)
                  if (tabType == ChatV2InboxTabType.inbox) ...[
                    const SizedBox(width: 6),
                    Material(
                      color: Colors.transparent,
                      shape: const CircleBorder(),
                      clipBehavior: Clip.antiAlias,
                      child: IconButton(
                        icon: const Icon(
                          LucideIcons.check,
                          size: 19,
                          color: Color(0xFF00C83A),
                        ),
                        tooltip: 'Đánh dấu đã xong',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        splashRadius: 18,
                        onPressed: () {
                          ref
                              .read(chatV2InboxControllerProvider.notifier)
                              .markDone(item);
                        },
                      ),
                    ),
                  ],

                  if (item.channelId != null && item.channelId! > 0) ...[
                    const SizedBox(width: 8),
                    InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () => context.push('/chat_v2/${item.channelId}'),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Vào trò chuyện',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? const Color(0xFF38BDF8)
                                    : const Color(0xFF0077CD),
                              ),
                            ),
                            const SizedBox(width: 2),
                            Icon(
                              LucideIcons.chevronRight,
                              size: 14,
                              color: isDark
                                  ? const Color(0xFF38BDF8)
                                  : const Color(0xFF0077CD),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetailDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) {
        final isDarkTheme = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            item.subject.isNotEmpty ? item.subject : item.recordName,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    UserAvatar(
                      userId: item.authorId?.toString() ?? '',
                      displayName: item.authorName,
                      avatarUrl: item.authorAvatar,
                      size: 28,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.authorName,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                    if (item.date != null)
                      Text(
                        '${Dates.time(item.date!)} ${Dates.dateVi(item.date!)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDarkTheme ? Colors.white38 : const Color(0xFF94A3B8),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  item.plainSnippet,
                  style: const TextStyle(fontSize: 13.5, height: 1.4),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Đóng'),
            ),
            if (tabType == ChatV2InboxTabType.inbox)
              ElevatedButton.icon(
                icon: const Icon(LucideIcons.check, size: 16),
                label: const Text('Đã xử lý xong'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00C83A),
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  ref
                      .read(chatV2InboxControllerProvider.notifier)
                      .markDone(item);
                },
              ),
          ],
        );
      },
    );
  }
}
