import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_format.dart';
import '../../../shared/models/ticket.dart';
import '../../../shared/models/ticket_comment.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../../shared/widgets/ui_kit.dart';
import '../../auth/application/auth_controller.dart';
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
  final _commentsKey = GlobalKey();
  final _optimisticComments = <TicketComment>[];
  int _visibleCommentCount = 3;
  bool _sendingComment = false;

  @override
  void initState() {
    super.initState();
    _myId = ref.read(authControllerProvider).value?.id ?? '';
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
    final pendingComment = TicketComment(
      id: 'pending-${DateTime.now().microsecondsSinceEpoch}',
      ticketId: widget.ticketId,
      authorId: _myId,
      content: text,
      createdAt: DateTime.now(),
      authorName: 'Bạn',
    );

    setState(() {
      _sendingComment = true;
      _optimisticComments.add(pendingComment);
      _commentController.clear();
    });
    _scrollToComments();

    try {
      final savedComment = await ref
          .read(ticketCommentActionsProvider)
          .add(widget.ticketId, text);
      if (mounted) {
        setState(() {
          final index = _optimisticComments.indexWhere(
            (comment) => comment.id == pendingComment.id,
          );
          if (index >= 0) _optimisticComments[index] = savedComment;
        });
      }
      _scrollToComments();
    } catch (e) {
      if (mounted) {
        setState(() {
          _optimisticComments.removeWhere(
            (comment) => comment.id == pendingComment.id,
          );
          _commentController.text = text;
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gửi bình luận thất bại: $e')));
      }
    } finally {
      if (mounted) setState(() => _sendingComment = false);
    }
  }

  void _scrollToComments() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _commentsKey.currentContext;
      if (context == null) return;
      Scrollable.ensureVisible(
        context,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        alignment: 0.04,
      );
    });
  }

  List<TicketComment> _mergeComments(List<TicketComment> serverComments) {
    final serverIds = serverComments.map((comment) => comment.id).toSet();
    final comments = <TicketComment>[
      ...serverComments,
      for (final comment in _optimisticComments)
        if (!serverIds.contains(comment.id)) comment,
    ];
    comments.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return comments;
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
    ref.listen(ticketCommentsProvider(widget.ticketId), (previous, next) {
      final previousCount = previous?.valueOrNull?.length ?? 0;
      final nextCount = next.valueOrNull?.length ?? previousCount;
      final serverIds =
          next.valueOrNull?.map((comment) => comment.id).toSet() ??
          const <String>{};
      if (serverIds.isNotEmpty && _optimisticComments.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _optimisticComments.removeWhere(
              (comment) => serverIds.contains(comment.id),
            );
          });
        });
      }
      if (nextCount > previousCount) _scrollToComments();
    });

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
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
                  const SizedBox(height: 16),
                  _SectionTitle(
                    key: _commentsKey,
                    icon: LucideIcons.messageSquare,
                    title: 'Bình luận',
                  ),
                  const SizedBox(height: 10),
                  comments.when(
                    data: (list) {
                      final mergedComments = _mergeComments(list);
                      if (mergedComments.isEmpty) {
                        return const _SoftEmpty(text: 'Chưa có bình luận nào');
                      }
                      final hiddenCount =
                          mergedComments.length > _visibleCommentCount
                          ? mergedComments.length - _visibleCommentCount
                          : 0;
                      final visibleComments = mergedComments
                          .take(_visibleCommentCount)
                          .toList();
                      return Column(
                        children: [
                          for (final comment in visibleComments)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _CommentCard(
                                comment: comment,
                                myId: _myId,
                                pending: comment.id.startsWith('pending-'),
                              ),
                            ),
                          if (hiddenCount > 0) ...[
                            _LoadMoreCommentsButton(
                              hiddenCount: hiddenCount,
                              onTap: () {
                                setState(() => _visibleCommentCount += 5);
                              },
                            ),
                          ],
                        ],
                      );
                    },
                    loading: () {
                      if (_optimisticComments.isNotEmpty) {
                        return Column(
                          children: [
                            for (final comment in _optimisticComments)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _CommentCard(
                                  comment: comment,
                                  myId: _myId,
                                  pending: true,
                                ),
                              ),
                          ],
                        );
                      }
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    },
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
            _TicketActionBar(
              ticket: ticket,
              onTake: () async {
                await ref.read(ticketActionsProvider).updateStatus(widget.ticketId, TicketStatus.doing);
                _load();
              },
              onComplete: () async {
                await ref.read(ticketActionsProvider).updateStatus(widget.ticketId, TicketStatus.done);
                _load();
              },
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

class _TicketActionBar extends StatefulWidget {
  const _TicketActionBar({
    required this.ticket,
    required this.onTake,
    required this.onComplete,
  });

  final Ticket ticket;
  final Future<void> Function() onTake;
  final Future<void> Function() onComplete;

  @override
  State<_TicketActionBar> createState() => _TicketActionBarState();
}

class _TicketActionBarState extends State<_TicketActionBar> {
  bool _loadingTake = false;
  bool _loadingComplete = false;

  @override
  Widget build(BuildContext context) {
    final status = widget.ticket.status;
    final isDone = status == TicketStatus.done;


    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFE2E8F0)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: (_loadingTake || _loadingComplete)
                  ? null
                  : () async {
                      setState(() => _loadingTake = true);
                      try {
                        await widget.onTake();
                      } finally {
                        if (mounted) setState(() => _loadingTake = false);
                      }
                    },
              icon: _loadingTake
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(LucideIcons.userCheck, size: 18),
              label: Text(_loadingTake ? 'Đang nhận...' : 'Nhận ticket'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: isDone ? const Color(0xFF94A3B8) : const Color(0xFF16A34A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: (isDone || _loadingTake || _loadingComplete)
                  ? null
                  : () async {
                      setState(() => _loadingComplete = true);
                      try {
                        await widget.onComplete();
                      } finally {
                        if (mounted) setState(() => _loadingComplete = false);
                      }
                    },
              icon: _loadingComplete
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Icon(isDone ? LucideIcons.checkCheck : LucideIcons.checkCircle, size: 18),
              label: Text(_loadingComplete ? 'Đang xử lý...' : (isDone ? 'Đã hoàn thành' : 'Hoàn thành')),
            ),
          ),
        ],
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
    final detail = _TicketDetailViewData.fromTicket(ticket);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DetailField(
            label: 'Tiêu đề',
            icon: LucideIcons.type,
            child: Hero(
              tag: 'ticket-title-${ticket.id}',
              child: Material(
                color: Colors.transparent,
                child: Text(
                  ticket.title,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    height: 1.18,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _DetailField(
            label: 'Mô tả vấn đề',
            icon: LucideIcons.fileText,
            child: Text(
              detail.description.isEmpty
                  ? 'Chưa có mô tả vấn đề.'
                  : detail.description,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 15,
                height: 1.42,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 14),
          _DetailField(
            label: 'Mức độ ưu tiên',
            icon: LucideIcons.star,
            child: Row(
              children: [
                for (var i = 1; i <= 4; i++) ...[
                  Icon(
                    LucideIcons.star,
                    color: i <= _priorityStars(ticket.priority)
                        ? AppColors.ticket
                        : AppColors.textMuted,
                    size: 22,
                  ),
                  const SizedBox(width: 5),
                ],
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    ticket.priority.displayName,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),

              ],
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _InfoChip(
                icon: LucideIcons.tag,
                label: detail.tags.isEmpty ? 'Không chọn tag' : detail.tags,
                color: AppColors.primary,
              ),
              _InfoChip(
                icon: LucideIcons.mail,
                label: detail.ccEmail.isEmpty
                    ? 'Không CC email'
                    : detail.ccEmail,
                color: AppColors.chat,
              ),
              _InfoChip(
                icon: LucideIcons.users,
                label: detail.team.isEmpty ? 'Hỗ trợ chung' : detail.team,
                color: AppColors.ticket,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TicketDetailViewData {
  const _TicketDetailViewData({
    required this.description,
    required this.ccEmail,
    required this.tags,
    required this.team,
  });

  final String description;
  final String ccEmail;
  final String tags;
  final String team;

  factory _TicketDetailViewData.fromTicket(Ticket ticket) {
    final rawDescription = ticket.description?.trim() ?? '';
    final lines = rawDescription
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    var ccEmail = '';
    final descriptionLines = <String>[];

    for (final line in lines) {
      if (line.toLowerCase().startsWith('cc email:')) {
        ccEmail = line.substring(line.indexOf(':') + 1).trim();
      } else if (!line.toLowerCase().startsWith('tài liệu:')) {
        descriptionLines.add(line);
      }
    }

    return _TicketDetailViewData(
      description: descriptionLines.join('\n'),
      ccEmail: ccEmail,
      tags: ticket.tagLabels.join(', '),
      team: ticket.category ?? '',
    );
  }
}

class _DetailField extends StatelessWidget {
  const _DetailField({
    required this.label,
    required this.icon,
    required this.child,
  });

  final String label;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFE),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.ticket, size: 17),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.soft(color),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 230),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadMoreCommentsButton extends StatelessWidget {
  const _LoadMoreCommentsButton({
    required this.hiddenCount,
    required this.onTap,
  });

  final int hiddenCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: AppColors.soft(AppColors.primary),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.12)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              LucideIcons.chevronsDown,
              color: AppColors.primary,
              size: 17,
            ),
            const SizedBox(width: 7),
            Text(
              'Xem thêm $hiddenCount bình luận cũ',
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentCard extends StatelessWidget {
  const _CommentCard({
    required this.comment,
    required this.myId,
    this.pending = false,
  });

  final TicketComment comment;
  final String myId;
  final bool pending;

  @override
  Widget build(BuildContext context) {
    final isMe = comment.authorId == myId;
    final name = comment.authorName ?? (isMe ? 'Bạn' : 'Người dùng');
    final initials = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Opacity(
      opacity: pending ? 0.72 : 1,
      child: Container(
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
                        pending ? 'Đang gửi...' : Dates.time(comment.createdAt),
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({super.key, required this.icon, required this.title});

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

int _priorityStars(TicketPriority priority) => switch (priority) {
  TicketPriority.p1 => 4,
  TicketPriority.p2 => 3,
  TicketPriority.p3 => 2,
  TicketPriority.p4 => 1,
};
