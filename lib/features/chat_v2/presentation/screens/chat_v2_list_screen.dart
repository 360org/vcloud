import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../data/chat_v2_repository.dart';

import '../../../../core/utils/date_format.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../auth/application/auth_controller.dart';
import '../../application/chat_v2_channels_controller.dart';
import '../../application/chat_v2_messages_controller.dart';
import '../../application/chat_v2_read_state_controller.dart';
import '../../data/models/chat_v2_channel.dart';

class ChatV2ListScreen extends ConsumerStatefulWidget {
  const ChatV2ListScreen({super.key, this.initialFilter});

  final String? initialFilter;

  @override
  ConsumerState<ChatV2ListScreen> createState() => _ChatV2ListScreenState();
}

class _ChatV2ListScreenState extends ConsumerState<ChatV2ListScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';
  int? _selectedFilterIndex; // null: Mặc định (Tất cả), 0: Chưa đọc, 1: Nội bộ, 2: Nhóm, 3: Kênh
  Timer? _searchDebounceTimer;

  final List<String> _filters = ['Chưa đọc', 'Nội bộ', 'Nhóm', 'Kênh'];

  int? _resolveFilterIndex(String? filter) {
    if (filter == null || filter.isEmpty || filter == 'all' || filter == 'tatca') return null;
    if (filter == 'unread' || filter == 'chuadoc') return 0;
    if (filter == 'internal' || filter == 'noibo' || filter == 'direct' || filter == 'dm' || filter == 'canhan' || filter == 'tructiep') return 1;
    if (filter == 'group' || filter == 'nhom') return 2;
    if (filter == 'channel' || filter == 'kenh') return 3;
    return null;
  }

  void _onSearchChanged(String val) {
    final query = val.trim().toLowerCase();
    setState(() => _searchQuery = query);

    _searchDebounceTimer?.cancel();
    if (query.isNotEmpty) {
      _searchDebounceTimer = Timer(const Duration(milliseconds: 350), () async {
        try {
          final results = await ref.read(chatV2RepositoryProvider).getChannels(
                search: query,
                limit: 50,
              );
          if (mounted && results.isNotEmpty) {
            final current = List<ChatV2Channel>.from(ChatV2ChannelLocalCache.cached);
            final existingIds = current.map((c) => c.id).toSet();
            final toAdd = results.where((c) => !existingIds.contains(c.id)).toList();
            if (toAdd.isNotEmpty) {
              ChatV2ChannelLocalCache.set([...current, ...toAdd]);
            }
          }
        } catch (_) {}
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _selectedFilterIndex = _resolveFilterIndex(widget.initialFilter);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      ref.read(chatV2ChannelsProvider.notifier).loadMore();
    }
  }

  @override
  void didUpdateWidget(covariant ChatV2ListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialFilter != oldWidget.initialFilter) {
      setState(() {
        _selectedFilterIndex = _resolveFilterIndex(widget.initialFilter);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final channelsAsync = ref.watch(chatV2ChannelsProvider);
    final currentUser = ref.watch(authControllerProvider).valueOrNull;
    final meta = currentUser?.userMetadata;
    final currentUserName = (meta?['name'] ??
            meta?['display_name'] ??
            meta?['partner_name'] ??
            meta?['partner']?['name']) as String?;
    final currentPartnerId = meta?['partner_id']?.toString() ??
        meta?['partner']?['id']?.toString();
    final currentUserId = currentUser?.id;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppScaffold(
      title: 'Trò chuyện',
      showAppBar: false,
      body: Column(
        children: [
          // ── 1. Top Header ───────────────────────────────────────────────
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 10,
              left: 20,
              right: 16,
              bottom: 12,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : const Color(0xFFE2E8F0),
                  width: 0.8,
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Trò chuyện',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                          letterSpacing: -0.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Material(
                      color: const Color(0xFF00C83A),
                      shape: const CircleBorder(),
                      elevation: 1,
                      shadowColor:
                          const Color(0xFF00C83A).withValues(alpha: 0.4),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => context.push('/chat/new'),
                        child: const Padding(
                          padding: EdgeInsets.all(10),
                          child: Icon(
                            LucideIcons.messageSquarePlus,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // ── 2. Search & Filter Bar ───────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 42,
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF0F172A)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                            width: 0.8,
                          ),
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: _onSearchChanged,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                          decoration: InputDecoration(
                            hintText: 'Tìm kiếm cuộc trò chuyện...',
                            hintStyle: TextStyle(
                              fontSize: 14,
                              color: isDark
                                  ? Colors.white38
                                  : const Color(0xFF94A3B8),
                            ),
                            prefixIcon: Icon(
                              LucideIcons.search,
                              size: 18,
                              color: isDark
                                  ? Colors.white54
                                  : const Color(0xFF94A3B8),
                            ),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(LucideIcons.x, size: 16),
                                    color: isDark
                                        ? Colors.white54
                                        : const Color(0xFF94A3B8),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // ── Nút Filter Icon ─────────────────────────────────────
                    channelsAsync.maybeWhen(
                      data: (channels) {
                        final unreadCount = ref.watch(chatV2TotalUnreadProvider);
                        final internalCount = channels
                            .where((c) => c.isInternalDirect(currentUserName))
                            .length;
                        final groupCount = channels
                            .where((c) => c.isGroupChat(currentUserName))
                            .length;
                        final channelCount = channels
                            .where((c) => c.isChannel)
                            .length;
                        final counts = [unreadCount, internalCount, groupCount, channelCount];
                        final isFilterActive = _selectedFilterIndex != null;

                        return Material(
                          color: isFilterActive
                              ? const Color(0xFF00C83A)
                              : (isDark
                                  ? const Color(0xFF0F172A)
                                  : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(14),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => _showFilterSheet(
                              context: context,
                              channels: channels,
                              counts: counts,
                              currentUserName: currentUserName,
                            ),
                            child: Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isFilterActive
                                      ? Colors.transparent
                                      : (isDark
                                          ? Colors.white10
                                          : const Color(0xFFE2E8F0)),
                                  width: 0.8,
                                ),
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Icon(
                                    LucideIcons.slidersHorizontal,
                                    size: 19,
                                    color: isFilterActive
                                        ? Colors.white
                                        : (isDark
                                            ? Colors.white70
                                            : const Color(0xFF475569)),
                                  ),
                                  if (isFilterActive)
                                    Positioned(
                                      top: 8,
                                      right: 8,
                                      child: Container(
                                        width: 7,
                                        height: 7,
                                        decoration: const BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                      orElse: () => Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF0F172A)
                              : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark
                                ? Colors.white10
                                : const Color(0xFFE2E8F0),
                            width: 0.8,
                          ),
                        ),
                        child: Icon(
                          LucideIcons.slidersHorizontal,
                          size: 19,
                          color: isDark
                              ? Colors.white38
                              : const Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ],
                ),
                // ── 3. Active Filter Mini Indicator (khi đang lọc) ──────────
                if (_selectedFilterIndex != null) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF00C83A).withValues(alpha: 0.18)
                              : const Color(0xFFE8F9EE),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFF00C83A).withValues(alpha: 0.35),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              LucideIcons.filter,
                              size: 12,
                              color: Color(0xFF00C83A),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              'Đang lọc: ${_filters[_selectedFilterIndex!]}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF00C83A),
                              ),
                            ),
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: () =>
                                  setState(() => _selectedFilterIndex = null),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00C83A).withValues(alpha: 0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  LucideIcons.x,
                                  size: 11,
                                  color: Color(0xFF00C83A),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // ── 4. Channels List ────────────────────────────────────────────
          Expanded(
            child: RefreshIndicator(
              color: const Color(0xFF00C83A),
              onRefresh: () async => ref.refresh(chatV2ChannelsProvider.future),
              child: channelsAsync.when(
                skipLoadingOnReload: true,
                loading: () => const Center(
                  child: CircularProgressIndicator(color: Color(0xFF00C83A)),
                ),
                error: (error, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(LucideIcons.alertCircle,
                            size: 44, color: Colors.redAccent),
                        const SizedBox(height: 12),
                        Text(
                          'Không thể tải danh sách hội thoại',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color:
                                isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          error.toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              fontSize: 13, color: Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => ref.refresh(chatV2ChannelsProvider),
                          icon: const Icon(LucideIcons.rotateCw, size: 16),
                          label: const Text('Thử lại'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00C83A),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                data: (channels) {
                  // Lọc theo search query và filter index
                  final filtered = channels.where((c) {
                    final cleanName = c.getCleanName(currentUserName);

                    if (_searchQuery.isNotEmpty) {
                      final q = _searchQuery.replaceAll('#', '').trim().toLowerCase();
                      final matchCleanName = cleanName.replaceAll('#', '').toLowerCase().contains(q);
                      final matchRawName = c.name.replaceAll('#', '').toLowerCase().contains(q);
                      final matchMsg = (c.lastMessage ?? '').toLowerCase().contains(q);
                      final matchMembers = c.memberNames.any((m) => m.toLowerCase().contains(q));
                      final matchDirect = (c.directPartnerName ?? '').toLowerCase().contains(q);

                      if (!matchCleanName && !matchRawName && !matchMsg && !matchMembers && !matchDirect) {
                        return false;
                      }
                    }
                    if (_selectedFilterIndex == 0) {
                      // 0: Chưa đọc
                      final cachedMsgs = ChatV2MessageLocalCache.get(c.id);
                      final isFirstMsgMine = cachedMsgs != null &&
                          cachedMsgs.isNotEmpty &&
                          cachedMsgs.first.isMine;
                      final lastSentText = ref.watch(
                          chatV2LastSentTrackerProvider.select((m) => m[c.id]));
                      final isMineFromTracker = lastSentText != null &&
                          (c.lastMessage != null &&
                              c.lastMessage!.trim() == lastSentText.trim());

                      final isMine = isFirstMsgMine ||
                          isMineFromTracker ||
                          c.isLastMessageFromMe(
                            currentUserName: currentUserName,
                            currentPartnerId: currentPartnerId,
                            currentUserId: currentUserId,
                          );

                      // Nếu tin nhắn cuối do chính mình gửi -> Chắc chắn KHÔNG nằm trong tab Chưa đọc
                      if (isMine) return false;

                      final readNotifier =
                          ref.watch(chatV2ReadStateProvider.notifier);
                      final isUnread = readNotifier.isChannelUnread(
                        channelId: c.id,
                        serverUnreadCount: c.unreadCount,
                        lastMessageDate: c.lastMessageDate,
                      );
                      if (!isUnread) return false;
                    } else if (_selectedFilterIndex == 1) {
                      // 1: Nội bộ (1-1 trực tiếp)
                      if (!c.isInternalDirect(currentUserName)) {
                        return false;
                      }
                    } else if (_selectedFilterIndex == 2) {
                      // 2: Nhóm
                      if (!c.isGroupChat(currentUserName)) {
                        return false;
                      }
                    } else if (_selectedFilterIndex == 3) {
                      // 3: Kênh
                      if (!c.isChannel) {
                        return false;
                      }
                    }
                    return true;
                  }).toList();

                  // Sắp xếp các đoạn chat: Cuộc trò chuyện có hoạt động mới nhất lên đầu tiên
                  filtered.sort((a, b) {
                    if (a.lastMessageDate == null && b.lastMessageDate == null) {
                      final aId = int.tryParse(a.id) ?? 0;
                      final bId = int.tryParse(b.id) ?? 0;
                      return bId.compareTo(aId);
                    }
                    if (a.lastMessageDate == null) return 1;
                    if (b.lastMessageDate == null) return -1;
                    return b.lastMessageDate!.compareTo(a.lastMessageDate!);
                  });

                  if (filtered.isEmpty) {
                    final String emptyMessage;
                    if (_searchQuery.isNotEmpty) {
                      emptyMessage = 'Không tìm thấy cuộc trò chuyện nào';
                    } else if (_selectedFilterIndex == 0) {
                      emptyMessage = 'Không có tin nhắn chưa đọc';
                    } else if (_selectedFilterIndex == 1) {
                      emptyMessage = 'Chưa có cuộc trò chuyện nội bộ nào';
                    } else if (_selectedFilterIndex == 2) {
                      emptyMessage = 'Chưa có nhóm trò chuyện nào';
                    } else if (_selectedFilterIndex == 3) {
                      emptyMessage = 'Chưa có kênh thảo luận nào';
                    } else {
                      emptyMessage = 'Chưa có cuộc trò chuyện nào';
                    }

                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        SizedBox(
                            height: MediaQuery.of(context).size.height * 0.18),
                        Center(
                          child: Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white10
                                  : const Color(0xFFF1F5F9),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              LucideIcons.messageSquareDashed,
                              size: 32,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          emptyMessage,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : const Color(0xFF64748B),
                          ),
                        ),
                        if (_searchQuery.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Center(
                            child: TextButton(
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                              child: const Text(
                                'Xóa tìm kiếm',
                                style: TextStyle(color: Color(0xFF00C83A)),
                              ),
                            ),
                          ),
                        ],
                      ],
                    );
                  }

                  final channelsNotifier = ref.watch(chatV2ChannelsProvider.notifier);
                  final hasMore = channelsNotifier.hasMore;
                  final isLoadingMore = channelsNotifier.isLoadingMore;
                  final isFiltered = _searchQuery.isNotEmpty || _selectedFilterIndex != null;

                  return ListView.separated(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    addRepaintBoundaries: true,
                    addAutomaticKeepAlives: false,
                    itemCount: filtered.length + ((!isFiltered && (isLoadingMore || (!hasMore && filtered.length >= 40))) ? 1 : 0),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      indent: 76,
                      endIndent: 16,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : const Color(0xFFE2E8F0).withValues(alpha: 0.7),
                    ),
                    itemBuilder: (context, index) {
                      if (index == filtered.length) {
                        if (isLoadingMore) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00C83A)),
                                ),
                              ),
                            ),
                          );
                        }
                        if (!hasMore) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Text(
                                'Đã hiển thị tất cả cuộc trò chuyện (${filtered.length})',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                                ),
                              ),
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      }

                      final channel = filtered[index];
                      return _ChannelListItem(
                        key: ValueKey(channel.id),
                        channel: channel,
                        currentUserName: currentUserName,
                        currentPartnerId: currentPartnerId,
                        currentUserId: currentUserId,
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterSheet({
    required BuildContext context,
    required List<ChatV2Channel> channels,
    required List<int> counts,
    required String? currentUserName,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag Handle
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Sheet Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00C83A).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            LucideIcons.slidersHorizontal,
                            size: 18,
                            color: Color(0xFF00C83A),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Lọc cuộc trò chuyện',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                    if (_selectedFilterIndex != null)
                      TextButton(
                        onPressed: () {
                          setState(() => _selectedFilterIndex = null);
                          Navigator.pop(ctx);
                        },
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                        child: const Text(
                          'Đặt lại',
                          style: TextStyle(
                            color: Color(0xFF00C83A),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else
                      IconButton(
                        icon: Icon(
                          LucideIcons.x,
                          size: 20,
                          color: isDark ? Colors.white60 : const Color(0xFF64748B),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                // Option 1: Tất cả
                _buildFilterOption(
                  ctx: ctx,
                  isDark: isDark,
                  title: 'Tất cả cuộc trò chuyện',
                  subtitle: 'Toàn bộ danh sách trò chuyện',
                  count: channels.length,
                  icon: LucideIcons.messageSquare,
                  iconColor: const Color(0xFF3B82F6),
                  isSelected: _selectedFilterIndex == null,
                  onTap: () {
                    setState(() => _selectedFilterIndex = null);
                    Navigator.pop(ctx);
                  },
                ),
                const SizedBox(height: 8),
                // Option 2: Chưa đọc (index 0)
                _buildFilterOption(
                  ctx: ctx,
                  isDark: isDark,
                  title: 'Chưa đọc',
                  subtitle: 'Tin nhắn mới chưa xem',
                  count: counts[0],
                  icon: LucideIcons.bellRing,
                  iconColor: const Color(0xFFEF4444),
                  isSelected: _selectedFilterIndex == 0,
                  onTap: () {
                    setState(() => _selectedFilterIndex = 0);
                    Navigator.pop(ctx);
                  },
                ),
                const SizedBox(height: 8),
                // Option 3: Nội bộ 1-1 (index 1)
                _buildFilterOption(
                  ctx: ctx,
                  isDark: isDark,
                  title: 'Trò chuyện nội bộ',
                  subtitle: 'Tin nhắn trực tiếp 1-1',
                  count: counts[1],
                  icon: LucideIcons.user,
                  iconColor: const Color(0xFF10B981),
                  isSelected: _selectedFilterIndex == 1,
                  onTap: () {
                    setState(() => _selectedFilterIndex = 1);
                    Navigator.pop(ctx);
                  },
                ),
                const SizedBox(height: 8),
                // Option 4: Nhóm (index 2)
                _buildFilterOption(
                  ctx: ctx,
                  isDark: isDark,
                  title: 'Nhóm trò chuyện',
                  subtitle: 'Nhóm thảo luận nhiều người',
                  count: counts[2],
                  icon: LucideIcons.users,
                  iconColor: const Color(0xFF8B5CF6),
                  isSelected: _selectedFilterIndex == 2,
                  onTap: () {
                    setState(() => _selectedFilterIndex = 2);
                    Navigator.pop(ctx);
                  },
                ),
                const SizedBox(height: 8),
                // Option 5: Kênh (index 3)
                _buildFilterOption(
                  ctx: ctx,
                  isDark: isDark,
                  title: 'Kênh thảo luận',
                  subtitle: 'Kênh phòng ban & dự án',
                  count: counts[3],
                  icon: LucideIcons.hash,
                  iconColor: const Color(0xFFF59E0B),
                  isSelected: _selectedFilterIndex == 3,
                  onTap: () {
                    setState(() => _selectedFilterIndex = 3);
                    Navigator.pop(ctx);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterOption({
    required BuildContext ctx,
    required bool isDark,
    required String title,
    required String subtitle,
    required int count,
    required IconData icon,
    required Color iconColor,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: isSelected
          ? (isDark
              ? const Color(0xFF00C83A).withValues(alpha: 0.15)
              : const Color(0xFFE8F9EE))
          : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF00C83A)
                  : (isDark ? Colors.white10 : const Color(0xFFE2E8F0)),
              width: isSelected ? 1.4 : 0.8,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF00C83A).withValues(alpha: 0.2)
                      : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isSelected
                        ? const Color(0xFF00C83A)
                        : (isDark ? Colors.white70 : const Color(0xFF64748B)),
                  ),
                ),
              ),
              if (isSelected) ...[
                const SizedBox(width: 8),
                const Icon(
                  LucideIcons.check,
                  color: Color(0xFF00C83A),
                  size: 18,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ChannelListItem extends ConsumerWidget {
  final ChatV2Channel channel;
  final String? currentUserName;
  final String? currentPartnerId;
  final String? currentUserId;

  const _ChannelListItem({
    super.key,
    required this.channel,
    required this.currentUserName,
    this.currentPartnerId,
    this.currentUserId,
  });

  // Bảng màu gradient pastel sinh động phân bổ theo tên người dùng
  static const _avatarGradients = [
    [Color(0xFF3B82F6), Color(0xFF2563EB)], // Blue
    [Color(0xFF10B981), Color(0xFF059669)], // Emerald
    [Color(0xFF8B5CF6), Color(0xFF7C3AED)], // Purple
    [Color(0xFFF59E0B), Color(0xFFD97706)], // Amber
    [Color(0xFFEC4899), Color(0xFFDB2777)], // Pink
    [Color(0xFF06B6D4), Color(0xFF0891B2)], // Cyan
    [Color(0xFFF97316), Color(0xFFEA580C)], // Orange
    [Color(0xFF14B8A6), Color(0xFF0D9488)], // Teal
  ];

  List<Color> _getAvatarGradient(String name) {
    if (name.isEmpty) return _avatarGradients[0];
    final hash = name.codeUnits.fold(0, (acc, c) => acc + c);
    return _avatarGradients[hash % _avatarGradients.length];
  }

  static String _getShortAuthorName(String fullName) {
    final clean = fullName.trim();
    if (clean.isEmpty) return '';
    if (clean.contains(',')) {
      final parts = clean.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      if (parts.isNotEmpty) return parts.first;
    }
    return clean.split(' ').last;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cleanName = channel.getCleanName(currentUserName);
    final isGroup = channel.getActualIsGroup(currentUserName);
    // Kiểm tra tin nhắn cuối từ channel hoặc từ cache tin nhắn
    final cachedMsgs = ChatV2MessageLocalCache.get(channel.id);
    final effectiveLastMsg = (channel.lastMessage != null && channel.lastMessage!.isNotEmpty)
        ? channel.lastMessage
        : (cachedMsgs != null && cachedMsgs.isNotEmpty
            ? (cachedMsgs.first.content.isNotEmpty
                ? cachedMsgs.first.content
                : (cachedMsgs.first.attachments.isNotEmpty ? '[Hình ảnh]' : null))
            : null);

    // Ưu tiên thời gian của tin nhắn thực tế từ cache nếu có
    final effectiveLastDate = (cachedMsgs != null && cachedMsgs.isNotEmpty && cachedMsgs.first.createdAt != null)
        ? cachedMsgs.first.createdAt
        : channel.lastMessageDate;

    final timeStr = effectiveLastDate != null
        ? _formatDate(effectiveLastDate)
        : '';
    final avatarGrad = _getAvatarGradient(cleanName);

    final isFirstMsgMine = cachedMsgs != null && cachedMsgs.isNotEmpty && cachedMsgs.first.isMine;

    // Kiểm tra trạng thái chưa đọc từ ReadState Tracker với provider.select
    final readNotifier = ref.watch(chatV2ReadStateProvider.notifier);
    final lastSentText = ref.watch(chatV2LastSentTrackerProvider.select((m) => m[channel.id]));
    final isMineFromTracker = lastSentText != null &&
        effectiveLastMsg?.trim() == lastSentText.trim();

    final isMine = isFirstMsgMine ||
        isMineFromTracker ||
        channel.isLastMessageFromMe(
          currentUserName: currentUserName,
          currentPartnerId: currentPartnerId,
          currentUserId: currentUserId,
        );

    // Watch riêng trạng thái seen của channel này để tự động cập nhật khi có trạng thái đọc mới
    ref.watch(chatV2ReadStateProvider.select((m) => m[channel.id]));
    final hasUnread = !isMine &&
        effectiveLastMsg != null &&
        effectiveLastMsg.isNotEmpty &&
        readNotifier.isChannelUnread(
          channelId: channel.id,
          serverUnreadCount: channel.unreadCount,
          lastMessageDate: effectiveLastDate,
        );

    return RepaintBoundary(
      child: Material(
        color: hasUnread
            ? (isDark
                ? const Color(0xFF00C83A).withValues(alpha: 0.08)
                : const Color(0xFF00C83A).withValues(alpha: 0.05))
            : Colors.transparent,
        child: InkWell(
          onTap: () {
            ref.read(chatV2ReadStateProvider.notifier).markChannelAsRead(channel.id);
            context.push('/chat/${channel.id}');
          },
          child: Container(
          decoration: BoxDecoration(
            border: hasUnread
                ? const Border(
                    left: BorderSide(
                      color: Color(0xFF00C83A),
                      width: 3.5,
                    ),
                  )
                : null,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: hasUnread ? 12.5 : 16,
            vertical: 11,
          ),
          child: Row(
            children: [
              // Avatar
              Stack(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: avatarGrad,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: avatarGrad[0].withValues(alpha: 0.28),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: ClipOval(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Center(
                            child: Text(
                              cleanName.isNotEmpty
                                  ? cleanName[0].toUpperCase()
                                  : 'C',
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          if (channel.avatarUrl != null &&
                              channel.avatarUrl!.isNotEmpty)
                            Image.network(
                              channel.avatarUrl!,
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                              gaplessPlayback: true,
                              errorBuilder: (context, error, stackTrace) =>
                                  const SizedBox.shrink(),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (isGroup)
                    Positioned(
                      right: -1,
                      bottom: -1,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(2.5),
                          decoration: const BoxDecoration(
                            color: Color(0xFF3B82F6),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            LucideIcons.users,
                            size: 11,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    )
                  else if (channel.imStatus == 'online')
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? const Color(0xFF1E293B) : Colors.white,
                            width: 2.2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),

              // Title & Last message
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            cleanName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight:
                                  hasUnread ? FontWeight.w800 : FontWeight.w600,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        if (timeStr.isNotEmpty)
                          Text(
                            timeStr,
                            style: TextStyle(
                              fontSize: 12,
                              color: hasUnread
                                  ? const Color(0xFF00C83A)
                                  : (isDark
                                      ? Colors.white54
                                      : const Color(0xFF94A3B8)),
                              fontWeight: hasUnread
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: _buildLastMessageSnippet(
                              ref, isDark, hasUnread, cleanName),
                        ),
                        if (hasUnread)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7.5, vertical: 2.5),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFEF4444)
                                      .withValues(alpha: 0.45),
                                  blurRadius: 5,
                                  offset: const Offset(0, 1.5),
                                ),
                              ],
                            ),
                            child: Text(
                              channel.unreadCount > 99
                                  ? '99+'
                                  : (channel.unreadCount > 0
                                      ? channel.unreadCount.toString()
                                      : '1'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                              ),
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

  Widget _buildLastMessageSnippet(
      WidgetRef ref, bool isDark, bool hasUnread, String cleanName) {
    final cachedMsgs = ChatV2MessageLocalCache.get(channel.id);
    final effectiveLastMsg = (channel.lastMessage != null && channel.lastMessage!.isNotEmpty)
        ? channel.lastMessage
        : (cachedMsgs != null && cachedMsgs.isNotEmpty
            ? (cachedMsgs.first.content.isNotEmpty
                ? cachedMsgs.first.content
                : (cachedMsgs.first.attachments.isNotEmpty ? '[Hình ảnh]' : null))
            : null);

    if (effectiveLastMsg == null || effectiveLastMsg.isEmpty) {
      return Text(
        'Nhấn để bắt đầu trò chuyện',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 13.5,
          color: isDark ? Colors.white60 : const Color(0xFF94A3B8),
          fontStyle: FontStyle.italic,
        ),
      );
    }

    final msg = effectiveLastMsg;
    final isFirstMsgMine = cachedMsgs != null && cachedMsgs.isNotEmpty && cachedMsgs.first.isMine;

    // Kiểm tra xem tin nhắn có phải do mình vừa gửi không với provider.select
    final lastSentText = ref.watch(chatV2LastSentTrackerProvider.select((m) => m[channel.id]));
    final isMineFromTracker =
        lastSentText != null && msg.trim() == lastSentText.trim();

    final isMine = isFirstMsgMine ||
        isMineFromTracker ||
        channel.isLastMessageFromMe(
          currentUserName: currentUserName,
          currentPartnerId: currentPartnerId,
          currentUserId: currentUserId,
        );

    // Xác định tiền tố người gửi (Bạn: hoặc Tên người gửi trong nhóm)
    String prefix = '';
    final isGroup = channel.getActualIsGroup(currentUserName);

    if (isMine) {
      prefix = 'Bạn: ';
    } else if (isGroup) {
      String author = '';
      if (channel.lastMessageAuthorName != null &&
          channel.lastMessageAuthorName!.isNotEmpty) {
        author = _getShortAuthorName(channel.lastMessageAuthorName!);
      } else {
        // Kiểm tra từ Local Cache của tin nhắn kênh nếu đã nạp (phần tử .first là tin mới nhất)
        if (cachedMsgs != null && cachedMsgs.isNotEmpty) {
          final lastMsgObj = cachedMsgs.first;
          if (!lastMsgObj.isMine && lastMsgObj.authorName.isNotEmpty) {
            author = _getShortAuthorName(lastMsgObj.authorName);
          }
        }
      }
      if (author.isNotEmpty &&
          author.toLowerCase() != (currentUserName ?? '').toLowerCase()) {
        prefix = '$author: ';
      }
    }

    final lower = msg.toLowerCase().trim();
    final isImageFilename = lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.svg') ||
        lower.endsWith('.bmp') ||
        lower.endsWith('.ico') ||
        lower.endsWith('.heic') ||
        lower.endsWith('.heif') ||
        lower.startsWith('scaled_') ||
        lower.startsWith('image_picker_') ||
        lower == 'hình ảnh' ||
        lower == '[hình ảnh]' ||
        lower.contains('ảnh chụp');

    final isDoc = lower.endsWith('.docx') ||
        lower.endsWith('.pdf') ||
        lower.endsWith('.xlsx') ||
        lower.endsWith('.xls') ||
        lower.endsWith('.doc') ||
        lower.endsWith('.zip') ||
        lower.endsWith('.txt') ||
        lower.contains('tệp tin') ||
        lower.contains('tài liệu');

    // Chuyển đổi tên file kỹ thuật sang text hiển thị chuyên nghiệp (chuẩn Zalo / Messenger)
    String displayText = msg;
    if (isImageFilename) {
      displayText = '[Hình ảnh]';
    } else if (isDoc && !msg.startsWith('[Tập tin]') && !msg.startsWith('[Tài liệu]')) {
      displayText = '[Tập tin]';
    }

    // Lấy trạng thái tin nhắn cuối từ Local Cache (phần tử .first là tin mới nhất)
    String lastMsgStatus = 'sent';
    if (cachedMsgs != null && cachedMsgs.isNotEmpty) {
      lastMsgStatus = cachedMsgs.first.status;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Hiển thị trạng thái tin nhắn gửi đi đồng bộ với chi tiết (1 tích = đã gửi, 2 tích = đối phương đã xem)
        if (isMine) ...[
          Icon(
            lastMsgStatus == 'read'
                ? LucideIcons.checkCheck
                : LucideIcons.check,
            size: 14,
            color: lastMsgStatus == 'read'
                ? const Color(0xFF53BDEB)
                : (isDark ? const Color(0xFF8696A0) : const Color(0xFF667781)),
          ),
          const SizedBox(width: 4.5),
        ],
        if (isDoc) ...[
          Icon(
            LucideIcons.fileText,
            size: 14,
            color: hasUnread ? const Color(0xFF2563EB) : const Color(0xFF60A5FA),
          ),
          const SizedBox(width: 4),
        ] else if (isImageFilename) ...[
          Icon(
            LucideIcons.image,
            size: 14,
            color: hasUnread ? const Color(0xFFEA580C) : const Color(0xFFFB923C),
          ),
          const SizedBox(width: 4),
        ],
        Expanded(
          child: Text(
            '$prefix$displayText',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13.5,
              color: hasUnread
                  ? (isDark ? Colors.white : const Color(0xFF0F172A))
                  : (isDark ? Colors.white60 : const Color(0xFF64748B)),
              fontWeight: hasUnread ? FontWeight.w700 : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    return Dates.chatTimestamp(dt);
  }
}

