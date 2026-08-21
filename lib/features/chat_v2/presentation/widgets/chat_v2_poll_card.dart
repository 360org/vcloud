import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../../auth/application/auth_controller.dart';
import '../../application/chat_v2_messages_controller.dart';
import '../../data/models/chat_v2_message.dart';
import '../../domain/models/chat_v2_poll_model.dart';

/// Thẻ hiển thị cuộc bình chọn (Poll Card) chuẩn Zalo/Telegram
class ChatV2PollCard extends ConsumerStatefulWidget {
  const ChatV2PollCard({
    super.key,
    required this.message,
    required this.poll,
    required this.isMine,
    required this.timeStr,
  });

  final ChatV2Message message;
  final ChatV2Poll poll;
  final bool isMine;
  final String timeStr;

  @override
  ConsumerState<ChatV2PollCard> createState() => _ChatV2PollCardState();
}

class _ChatV2PollCardState extends ConsumerState<ChatV2PollCard> {
  bool _isSubmitting = false;

  Future<void> _handleVote(int optionId) async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      await ref
          .read(chatV2MessagesProvider(widget.message.channelId).notifier)
          .votePoll(widget.message.id, optionId);
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(authControllerProvider).valueOrNull;
    final meta = user?.userMetadata;
    final partnerIdStr = meta?['partner_id']?.toString() ??
        meta?['partner']?['id']?.toString();
    final currentPartnerId = int.tryParse(partnerIdStr ?? '');

    final poll = widget.poll;
    final totalVotes = poll.totalVotes;
    final isMulti = poll.allowMultiple;

    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Header: Icon biểu đồ + Tiêu đề bình chọn + Badge Chọn 1/Chọn nhiều
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF0F172A).withValues(alpha: 0.6)
                  : const Color(0xFFF8FAFC),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                  width: 1,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF10B981), Color(0xFF059669)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        LucideIcons.barChart2,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'BÌNH CHỌN',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: isDark ? const Color(0xFF34D399) : const Color(0xFF059669),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isMulti ? 'Chọn nhiều' : 'Chọn 1',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  poll.question,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                    color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
          ),

          // 2. Danh sách các lựa chọn bình chọn
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: Column(
              children: [
                for (final opt in poll.options) ...[
                  _buildOptionTile(
                    context: context,
                    option: opt,
                    totalVotes: totalVotes,
                    isMulti: isMulti,
                    isDark: isDark,
                    hasVotedThis: opt.hasVoted(currentPartnerId),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),

          // 3. Footer: Tổng số lượt bình chọn + Thời gian & Tình trạng gửi
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      LucideIcons.users,
                      size: 13,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      totalVotes > 0
                          ? '$totalVotes lượt bình chọn'
                          : 'Chưa có lượt bình chọn nào',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.timeStr,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                    if (widget.isMine) ...[
                      const SizedBox(width: 4),
                      const Icon(
                        LucideIcons.checkCheck,
                        size: 13,
                        color: Color(0xFF00C83A),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionTile({
    required BuildContext context,
    required ChatV2PollOption option,
    required int totalVotes,
    required bool isMulti,
    required bool isDark,
    required bool hasVotedThis,
  }) {
    final ratio = totalVotes > 0 ? (option.voteCount / totalVotes) : 0.0;
    final percent = (ratio * 100).round();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _handleVote(option.id),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            color: hasVotedThis
                ? (isDark
                    ? const Color(0xFF065F46).withValues(alpha: 0.25)
                    : const Color(0xFFD1FAE5).withValues(alpha: 0.6))
                : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: hasVotedThis
                  ? const Color(0xFF10B981)
                  : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              width: hasVotedThis ? 1.4 : 1,
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: Stack(
              children: [
                // Thanh tiến trình phần trăm trượt mượt mà
                Positioned.fill(
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: ratio.clamp(0.0, 1.0),
                    child: Container(
                      color: hasVotedThis
                          ? const Color(0xFF10B981).withValues(alpha: 0.22)
                          : (isDark
                              ? const Color(0xFF334155).withValues(alpha: 0.45)
                              : const Color(0xFFE2E8F0).withValues(alpha: 0.7)),
                    ),
                  ),
                ),

                // Nội dung lựa chọn
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                  child: Row(
                    children: [
                      // Icon Radio hoặc Checkbox
                      Container(
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: isMulti ? BoxShape.rectangle : BoxShape.circle,
                          borderRadius: isMulti ? BorderRadius.circular(5) : null,
                          color: hasVotedThis
                              ? const Color(0xFF10B981)
                              : Colors.transparent,
                          border: Border.all(
                            color: hasVotedThis
                                ? const Color(0xFF10B981)
                                : (isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8)),
                            width: 1.6,
                          ),
                        ),
                        child: hasVotedThis
                            ? const Icon(
                                LucideIcons.check,
                                size: 13,
                                color: Colors.white,
                              )
                            : null,
                      ),
                      const SizedBox(width: 9),

                      // Tên phương án
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              option.text,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: hasVotedThis ? FontWeight.w700 : FontWeight.w500,
                                color: isDark
                                    ? const Color(0xFFF1F5F9)
                                    : const Color(0xFF1E293B),
                              ),
                            ),
                            if (option.voterNames.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                option.voterNames.join(', '),
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(width: 8),

                      // Số phiếu và Phần trăm
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${option.voteCount} phiếu',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: hasVotedThis
                                  ? (isDark ? const Color(0xFF34D399) : const Color(0xFF059669))
                                  : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                            ),
                          ),
                          if (totalVotes > 0)
                            Text(
                              '$percent%',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                                color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
