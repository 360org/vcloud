import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_format.dart';
import '../../../shared/models/ticket.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/error_view.dart';

import '../../../shared/widgets/loading_view.dart';
import '../../../shared/widgets/ui_kit.dart';
import '../application/ticket_controller.dart';
import '../../profile/application/profile_controller.dart';

class TicketListScreen extends ConsumerStatefulWidget {
  const TicketListScreen({super.key});

  @override
  ConsumerState<TicketListScreen> createState() => _TicketListScreenState();
}

class _TicketListScreenState extends ConsumerState<TicketListScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  int _tab = 0;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final source = ref.watch(ticketsProvider);
    final tickets = [...ref.watch(effectiveTicketsProvider)]
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    final doing = tickets
        .where((ticket) => ticket.status != TicketStatus.done)
        .where(_matchesQuery)
        .toList();
    final done = tickets
        .where((ticket) => ticket.status == TicketStatus.done)
        .where(_matchesQuery)
        .toList();

    return AppScaffold(
      title: 'Ticket hỗ trợ',
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/tickets/new'),
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(LucideIcons.plus, size: 26),
      ),

      body: ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: SafeArea(
          child: source.when(
            loading: () => const LoadingView(),
            error: (e, _) => ErrorView(
              error: e,
              onRetry: () => ref.invalidate(ticketsProvider),
            ),
            data: (_) => Column(
              children: [
                const SizedBox(height: 8),
                _TicketSearchBar(
                  query: _query,
                  onChanged: (value) => setState(() => _query = value),
                  onClear: () => setState(() => _query = ''),
                ),
                const SizedBox(height: 12),
                _TicketTabs(
                  selected: _tab,
                  doingCount: doing.length,
                  doneCount: done.length,
                  onChanged: (value) => setState(() => _tab = value),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: 450.ms,
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeOutCubic,
                    child: _tab == 0
                        ? _TicketList(
                            key: const ValueKey('doing'),
                            tickets: doing,
                            done: false,
                          )
                        : _TicketList(
                            key: const ValueKey('done'),
                            tickets: done,
                            done: true,
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _matchesQuery(Ticket ticket) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return '${ticket.title} ${ticket.description ?? ''}'.toLowerCase().contains(
      q,
    );
  }
}


class _TicketSearchBar extends StatelessWidget {
  const _TicketSearchBar({
    required this.query,
    required this.onChanged,
    required this.onClear,
  });

  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF0F3F8),
          borderRadius: BorderRadius.circular(16),
        ),
        child: TextField(
          onChanged: onChanged,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 16,
          ),
          decoration: InputDecoration(
            hintText: 'Tìm kiếm ticket',
            hintStyle: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            prefixIcon: const Icon(
              LucideIcons.search,
              color: AppColors.textMuted,
              size: 21,
            ),
            suffixIcon: query.isEmpty
                ? null
                : IconButton(
                    onPressed: onClear,
                    icon: const Icon(
                      LucideIcons.x,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                  ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 15),
          ),
        ),
      ),
    );
  }
}

class _TicketTabs extends StatelessWidget {
  const _TicketTabs({
    required this.selected,
    required this.doingCount,
    required this.doneCount,
    required this.onChanged,
  });

  final int selected;
  final int doingCount;
  final int doneCount;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0A0F172A),
              blurRadius: 12,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            _TicketTabButton(
              label: 'Đang xử lý',
              count: doingCount,
              selected: selected == 0,
              onTap: () => onChanged(0),
            ),
            _TicketTabButton(
              label: 'Hoàn thành',
              count: doneCount,
              selected: selected == 1,
              onTap: () => onChanged(1),
            ),
          ],
        ),
      ),
    );
  }
}


class _TicketTabButton extends StatelessWidget {
  const _TicketTabButton({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: PressableScale(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: selected
                ? AppColors.featureGrad(AppColors.ticket, AppColors.ticketDeep)
                : null,
            color: selected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            '$label · $count',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _TicketList extends StatelessWidget {
  const _TicketList({super.key, required this.tickets, required this.done});

  final List<Ticket> tickets;
  final bool done;

  @override
  Widget build(BuildContext context) {
    if (tickets.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            done ? 'Chưa có ticket hoàn thành.' : 'Không có ticket đang xử lý.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
      itemCount: tickets.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final ticket = tickets[index];
        return done
            ? _TicketCard(ticket: ticket, done: true)
            : _OpenTicketCard(ticket: ticket);
      },
    );
  }
}

class _OpenTicketCard extends ConsumerWidget {
  const _OpenTicketCard({required this.ticket});

  final Ticket ticket;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canChangeStatus = ref.watch(canChangeTicketStatusProvider);
    return Dismissible(
      key: ValueKey(ticket.id),
      direction: canChangeStatus
          ? DismissDirection.startToEnd
          : DismissDirection.none,
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 24),
        decoration: BoxDecoration(
          gradient: AppColors.successGrad,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Icon(LucideIcons.check, color: Colors.white, size: 26),
      ),
      confirmDismiss: (_) => _confirmComplete(context, ticket),
      onDismissed: (_) {
        ref
            .read(ticketActionsProvider)
            .updateStatus(ticket.id, TicketStatus.done);
      },
      child: _TicketCard(ticket: ticket, done: false),
    );
  }
}

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.ticket, required this.done});

  final Ticket ticket;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rawDesc = cleanHtmlText(ticket.description);
    final desc = rawDesc.isNotEmpty ? rawDesc : null;
    final isOverdue = ticket.isOverdue;
    final color = done
        ? AppColors.success
        : (isOverdue ? AppColors.danger : _priorityColor(ticket.priority));
    final displayDate = ticket.deadline ?? ticket.createdAt;
    final formattedDate = Dates.isoDate(displayDate);

    return PressableScale(
      onTap: () => context.push('/tickets/${ticket.id}'),
      scale: 0.99,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isOverdue
                ? AppColors.danger.withValues(alpha: 0.45)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : AppColors.border.withValues(alpha: 0.7)),
            width: isOverdue ? 1.5 : 1.0,
          ),
          boxShadow: isOverdue
              ? [
                  BoxShadow(
                    color: AppColors.danger.withValues(alpha: 0.1),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : const [
                  BoxShadow(
                    color: Color(0x0A0F172A),
                    blurRadius: 16,
                    offset: Offset(0, 8),
                  ),
                ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.soft(color),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                done
                    ? LucideIcons.check
                    : (isOverdue ? LucideIcons.alertTriangle : LucideIcons.ticket),
                color: color,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Hero(
                    tag: 'ticket-title-${ticket.id}',
                    child: Material(
                      color: Colors.transparent,
                      child: Text(
                        ticket.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: done
                              ? (isDark
                                  ? AppColors.darkTextMuted
                                  : AppColors.textSecondary)
                              : Theme.of(context).colorScheme.onSurface,
                          fontSize: 15,
                          height: 1.2,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 6),
                  Text(
                    desc?.isNotEmpty == true ? desc! : 'Không có mô tả',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _TicketPill(
                        label: _statusText(ticket.status),
                        color: done ? AppColors.success : AppColors.ticket,
                      ),
                      _TicketPill(
                        label: ticket.priority.label,
                        color: _priorityColor(ticket.priority),
                      ),
                      if (isOverdue)
                        _TicketPill(
                          label: 'Trễ hạn · $formattedDate',
                          color: AppColors.danger,
                          icon: LucideIcons.clock,
                        )
                      else
                        _TicketPill(
                          label: formattedDate,
                          color: AppColors.textMuted,
                        ),
                    ],
                  ),
                ],
              ).animate().fadeIn(duration: 450.ms, curve: Curves.easeOutCubic).slideY(begin: -0.15, end: 0.0, duration: 450.ms, curve: Curves.easeOutCubic),
            ),
            const SizedBox(width: 8),
            const Icon(
              LucideIcons.chevronRight,
              color: AppColors.textMuted,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

class _TicketPill extends StatelessWidget {
  const _TicketPill({
    required this.label,
    required this.color,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.soft(color),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

Future<bool?> _confirmComplete(BuildContext context, Ticket ticket) {
  return showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Hoàn thành ticket?'),
      content: Text('Đánh dấu "${ticket.title}" là hoàn thành?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Hủy'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          style: FilledButton.styleFrom(backgroundColor: AppColors.success),
          child: const Text('Hoàn thành'),
        ),
      ],
    ),
  );
}

Color _priorityColor(TicketPriority priority) => switch (priority) {
  TicketPriority.p1 => AppColors.danger,
  TicketPriority.p2 => AppColors.ticket,
  TicketPriority.p3 => AppColors.primary,
  TicketPriority.p4 => AppColors.success,
};

String _statusText(TicketStatus status) => switch (status) {
  TicketStatus.todo => 'Chờ xử lý',
  TicketStatus.doing => 'Đang xử lý',
  TicketStatus.done => 'Hoàn thành',
};
