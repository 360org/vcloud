import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../application/conversations_controller.dart';

/// Mockup 02 — "Tin nhắn": search + conversation list, Zalo/Telegram-like.
class ConversationListScreen extends ConsumerStatefulWidget {
  const ConversationListScreen({super.key});

  @override
  ConsumerState<ConversationListScreen> createState() =>
      _ConversationListScreenState();
}

class _ConversationListScreenState
    extends ConsumerState<ConversationListScreen> {
  String _query = '';

  static String _viTime(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(d).inDays;
    if (diff == 0) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    if (diff == 1) return 'Hôm qua';
    if (diff < 7) return '$diff ngày';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final convs = ref.watch(conversationsProvider);
    return AppScaffold(
      title: 'Tin nhắn',
      actions: [
        IconButton(
          onPressed: () => context.push('/chat/new'),
          icon: const Icon(Icons.edit_square),
        ),
      ],
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/chat/new'),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: convs.when(
        data: (list) {
          final filtered = _query.isEmpty
              ? list
              : list
                  .where((c) => (c.title)
                      .toLowerCase()
                      .contains(_query.toLowerCase()))
                  .toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: const InputDecoration(
                    hintText: 'Tìm kiếm',
                    prefixIcon: Icon(Icons.search, color: AppColors.textMuted),
                  ),
                ),
              ),
              if (list.isEmpty)
                const Expanded(
                  child: EmptyState(
                    icon: Icons.forum_outlined,
                    title: 'Chưa có cuộc trò chuyện',
                    subtitle: 'Nhấn nút + để bắt đầu trò chuyện hoặc tạo nhóm.',
                  ),
                )
              else
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(conversationsProvider);
                      await ref.read(conversationsProvider.future);
                    },
                    child: ListView.separated(
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) =>
                          const Divider(indent: 76, height: 1),
                      itemBuilder: (_, i) {
                        final c = filtered[i];
                        final preview =
                            c.lastMessage?.content ?? 'Chưa có tin nhắn';
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          leading: c.isGroup
                              ? _GroupAvatar(title: c.title)
                              : UserAvatar(
                                  userId: c.id,
                                  displayName: c.title,
                                  size: 48,
                                ),
                          title: Text(c.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 15)),
                          subtitle: Text(preview,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: AppColors.textSecondary)),
                          trailing: Text(
                            _viTime(c.updatedAt),
                            style: const TextStyle(
                                color: AppColors.textMuted, fontSize: 12),
                          ),
                          onTap: () => context.push('/chat/${c.id}'),
                        );
                      },
                    ),
                  ),
                ),
            ],
          );
        },
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(conversationsProvider),
        ),
      ),
    );
  }
}

class _GroupAvatar extends StatelessWidget {
  const _GroupAvatar({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: const BoxDecoration(
        color: AppColors.primarySoft,
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.groups, color: AppColors.primary),
    );
  }
}
