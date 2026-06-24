import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/ui_kit.dart';
import '../../attendance/application/attendance_controller.dart';
import '../../auth/application/auth_controller.dart';
import '../../ticket/application/ticket_controller.dart';
import '../../../shared/models/ticket.dart';
import '../application/home_summary_controller.dart';

/// Mockup 01 — Home dashboard (premium refresh): greeting, gradient
/// check-in card, animated stat tiles, today's tasks.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(homeSummaryProvider);
    final user = ref.watch(authControllerProvider).value;
    final meta = user?.userMetadata;
    final name = (meta?['display_name'] as String?)?.trim();
    final displayName = (name != null && name.isNotEmpty)
        ? name
        : (user?.email?.split('@').first ?? 'Người dùng');
    final openTickets = ref
        .watch(effectiveTicketsProvider)
        .where((t) => t.status.isOpen)
        .take(3)
        .toList();

    final blocks = <Widget>[
      _Greeting(name: displayName),
      const SizedBox(height: 18),
      const _CheckInCard(),
      const SizedBox(height: 18),
      Row(
        children: [
          Expanded(
            child: _StatTile(
              icon: LucideIcons.messageCircle,
              color: AppColors.chat,
              label: 'CHAT',
              value: (summary?.recentConversationCount ?? 0).toDouble(),
              sub: 'tin nhắn mới',
              onTap: () => context.go('/chat'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatTile(
              icon: LucideIcons.clock,
              color: AppColors.timesheet,
              label: 'TIMESHEET',
              value: (summary?.todayMinutes ?? 0) / 60.0,
              decimals: 1,
              sub: 'giờ hôm nay',
              onTap: () => context.go('/timesheet'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: _StatTile(
              icon: LucideIcons.ticket,
              color: AppColors.ticket,
              label: 'TICKET',
              value: (summary?.openTickets ?? 0).toDouble(),
              sub: 'việc cần xử lý',
              onTap: () => context.go('/tickets'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatTile(
              icon: LucideIcons.calendar,
              color: AppColors.calendar,
              label: 'LỊCH',
              value: 0,
              sub: 'cuộc họp hôm nay',
              onTap: () {},
            ),
          ),
        ],
      ),
      const SizedBox(height: 22),
      _TodayTasks(tickets: openTickets),
    ];

    return AppScaffold(
      title: 'Home',
      showAppBar: false,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
        children: [
          for (var i = 0; i < blocks.length; i++)
            blocks[i]
                .animate()
                .fadeIn(duration: 380.ms, delay: (i * 60).ms)
                .slideY(begin: 0.10, end: 0, curve: Curves.easeOutCubic),
        ],
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: AppColors.glow(AppColors.primary, opacity: 0.25),
          ),
          child: UserAvatar(
              userId: currentUserId(), displayName: name, size: 46),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Xin chào,',
                  style:
                      TextStyle(color: AppColors.textSecondary, fontSize: 13)),
              Text(name,
                  style: const TextStyle(
                      fontSize: 19, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(LucideIcons.bell,
                  size: 20, color: AppColors.textPrimary),
            ),
            Positioned(
              right: 9,
              top: 9,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.danger,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.surface, width: 1.5),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Location + check-in / check-out actions.
class _CheckInCard extends ConsumerStatefulWidget {
  const _CheckInCard();
  @override
  ConsumerState<_CheckInCard> createState() => _CheckInCardState();
}

class _CheckInCardState extends ConsumerState<_CheckInCard> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Failure: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final actions = ref.read(attendanceActionsProvider);
    final isCheckedIn = ref.watch(openSessionProvider) != null;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: cardDecoration(),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: AppColors.brand,
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: AppColors.glow(AppColors.primary, opacity: 0.3),
                ),
                child: const Icon(LucideIcons.building2,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isCheckedIn
                          ? 'Bạn đang Check-in tại'
                          : 'Chưa check-in hôm nay',
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    const Text('360 CORP HCM',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
              if (isCheckedIn)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.soft(AppColors.success),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                            color: AppColors.success, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 5),
                      const Text('Đang làm',
                          style: TextStyle(
                              color: AppColors.success,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),
          GradientButton(
            label: 'CHECK-IN',
            icon: LucideIcons.mapPin,
            gradient: AppColors.successGrad,
            glowColor: AppColors.success,
            loading: _busy,
            onPressed: isCheckedIn ? null : () => _run(actions.checkIn),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Hoặc',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ),
          PressableScale(
            onTap: _busy || !isCheckedIn ? null : () => _run(actions.checkOut),
            child: Opacity(
              opacity: isCheckedIn ? 1 : 0.5,
              child: Container(
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.danger, width: 1.4),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.logOut, color: AppColors.danger, size: 20),
                    SizedBox(width: 8),
                    Text('CHECK-OUT',
                        style: TextStyle(
                            color: AppColors.danger,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.sub,
    required this.onTap,
    this.decimals = 0,
  });
  final IconData icon;
  final Color color;
  final String label;
  final double value;
  final int decimals;
  final String sub;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    gradient: AppColors.accent(color),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: AppColors.glow(color, opacity: 0.28),
                  ),
                  child: Icon(icon, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 8),
                Text(label,
                    style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3)),
              ],
            ),
            const SizedBox(height: 12),
            AnimatedCount(
              value: value,
              decimals: decimals,
              style: const TextStyle(
                  fontSize: 27, fontWeight: FontWeight.w800, height: 1),
            ),
            const SizedBox(height: 3),
            Text(sub,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _TodayTasks extends StatelessWidget {
  const _TodayTasks({required this.tickets});
  final List<Ticket> tickets;

  Color _dot(TicketStatus s) => switch (s) {
        TicketStatus.todo => AppColors.ticket,
        TicketStatus.doing => AppColors.primary,
        TicketStatus.done => AppColors.success,
      };

  String _statusVi(TicketStatus s) => switch (s) {
        TicketStatus.todo => 'Cần làm',
        TicketStatus.doing => 'Đang làm',
        TicketStatus.done => 'Hoàn thành',
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Công việc hôm nay',
                  style:
                      TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              GestureDetector(
                onTap: () => context.go('/tickets'),
                child: const Text('Xem tất cả',
                    style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (tickets.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Không có công việc nào hôm nay',
                  style: TextStyle(color: AppColors.textMuted)),
            )
          else
            for (final t in tickets) ...[
              Row(
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                        color: _dot(t.status), shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(t.title,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  Text(_statusVi(t.status),
                      style: TextStyle(
                          color: _dot(t.status),
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                ],
              ),
              if (t != tickets.last) const Divider(height: 20),
            ],
        ],
      ),
    );
  }
}
