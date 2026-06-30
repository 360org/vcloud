import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_format.dart';
import '../../../shared/models/activity_log.dart';
import '../../../shared/models/ticket.dart';
import '../../../shared/models/ticket_comment.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../../shared/widgets/ui_kit.dart';
import '../application/ticket_controller.dart';

class TicketDetailScreen extends ConsumerStatefulWidget {
  const TicketDetailScreen({super.key, required this.ticketId});

  final String ticketId;

  @override
  ConsumerState<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends ConsumerState<TicketDetailScreen> {
  Ticket? _ticket;
  Object? _error;
  String _myId = '';
  final _commentController = TextEditingController();
  final _scrollController = ScrollController();
  bool _sendingComment = false;

  @override
  void initState() {
    super.initState();
    _myId = Supabase.instance.client.auth.currentUser?.id ?? '';
    _load();
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final repo = ref.read(ticketRepositoryProvider);
      final ticket = await repo.one(widget.ticketId);
      if (mounted) setState(() => _ticket = ticket);
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;
    setState(() => _sendingComment = true);
    try {
      await ref.read(ticketCommentActionsProvider).add(widget.ticketId, text);
      _commentController.clear();
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gửi bình luận thất bại: $e')));
      }
    } finally {
      if (mounted) setState(() => _sendingComment = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xoá ticket?'),
        content: const Text('Hành động này không thể hoàn tác.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Huỷ'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(ticketActionsProvider).delete(widget.ticketId);
      if (mounted) context.go('/tickets');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Xoá thất bại: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF7F8FC),
        body: SafeArea(child: ErrorView(error: _error!)),
      );
    }
    if (_ticket == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFF7F8FC),
        body: LoadingView(),
      );
    }

    final ticket = _ticket!;
    final canDelete = ticket.createdBy == _myId;
    final comments = ref.watch(ticketCommentsProvider(widget.ticketId));

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            _TicketDetailHeader(canDelete: canDelete, onDelete: _delete),
            Expanded(
              child: ListView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  _TicketInfoCard(ticket: ticket),
                  const SizedBox(height: 14),
                  _StatusTimeline(ticket: ticket),
                  const SizedBox(height: 14),
                  _ActivityLogSection(ticketId: widget.ticketId),
                  const SizedBox(height: 16),
                  const _SectionTitle(
                    icon: LucideIcons.messageSquare,
                    title: 'Bình luận',
                  ),
                  const SizedBox(height: 10),
                  comments.when(
                    data: (list) {
                      if (list.isEmpty) {
                        return const _SoftEmpty(text: 'Chưa có bình luận nào');
                      }
                      return Column(
                        children: [
                          for (final comment in list)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _CommentCard(
                                comment: comment,
                                myId: _myId,
                              ),
                            ),
                        ],
                      );
                    },
                    loading: () => const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (e, _) => Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: Text(
                          'Lỗi tải bình luận: $e',
                          style: const TextStyle(color: AppColors.danger),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 72),
                ],
              ),
            ),
            _CommentComposer(
              controller: _commentController,
              sending: _sendingComment,
              onSubmit: _sendComment,
            ),
          ],
        ),
      ),
    );
  }
}

class _TicketDetailHeader extends StatelessWidget {
  const _TicketDetailHeader({required this.canDelete, required this.onDelete});

  final bool canDelete;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Row(
        children: [
          PressableScale(
            onTap: () => Navigator.maybePop(context),
            child: Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.chevronLeft,
                color: AppColors.textPrimary,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Container(
              height: 42,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A0F172A),
                    blurRadius: 12,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.ticket, color: AppColors.ticket, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Ticket',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          if (canDelete)
            PressableScale(
              onTap: onDelete,
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.soft(AppColors.danger),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.trash2,
                  color: AppColors.danger,
                  size: 20,
                ),
              ),
            )
          else
            const SizedBox(width: 42),
        ],
      ),
    );
  }
}

class _TicketInfoCard extends StatelessWidget {
  const _TicketInfoCard({required this.ticket});

  final Ticket ticket;

  @override
  Widget build(BuildContext context) {
    final description = ticket.description?.trim();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Hero(
            tag: 'ticket-title-${ticket.id}',
            child: Material(
              color: Colors.transparent,
              child: Text(
                ticket.title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  height: 1.15,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tạo ${Dates.relativeShort(ticket.createdAt)} · Cập nhật ${Dates.relativeShort(ticket.updatedAt)}',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _TicketPill(
                label: _statusText(ticket.status),
                color: ticket.status == TicketStatus.done
                    ? AppColors.success
                    : AppColors.ticket,
              ),
              _TicketPill(
                label: ticket.priority.label,
                color: _priorityColor(ticket.priority),
              ),
              if (ticket.category?.isNotEmpty == true)
                _TicketPill(label: ticket.category!, color: AppColors.primary),
            ],
          ),
          if (description != null && description.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F6FC),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                description,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 15,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CommentCard extends StatelessWidget {
  const _CommentCard({required this.comment, required this.myId});

  final TicketComment comment;
  final String myId;

  @override
  Widget build(BuildContext context) {
    final isMe = comment.authorId == myId;
    final name = comment.authorName ?? (isMe ? 'Bạn' : 'Người dùng');
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration(radius: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: isMe
                      ? AppColors.brand
                      : AppColors.featureGrad(
                          AppColors.primary,
                          AppColors.primaryDeep,
                        ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      Dates.time(comment.createdAt),
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            comment.content,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentComposer extends StatelessWidget {
  const _CommentComposer({
    required this.controller,
    required this.sending,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        border: const Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F3F8),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: TextField(
                  controller: controller,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSubmit(),
                  enabled: !sending,
                  style: const TextStyle(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'Nhập bình luận...',
                    hintStyle: TextStyle(color: AppColors.textMuted),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 13,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            PressableScale(
              onTap: sending ? null : onSubmit,
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: AppColors.featureGrad(
                    AppColors.ticket,
                    AppColors.ticketDeep,
                  ),
                  shape: BoxShape.circle,
                ),
                child: sending
                    ? const Padding(
                        padding: EdgeInsets.all(15),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        LucideIcons.send,
                        color: Colors.white,
                        size: 22,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusTimeline extends StatelessWidget {
  const _StatusTimeline({required this.ticket});

  final Ticket ticket;

  @override
  Widget build(BuildContext context) {
    final statuses = [
      _TimelineStep(
        status: 'Tạo ticket',
        icon: LucideIcons.plus,
        color: AppColors.primary,
        time: ticket.createdAt,
        isCompleted: true,
      ),
      _TimelineStep(
        status: 'Đang xử lý',
        icon: LucideIcons.play,
        color: AppColors.ticket,
        time: ticket.updatedAt,
        isCompleted:
            ticket.status == TicketStatus.doing ||
            ticket.status == TicketStatus.done,
      ),
      _TimelineStep(
        status: 'Hoàn thành',
        icon: LucideIcons.check,
        color: AppColors.success,
        time: ticket.status == TicketStatus.done ? ticket.updatedAt : null,
        isCompleted: ticket.status == TicketStatus.done,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(icon: LucideIcons.gitBranch, title: 'Tiến trình'),
          const SizedBox(height: 16),
          for (var i = 0; i < statuses.length; i++)
            _TimelineItem(step: statuses[i], isLast: i == statuses.length - 1),
        ],
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  const _TimelineItem({required this.step, required this.isLast});

  final _TimelineStep step;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: step.isCompleted
                    ? step.color
                    : AppColors.textMuted.withValues(alpha: 0.08),
                shape: BoxShape.circle,
                border: step.isCompleted
                    ? null
                    : Border.all(color: AppColors.border),
              ),
              child: Icon(
                step.icon,
                size: 17,
                color: step.isCompleted ? Colors.white : AppColors.textMuted,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 28,
                color: step.isCompleted
                    ? step.color.withValues(alpha: 0.28)
                    : AppColors.border,
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.status,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: step.isCompleted
                        ? AppColors.textPrimary
                        : AppColors.textMuted,
                  ),
                ),
                if (step.time != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    Dates.relativeShort(step.time!),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TimelineStep {
  const _TimelineStep({
    required this.status,
    required this.icon,
    required this.color,
    required this.isCompleted,
    this.time,
  });

  final String status;
  final IconData icon;
  final Color color;
  final DateTime? time;
  final bool isCompleted;
}

class _ActivityLogSection extends ConsumerWidget {
  const _ActivityLogSection({required this.ticketId});

  final String ticketId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activityLog = ref.watch(activityLogProvider(ticketId));

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            icon: LucideIcons.history,
            title: 'Lịch sử hoạt động',
          ),
          const SizedBox(height: 12),
          activityLog.when(
            data: (list) {
              if (list.isEmpty) {
                return const _SoftEmpty(text: 'Chưa có hoạt động nào');
              }
              return Column(
                children: [
                  for (final log in list.take(10))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _ActivityLogItem(log: log),
                    ),
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(8),
              child: Center(
                child: Text(
                  'Lỗi tải lịch sử: $e',
                  style: const TextStyle(color: AppColors.danger),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityLogItem extends StatelessWidget {
  const _ActivityLogItem({required this.log});

  final ActivityLog log;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(top: 6),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.5),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                log.displayAction,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              Text(
                Dates.relativeShort(log.createdAt),
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _SoftEmpty extends StatelessWidget {
  const _SoftEmpty({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _TicketPill extends StatelessWidget {
  const _TicketPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.soft(color),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

BoxDecoration _cardDecoration({double radius = 22}) {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: AppColors.border.withValues(alpha: 0.7)),
    boxShadow: const [
      BoxShadow(color: Color(0x0A0F172A), blurRadius: 16, offset: Offset(0, 8)),
    ],
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
