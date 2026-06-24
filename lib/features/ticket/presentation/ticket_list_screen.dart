import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/ticket.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../application/ticket_controller.dart';

/// Mockup 05 — "Ticket": status tabs + cards with a forward-action button.
class TicketListScreen extends ConsumerWidget {
  const TicketListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sourceAsync = ref.watch(ticketsProvider);
    final list = ref.watch(effectiveTicketsProvider);

    List<Ticket> of(TicketStatus s) =>
        list.where((t) => t.status == s).toList();

    return AppScaffold(
      title: 'Ticket',
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/tickets/new'),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: sourceAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
            error: e, onRetry: () => ref.invalidate(ticketsProvider)),
        data: (_) => DefaultTabController(
          length: 3,
          child: Column(
            children: [
              Material(
                color: AppColors.surface,
                child: TabBar(
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicatorColor: AppColors.primary,
                  indicatorWeight: 2.5,
                  labelStyle: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13),
                  unselectedLabelStyle: const TextStyle(fontSize: 13),
                  tabs: [
                    Tab(text: 'Cần làm (${of(TicketStatus.todo).length})'),
                    Tab(text: 'Đang làm (${of(TicketStatus.doing).length})'),
                    Tab(text: 'Hoàn thành (${of(TicketStatus.done).length})'),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _TicketTab(tickets: of(TicketStatus.todo)),
                    _TicketTab(tickets: of(TicketStatus.doing)),
                    _TicketTab(tickets: of(TicketStatus.done)),
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

class _TicketTab extends StatelessWidget {
  const _TicketTab({required this.tickets});
  final List<Ticket> tickets;

  @override
  Widget build(BuildContext context) {
    if (tickets.isEmpty) {
      return const Center(
        child: Text('Không có ticket nào',
            style: TextStyle(color: AppColors.textMuted)),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tickets.length,
      itemBuilder: (_, i) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: _TicketCard(ticket: tickets[i]),
      ),
    );
  }
}

class _TicketCard extends ConsumerWidget {
  const _TicketCard({required this.ticket});
  final Ticket ticket;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final desc = ticket.description?.trim();
    return InkWell(
      onTap: () => context.push('/tickets/${ticket.id}'),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: cardDecoration(),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ticket.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 6),
                  Text(
                    (desc != null && desc.isNotEmpty)
                        ? desc
                        : 'Không có mô tả',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _ActionButton(ticket: ticket),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends ConsumerWidget {
  const _ActionButton({required this.ticket});
  final Ticket ticket;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> move(TicketStatus next) async {
      try {
        await ref.read(ticketActionsProvider).updateStatus(ticket.id, next);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(e.toString().replaceFirst('Failure: ', ''))));
        }
      }
    }

    switch (ticket.status) {
      case TicketStatus.todo:
        return OutlinedButton(
          onPressed: () => move(TicketStatus.doing),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Bắt đầu',
              style: TextStyle(fontWeight: FontWeight.w600)),
        );
      case TicketStatus.doing:
        return FilledButton(
          onPressed: () => move(TicketStatus.done),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.success,
            minimumSize: const Size(0, 36),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: const Text('Hoàn thành',
              style: TextStyle(fontWeight: FontWeight.w600)),
        );
      case TicketStatus.done:
        return Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.soft(AppColors.success),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.check, color: AppColors.success, size: 20),
        );
    }
  }
}
