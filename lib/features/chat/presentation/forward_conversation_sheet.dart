import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_format.dart';
import '../../../shared/models/conversation.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../application/conversations_controller.dart';

/// Opens a bottom sheet listing the user's conversations and returns the one
/// they pick (or null if dismissed). Used by the image viewer and the message
/// context menu to forward an attachment into another chat.
Future<ConversationSummary?> showForwardConversationPicker(
  BuildContext context,
) {
  return showModalBottomSheet<ConversationSummary>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _ForwardConversationSheet(),
  );
}

class _ForwardConversationSheet extends ConsumerWidget {
  const _ForwardConversationSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversations = ref.watch(conversationsProvider);
    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: context.isDarkMode ? AppColors.darkSurface : const Color(0xFFF6F6FA),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(34)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
                child: Column(
                  children: [
                    Container(
                      width: 46,
                      height: 5,
                      decoration: BoxDecoration(
                        color: context.borderColor,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        const Icon(
                          LucideIcons.forward,
                          color: AppColors.primary,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Chuyển tiếp đến',
                          style: TextStyle(
                            color: context.textColor,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: conversations.when(
                  data: (list) {
                    if (list.isEmpty) {
                      return Center(
                        child: Text(
                          'Chưa có cuộc trò chuyện nào.',
                          style: TextStyle(color: context.textSecondary),
                        ),
                      );
                    }
                    return ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => Divider(
                        height: 1,
                        indent: 64,
                        color: context.borderColor,
                      ),
                      itemBuilder: (context, index) {
                        final conversation = list[index];
                        return _ForwardTile(
                          conversation: conversation,
                          onTap: () => Navigator.pop(context, conversation),
                        );
                      },
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                  error: (e, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Không tải được danh sách chat: $e',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: context.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ForwardTile extends StatelessWidget {
  const _ForwardTile({required this.conversation, required this.onTap});

  final ConversationSummary conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = conversation.lastMessage?.content.trim();
    return InkWell(
      onTap: onTap,
      child: Container(
        color: context.cardColor,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            UserAvatar(
              userId: conversation.id,
              displayName: conversation.title,
              avatarUrl: conversation.avatarUrl,
              isGroup: conversation.isGroup,
              size: 44,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    conversation.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: context.textColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle != null && subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Text(
              Dates.time(conversation.updatedAt),
              style: TextStyle(
                color: context.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
