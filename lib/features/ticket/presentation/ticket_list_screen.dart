import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/utils/html_text.dart';
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

    final filter = ref.watch(ticketFilterProvider);
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
      showAppBar: false,
      wrapSafeArea: false,
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/tickets/new'),
        backgroundColor: const Color(0xFF00C83A),
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
                const _TicketHeader(),
                const SizedBox(height: 8),
                _TicketSearchBar(
                  query: _query,
                  isFilterActive: !filter.isEmpty,
                  onChanged: (value) => setState(() => _query = value),
                  onClear: () => setState(() => _query = ''),
                  onOpenFilter: () {
                    showModalBottomSheet<void>(
                      context: context,
                      backgroundColor: Colors.transparent,
                      isScrollControlled: true,
                      builder: (_) => _TicketFilterSheet(initialFilter: filter),
                    );
                  },
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

class _TicketHeader extends StatelessWidget {
  const _TicketHeader();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: isDark
                  ? Border.all(color: Colors.white.withValues(alpha: 0.08))
                  : null,
              boxShadow: isDark
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : const [
                      BoxShadow(
                        color: Color(0x0D0F172A),
                        blurRadius: 14,
                        offset: Offset(0, 6),
                      ),
                    ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  LucideIcons.ticket,
                  color: Color(0xFF00C83A),
                  size: 18,
                ),
                const SizedBox(width: 8),
                Text(
                  'Ticket',
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          PressableScale(
            onTap: () => context.push('/tickets/new'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00C83A), Color(0xFF009D2E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00C83A).withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    LucideIcons.plus,
                    color: Colors.white,
                    size: 17,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Tạo ticket',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
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
}

class _TicketSearchBar extends StatelessWidget {
  const _TicketSearchBar({
    required this.query,
    required this.isFilterActive,
    required this.onChanged,
    required this.onClear,
    required this.onOpenFilter,
  });

  final String query;
  final bool isFilterActive;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;
  final VoidCallback onOpenFilter;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF0F3F8),
                borderRadius: BorderRadius.circular(16),
                border: isDark
                    ? Border.all(color: Colors.white.withValues(alpha: 0.08))
                    : null,
              ),
              child: TextField(
                onChanged: onChanged,
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                  fontSize: 15,
                ),
                decoration: InputDecoration(
                  hintText: 'Tìm kiếm ticket',
                  hintStyle: TextStyle(
                    color: isDark ? Colors.white38 : AppColors.textMuted,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                  prefixIcon: Icon(
                    LucideIcons.search,
                    color: isDark ? Colors.white60 : AppColors.textMuted,
                    size: 20,
                  ),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          onPressed: onClear,
                          icon: Icon(
                            LucideIcons.x,
                            color: isDark ? Colors.white70 : AppColors.textMuted,
                            size: 19,
                          ),
                        ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          PressableScale(
            onTap: onOpenFilter,
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: isFilterActive
                    ? const Color(0xFF00C83A)
                    : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF0F3F8)),
                borderRadius: BorderRadius.circular(16),
                border: isDark && !isFilterActive
                    ? Border.all(color: Colors.white.withValues(alpha: 0.08))
                    : null,
              ),
              child: Icon(
                LucideIcons.slidersHorizontal,
                color: isFilterActive ? Colors.white : (isDark ? Colors.white70 : AppColors.textMuted),
                size: 20,
              ),
            ),
          ),
        ],
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
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF0F3F8),
          borderRadius: BorderRadius.circular(22),
          border: isDark
              ? Border.all(color: Colors.white.withValues(alpha: 0.08))
              : null,
          boxShadow: isDark
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : const [
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
              activeColor: const Color(0xFF00C83A),
              activeColorDeep: const Color(0xFF009D2E),
              onTap: () => onChanged(0),
            ),
            _TicketTabButton(
              label: 'Hoàn thành',
              count: doneCount,
              selected: selected == 1,
              activeColor: const Color(0xFF2563EB),
              activeColorDeep: const Color(0xFF1D4ED8),
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
    required this.activeColor,
    required this.activeColorDeep,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final Color activeColor;
  final Color activeColorDeep;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: PressableScale(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: selected
                ? LinearGradient(
                    colors: [activeColor, activeColorDeep],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: selected ? null : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            '$label · $count',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected
                  ? Colors.white
                  : (isDark ? Colors.white70 : AppColors.textSecondary),
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
    final iconColor = done
        ? AppColors.success
        : (isOverdue ? AppColors.danger : _priorityColor(ticket.priority));
    final displayDate = ticket.deadline ?? ticket.createdAt;

    return PressableScale(
      onTap: () => context.push('/tickets/${ticket.id}'),
      scale: 0.99,
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.12)
                : AppColors.border.withValues(alpha: 0.7),
            width: 1.0,
          ),
          boxShadow: const [
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
                color: AppColors.soft(iconColor),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                done
                    ? LucideIcons.check
                    : (isOverdue ? LucideIcons.alertTriangle : LucideIcons.ticket),
                color: iconColor,
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
                      // 1. Trạng thái (Status)
                      _TicketPill(
                        label: _statusText(ticket.status),
                        color: _statusColor(ticket.status),
                      ),
                      // 2. SLA / Deadline
                      if (isOverdue)
                        _TicketPill(
                          label: Dates.slaLabelVi(displayDate),
                          color: AppColors.danger,
                          icon: LucideIcons.alertTriangle,
                        )
                      else
                        _TicketPill(
                          label: Dates.dateVi(displayDate),
                          color: AppColors.textMuted,
                          icon: LucideIcons.calendar,
                        ),
                      // 3. Ưu tiên (Priority)
                      _TicketPill(
                        label: '${ticket.priority.label} · ${ticket.priority.displayName}',
                        color: _priorityColor(ticket.priority),
                      ),
                    ],
                  ),
                ],
              ),
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

Color _statusColor(TicketStatus status) => switch (status) {
  TicketStatus.todo => const Color(0xFF64748B),
  TicketStatus.doing => const Color(0xFFD97706),
  TicketStatus.done => const Color(0xFF10B981),
};

String _statusText(TicketStatus status) => switch (status) {
  TicketStatus.todo => 'Chờ xử lý',
  TicketStatus.doing => 'Đang xử lý',
  TicketStatus.done => 'Hoàn thành',
};

class _TicketFilterSheet extends ConsumerStatefulWidget {
  const _TicketFilterSheet({required this.initialFilter});

  final TicketFilter initialFilter;

  @override
  ConsumerState<_TicketFilterSheet> createState() => _TicketFilterSheetState();
}

class _TicketFilterSheetState extends ConsumerState<_TicketFilterSheet> {
  late TicketPriority? _selectedPriority;
  late int? _selectedTeamId;

  @override
  void initState() {
    super.initState();
    _selectedPriority = widget.initialFilter.priority;
    _selectedTeamId = widget.initialFilter.teamId;
  }

  @override
  Widget build(BuildContext context) {
    final teamsAsync = ref.watch(ticketTeamsProvider);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Bộ lọc Ticket',
                style: TextStyle(
                  color: context.textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Icon(LucideIcons.x, size: 20, color: context.textColor),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Mức độ ưu tiên',
            style: TextStyle(
              color: context.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _FilterChoiceChip(
                label: 'Tất cả',
                selected: _selectedPriority == null,
                onSelected: (_) => setState(() => _selectedPriority = null),
              ),
              for (final p in TicketPriority.values)
                _FilterChoiceChip(
                  label: '${p.label} · ${p.displayName}',
                  selected: _selectedPriority == p,
                  onSelected: (_) => setState(() => _selectedPriority = p),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'Đội hỗ trợ',
            style: TextStyle(
              color: context.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          teamsAsync.when(
            data: (teams) => Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _FilterChoiceChip(
                  label: 'Tất cả',
                  selected: _selectedTeamId == null,
                  onSelected: (_) => setState(() => _selectedTeamId = null),
                ),
                for (final team in teams)
                  _FilterChoiceChip(
                    label: team.name,
                    selected: _selectedTeamId == team.id,
                    onSelected: (_) => setState(() => _selectedTeamId = team.id),
                  ),
              ],
            ),
            loading: () => const SizedBox(
              height: 32,
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (_, _) => Text(
              'Không thể tải danh sách team',
              style: TextStyle(color: context.textMuted, fontSize: 12),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _selectedPriority = null;
                      _selectedTeamId = null;
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: context.borderColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Xóa bộ lọc',
                    style: TextStyle(color: context.textSecondary),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    ref.read(ticketFilterProvider.notifier).update(
                          TicketFilter(
                            priority: _selectedPriority,
                            teamId: _selectedTeamId,
                          ),
                        );
                    Navigator.pop(context);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Áp dụng'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilterChoiceChip extends StatelessWidget {
  const _FilterChoiceChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: selected
              ? Colors.white
              : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      selected: selected,
      onSelected: onSelected,
      selectedColor: const Color(0xFF2563EB),
      backgroundColor: isDark ? AppColors.darkSurface : const Color(0xFFF1F5F9),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: selected
              ? const Color(0xFF2563EB)
              : (isDark ? AppColors.darkBorder : const Color(0xFFE2E8F0)),
        ),
      ),
    );
  }
}
