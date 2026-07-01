import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../../core/error/failure.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_format.dart';
import '../../../shared/models/ticket.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/ui_kit.dart';
import '../../attendance/application/attendance_controller.dart';
import '../../auth/application/auth_controller.dart';
import '../../chat/application/conversations_controller.dart';
import '../../ticket/application/ticket_controller.dart';
import '../../timesheet/presentation/timesheet_list_screen.dart';
import '../application/home_summary_controller.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _statusBusy = false;

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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(describeError(e))));
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
    final user = ref.watch(authControllerProvider).valueOrNull;
    final meta = user?.userMetadata;
    final name = (meta?['display_name'] as String?)?.trim();
    final avatarUrl = meta?['avatar_url'] as String?;
    final displayName = name?.isNotEmpty == true
        ? name!
        : (user?.email?.split('@').first ?? 'Người dùng');
    final tickets = ref.watch(effectiveTicketsProvider);
    final latestTicket = tickets.isEmpty
        ? null
        : tickets.reduce((a, b) => a.updatedAt.isAfter(b.updatedAt) ? a : b);
    final todayTasks = ref.watch(hardcodedTodayTasksProvider).take(3).toList();
    final isOnline = dashboard?.isCheckedIn ?? summary?.isCheckedIn ?? false;
    final todayMinutes = dashboard?.todayMinutes ?? summary?.todayMinutes ?? 0;
    final openTickets =
        dashboard?.openTickets ?? summary?.openTickets ?? tickets.length;
    final unreadMessages =
        dashboard?.unreadMessageCount ?? summary?.unreadMessageCount ?? 0;
    final chatCount =
        dashboard?.recentConversationCount ??
        summary?.recentConversationCount ??
        0;
    final statusBusy = _statusBusy || todayState.isLoading;

    return AppScaffold(
      title: 'Home',
      showAppBar: false,
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(homeSummaryProvider);
          ref.invalidate(mobileDashboardSummaryProvider);
          ref.invalidate(attendanceTodayProvider);
          ref.invalidate(ticketsProvider);
          ref.invalidate(openSessionProvider);
          ref.invalidate(conversationsProvider);
        },
        color: AppColors.primary,
        backgroundColor: AppColors.surface,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            _HeaderCard(
              userId: user?.id ?? '',
              displayName: displayName,
              email: user?.email,
              avatarUrl: avatarUrl,
              isOnline: isOnline,
              statusBusy: statusBusy,
              onStatusTap: () => _toggleAttendance(isOnline),
              todayMinutes: todayMinutes,
            ),
            const SizedBox(height: 12),
            _DashboardMetrics(
              openTickets: openTickets,
              unreadMessages: unreadMessages,
              chatCount: chatCount,
            ),
            const SizedBox(height: 16),
            _TodayWork(tasks: todayTasks),
            const SizedBox(height: 18),
            const _QuickActions(),
            const SizedBox(height: 18),
            _TicketStatusNotice(ticket: latestTicket),
          ],
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.userId,
    required this.displayName,
    required this.email,
    required this.avatarUrl,
    required this.isOnline,
    required this.statusBusy,
    required this.onStatusTap,
    required this.todayMinutes,
  });

  final String userId;
  final String displayName;
  final String? email;
  final String? avatarUrl;
  final bool isOnline;
  final bool statusBusy;
  final VoidCallback onStatusTap;
  final int todayMinutes;

  @override
  Widget build(BuildContext context) {
    final today = _vietnameseDateTime(DateTime.now());
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border),
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
                      style: const TextStyle(
                        color: AppColors.textPrimary,
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
                        color: AppColors.textSecondary,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _PresenceIndicator(isOnline: isOnline),
              const SizedBox(width: 10),
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
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _CheckInStatusButton(
                isOnline: isOnline,
                busy: statusBusy,
                onTap: onStatusTap,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Hôm nay: ${_durationVi(Duration(minutes: todayMinutes))}',
                  textAlign: TextAlign.end,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DashboardMetrics extends StatelessWidget {
  const _DashboardMetrics({
    required this.openTickets,
    required this.unreadMessages,
    required this.chatCount,
  });

  final int openTickets;
  final int unreadMessages;
  final int chatCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricPill(
            icon: LucideIcons.ticket,
            label: 'Ticket mở',
            value: openTickets.toString(),
            color: AppColors.ticket,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetricPill(
            icon: LucideIcons.messageCircle,
            label: 'Chưa đọc',
            value: unreadMessages.toString(),
            color: AppColors.chat,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetricPill(
            icon: LucideIcons.users,
            label: 'Kênh chat',
            value: chatCount.toString(),
            color: AppColors.primary,
          ),
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
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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

class _TodayWork extends StatelessWidget {
  const _TodayWork({required this.tasks});

  final List<TodayTaskPreview> tasks;

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

class _TimesheetRow extends StatelessWidget {
  const _TimesheetRow({required this.task});

  final TodayTaskPreview task;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: () => context.go('/timesheet'),
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
                style: const TextStyle(
                  color: AppColors.textPrimary,
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

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SectionHeader(title: 'Thao tác nhanh'),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.96,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            CompactActionTile(
              icon: LucideIcons.messageCircle,
              label: 'Chat',
              color: AppColors.chat,
              onTap: () => context.go('/chat'),
            ),
            CompactActionTile(
              icon: LucideIcons.clock3,
              label: 'Công việc',
              color: AppColors.timesheet,
              onTap: () => context.go('/timesheet'),
            ),
            CompactActionTile(
              icon: LucideIcons.ticket,
              label: 'Ticket',
              color: AppColors.ticket,
              onTap: () => context.go('/tickets'),
            ),
          ],
        ),
      ],
    );
  }
}

class _TicketStatusNotice extends StatelessWidget {
  const _TicketStatusNotice({required this.ticket});

  final Ticket? ticket;

  @override
  Widget build(BuildContext context) {
    final current = ticket;
    return Column(
      children: [
        const SectionHeader(title: 'Thông báo'),
        const SizedBox(height: 10),
        GlassCard(
          radius: 18,
          padding: const EdgeInsets.all(16),
          child: current == null
              ? const Row(
                  children: [
                    _NoticeIcon(color: AppColors.ticket),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Chưa có cập nhật ticket.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                )
              : PressableScale(
                  onTap: () => context.push('/tickets/${current.id}'),
                  child: Row(
                    children: [
                      _NoticeIcon(color: _ticketStatusColor(current.status)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Ticket đổi trạng thái: ${_ticketStatusText(current.status)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${current.title} · ${Dates.relativeShort(current.updatedAt)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        LucideIcons.chevronRight,
                        color: AppColors.textMuted,
                        size: 18,
                      ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

class _NoticeIcon extends StatelessWidget {
  const _NoticeIcon({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: AppColors.soft(color),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(LucideIcons.bellRing, color: color, size: 19),
    );
  }
}

Color _ticketStatusColor(TicketStatus status) => switch (status) {
  TicketStatus.todo => AppColors.textMuted,
  TicketStatus.doing => AppColors.ticket,
  TicketStatus.done => AppColors.success,
};

String _ticketStatusText(TicketStatus status) => switch (status) {
  TicketStatus.todo => 'Chờ xử lý',
  TicketStatus.doing => 'Đang xử lý',
  TicketStatus.done => 'Hoàn thành',
};

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
