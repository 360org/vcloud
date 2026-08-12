import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../../core/api/auth_user.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_format.dart';
import '../../../features/auth/application/auth_controller.dart';
import '../../../shared/models/conversation.dart';
import '../../../shared/models/profile.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../../shared/widgets/ui_kit.dart';
import '../application/conversations_controller.dart';

String _conversationTitleForCurrentUser(
  ConversationSummary conversation,
  AuthUser? currentUser,
) {
  final title = conversation.title.trim();
  if (title.isEmpty || currentUser == null) return title;

  final currentLabels =
      <String>{
        currentUser.id,
        currentUser.email ?? '',
        currentUser.email?.split('@').first ?? '',
        currentUser.userMetadata['display_name']?.toString() ?? '',
      }.map((label) => label.trim().toLowerCase()).where((label) {
        return label.isNotEmpty;
      }).toSet();

  if (currentLabels.isEmpty || !title.contains(',')) return title;

  final others = title
      .split(',')
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .where((part) => !currentLabels.contains(part.toLowerCase()))
      .toList();

  return others.isEmpty ? title : others.join(', ');
}

/// "Tin nhắn": search + conversation list with inline new-chat bottom sheet.
DateTime _latestConversationTime(ConversationSummary conversation) {
  return conversation.lastMessage?.createdAt ?? conversation.updatedAt;
}

int _compareConversationsByLatestMessage(
  ConversationSummary a,
  ConversationSummary b,
) {
  return _latestConversationTime(b).compareTo(_latestConversationTime(a));
}

class ConversationListScreen extends ConsumerStatefulWidget {
  const ConversationListScreen({super.key});

  @override
  ConsumerState<ConversationListScreen> createState() =>
      _ConversationListScreenState();
}

class _ConversationListScreenState
    extends ConsumerState<ConversationListScreen> {
  String _query = '';
  String _filter = 'all'; // 'all', 'unread', 'group', 'direct'
  bool _filterInitialized = false;

  static String _viTime(DateTime dt) => Dates.chatListLabelVi(dt);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_filterInitialized) {
      _filterInitialized = true;
      try {
        final paramFilter = GoRouterState.of(context).uri.queryParameters['filter'];
        if (paramFilter != null && paramFilter.isNotEmpty) {
          _filter = paramFilter;
        }
      } catch (_) {}
    }
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
          final currentUser = ref.watch(authControllerProvider).value;
          final unreadCount = list.where((c) => c.unreadCount > 0).length;
          final groupCount = list.where((c) => c.isGroup).length;
          final directCount = list.where((c) => !c.isGroup).length;

          final filtered = list.where((c) {
            if (c.lastMessage == null) return false;

            // Apply quick filter chips
            if (_filter == 'unread' && c.unreadCount <= 0) return false;
            if (_filter == 'group' && !c.isGroup) return false;
            if (_filter == 'direct' && c.isGroup) return false;

            final preview = c.lastMessage?.content ?? '';
            final title = _conversationTitleForCurrentUser(c, currentUser);
            final searchable = '$title $preview'.toLowerCase();
            return searchable.contains(_query.toLowerCase());
          }).toList()..sort(_compareConversationsByLatestMessage);

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
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

              // Quick Filter Chips Bar [Tất cả | Chưa đọc | Nhóm | Trực tiếp]
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: Row(
                  children: [
                    _ChatFilterChip(
                      label: 'Tất cả',
                      count: list.length,
                      selected: _filter == 'all',
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _filter = 'all');
                      },
                    ),
                    const SizedBox(width: 8),
                    _ChatFilterChip(
                      label: 'Chưa đọc',
                      count: unreadCount,
                      selected: _filter == 'unread',
                      accentColor: AppColors.danger,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _filter = 'unread');
                      },
                    ),
                    const SizedBox(width: 8),
                    _ChatFilterChip(
                      label: 'Nhóm',
                      count: groupCount,
                      selected: _filter == 'group',
                      accentColor: AppColors.chat,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _filter = 'group');
                      },
                    ),
                    const SizedBox(width: 8),
                    _ChatFilterChip(
                      label: 'Trực tiếp',
                      count: directCount,
                      selected: _filter == 'direct',
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _filter = 'direct');
                      },
                    ),
                  ],
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
                        final title = _conversationTitleForCurrentUser(
                          c,
                          currentUser,
                        );
                        final rawPreview = c.lastMessage?.content ?? '';
                        final cleanedPreview = _stripHtml(rawPreview);
                        final preview = cleanedPreview.isEmpty ? 'Chưa có tin nhắn' : cleanedPreview;
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
                                    title: title,
                                    preview: preview,
                                    timeLabel: _viTime(
                                      _latestConversationTime(c),
                                    ),
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
  const TelegramConversationListScreen({
    super.key,
    this.unreadOnly = false,
  });

  final bool unreadOnly;

  @override
  ConsumerState<TelegramConversationListScreen> createState() =>
      _TelegramConversationListScreenState();
}

class _TelegramConversationListScreenState
    extends ConsumerState<TelegramConversationListScreen> {
  String _query = '';
  String _filter = 'all'; // 'all', 'unread', 'group', 'direct'
  bool _filterInitialized = false;

  @override
  void initState() {
    super.initState();
    if (widget.unreadOnly) {
      _filter = 'unread';
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_filterInitialized) {
      _filterInitialized = true;
      try {
        final paramFilter = GoRouterState.of(context).uri.queryParameters['filter'];
        if (paramFilter != null && paramFilter.isNotEmpty) {
          _filter = paramFilter;
        }
      } catch (_) {}
    }
  }

  @override
  void didUpdateWidget(covariant TelegramConversationListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.unreadOnly != widget.unreadOnly && widget.unreadOnly) {
      _filter = 'unread';
    }
  }

  static String _timeLabel(DateTime dt) => Dates.chatListLabelVi(dt);

  void _openNewMessageSheet(List<ConversationSummary> conversations) {
    final currentUser = ref.read(authControllerProvider).value;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NewMessageSheet(
        conversations: conversations,
        currentUser: currentUser,
        onOpenConversation: (conversation) {
          Navigator.pop(context);
          context.push('/chat/${conversation.id}');
        },
        onCreateGroup: () {
          Navigator.pop(context);
          _openNewGroupSheet();
        },
      ),
    );
  }

  Future<void> _openNewGroupSheet() async {
    final channelId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _NewGroupSheet(),
    );
    if (!mounted || channelId == null) return;
    ref.invalidate(conversationsProvider);
    context.push('/chat/$channelId');
  }

  @override
  Widget build(BuildContext context) {
    final conversations = ref.watch(conversationsProvider);

    return AppScaffold(
      title: 'Trò chuyện',
      showAppBar: false,
      wrapSafeArea: false,
      body: ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: SafeArea(
          child: conversations.when(
            data: (list) {
              final currentUser = ref.watch(authControllerProvider).value;
              final unreadTotal = list.where((c) => c.unreadCount > 0).length;
              final groupTotal = list.where((c) => c.isGroup).length;
              final directTotal = list.where((c) => !c.isGroup).length;

              final filtered = list.where((conversation) {
                if (conversation.lastMessage == null) return false;

                if (_filter == 'unread' && conversation.unreadCount <= 0) return false;
                if (_filter == 'group' && !conversation.isGroup) return false;
                if (_filter == 'direct' && conversation.isGroup) return false;

                final preview = conversation.lastMessage?.content ?? '';
                final title = _conversationTitleForCurrentUser(
                  conversation,
                  currentUser,
                );
                final haystack = '$title $preview'.toLowerCase();
                return haystack.contains(_query.toLowerCase());
              }).toList()..sort(_compareConversationsByLatestMessage);

              return Column(
                children: [
                  _BalancedTelegramChatHeader(
                    onNewChat: () => _openNewMessageSheet(
                      List<ConversationSummary>.of(list)
                        ..sort(_compareConversationsByLatestMessage),
                    ),
                  ),
                  _TelegramSearchBar(
                    query: _query,
                    onChanged: (value) => setState(() => _query = value),
                    onClear: () {
                      setState(() => _query = '');
                      HapticFeedback.lightImpact();
                    },
                  ),
                  _TelegramChatFilterBar(
                    filter: _filter,
                    totalCount: list.length,
                    unreadCount: unreadTotal,
                    groupCount: groupTotal,
                    directCount: directTotal,
                    onSelectFilter: (newFilter) {
                      setState(() => _filter = newFilter);
                      HapticFeedback.selectionClick();
                    },
                  ),
                  Expanded(
                    child: filtered.isEmpty
                        ? _TelegramEmptyChats(
                            message: _filter == 'unread'
                                ? 'Không có tin nhắn chưa đọc'
                                : (_filter == 'group'
                                    ? 'Chưa có nhóm chat nào'
                                    : (_filter == 'direct'
                                        ? 'Chưa có cuộc trò chuyện trực tiếp nào'
                                        : 'Chưa có cuộc trò chuyện')),
                          )
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
                                final title = _conversationTitleForCurrentUser(
                                  conversation,
                                  currentUser,
                                );
                                return _TelegramConversationRow(
                                  conversation: conversation,
                                  title: title,
                                  preview:
                                      conversation.lastMessage?.content ??
                                      'Chưa có tin nhắn',
                                  timeLabel: _timeLabel(
                                    _latestConversationTime(conversation),
                                  ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF5F5F5),
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
            color: Theme.of(context).colorScheme.onSurface,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return PressableScale(
      onTap: onTap,
      child: Container(
        width: 72,
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF5F5F5),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF0F3F8),
          borderRadius: BorderRadius.circular(14),
        ),
        child: TextField(
          onChanged: onChanged,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 16,
          ),

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

class _TelegramChatFilterBar extends StatelessWidget {
  const _TelegramChatFilterBar({
    required this.filter,
    required this.totalCount,
    required this.unreadCount,
    required this.groupCount,
    required this.directCount,
    required this.onSelectFilter,
  });

  final String? filter;
  final int totalCount;
  final int unreadCount;
  final int groupCount;
  final int directCount;
  final ValueChanged<String> onSelectFilter;

  @override
  Widget build(BuildContext context) {
    final activeFilter = (filter == null || filter!.isEmpty) ? 'all' : filter!;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 6),
      child: Row(
        children: [
          _TelegramFilterChipPill(
            label: 'Tất cả',
            count: totalCount,
            selected: activeFilter == 'all',
            onTap: () => onSelectFilter('all'),
          ),
          const SizedBox(width: 8),
          _TelegramFilterChipPill(
            label: 'Chưa đọc',
            count: unreadCount,
            selected: activeFilter == 'unread',
            accentColor: AppColors.danger,
            onTap: () => onSelectFilter('unread'),
          ),
          const SizedBox(width: 8),
          _TelegramFilterChipPill(
            label: 'Nhóm',
            count: groupCount,
            selected: activeFilter == 'group',
            accentColor: AppColors.chat,
            onTap: () => onSelectFilter('group'),
          ),
          const SizedBox(width: 8),
          _TelegramFilterChipPill(
            label: 'Trực tiếp',
            count: directCount,
            selected: activeFilter == 'direct',
            accentColor: AppColors.primary,
            onTap: () => onSelectFilter('direct'),
          ),
        ],
      ),
    );
  }
}

class _TelegramFilterChipPill extends StatelessWidget {
  const _TelegramFilterChipPill({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    this.accentColor,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final activeColor = accentColor ?? AppColors.chat;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PressableScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.soft(activeColor)
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF0F3F8)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? activeColor
                : (isDark ? Colors.white.withValues(alpha: 0.12) : AppColors.border),
            width: selected ? 1.5 : 1.0,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.18),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              Icon(LucideIcons.check, size: 14, color: activeColor),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                color: selected ? activeColor : AppColors.textPrimary,
                fontSize: 13,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: selected
                      ? activeColor
                      : (isDark ? Colors.white12 : AppColors.border),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count > 99 ? '99+' : count.toString(),
                  style: TextStyle(
                    color: selected ? Colors.white : AppColors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NewMessageSheet extends ConsumerStatefulWidget {
  const _NewMessageSheet({
    required this.conversations,
    required this.currentUser,
    required this.onOpenConversation,
    required this.onCreateGroup,
  });

  final List<ConversationSummary> conversations;
  final AuthUser? currentUser;
  final ValueChanged<ConversationSummary> onOpenConversation;
  final VoidCallback onCreateGroup;

  @override
  ConsumerState<_NewMessageSheet> createState() => _NewMessageSheetState();
}

class _NewMessageSheetState extends ConsumerState<_NewMessageSheet> {
  String _query = '';
  bool _busy = false;

  Future<void> _openDirect(Profile user) async {
    final partnerId = user.partnerId;
    if (partnerId == null) return;

    setState(() => _busy = true);
    try {
      final channelId = await ref
          .read(conversationActionsProvider)
          .openDirect(partnerId);
      ref.invalidate(conversationsProvider);
      if (!mounted) return;
      Navigator.pop(context);
      context.push('/chat/$channelId');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Failure: ', '')),
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
    final normalizedQuery = _query.trim();
    final userResults = normalizedQuery.isEmpty
        ? null
        : ref.watch(_userSearchProvider(normalizedQuery));
    final filtered = widget.conversations.where((conversation) {
      if (conversation.lastMessage == null) return false;
      final preview = conversation.lastMessage?.content ?? '';
      final title = _conversationTitleForCurrentUser(
        conversation,
        widget.currentUser,
      );
      final haystack = '$title $preview'.toLowerCase();
      return haystack.contains(_query.toLowerCase());
    }).toList()..sort(_compareConversationsByLatestMessage);

    return SafeArea(
      top: false,
      child: Container(
        height: MediaQuery.sizeOf(context).height * 0.78,
        margin: const EdgeInsets.only(top: 56),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
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
            _NewMessageActionRow(
              icon: LucideIcons.users,
              label: 'Nhóm mới',
              onTap: widget.onCreateGroup,
            ),
            const _NewMessageActionRow(
              icon: LucideIcons.userPlus,
              label: 'Liên hệ mới',
            ),
            const _NewMessageActionRow(
              icon: LucideIcons.megaphone,
              label: 'Kênh mới',
            ),
            if (userResults != null) ...[
              Expanded(
                child: userResults.when(
                  loading: () => const LoadingView(),
                  error: (error, _) => ErrorView(
                    error: error,
                    onRetry: () =>
                        ref.invalidate(_userSearchProvider(normalizedQuery)),
                  ),
                  data: (users) {
                    final currentUserId = widget.currentUser?.id;
                    final others = users
                        .where((user) => user.id != currentUserId)
                        .toList();
                    if (others.isEmpty) {
                      return const Center(
                        child: Text(
                          'Không tìm thấy người dùng nội bộ',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.only(bottom: 18),
                      itemCount: others.length,
                      separatorBuilder: (_, _) => const Padding(
                        padding: EdgeInsets.only(left: 88),
                        child: Divider(height: 1, color: AppColors.border),
                      ),
                      itemBuilder: (context, index) => _NewMessageUserRow(
                        user: others[index],
                        busy: _busy,
                        onTap: () => _openDirect(others[index]),
                      ),
                    );
                  },
                ),
              ),
            ] else if (filtered.isNotEmpty) ...[
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
                    final title = _conversationTitleForCurrentUser(
                      conversation,
                      widget.currentUser,
                    );
                    return _NewMessageConversationRow(
                      conversation: conversation,
                      title: title,
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
  const _NewMessageActionRow({
    required this.icon,
    required this.label,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap:
          onTap ??
          () {
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

class _NewGroupSheet extends ConsumerStatefulWidget {
  const _NewGroupSheet();

  @override
  ConsumerState<_NewGroupSheet> createState() => _NewGroupSheetState();
}

class _NewGroupSheetState extends ConsumerState<_NewGroupSheet> {
  final TextEditingController _name = TextEditingController();
  final Set<String> _selected = <String>{};
  String _query = '';
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _createGroup() async {
    if (_busy || _name.text.trim().isEmpty || _selected.length < 2) return;
    setState(() => _busy = true);
    try {
      final id = await ref
          .read(conversationActionsProvider)
          .createGroup(_name.text.trim(), _selected.toList());
      if (mounted) Navigator.pop(context, id);
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
    final users = ref.watch(_allUsersProvider);
    final currentUserId = ref.read(authControllerProvider).value?.id;
    final canCreate =
        !_busy && _name.text.trim().isNotEmpty && _selected.length >= 2;

    return SafeArea(
      top: false,
      child: Container(
        height: MediaQuery.sizeOf(context).height * 0.86,
        margin: const EdgeInsets.only(top: 42),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            _NewGroupHeader(selectedCount: _selected.length),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 4, 24, 10),
              child: _NewGroupNameField(
                controller: _name,
                onChanged: (_) => setState(() {}),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: _NewGroupSearchField(
                query: _query,
                onChanged: (value) => setState(() => _query = value),
                onClear: () => setState(() => _query = ''),
              ),
            ),
            Expanded(
              child: users.when(
                data: (list) {
                  final query = _query.trim().toLowerCase();
                  final people = list.where((user) {
                    if (user.id == currentUserId) return false;
                    if (query.isEmpty) return true;
                    final haystack = '${user.displayName} ${user.email}'
                        .toLowerCase();
                    return haystack.contains(query);
                  }).toList();
                  if (people.isEmpty) {
                    return const Center(
                      child: Text(
                        'Không tìm thấy thành viên',
                        style: TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: people.length,
                    separatorBuilder: (_, _) => const Padding(
                      padding: EdgeInsets.only(left: 92),
                      child: Divider(height: 1, color: AppColors.border),
                    ),
                    itemBuilder: (context, index) {
                      final user = people[index];
                      final selected = _selected.contains(user.id);
                      return _NewGroupMemberRow(
                        user: user,
                        selected: selected,
                        enabled: !_busy,
                        onTap: () {
                          setState(() {
                            if (selected) {
                              _selected.remove(user.id);
                            } else {
                              _selected.add(user.id);
                            }
                          });
                        },
                      );
                    },
                  );
                },
                loading: () => const LoadingView(),
                error: (e, _) => ErrorView(
                  error: e,
                  onRetry: () => ref.invalidate(_allUsersProvider),
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 10, 24, 18),
                child: GradientButton(
                  label: 'Tạo nhóm',
                  icon: LucideIcons.users,
                  loading: _busy,
                  gradient: AppColors.chatGrad,
                  glowColor: AppColors.chat,
                  onPressed: canCreate ? _createGroup : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NewGroupHeader extends StatelessWidget {
  const _NewGroupHeader({required this.selectedCount});

  final int selectedCount;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 78,
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
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Tạo nhóm mới',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  selectedCount == 0
                      ? 'Chọn ít nhất 2 thành viên'
                      : 'Đã chọn $selectedCount thành viên',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
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

class _NewGroupNameField extends StatelessWidget {
  const _NewGroupNameField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: const Color(0xFFF0F3F8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        decoration: const InputDecoration(
          hintText: 'Tên nhóm',
          hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 16),
          prefixIcon: Icon(
            LucideIcons.users,
            color: AppColors.textMuted,
            size: 21,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }
}

class _NewGroupSearchField extends StatelessWidget {
  const _NewGroupSearchField({
    required this.query,
    required this.onChanged,
    required this.onClear,
  });

  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(15),
      ),
      child: TextField(
        onChanged: onChanged,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
        decoration: InputDecoration(
          hintText: 'Tìm thành viên',
          hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 15),
          prefixIcon: const Icon(
            LucideIcons.search,
            color: AppColors.textMuted,
            size: 20,
          ),
          suffixIcon: query.isEmpty
              ? null
              : IconButton(
                  onPressed: onClear,
                  icon: const Icon(LucideIcons.x, size: 18),
                ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 13),
        ),
      ),
    );
  }
}

class _NewGroupMemberRow extends StatelessWidget {
  const _NewGroupMemberRow({
    required this.user,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final Profile user;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = user.displayName.isNotEmpty
        ? user.displayName
        : user.email.split('@').first;
    return PressableScale(
      onTap: enabled ? onTap : null,
      scale: 0.99,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 9, 24, 9),
        child: Row(
          children: [
            UserAvatar(
              userId: user.id,
              displayName: name,
              email: user.email,
              avatarUrl: user.avatarUrl,
              size: 50,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
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
                    user.email,
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
            const SizedBox(width: 12),
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? AppColors.primary : Colors.transparent,
                border: Border.all(
                  color: selected ? AppColors.primary : AppColors.border,
                  width: 2,
                ),
              ),
              child: selected
                  ? const Icon(LucideIcons.check, color: Colors.white, size: 16)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _NewMessageUserRow extends StatelessWidget {
  const _NewMessageUserRow({
    required this.user,
    required this.busy,
    required this.onTap,
  });

  final Profile user;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final name = user.displayName.isNotEmpty
        ? user.displayName
        : user.email.split('@').first;
    return PressableScale(
      onTap: busy || user.partnerId == null ? null : onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 10, 24, 10),
        child: Row(
          children: [
            UserAvatar(
              userId: user.id,
              displayName: name,
              email: user.email,
              avatarUrl: user.avatarUrl,
              size: 50,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (user.email.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      user.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (busy)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              const Icon(
                LucideIcons.messageCircle,
                color: AppColors.primary,
                size: 22,
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
    required this.title,
    required this.onTap,
  });

  final ConversationSummary conversation;
  final String title;
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
            UserAvatar(
              userId: conversation.id,
              displayName: title,
              avatarUrl: conversation.avatarUrl,
              isGroup: conversation.isGroup,
              size: 48,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
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
    required this.title,
    required this.preview,
    required this.timeLabel,
    required this.onTap,
  });

  final ConversationSummary conversation;
  final String title;
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
            UserAvatar(
              userId: conversation.id,
              displayName: title,
              avatarUrl: conversation.avatarUrl,
              isGroup: conversation.isGroup,
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
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? AppColors.darkTextPrimary
                                : AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            height: 1.15,
                          ),
                        ),
                      ),
                      if (timeLabel.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          timeLabel,
                          style: TextStyle(
                            color: Theme.of(context).brightness == Brightness.dark
                                ? AppColors.darkTextSecondary
                                : AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          preview,
                          maxLines: 1,
                          softWrap: false,
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



class _TelegramEmptyChats extends StatelessWidget {
  const _TelegramEmptyChats({this.message = 'Chưa có cuộc trò chuyện'});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        style: const TextStyle(
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
    required this.title,
    required this.preview,
    required this.timeLabel,
    required this.onTap,
  });

  final ConversationSummary conversation;
  final String title;
  final String preview;
  final String timeLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = Theme.of(context).colorScheme.onSurface;
    final secondaryTextColor = isDark ? AppColors.darkTextMuted : AppColors.textSecondary;
    final c = conversation;
    final unreadCount = c.unreadCount;
    return PressableScale(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: unreadCount > 0
              ? (isDark
                  ? AppColors.chat.withValues(alpha: 0.25)
                  : AppColors.featureBackgroundStrong(AppColors.chat))
              : (isDark ? const Color(0xFF1E293B) : AppColors.surface),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: unreadCount > 0
                ? AppColors.chat.withValues(alpha: 0.4)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : AppColors.border.withValues(alpha: 0.7)),
            width: unreadCount > 0 ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: unreadCount > 0
                  ? AppColors.chat.withValues(alpha: 0.1)
                  : Colors.black.withValues(alpha: 0.03),
              blurRadius: unreadCount > 0 ? 10 : 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),

        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                UserAvatar(
                  userId: c.id,
                  displayName: title,
                  avatarUrl: c.avatarUrl,
                  isGroup: c.isGroup,
                  size: 52,
                ),
                if (unreadCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 13,
                      height: 13,
                      decoration: BoxDecoration(
                        color: AppColors.danger,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).cardColor,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
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
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: unreadCount > 0
                              ? FontWeight.w800
                              : FontWeight.w600,
                          fontSize: 15,
                          color: primaryTextColor,
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
                          ? primaryTextColor
                          : secondaryTextColor,
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



/// Provider for all users (used in new chat sheet).
final _allUsersProvider = FutureProvider.autoDispose<List<Profile>>((
  ref,
) async {
  final repo = ref.read(chatRepositoryProvider);
  return repo.allUsers();
});

final _userSearchProvider = FutureProvider.autoDispose
    .family<List<Profile>, String>((ref, query) async {
      final repo = ref.read(chatRepositoryProvider);
      return repo.searchUsers(query);
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

  Future<void> _open(String partnerId) async {
    setState(() => _busy = true);
    try {
      final id = await ref
          .read(conversationActionsProvider)
          .openDirect(partnerId);
      ref.invalidate(conversationsProvider);
      if (mounted) {
        Navigator.pop(context);
        context.push('/chat/$id');
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

  Future<void> _createGroup(String name, List<String> memberIds) async {
    setState(() => _busy = true);
    try {
      final id = await ref
          .read(conversationActionsProvider)
          .createGroup(name, memberIds);
      ref.invalidate(conversationsProvider);
      if (mounted) {
        Navigator.pop(context);
        context.push('/chat/$id');
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
                _GroupTab(busy: _busy, onCreate: _createGroup),
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
    final users =
        ref.watch(_userSearchProvider(_searchQuery.trim())).value ?? [];
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
                    return Material(
                      type: MaterialType.transparency,
                      child: ListTile(
                        leading: UserAvatar(
                          userId: u.id,
                          displayName: name,
                          email: u.email,
                          avatarUrl: u.avatarUrl,
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
                        onTap: widget.busy || u.partnerId == null
                            ? null
                            : () => widget.onOpen(u.partnerId!),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _GroupTab extends ConsumerStatefulWidget {
  const _GroupTab({required this.busy, required this.onCreate});

  final bool busy;
  final Future<void> Function(String name, List<String> memberIds) onCreate;

  @override
  ConsumerState<_GroupTab> createState() => _GroupTabState();
}

class _GroupTabState extends ConsumerState<_GroupTab> {
  final _name = TextEditingController();
  final Set<String> _selected = <String>{};

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final users = ref.watch(_allUsersProvider);
    return users.when(
      data: (list) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _name,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Tên nhóm',
                prefixIcon: const Icon(
                  LucideIcons.users,
                  color: AppColors.textMuted,
                ),
                filled: true,
                fillColor: AppColors.bg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: list.length,
              itemBuilder: (_, index) {
                final user = list[index];
                final selected = _selected.contains(user.id);
                return CheckboxListTile(
                  value: selected,
                  onChanged: widget.busy
                      ? null
                      : (value) {
                          setState(() {
                            if (value == true) {
                              _selected.add(user.id);
                            } else {
                              _selected.remove(user.id);
                            }
                          });
                        },
                  secondary: UserAvatar(
                    userId: user.id,
                    displayName: user.displayName,
                    email: user.email,
                    avatarUrl: user.avatarUrl,
                  ),
                  title: Text(user.displayName),
                  subtitle: Text(user.email),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: GradientButton(
                label: 'Tạo nhóm',
                icon: LucideIcons.users,
                loading: widget.busy,
                gradient: AppColors.chatGrad,
                glowColor: AppColors.chat,
                onPressed:
                    widget.busy ||
                        _name.text.trim().isEmpty ||
                        _selected.isEmpty
                    ? null
                    : () => widget.onCreate(
                        _name.text.trim(),
                        _selected.toList(),
                      ),
              ),
            ),
          ),
        ],
      ),
      loading: () => const LoadingView(),
      error: (e, _) =>
          ErrorView(error: e, onRetry: () => ref.invalidate(_allUsersProvider)),
    );
  }
}

String _stripHtml(String input) {
  if (input.isEmpty) return '';
  final stripped = input.replaceAll(RegExp(r'<[^>]*>'), '');
  return stripped
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&nbsp;', ' ')
      .trim();
}

class _ChatFilterChip extends StatelessWidget {
  const _ChatFilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    this.accentColor,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final activeColor = accentColor ?? AppColors.chat;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.soft(activeColor)
              : (isDark ? const Color(0xFF1E293B) : AppColors.surface),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? activeColor
                : (isDark ? Colors.white.withValues(alpha: 0.12) : AppColors.border),
            width: selected ? 1.5 : 1.0,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.18),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? activeColor : AppColors.textPrimary,
                fontSize: 13,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: selected
                      ? activeColor
                      : (isDark ? Colors.white12 : AppColors.border),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count > 99 ? '99+' : count.toString(),
                  style: TextStyle(
                    color: selected ? Colors.white : AppColors.textSecondary,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
