import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../../../core/notifications/push_notification_controller.dart';
import '../../../../core/notifications/push_notification_repository.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/application/auth_controller.dart';

/// Sheet hiển thị thông báo native cho Mobile Client (BUG-030).
class MobileNotificationSheet extends ConsumerStatefulWidget {
  const MobileNotificationSheet({super.key});

  @override
  ConsumerState<MobileNotificationSheet> createState() => _MobileNotificationSheetState();
}

class _MobileNotificationSheetState extends ConsumerState<MobileNotificationSheet> {
  static const _portalAllowedEvents = <String>{
    'ticket',
    'ticket_message',
    'livechat',
    'system',
  };

  String _formatTimeAgo(DateTime? time) {
    if (time == null) return '';
    final local = time.toLocal();
    final diff = DateTime.now().difference(local);
    if (diff.inSeconds < 60) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    if (diff.inDays < 7) return '${diff.inDays} ngày trước';
    final d = local.day.toString().padLeft(2, '0');
    final m = local.month.toString().padLeft(2, '0');
    return '$d/$m/${local.year}';
  }

  void _handleItemTap(MobileNotificationItem item) {
    // 1. Đánh dấu đã đọc
    ref.read(dismissedNotificationIdsProvider.notifier).dismiss(item.id.toString());

    final event = item.eventType.toLowerCase();
    final data = item.data;

    // 2. Điều hướng theo loại sự kiện
    if (event.contains('ticket') ||
        data.containsKey('ticket_id') ||
        data.containsKey('helpdesk_ticket_id')) {
      Navigator.of(context).pop();
      final tid = data['ticket_id'] ?? data['helpdesk_ticket_id'] ?? data['res_id'];
      if (tid != null && tid.toString().isNotEmpty && tid.toString() != '0') {
        context.push('/tickets/$tid');
      } else {
        context.push('/tickets');
      }
    } else if (event.contains('livechat') ||
        event.contains('chat') ||
        event.contains('discuss') ||
        data.containsKey('channel_id') ||
        data.containsKey('discuss_channel_id')) {
      Navigator.of(context).pop();
      final cid = data['channel_id'] ?? data['discuss_channel_id'] ?? data['res_id'];
      if (cid != null && cid.toString().isNotEmpty && cid.toString() != '0') {
        context.push('/chat/$cid');
      } else {
        context.push('/chat');
      }
    } else if (event.contains('attendance')) {
      Navigator.of(context).pop();
      context.push('/attendance');
    } else if (event.contains('task') || event.contains('timesheet')) {
      Navigator.of(context).pop();
      final tid = data['task_id'] ?? data['res_id'];
      if (tid != null && tid.toString().isNotEmpty && tid.toString() != '0') {
        context.push('/timesheet?task_id=$tid');
      } else {
        context.push('/timesheet');
      }
    } else {
      // 3. Với thông báo hệ thống / chung không có route: hiển thị popup chi tiết
      _showDetailDialog(item);
    }
  }

  void _showDetailDialog(MobileNotificationItem item) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item.title.isNotEmpty ? item.title : 'Thông báo'),
        content: SingleChildScrollView(
          child: Text(
            item.body.isNotEmpty ? item.body : 'Không có nội dung chi tiết.',
            style: const TextStyle(fontSize: 14, height: 1.4),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  IconData _iconForEvent(String eventType) {
    final e = eventType.toLowerCase();
    if (e.contains('ticket')) return LucideIcons.ticket;
    if (e.contains('livechat') || e.contains('chat') || e.contains('discuss')) {
      return LucideIcons.messageSquare;
    }
    if (e.contains('attendance')) return LucideIcons.clock;
    if (e.contains('task') || e.contains('timesheet')) return LucideIcons.checkSquare;
    return LucideIcons.bell;
  }

  Color _colorForEvent(String eventType) {
    final e = eventType.toLowerCase();
    if (e.contains('ticket')) return AppColors.ticket;
    if (e.contains('livechat') || e.contains('chat') || e.contains('discuss')) {
      return AppColors.chat;
    }
    if (e.contains('attendance')) return AppColors.attendance;
    if (e.contains('task') || e.contains('timesheet')) return AppColors.timesheet;
    if (e.contains('system')) return AppColors.primaryViolet;
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(authControllerProvider).valueOrNull;
    final isPortal = user?.isPortal == true;

    final notifsAsync = ref.watch(mobileNotificationsProvider);
    final dismissedIds = ref.watch(dismissedNotificationIdsProvider);

    final rawItems = notifsAsync.valueOrNull?.items ?? const <MobileNotificationItem>[];
    // Lọc theo phạm vi Portal nếu là tài khoản Portal
    final items = isPortal
        ? rawItems.where((it) => _portalAllowedEvents.contains(it.eventType.toLowerCase())).toList()
        : rawItems;

    bool isItemUnread(MobileNotificationItem item) =>
        !dismissedIds.contains(item.id.toString()) &&
        !dismissedIds.contains('${item.eventType}_${item.id}');

    final unreadItems = items.where(isItemUnread).toList();
    final maxHeight = MediaQuery.of(context).size.height * 0.82;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            // Drag handle
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Header bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  const Icon(LucideIcons.bell, size: 20, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Thông báo',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  if (unreadItems.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.danger,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${unreadItems.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (unreadItems.isNotEmpty)
                    TextButton.icon(
                      onPressed: () {
                        final keys = unreadItems.map((e) => e.id.toString()).toList();
                        ref.read(dismissedNotificationIdsProvider.notifier).dismissAll(keys);
                      },
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(LucideIcons.checkCheck, size: 14),
                      label: const Text(
                        'Đã đọc tất cả',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(LucideIcons.x, size: 18),
                    tooltip: 'Đóng',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            // Content
            Expanded(
              child: notifsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
                error: (err, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.alertCircle, size: 36, color: AppColors.danger),
                        const SizedBox(height: 10),
                        Text(
                          'Không thể tải danh sách thông báo',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: () => ref.invalidate(mobileNotificationsProvider),
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (_) {
                  if (items.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              LucideIcons.bellOff,
                              size: 44,
                              color: isDark ? Colors.white30 : AppColors.textMuted,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Không có thông báo nào',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isPortal
                                  ? 'Bạn chưa có thông báo về vé hỗ trợ hoặc tin nhắn.'
                                  : 'Các thông báo mới sẽ xuất hiện tại đây.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? Colors.white54 : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final unread = isItemUnread(item);
                      final eventColor = _colorForEvent(item.eventType);
                      final eventIcon = _iconForEvent(item.eventType);
                      final timeStr = _formatTimeAgo(item.timestamp);

                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _handleItemTap(item),
                          borderRadius: BorderRadius.circular(16),
                          child: Ink(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: unread
                                  ? (isDark
                                      ? const Color(0xFF0F172A).withValues(alpha: 0.6)
                                      : eventColor.withValues(alpha: 0.08))
                                  : (isDark
                                      ? const Color(0xFF1E293B)
                                      : const Color(0xFFF8FAFC)),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: unread
                                    ? eventColor.withValues(alpha: 0.35)
                                    : (isDark
                                        ? Colors.white.withValues(alpha: 0.08)
                                        : AppColors.border),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Icon sự kiện
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: eventColor.withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(eventIcon, size: 20, color: eventColor),
                                ),
                                const SizedBox(width: 12),
                                // Nội dung
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              item.title.isNotEmpty ? item.title : 'Thông báo',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: unread ? FontWeight.w800 : FontWeight.w600,
                                                color: isDark ? Colors.white : AppColors.textPrimary,
                                              ),
                                            ),
                                          ),
                                          if (timeStr.isNotEmpty) ...[
                                            const SizedBox(width: 6),
                                            Text(
                                              timeStr,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: isDark ? Colors.white38 : AppColors.textMuted,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      if (item.body.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          item.body,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 13,
                                            height: 1.3,
                                            color: isDark ? Colors.white70 : AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                if (unread) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    margin: const EdgeInsets.only(top: 4),
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: eventColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
