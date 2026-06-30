import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../features/auth/application/auth_controller.dart';
import '../../../shared/models/conversation.dart';
import '../../../shared/models/profile.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../../shared/widgets/ui_kit.dart';
import '../application/conversations_controller.dart';

/// "Tin nhắn": search + conversation list with inline new-chat bottom sheet.
class ConversationListScreen extends ConsumerStatefulWidget {
  const ConversationListScreen({super.key});

  @override
  ConsumerState<ConversationListScreen> createState() =>
      _ConversationListScreenState();
}

class _ConversationListScreenState
    extends ConsumerState<ConversationListScreen> {
  String _query = '';
  int _selectedTab = 0;

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

  void _openNewChatSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _NewChatSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final convs = ref.watch(conversationsProvider);
    return AppScaffold(
      title: 'Tin nhắn',
      actions: [
        IconButton(
          onPressed: _openNewChatSheet,
          icon: const Icon(LucideIcons.squarePen),
        ),
      ],
      body: convs.when(
        data: (list) {
          final showGroups = _selectedTab == 1;
          final filtered = list.where((c) {
            final preview = c.lastMessage?.content ?? '';
            final searchable = '${c.title} $preview'.toLowerCase();
            return c.isGroup == showGroups &&
                searchable.contains(_query.toLowerCase());
          }).toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: SegmentedTabs(
                  labels: const ['Trực tiếp', 'Nhóm'],
                  selectedIndex: _selectedTab,
                  onChanged: (index) => setState(() => _selectedTab = index),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Container(
                  decoration: glassDecoration(radius: 14),
                  child: TextField(
                    onChanged: (v) => setState(() => _query = v),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Tìm kiếm tin nhắn...',
                      hintStyle: const TextStyle(color: AppColors.textMuted),
                      prefixIcon: const Icon(
                        LucideIcons.search,
                        color: AppColors.textMuted,
                        size: 20,
                      ),
                      suffixIcon: _query.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                LucideIcons.x,
                                color: AppColors.textMuted,
                                size: 18,
                              ),
                              onPressed: () {
                                setState(() => _query = '');
                                HapticFeedback.lightImpact();
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: AppColors.surface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ),
              if (filtered.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            gradient: AppColors.chatGrad,
                            shape: BoxShape.circle,
                            boxShadow: AppColors.glow(
                              AppColors.chat,
                              opacity: 0.3,
                            ),
                          ),
                          child: const Icon(
                            LucideIcons.messageCircle,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Chưa có cuộc trò chuyện',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Nhấn nút viết để bắt đầu trò chuyện.',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(conversationsProvider);
                      await ref.read(conversationsProvider.future);
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 8,
                      ),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final c = filtered[i];
                        final preview =
                            c.lastMessage?.content ?? 'Chưa có tin nhắn';
                        return Dismissible(
                          key: ValueKey(c.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            padding: const EdgeInsets.only(right: 20),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Icon(
                              LucideIcons.archive,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          confirmDismiss: (_) async {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                title: const Text('Lưu trữ cuộc trò chuyện?'),
                                content: const Text(
                                  'Cuộc trò chuyện sẽ được chuyển vào kho lưu trữ.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () =>
                                        Navigator.pop(context, false),
                                    child: const Text('Huỷ'),
                                  ),
                                  FilledButton.tonal(
                                    onPressed: () =>
                                        Navigator.pop(context, true),
                                    child: const Text('Lưu trữ'),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed == true) {
                              await ref
                                  .read(conversationActionsProvider)
                                  .archive(c.id);
                              ref.invalidate(conversationsProvider);
                              return true;
                            }
                            return false;
                          },
                          child:
                              _ConversationItem(
                                    conversation: c,
                                    preview: preview,
                                    timeLabel: _viTime(c.updatedAt),
                                    onTap: () => context.push('/chat/${c.id}'),
                                  )
                                  .animate()
                                  .fadeIn(
                                    duration: 300.ms,
                                    delay: Duration(milliseconds: 50 * i),
                                  )
                                  .slideX(
                                    begin: 0.02,
                                    end: 0,
                                    duration: 300.ms,
                                    delay: Duration(milliseconds: 50 * i),
                                    curve: Curves.easeOutCubic,
                                  ),
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

class TelegramConversationListScreen extends ConsumerStatefulWidget {
  const TelegramConversationListScreen({super.key});

  @override
  ConsumerState<TelegramConversationListScreen> createState() =>
      _TelegramConversationListScreenState();
}

class _TelegramConversationListScreenState
    extends ConsumerState<TelegramConversationListScreen> {
  String _query = '';

  static String _timeLabel(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) {
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    if (diff == 1) return 'Hôm qua';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}';
  }

  void _openNewMessageSheet(List<ConversationSummary> conversations) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NewMessageSheet(
        conversations: conversations,
        onOpenConversation: (conversation) {
          Navigator.pop(context);
          context.push('/chat/${conversation.id}');
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final conversations = ref.watch(conversationsProvider);

    return AppScaffold(
      title: 'Trò chuyện',
      showAppBar: false,
      wrapSafeArea: false,
      body: ColoredBox(
        color: AppColors.surface,
        child: SafeArea(
          child: conversations.when(
            data: (list) {
              final filtered = list.where((conversation) {
                final preview = conversation.lastMessage?.content ?? '';
                final haystack = '${conversation.title} $preview'.toLowerCase();
                return haystack.contains(_query.toLowerCase());
              }).toList();

              return Column(
                children: [
                  _BalancedTelegramChatHeader(
                    onNewChat: () => _openNewMessageSheet(list),
                  ),
                  _TelegramSearchBar(
                    query: _query,
                    onChanged: (value) => setState(() => _query = value),
                    onClear: () {
                      setState(() => _query = '');
                      HapticFeedback.lightImpact();
                    },
                  ),
                  Expanded(
                    child: filtered.isEmpty
                        ? const _TelegramEmptyChats()
                        : RefreshIndicator(
                            onRefresh: () async {
                              ref.invalidate(conversationsProvider);
                              await ref.read(conversationsProvider.future);
                            },
                            child: ListView.separated(
                              padding: const EdgeInsets.fromLTRB(0, 12, 0, 104),
                              itemCount: filtered.length,
                              separatorBuilder: (_, _) => const Padding(
                                padding: EdgeInsets.only(left: 96),
                                child: Divider(
                                  height: 1,
                                  color: AppColors.border,
                                ),
                              ),
                              itemBuilder: (context, index) {
                                final conversation = filtered[index];
                                return _TelegramConversationRow(
                                  conversation: conversation,
                                  preview:
                                      conversation.lastMessage?.content ??
                                      'Chưa có tin nhắn',
                                  timeLabel: _timeLabel(conversation.updatedAt),
                                  onTap: () =>
                                      context.push('/chat/${conversation.id}'),
                                ).animate().fadeIn(
                                  duration: 220.ms,
                                  delay: Duration(milliseconds: 28 * index),
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
        ),
      ),
    );
  }
}

// ignore: unused_element
class _TelegramChatHeader extends StatelessWidget {
  const _TelegramChatHeader({required this.onNewChat});

  final VoidCallback onNewChat;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
      child: Row(
        children: [
          _HeaderPillButton(label: 'Sửa', onTap: () {}),
          const SizedBox(width: 12),
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.lockOpen,
                color: AppColors.textPrimary,
                size: 17,
              ),
              SizedBox(width: 6),
              Text(
                'Trò chuyện',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(22),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0D0F172A),
                  blurRadius: 10,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Tạo nhanh',
                  onPressed: onNewChat,
                  icon: const Icon(LucideIcons.circlePlus, size: 20),
                  color: AppColors.textPrimary,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 34,
                    height: 34,
                  ),
                ),
                IconButton(
                  tooltip: 'Tin nhắn mới',
                  onPressed: onNewChat,
                  icon: const Icon(LucideIcons.squarePen, size: 20),
                  color: AppColors.textPrimary,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 34,
                    height: 34,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _CenteredTelegramChatHeader extends StatelessWidget {
  const _CenteredTelegramChatHeader({required this.onNewChat});

  final VoidCallback onNewChat;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
      child: SizedBox(
        height: 42,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: _HeaderPillButton(label: 'Sửa', onTap: () {}),
            ),
            const Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    LucideIcons.lockOpen,
                    color: AppColors.textPrimary,
                    size: 17,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Trò chuyện',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0D0F172A),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Tạo nhanh',
                      onPressed: onNewChat,
                      icon: const Icon(LucideIcons.circlePlus, size: 20),
                      color: AppColors.textPrimary,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 34,
                        height: 34,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Tin nhắn mới',
                      onPressed: onNewChat,
                      icon: const Icon(LucideIcons.squarePen, size: 20),
                      color: AppColors.textPrimary,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints.tightFor(
                        width: 34,
                        height: 34,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BalancedTelegramChatHeader extends StatelessWidget {
  const _BalancedTelegramChatHeader({required this.onNewChat});

  final VoidCallback onNewChat;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
      child: SizedBox(
        height: 42,
        child: Row(
          children: [
            SizedBox(
              width: 86,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _HeaderPillButton(label: 'Sửa', onTap: () {}),
              ),
            ),
            const Expanded(
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      LucideIcons.lockOpen,
                      color: AppColors.textPrimary,
                      size: 17,
                    ),
                    SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Trò chuyện',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: 86,
              child: Align(
                alignment: Alignment.centerRight,
                child: _HeaderActionPill(onTap: onNewChat),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderActionPill extends StatelessWidget {
  const _HeaderActionPill({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D0F172A),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Tin nhắn mới',
            onPressed: onTap,
            icon: const Icon(LucideIcons.squarePen, size: 20),
            color: AppColors.textPrimary,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 34, height: 34),
          ),
        ],
      ),
    );
  }
}

class _HeaderPillButton extends StatelessWidget {
  const _HeaderPillButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        width: 72,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0D0F172A),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _TelegramSearchBar extends StatelessWidget {
  const _TelegramSearchBar({
    required this.query,
    required this.onChanged,
    required this.onClear,
  });

  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFFF0F3F8),
          borderRadius: BorderRadius.circular(14),
        ),
        child: TextField(
          onChanged: onChanged,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 16),
          decoration: InputDecoration(
            hintText: 'Tìm kiếm',
            hintStyle: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: const Padding(
              padding: EdgeInsets.only(left: 10, right: 2),
              child: Icon(
                LucideIcons.search,
                color: AppColors.textMuted,
                size: 21,
              ),
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
            contentPadding: const EdgeInsets.symmetric(vertical: 13),
          ),
        ),
      ),
    );
  }
}

class _NewMessageSheet extends StatefulWidget {
  const _NewMessageSheet({
    required this.conversations,
    required this.onOpenConversation,
  });

  final List<ConversationSummary> conversations;
  final ValueChanged<ConversationSummary> onOpenConversation;

  @override
  State<_NewMessageSheet> createState() => _NewMessageSheetState();
}

class _NewMessageSheetState extends State<_NewMessageSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.conversations.where((conversation) {
      final preview = conversation.lastMessage?.content ?? '';
      final haystack = '${conversation.title} $preview'.toLowerCase();
      return haystack.contains(_query.toLowerCase());
    }).toList();

    return SafeArea(
      top: false,
      child: Container(
        height: MediaQuery.sizeOf(context).height * 0.78,
        margin: const EdgeInsets.only(top: 56),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            const _NewMessageHeader(),
            _NewMessageSearchField(
              query: _query,
              onChanged: (value) => setState(() => _query = value),
              onClear: () => setState(() => _query = ''),
            ),
            const SizedBox(height: 10),
            const _NewMessageActionRow(
              icon: LucideIcons.users,
              label: 'Nhóm mới',
            ),
            const _NewMessageActionRow(
              icon: LucideIcons.userPlus,
              label: 'Liên hệ mới',
            ),
            const _NewMessageActionRow(
              icon: LucideIcons.megaphone,
              label: 'Kênh mới',
            ),
            if (filtered.isNotEmpty) ...[
              const SizedBox(height: 4),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.only(bottom: 18),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const Padding(
                    padding: EdgeInsets.only(left: 88),
                    child: Divider(height: 1, color: AppColors.border),
                  ),
                  itemBuilder: (context, index) {
                    final conversation = filtered[index];
                    return _NewMessageConversationRow(
                      conversation: conversation,
                      onTap: () => widget.onOpenConversation(conversation),
                    );
                  },
                ),
              ),
            ] else
              const Expanded(
                child: Center(
                  child: Text(
                    'Chưa có người đã nhắn tin',
                    style: TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NewMessageHeader extends StatelessWidget {
  const _NewMessageHeader();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 10,
            child: Container(
              width: 46,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 14),
            child: Text(
              'Tin nhắn mới',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 21,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NewMessageSearchField extends StatelessWidget {
  const _NewMessageSearchField({
    required this.query,
    required this.onChanged,
    required this.onClear,
  });

  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: const Color(0xFFEFEFEF),
          borderRadius: BorderRadius.circular(16),
        ),
        child: TextField(
          onChanged: onChanged,
          style: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: 'Tìm kiếm',
            hintStyle: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 17,
            ),
            prefixIcon: const Padding(
              padding: EdgeInsets.only(left: 12, right: 2),
              child: Icon(
                LucideIcons.search,
                color: AppColors.textMuted,
                size: 22,
              ),
            ),
            suffixIcon: query.isEmpty
                ? null
                : IconButton(
                    onPressed: onClear,
                    icon: const Icon(LucideIcons.x, size: 20),
                  ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }
}

class _NewMessageActionRow extends StatelessWidget {
  const _NewMessageActionRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: () {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$label sắp có')));
      },
      child: Padding(
        padding: const EdgeInsets.only(left: 34),
        child: Row(
          children: [
            SizedBox(
              width: 44,
              height: 50,
              child: Icon(icon, color: AppColors.primary, size: 26),
            ),
            Expanded(
              child: Container(
                height: 50,
                alignment: Alignment.centerLeft,
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: AppColors.border, width: 1),
                  ),
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 19,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewMessageConversationRow extends StatelessWidget {
  const _NewMessageConversationRow({
    required this.conversation,
    required this.onTap,
  });

  final ConversationSummary conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final preview = conversation.lastMessage?.content ?? 'Chưa có tin nhắn';
    return PressableScale(
      onTap: onTap,
      scale: 0.99,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 8, 24, 8),
        child: Row(
          children: [
            conversation.isGroup
                ? _TelegramGroupAvatar(title: conversation.title)
                : UserAvatar(
                    userId: conversation.id,
                    displayName: conversation.title,
                    size: 48,
                  ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    conversation.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TelegramConversationRow extends StatelessWidget {
  const _TelegramConversationRow({
    required this.conversation,
    required this.preview,
    required this.timeLabel,
    required this.onTap,
  });

  final ConversationSummary conversation;
  final String preview;
  final String timeLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unreadCount = conversation.unreadCount;
    return PressableScale(
      onTap: onTap,
      scale: 0.985,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            conversation.isGroup
                ? _TelegramGroupAvatar(title: conversation.title)
                : UserAvatar(
                    userId: conversation.id,
                    displayName: conversation.title,
                    size: 52,
                  ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Hero(
                          tag: 'chat-title-${conversation.id}',
                          child: Material(
                            color: Colors.transparent,
                            child: Text(
                              conversation.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                height: 1.15,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        timeLabel,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          preview,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: unreadCount > 0
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                            fontSize: 13,
                            height: 1.2,
                            fontWeight: unreadCount > 0
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                      if (unreadCount > 0) ...[
                        const SizedBox(width: 8),
                        _TelegramUnreadPill(count: unreadCount),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TelegramUnreadPill extends StatelessWidget {
  const _TelegramUnreadPill({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final label = count > 999 ? '999+' : count.toString();
    return Container(
      constraints: const BoxConstraints(minWidth: 32, minHeight: 24),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 9),
      decoration: BoxDecoration(
        color: AppColors.danger,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _TelegramGroupAvatar extends StatelessWidget {
  const _TelegramGroupAvatar({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final initial = title.trim().isEmpty ? '?' : title.trim()[0].toUpperCase();
    return Container(
      width: 56,
      height: 56,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF26E3D9), Color(0xFF14B8A6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _TelegramEmptyChats extends StatelessWidget {
  const _TelegramEmptyChats();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'Chưa có cuộc trò chuyện',
        style: TextStyle(
          color: AppColors.textMuted,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ConversationItem extends StatelessWidget {
  const _ConversationItem({
    required this.conversation,
    required this.preview,
    required this.timeLabel,
    required this.onTap,
  });

  final ConversationSummary conversation;
  final String preview;
  final String timeLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = conversation;
    final unreadCount = c.unreadCount;
    return PressableScale(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: unreadCount > 0
              ? AppColors.featureBackgroundStrong(AppColors.chat)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: unreadCount > 0
                ? AppColors.chat.withValues(alpha: 0.18)
                : AppColors.border.withValues(alpha: 0.7),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            c.isGroup
                ? _GroupAvatar(title: c.title)
                : UserAvatar(userId: c.id, displayName: c.title, size: 52),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Hero(
                    tag: 'chat-title-${c.id}',
                    child: Material(
                      color: Colors.transparent,
                      child: Text(
                        c.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: unreadCount > 0
                              ? FontWeight.w800
                              : FontWeight.w600,
                          fontSize: 15,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    preview,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: unreadCount > 0
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: unreadCount > 0
                          ? FontWeight.w600
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  timeLabel,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                  ),
                ),
                if (unreadCount > 0) ...[
                  const SizedBox(height: 4),
                  UnreadBadge(count: unreadCount),
                ],
              ],
            ),
          ],
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
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        gradient: AppColors.chatGrad,
        shape: BoxShape.circle,
        boxShadow: AppColors.glow(AppColors.chat, opacity: 0.2),
      ),
      child: const Icon(LucideIcons.users, color: Colors.white, size: 22),
    );
  }
}

/// Provider for all users (used in new chat sheet).
final _allUsersProvider = FutureProvider.autoDispose<List<Profile>>((
  ref,
) async {
  final repo = ref.read(chatRepositoryProvider);
  return repo.allUsers();
});

/// Bottom sheet for creating new conversations (Direct + Group tabs).
class _NewChatSheet extends ConsumerStatefulWidget {
  const _NewChatSheet();

  @override
  ConsumerState<_NewChatSheet> createState() => _NewChatSheetState();
}

class _NewChatSheetState extends ConsumerState<_NewChatSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);
  bool _busy = false;

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _open(String otherId) async {
    setState(() => _busy = true);
    try {
      await ref.read(conversationActionsProvider).openDirect(otherId);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã tạo cuộc trò chuyện mới.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceFirst('Failure: ', '')),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.textMuted.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ],
            ),
          ),
          TabBar(
            controller: _tab,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textMuted,
            indicatorColor: AppColors.primary,
            labelStyle: const TextStyle(fontWeight: FontWeight.w600),
            tabs: const [
              Tab(text: 'Trực tiếp'),
              Tab(text: 'Nhóm'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tab,
              children: [
                _DirectTab(busy: _busy, onOpen: _open),
                const _GroupTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DirectTab extends ConsumerStatefulWidget {
  const _DirectTab({required this.busy, required this.onOpen});
  final bool busy;
  final void Function(String) onOpen;

  @override
  ConsumerState<_DirectTab> createState() => _DirectTabState();
}

class _DirectTabState extends ConsumerState<_DirectTab> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final users = ref.watch(_allUsersProvider).value ?? [];
    final me = ref.read(authControllerProvider).value?.id ?? '';
    final others = users.where((u) => u.id != me).toList();

    final filtered = _searchQuery.isEmpty
        ? others
        : others.where((u) {
            final name = u.displayName.toLowerCase();
            final email = u.email.toLowerCase();
            return name.contains(_searchQuery.toLowerCase()) ||
                email.contains(_searchQuery.toLowerCase());
          }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: 'Tìm người...',
              prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
              filled: true,
              fillColor: AppColors.bg,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: filtered.isEmpty
              ? const Center(
                  child: Text(
                    'Không tìm thấy người dùng.',
                    style: TextStyle(color: AppColors.textMuted),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final u = filtered[i];
                    final name = (u.displayName.isNotEmpty
                        ? u.displayName
                        : u.email.split('@').first);
                    final initial = name[0].toUpperCase();
                    return Material(
                      type: MaterialType.transparency,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primarySoft,
                          child: Text(
                            initial,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        title: Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          u.email,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                        trailing: widget.busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.arrow_forward_ios,
                                size: 14,
                                color: AppColors.textMuted,
                              ),
                        onTap: widget.busy ? null : () => widget.onOpen(u.id),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _GroupTab extends ConsumerWidget {
  const _GroupTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.groups, size: 64, color: AppColors.textMuted),
          SizedBox(height: 16),
          Text(
            'Tạo nhóm',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Tính năng này sắp có.',
            style: TextStyle(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
