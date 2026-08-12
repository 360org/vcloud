import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../../core/error/failure.dart';
import '../../../core/notifications/push_notification_controller.dart';
import '../../../core/notifications/push_notification_repository.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_format.dart';
import '../../../shared/models/task.dart';
import '../../../shared/models/timesheet.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/celebration_fireworks.dart';
import '../../../shared/widgets/ui_kit.dart';
import '../../../shared/widgets/location_prompt_dialog.dart';
import '../../attendance/application/attendance_controller.dart';
import '../../auth/application/auth_controller.dart';
import '../../chat/application/conversations_controller.dart';
import '../../timesheet/application/task_controller.dart';


import '../../timesheet/application/timesheet_controller.dart';
import '../../timesheet/presentation/widgets/checklist_editor.dart';
import '../application/home_summary_controller.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _statusBusy = false;

  Future<void> _showErrorDialog(dynamic error, StackTrace stackTrace) async {
    final errorMessage = error.toString();
    final fullDetails = 'Lỗi: $errorMessage\n\nStackTrace:\n$stackTrace';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Lỗi Chấm công'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(
                errorMessage,
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: fullDetails));
              if (dialogContext.mounted) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text('Đã sao chép chi tiết lỗi vào Clipboard!'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            child: const Text('Copy Lỗi'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleAttendance(bool isOnline) async {
    if (_statusBusy) return;
    setState(() => _statusBusy = true);
    try {
      final actions = ref.read(attendanceActionsProvider);
      if (isOnline) {
        await actions.checkOut();
      } else {
        await actions.checkIn();
      }
      ref.invalidate(homeSummaryProvider);
      ref.invalidate(attendanceTodayProvider);
      ref.invalidate(openSessionProvider);
      ref.invalidate(mobileDashboardSummaryProvider);
    } catch (e, stackTrace) {
      if (mounted) {
        if (isLocationError(e)) {
          await showLocationPromptDialog(context, message: e is Failure ? e.message : e.toString());
        } else {
          await _showErrorDialog(e, stackTrace);
        }
      }
    } finally {
      if (mounted) setState(() => _statusBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(homeSummaryProvider);
    final todayState = ref.watch(attendanceTodayProvider);
    final dashboard = ref.watch(mobileDashboardSummaryProvider).valueOrNull;
    final notificationState = ref.watch(mobileNotificationsProvider);
    final notificationCount = notificationState.valueOrNull?.total ?? 0;
    // DO NOT MODIFY OR REFACTOR THIS AVATAR LOADING LOGIC. IT IS THE SOURCE OF TRUTH FOR USER AVATAR DISPLAY.
    // CẤM SỬA HOẶC XÓA LOGIC TẢI AVATAR NÀY - ĐÂY LÀ NGUỒN SỰ THẬT HIỂN THỊ AVATAR DÙNG CHUNG.
    final user = ref.watch(authControllerProvider).valueOrNull;
    final meta = user?.userMetadata;
    final rawName = meta?['display_name'];
    final name = (rawName is String ? rawName : (rawName != null && rawName != false ? rawName.toString() : null))?.trim();
    final rawAvatar = meta?['avatar_url'] ??
        meta?['avatar_128_url'] ??
        meta?['image_128_url'] ??
        (user != null ? '/web/image/res.users/${user.id}/avatar_128' : null);
    final avatarUrl = rawAvatar is String && rawAvatar.isNotEmpty ? rawAvatar : null;
    final displayName = (name != null && name.isNotEmpty)
        ? name
        : (user?.email?.split('@').first ?? 'Người dùng');
    final todayTasks = ref
        .watch(todayTasksProvider)
        .maybeWhen(
          data: (tasks) => tasks
              .where((task) => !task.isCompleted)
              .take(3)
              .map(_todayTaskPreviewFromTask)
              .toList(),
          orElse: () => const <_TodayTaskPreview>[],
        );
    // Attendance is the source of truth immediately after a toggle. The
    // dashboard is a separate cached snapshot and may be one request behind.
    final openSession = ref.watch(openSessionProvider);
    final isOnline = openSession?.isOpen ?? summary?.isCheckedIn ?? dashboard?.isCheckedIn ?? false;
    final closedMinutes = dashboard?.todayMinutes ?? summary?.todayMinutes ?? 0;
    final ongoingMinutes = (isOnline && openSession?.checkinTime != null)
        ? DateTime.now().difference(openSession!.checkinTime!).inMinutes
        : 0;
    final todayMinutes = closedMinutes + (ongoingMinutes > 0 ? ongoingMinutes : 0);
    final openTickets = dashboard?.openTickets ?? summary?.openTickets ?? 0;
    final unreadMessages = ref.watch(totalUnreadCountProvider);
    final conversationsState = ref.watch(conversationsProvider);
    final conversationsList = conversationsState.value ?? const [];
    final chatCount = (dashboard?.recentConversationCount != null && dashboard!.recentConversationCount! > 0)
        ? dashboard.recentConversationCount!
        : (summary?.recentConversationCount != null && summary!.recentConversationCount > 0
            ? summary.recentConversationCount
            : (conversationsList.length >= 100 ? conversationsList.length : conversationsList.length));
    final statusBusy = _statusBusy || todayState.isLoading;

    return AppScaffold(
      title: 'Home',
      showAppBar: false,
      body: CelebrationFireworksOverlay(
        autoTrigger: todayMinutes >= 480,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(homeSummaryProvider);
            ref.invalidate(mobileDashboardSummaryProvider);
            ref.invalidate(attendanceTodayProvider);
            ref.invalidate(todayTasksProvider);
            ref.invalidate(openSessionProvider);
            ref.invalidate(conversationsProvider);
            ref.invalidate(mobileNotificationsProvider);
          },
          color: AppColors.primary,
          backgroundColor: Theme.of(context).cardColor,

          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _GreetingHeader(
                userId: user?.id ?? '',
                displayName: displayName,
                email: user?.email,
                avatarUrl: avatarUrl,
                isOnline: isOnline,
                statusBusy: statusBusy,
                onStatusTap: () => _toggleAttendance(isOnline),
                todayMinutes: todayMinutes,
                checkinTime: openSession?.checkinTime,
                notificationCount: notificationCount,
                notificationsLoading: notificationState.isLoading,
                onNotificationsTap: () => _openNotifications(context),
                onOpenAttendance: () => context.push('/attendance'),
              ),
              const SizedBox(height: 18),
              _QuickNavGrid(
                ticketCount: openTickets,
                unreadCount: unreadMessages,
                chatCount: chatCount,
                taskCount: todayTasks.length,
              ),
              const SizedBox(height: 20),
              _TodayWork(tasks: todayTasks),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openNotifications(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _NotificationSheet(),
    );
  }
}

class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader({
    required this.userId,
    required this.displayName,
    required this.email,
    required this.avatarUrl,
    required this.isOnline,
    required this.statusBusy,
    required this.onStatusTap,
    required this.todayMinutes,
    required this.checkinTime,
    required this.notificationCount,
    required this.notificationsLoading,
    required this.onNotificationsTap,
    required this.onOpenAttendance,
  });

  final String userId;
  final String displayName;
  final String? email;
  final String? avatarUrl;
  final bool isOnline;
  final bool statusBusy;
  final VoidCallback onStatusTap;
  final int todayMinutes;
  final DateTime? checkinTime;
  final int notificationCount;
  final bool notificationsLoading;
  final VoidCallback onNotificationsTap;
  final VoidCallback onOpenAttendance;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final today = _vietnameseDateTime(DateTime.now());
    const targetMinutes = 480; // Standard 8h shift
    final progress = (todayMinutes / targetMinutes).clamp(0.0, 1.0);
    final percent = (progress * 100).round();
    final checkinLabel = (isOnline && checkinTime != null)
        ? 'Vào ca lúc ${Dates.hm(checkinTime!)}'
        : (isOnline ? 'Đã vào ca' : 'Chưa vào ca làm');

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : AppColors.border,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UserAvatar(
                userId: userId,
                displayName: displayName,
                email: email,
                avatarUrl: avatarUrl,
                size: 48,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Xin chào, $displayName',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        height: 1.12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      today,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        color: isDark ? AppColors.darkTextMuted : AppColors.textSecondary,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              PressableScale(
                onTap: onOpenAttendance,
                child: _PresenceIndicator(isOnline: isOnline),
              ),
              const SizedBox(width: 10),
              PressableScale(
                onTap: onNotificationsTap,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.soft(AppColors.primary),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: notificationsLoading
                          ? const Center(
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary,
                                ),
                              ),
                            )
                          : const Icon(
                              LucideIcons.bell,
                              color: AppColors.primary,
                              size: 20,
                            ),
                    ),
                    if (notificationCount > 0)
                      Positioned(
                        top: -5,
                        right: -6,
                        child: UnreadBadge(
                          count: notificationCount,
                          compact: true,
                          gradient: AppColors.featureGrad(
                            AppColors.danger,
                            AppColors.dangerDeep,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Work Shift Info Banner & Progress Bar Card
          InkWell(
            onTap: onOpenAttendance,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.soft(isOnline ? AppColors.success : AppColors.primary).withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: (isOnline ? AppColors.success : AppColors.primary).withValues(alpha: 0.22),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      _CheckInStatusButton(
                        isOnline: isOnline,
                        busy: statusBusy,
                        onTap: onStatusTap,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  LucideIcons.mapPin,
                                  size: 13,
                                  color: AppColors.success,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'GPS vị trí hợp lệ',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.success,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              checkinLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(LucideIcons.chevronRight, size: 16, color: AppColors.textMuted),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Work Hours Progress Bar (6h 30m / 8h)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            LucideIcons.clock,
                            size: 14,
                            color: isOnline ? AppColors.success : AppColors.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Tiến độ ca làm: ${_durationVi(Duration(minutes: todayMinutes))} / 8h',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '$percent%',
                        style: TextStyle(
                          color: isOnline ? AppColors.success : AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Stack(
                    children: [
                      Container(
                        height: 7,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppColors.border.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: progress,
                        child: Container(
                          height: 7,
                          decoration: BoxDecoration(
                            gradient: AppColors.featureGrad(
                              isOnline ? AppColors.success : AppColors.primary,
                              isOnline ? AppColors.primary : AppColors.success,
                            ),
                            borderRadius: BorderRadius.circular(99),
                            boxShadow: [
                              BoxShadow(
                                color: (isOnline ? AppColors.success : AppColors.primary).withValues(alpha: 0.4),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (todayMinutes >= 480) ...[
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: () {
                        HapticFeedback.heavyImpact();
                        CelebrationFireworksOverlay.trigger(context);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: AppColors.featureGrad(
                            const Color(0xFFFFD700),
                            AppColors.success,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x33FFD700),
                              blurRadius: 8,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Text('🎉', style: TextStyle(fontSize: 14)),
                            const SizedBox(width: 6),
                            const Expanded(
                              child: Text(
                                'CHÚC MỪNG! ĐÃ HOÀN THÀNH 8H LÀM VIỆC XUẤT SẮC!',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 10,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(LucideIcons.sparkles, color: Colors.white, size: 11),
                                  SizedBox(width: 3),
                                  Text(
                                    'Bắn pháo',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationSheet extends ConsumerWidget {
  const _NotificationSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(mobileNotificationsProvider);
    final list = notifications.valueOrNull;
    final items = (list?.items ?? const <MobileNotificationItem>[]).toList()
      ..sort((a, b) {
        final aTime = a.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });
    final totalCount = list?.total ?? items.length;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.82,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(
                color: Color(0x260F172A),
                blurRadius: 28,
                offset: Offset(0, 12),
              ),
            ],
          ),

          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 12, 8),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.soft(AppColors.primary),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        LucideIcons.bell,
                        color: AppColors.primary,
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Thông báo',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),

                          const SizedBox(height: 2),
                          Text(
                            totalCount == 0
                                ? 'Không có mục mới cần chú ý.'
                                : '$totalCount mục cần chú ý',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Làm mới',
                      onPressed: () =>
                          ref.invalidate(mobileNotificationsProvider),
                      icon: const Icon(LucideIcons.refreshCw, size: 19),
                    ),
                  ],
                ),
              ),
              if (notifications.isLoading)
                const LinearProgressIndicator(
                  minHeight: 2,
                  color: AppColors.primary,
                  backgroundColor: AppColors.border,
                )
              else
                const SizedBox(height: 2),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 18),
                  children: [
                    for (final notification in items)
                      _NotificationItemTile(item: notification),
                    if (items.isEmpty && !notifications.isLoading)
                      const _NotificationEmptyState(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationItemTile extends StatelessWidget {
  const _NotificationItemTile({required this.item});

  final MobileNotificationItem item;

  @override
  Widget build(BuildContext context) {
    final decoration = _notificationDecoration(item.eventType);
    final route = _notificationRoute(item.data);
    return _NotificationTile(
      icon: decoration.icon,
      accent: decoration.accent,
      title: item.title,
      subtitle: item.body,
      time: item.timestamp == null
          ? ''
          : Dates.chatListLabelVi(item.timestamp!),
      onTap: () {
        Navigator.of(context).pop();
        if (route != null) context.go(route);
      },
    );
  }
}

/// Maps a notification's `event_type` to an icon + accent so the unified
/// feed still reads like the old groupings (chat / ticket / timesheet),
/// with a neutral bell fallback for anything the backend adds next.
({IconData icon, Color accent}) _notificationDecoration(String eventType) {
  final type = eventType.toLowerCase();
  if (type.contains('ticket')) {
    return (icon: LucideIcons.ticket, accent: AppColors.ticket);
  }
  if (type.contains('message') ||
      type.contains('chat') ||
      type.contains('conversation') ||
      type.contains('channel')) {
    return (icon: LucideIcons.messageCircle, accent: AppColors.chat);
  }
  if (type.contains('task') || type.contains('timesheet')) {
    return (icon: LucideIcons.listTodo, accent: AppColors.timesheet);
  }
  return (icon: LucideIcons.bell, accent: AppColors.primary);
}

/// Resolves a deep-link from the notification `data` payload — we support
/// the ticket and chat targets the backend emits today, and return null
/// for anything else so the tap just dismisses the sheet.
String? _notificationRoute(Map<String, dynamic> data) {
  final ticketId = data['ticket_id'];
  if (ticketId != null && ticketId.toString().isNotEmpty) {
    return '/tickets/$ticketId';
  }
  final conversationId = data['conversation_id'] ?? data['channel_id'];
  if (conversationId != null && conversationId.toString().isNotEmpty) {
    return '/chat/$conversationId';
  }
  return null;
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.icon,
    required this.accent,
    required this.title,
    required this.subtitle,
    required this.time,
    required this.onTap,
  });

  final IconData icon;
  final Color accent;
  final String title;
  final String subtitle;
  final String time;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.soft(accent).withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: accent.withValues(alpha: 0.12)),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.soft(accent),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: accent, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  time,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationEmptyState extends StatelessWidget {
  const _NotificationEmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: AppColors.soft(AppColors.success),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              LucideIcons.checkCheck,
              color: AppColors.success,
              size: 25,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Bạn đã xử lý hết thông báo.',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Khi có thông báo mới, chúng sẽ xuất hiện tại đây.',
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickNavGrid extends ConsumerWidget {
  const _QuickNavGrid({
    required this.ticketCount,
    required this.unreadCount,
    required this.chatCount,
    required this.taskCount,
  });

  final int ticketCount;
  final int unreadCount;
  final int chatCount;
  final int taskCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liveUnreadCount = ref.watch(totalUnreadCountProvider);
    final conversationsState = ref.watch(conversationsProvider);
    final conversationsList = conversationsState.value ?? const [];
    final liveChatCount = chatCount > 0
        ? chatCount
        : conversationsList.length;

    return Column(
      children: [
        SectionHeader(
          title: 'Tổng quan hôm nay',
          trailing: 'Tạo ticket',
          onTrailingTap: () => context.go('/tickets/new'),
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _MetricPill(
              icon: LucideIcons.ticket,
              label: 'Ticket',
              value: ticketCount.toString(),
              caption: 'Cần xử lý',
              gradient: AppColors.ticketGrad,
              onTap: () => context.go('/tickets'),
            ),
            _MetricPill(
              icon: LucideIcons.mailOpen,
              label: 'Chưa đọc',
              value: liveUnreadCount.toString(),
              caption: 'Tin nhắn mới',
              gradient: AppColors.chatGrad,
              onTap: () => context.go('/chat?filter=unread'),
            ),
            _MetricPill(
              icon: LucideIcons.messagesSquare,
              label: 'Chats',
              value: liveChatCount.toString(),
              caption: 'Cuộc trò chuyện',
              gradient: AppColors.brandWide,
              onTap: () => context.go('/chat'),
            ),
            _MetricPill(
              icon: LucideIcons.listTodo,
              label: 'Công việc hôm nay',
              value: taskCount.toString(),
              caption: 'Đang mở',
              gradient: AppColors.timesheetGrad,
              onTap: () => context.go('/timesheet'),
            ),
          ],
        ),
      ],
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.caption,
    required this.gradient,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final String caption;
  final Gradient gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A0F172A),
              blurRadius: 22,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -18,
              bottom: -22,
              child: Icon(
                icon,
                color: Colors.white.withValues(alpha: 0.12),
                size: 92,
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Icon(icon, color: Colors.white, size: 20),
                    ),
                    const Spacer(),
                    const Icon(
                      LucideIcons.chevronRight,
                      color: Colors.white70,
                      size: 18,
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckInStatusButton extends StatelessWidget {
  const _CheckInStatusButton({
    required this.isOnline,
    required this.busy,
    required this.onTap,
  });

  final bool isOnline;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = busy
        ? AppColors.warning
        : isOnline
        ? AppColors.danger
        : AppColors.success;
    return PressableScale(
      onTap: busy ? null : onTap,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.soft(color),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isOnline ? LucideIcons.logOut : LucideIcons.logIn,
              color: color,
              size: 16,
            ),
            const SizedBox(width: 7),
            Text(
              busy
                  ? '...'
                  : isOnline
                  ? 'Check out'
                  : 'Check in',
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PresenceIndicator extends StatelessWidget {
  const _PresenceIndicator({required this.isOnline});

  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    final color = isOnline ? AppColors.success : AppColors.danger;
    return Container(
      width: 42,
      height: 42,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.soft(color),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Center(
        child: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

_TodayTaskPreview _todayTaskPreviewFromTask(Task task) {
  final accent = _taskCategoryColor(task.category);
  return _TodayTaskPreview(
    id: task.id,
    title: task.title,
    tag: task.category.label,
    accent: accent,
    icon: _taskCategoryIcon(task.category),
    // Carried but not yet populated: the home dashboard only sees the
    // list view of open tasks, where the per-entry summary / duration
    // would have to come from the timesheet stream. We leave the
    // optional fields null so the popup opens empty.
    note: null,
    logged: null,
  );
}

IconData _taskCategoryIcon(TimesheetCategory category) {
  return switch (category) {
    TimesheetCategory.erp => LucideIcons.database,
    TimesheetCategory.crm => LucideIcons.users,
    TimesheetCategory.meeting => LucideIcons.calendarClock,
    TimesheetCategory.support => LucideIcons.headphones,
    TimesheetCategory.other => LucideIcons.circleDot,
  };
}

Color _taskCategoryColor(TimesheetCategory category) {
  return switch (category) {
    TimesheetCategory.erp => AppColors.primary,
    TimesheetCategory.crm => AppColors.chat,
    TimesheetCategory.meeting => AppColors.timesheet,
    TimesheetCategory.support => AppColors.ticket,
    TimesheetCategory.other => AppColors.textMuted,
  };
}

class _TodayTaskPreview {
  const _TodayTaskPreview({
    required this.id,
    required this.title,
    required this.tag,
    required this.accent,
    required this.icon,
    this.note,
    this.logged,
  });

  /// Odoo task id — needed so the quick-edit popup can route saves
  /// back to [TaskActions.log] without round-tripping the full sheet.
  final String id;
  final String title;
  final String tag;
  final Color accent;
  final IconData icon;

  /// Last logged "what I did" summary, if any. Used to pre-fill the
  /// editor when re-opening a task that already has a log entry.
  final String? note;

  /// Last logged duration, if any. Same purpose — defaults the
  /// duration picker to a sensible bucket when re-opening.
  final Duration? logged;
}

class _TodayWork extends StatelessWidget {
  const _TodayWork({required this.tasks});

  final List<_TodayTaskPreview> tasks;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SectionHeader(
          title: "Công việc hôm nay",
          trailing: 'Mở Timesheet',
          onTrailingTap: () => context.go('/timesheet'),
        ),
        const SizedBox(height: 10),
        GlassCard(
          padding: EdgeInsets.zero,
          radius: 18,
          child: tasks.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(18),
                  child: Text(
                    'Chưa có công việc hôm nay.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              : Column(
                  children: [
                    for (var i = 0; i < tasks.length; i++) ...[
                      _TimesheetRow(task: tasks[i]),
                      if (i != tasks.length - 1)
                        const Divider(height: 1, indent: 54),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _TimesheetRow extends ConsumerWidget {
  const _TimesheetRow({required this.task});

  final _TodayTaskPreview task;

  Future<void> _openQuickEdit(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TaskQuickEditSheet(task: task),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PressableScale(
      onTap: () {
        // Tap a task → popup that lets the user record work-time / note
        // without bouncing them over to the full timesheet screen.
        // They can still get there via the "Mở Timesheet" trailing link.
        _openQuickEdit(context, ref);
      },
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.soft(task.accent),
                shape: BoxShape.circle,
              ),
              child: Icon(task.icon, color: task.accent, size: 15),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                task.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),

            StatusPill(label: task.tag, color: task.accent),
          ],
        ),
      ),
    );
  }
}

/// Bottom-sheet that lets the user edit a task's `note` (nội dung công
/// việc đã làm) and re-log `duration` (thời gian làm việc) inline
/// from the home dashboard. Save always routes through
/// [TaskActions.log] — these cards only show open tasks, so we never
/// flip workflow status.
///
/// The widget is `ConsumerStatefulWidget` so its actions run on its
/// own `ref` (the parent's `WidgetRef` is short-lived and must not be
/// captured into the sheet's lifetime).
class _TaskQuickEditSheet extends ConsumerStatefulWidget {
  const _TaskQuickEditSheet({required this.task});

  final _TodayTaskPreview task;

  @override
  ConsumerState<_TaskQuickEditSheet> createState() =>
      _TaskQuickEditSheetState();
}

class _TaskQuickEditSheetState extends ConsumerState<_TaskQuickEditSheet> {
  late final TextEditingController _noteController;
  late TimesheetDuration _duration;
  bool _saving = false;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(text: widget.task.note ?? '');
    _noteController.addListener(_onNoteChanged);
    _duration = widget.task.logged == null
        ? TimesheetDuration.thirty
        : durationBucketForElapsed(widget.task.logged!);
  }

  void _onNoteChanged() {
    if (_hasError && _noteController.text.trim().isNotEmpty) {
      setState(() {
        _hasError = false;
        _errorMessage = null;
      });
    }
  }

  @override
  void dispose() {
    _noteController.removeListener(_onNoteChanged);
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final note = _noteController.text.trim();
    if (note.isEmpty) {
      HapticFeedback.mediumImpact();
      setState(() {
        _hasError = true;
        _errorMessage = 'Vui lòng nhập nội dung công việc đã làm trước khi lưu.';
      });
      showTopNotification(
        context,
        message: 'Vui lòng nhập nội dung công việc đã làm.',
        isError: true,
      );
      return;
    }
    setState(() {
      _hasError = false;
      _errorMessage = null;
      _saving = true;
    });
    try {
      await ref
          .read(taskActionsProvider)
          .log(taskId: widget.task.id, summary: note, duration: _duration);
      ref.invalidate(timesheetStreamProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Lưu log thất bại: ${describeError(e)}';
        });
        showTopNotification(
          context,
          message: 'Lưu log thất bại: ${describeError(e)}',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 12,
          right: 12,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 10,
        ),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(28),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.soft(widget.task.accent),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        widget.task.icon,
                        color: widget.task.accent,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.task.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),

                    StatusPill(
                      label: widget.task.tag,
                      color: widget.task.accent,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Cập nhật nội dung & thời gian làm việc.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                TaskChecklistEditor(
                  noteController: _noteController,
                  duration: _duration,
                  saving: _saving,
                  hasError: _hasError,
                  errorMessage: _errorMessage,
                  onDurationChanged: _saving
                      ? null
                      : (dur) => setState(() => _duration = dur),
                  onSave: _saving ? null : _save,
                  saveLabel: 'Lưu cập nhật',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _vietnameseDateTime(DateTime dt) {
  const weekdays = [
    'Thứ hai',
    'Thứ ba',
    'Thứ tư',
    'Thứ năm',
    'Thứ sáu',
    'Thứ bảy',
    'Chủ nhật',
  ];
  final weekday = weekdays[dt.weekday - 1];
  final day = dt.day.toString().padLeft(2, '0');
  final month = dt.month.toString().padLeft(2, '0');
  final hour = dt.hour.toString().padLeft(2, '0');
  final minute = dt.minute.toString().padLeft(2, '0');
  return '$weekday, $day/$month/${dt.year} · $hour:$minute';
}

String _durationVi(Duration duration) {
  final minutes = duration.inMinutes;
  if (minutes < 60) return '$minutes phút';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  if (rest == 0) return '$hours giờ';
  return '$hours giờ $rest phút';
}
