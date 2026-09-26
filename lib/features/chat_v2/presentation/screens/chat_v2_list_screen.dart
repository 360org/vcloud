import 'dart:async';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../../../core/api/odoo_api_client.dart';
import '../../data/chat_v2_repository.dart';

import '../../../../core/utils/date_format.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../auth/application/auth_controller.dart';
import '../../application/chat_v2_channels_controller.dart';
import '../../application/chat_v2_messages_controller.dart';
import '../../application/chat_v2_presence_controller.dart';
import '../../application/chat_v2_read_state_controller.dart';
import '../../data/models/chat_v2_channel.dart';
import '../../data/models/chat_v2_message.dart';

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
  int? _selectedFilterIndex; // null: Mặc định (Tất cả), 0: Chưa đọc, 1: Trực tiếp, 2: Nhóm, 3: Kênh, 4: Zalo OA
  Timer? _searchDebounceTimer;
  bool _dismissedVMobileWarning = false;

  int? _resolveFilterIndex(String? filter) {
    if (filter == null || filter.isEmpty || filter == 'all' || filter == 'tatca') return null;
    if (filter == 'unread' || filter == 'chuadoc') return 0;
    if (filter == 'internal' || filter == 'noibo' || filter == 'direct' || filter == 'dm' || filter == 'canhan' || filter == 'tructiep') return 1;
    if (filter == 'group' || filter == 'nhom') return 2;
    if (filter == 'channel' || filter == 'kenh') return 3;
    if (filter == 'zalo' || filter == 'zalo_oa' || filter == 'oa' || filter == 'customer') return 4;
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
    final syncStatus = ref.watch(chatV2SyncStatusProvider);
    final currentUser = ref.watch(authControllerProvider).valueOrNull;
    final meta = currentUser?.userMetadata;
    final currentUserName = (meta?['name'] ??
            meta?['display_name'] ??
            meta?['partner_name'] ??
            meta?['partner']?['name']) as String?;
    final currentPartnerId = meta?['partner_id']?.toString() ??
        meta?['partner']?['id']?.toString();
    final currentUserId = currentUser?.id;
    final currentDbName = (meta?['db'] as String?) ?? '';
    final hasVMobile = (meta?['has_v_mobile'] as bool?) ?? true;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppScaffold(
      title: 'Trò chuyện',
      showAppBar: false,
      floatingActionButton: (currentUser?.isPortal == true)
          ? null
          : FloatingActionButton(
              heroTag: 'chat_new_fab',
              onPressed: () => context.push('/chat/new'),
              backgroundColor: const Color(0xFF00C83A),
              foregroundColor: Colors.white,
              elevation: 4,
              shape: const CircleBorder(),
              child: const Icon(LucideIcons.plus, size: 26),
            ),
      body: Container(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        child: Column(
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
                Text(
                  'Trò chuyện',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    letterSpacing: -0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                // ── 2. Search Bar (Full Width) ──────────────────────────────
                Container(
                  height: 42,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF0F172A)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                      width: 0.8,
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    textAlignVertical: TextAlignVertical.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    decoration: InputDecoration(
                      isDense: true,
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
                      prefixIconConstraints: const BoxConstraints(
                        minWidth: 40,
                        minHeight: 42,
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
                      suffixIconConstraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 42,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // ── 3. Horizontal Filter Chips (6 Chips một chạm) ───────────
                channelsAsync.maybeWhen(
                  data: (channels) {
                    final unreadCount = ref.watch(chatV2TotalUnreadProvider);
                    final directCount = channels
                        .where((c) => c.isInternalDirect(currentUserName))
                        .length;
                    final groupCount = channels
                        .where((c) => c.isGroupChat(currentUserName))
                        .length;
                    final channelCount = channels
                        .where((c) => c.isChannel)
                        .length;
                    final zaloCount = channels
                        .where((c) => c.isZaloOA)
                        .length;

                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: [
                          _buildChip(
                            label: 'Tất cả',
                            count: channels.length,
                            isSelected: _selectedFilterIndex == null,
                            isDark: isDark,
                            onTap: () => setState(() => _selectedFilterIndex = null),
                          ),
                          const SizedBox(width: 8),
                          _buildChip(
                            label: 'Chưa đọc',
                            count: unreadCount,
                            isSelected: _selectedFilterIndex == 0,
                            isDark: isDark,
                            badgeColor: const Color(0xFFEF4444),
                            onTap: () => setState(() => _selectedFilterIndex = 0),
                          ),
                          const SizedBox(width: 8),
                          _buildChip(
                            label: 'Trực tiếp',
                            count: directCount,
                            isSelected: _selectedFilterIndex == 1,
                            isDark: isDark,
                            onTap: () => setState(() => _selectedFilterIndex = 1),
                          ),
                          const SizedBox(width: 8),
                          _buildChip(
                            label: 'Nhóm',
                            count: groupCount,
                            isSelected: _selectedFilterIndex == 2,
                            isDark: isDark,
                            onTap: () => setState(() => _selectedFilterIndex = 2),
                          ),
                          const SizedBox(width: 8),
                          _buildChip(
                            label: 'Kênh',
                            count: channelCount,
                            isSelected: _selectedFilterIndex == 3,
                            isDark: isDark,
                            onTap: () => setState(() => _selectedFilterIndex = 3),
                          ),
                          const SizedBox(width: 8),
                          _buildChip(
                            label: 'Zalo OA',
                            count: zaloCount,
                            isSelected: _selectedFilterIndex == 4,
                            isDark: isDark,
                            badgeColor: const Color(0xFF0068FF),
                            onTap: () => setState(() => _selectedFilterIndex = 4),
                          ),
                        ],
                      ),
                    );
                  },
                  orElse: () => const SizedBox.shrink(),
                ),
              ],
            ),
          ),

          // ── Warning Banner: Cơ sở dữ liệu chưa cài module vmobile ───────
          if (!hasVMobile && !_dismissedVMobileWarning)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFFFCA5A5),
                  width: 1.0,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: const Icon(
                      LucideIcons.alertTriangle,
                      color: Color(0xFFEF4444),
                      size: 17,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Chưa cài đặt module vmobile',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF991B1B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Cơ sở dữ liệu "$currentDbName" chưa cài module vmobile. Tất cả các tính năng không thể sử dụng được.',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Color(0xFFB91C1C),
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.x, size: 16, color: Color(0xFF991B1B)),
                    onPressed: () => setState(() => _dismissedVMobileWarning = true),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                    splashRadius: 16,
                  ),
                ],
              ),
            ),

          // ── 4. Channels List ────────────────────────────────────────────
          Expanded(
            child: RefreshIndicator(
              color: const Color(0xFF00C83A),
              onRefresh: () async =>
                  ref.read(chatV2ChannelsProvider.notifier).refresh(),
              child: Builder(
                builder: (context) {
                  final hasCachedOrData = (channelsAsync.valueOrNull?.isNotEmpty ?? false) ||
                      ChatV2ChannelLocalCache.cached.isNotEmpty;

                  if (!hasVMobile && !hasCachedOrData) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                LucideIcons.slash,
                                size: 32,
                                color: Color(0xFFEF4444),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Tính năng chưa khả dụng',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Cơ sở dữ liệu "$currentDbName" chưa cài module vmobile nên tất cả các tính năng không thể sử dụng được.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  if (!hasCachedOrData && (channelsAsync.isLoading || syncStatus == ChatV2SyncStatus.connecting)) {
                    return const Center(
                      child: CircularProgressIndicator(color: Color(0xFF00C83A)),
                    );
                  }

                  if (!hasCachedOrData && channelsAsync.hasError) {
                    final error = channelsAsync.error;
                    return Center(
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
                              onPressed: () => ref
                                  .read(chatV2ChannelsProvider.notifier)
                                  .refresh(),
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
                    );
                  }

                  final channels = channelsAsync.valueOrNull ??
                      ChatV2ChannelLocalCache.cached;

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
                      final isMine = (c.lastMessageAuthorId != null && c.lastMessageAuthorId!.isNotEmpty)
                          ? c.isLastMessageFromMe(
                              currentUserName: currentUserName,
                              currentPartnerId: currentPartnerId,
                              currentUserId: currentUserId,
                            )
                          : ((cachedMsgs != null && cachedMsgs.isNotEmpty)
                              ? ((currentPartnerId != null && cachedMsgs.first.authorId == currentPartnerId) ||
                                 (currentUserId != null && cachedMsgs.first.authorId == currentUserId))
                              : c.isLastMessageFromMe(
                                  currentUserName: currentUserName,
                                  currentPartnerId: currentPartnerId,
                                  currentUserId: currentUserId,
                                ));

                      // Nếu chưa có tin nhắn nào trong phòng -> Không hiển thị ở Chưa đọc
                      if (c.lastMessage == null || c.lastMessage!.trim().isEmpty) {
                        final cachedMsgs = ChatV2MessageLocalCache.get(c.id);
                        if (cachedMsgs == null || cachedMsgs.isEmpty) return false;
                      }

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
                      // 1: Trực tiếp (1-1)
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
                    } else if (_selectedFilterIndex == 4) {
                      // 4: Zalo OA
                      if (!c.isZaloOA) {
                        return false;
                      }
                    }
                    return true;
                  }).toList();

                  // Sắp xếp các đoạn chat:
                  // 1. Nhóm Ghim luôn cố định ở trên đầu theo đúng thứ tự ghim (1, 2, 3, 4, 5)
                  // 2. Nhóm không ghim sắp xếp theo thời gian tin nhắn mới nhất
                  filtered.sort((a, b) {
                    final aPinned = ChatV2ChannelLocalCache.isUserPinned(a.id);
                    final bPinned = ChatV2ChannelLocalCache.isUserPinned(b.id);
                    if (aPinned && !bPinned) return -1;
                    if (!aPinned && bPinned) return 1;
                    if (aPinned && bPinned) {
                      final idxA = ChatV2ChannelLocalCache.getPinnedIndex(a.id);
                      final idxB = ChatV2ChannelLocalCache.getPinnedIndex(b.id);
                      return idxA.compareTo(idxB);
                    }

                    if (a.lastMessageDate == null && b.lastMessageDate == null) {
                      final aId = int.tryParse(a.id) ?? 0;
                      final bId = int.tryParse(b.id) ?? 0;
                      return bId.compareTo(aId);
                    }
                    if (a.lastMessageDate == null) return 1;
                    if (b.lastMessageDate == null) return -1;
                    return b.lastMessageDate!.compareTo(a.lastMessageDate!);
                  });

                  final Widget listContent;
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

                    listContent = ListView(
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
                  } else {
                    final channelsNotifier = ref.watch(chatV2ChannelsProvider.notifier);
                    final hasMore = channelsNotifier.hasMore;
                    final isLoadingMore = channelsNotifier.isLoadingMore;
                    final isFiltered = _searchQuery.isNotEmpty || _selectedFilterIndex != null;

                    listContent = ListView.separated(
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
                  }

                  return Column(
                    children: [
                      _SyncStatusBanner(
                        status: syncStatus,
                        isDark: isDark,
                        onRetry: () => ref
                            .read(chatV2ChannelsProvider.notifier)
                            .resumeRefresh(),
                      ),
                      Expanded(child: listContent),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildChip({
    required String label,
    required int count,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
    Color? badgeColor,
  }) {
    const activeBg = Color(0xFF00C83A);
    final inactiveBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    final borderColor = isSelected
        ? const Color(0xFF00C83A)
        : (isDark ? Colors.white12 : const Color(0xFFE2E8F0));

    return Material(
      color: isSelected ? activeBg : inactiveBg,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor, width: 0.8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? Colors.white
                      : (isDark ? Colors.white70 : const Color(0xFF475569)),
                ),
              ),
              if (count > 0) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.25)
                        : (badgeColor ??
                            (isDark ? Colors.white12 : const Color(0xFFE2E8F0))),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    count.toString(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? Colors.white
                          : (badgeColor != null
                              ? Colors.white
                              : (isDark
                                  ? Colors.white70
                                  : const Color(0xFF64748B))),
                    ),
                  ),
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
                : (cachedMsgs.first.attachments.isNotEmpty
                    ? _getAttachmentFallbackText(cachedMsgs.first.attachments.first)
                    : null))
            : null);

    // Ưu tiên thời gian của tin nhắn thực tế từ cache nếu có
    final effectiveLastDate = (cachedMsgs != null && cachedMsgs.isNotEmpty && cachedMsgs.first.createdAt != null)
        ? cachedMsgs.first.createdAt
        : channel.lastMessageDate;

    final timeStr = effectiveLastDate != null
        ? _formatDate(effectiveLastDate)
        : '';
    final avatarGrad = _getAvatarGradient(cleanName);

    final isMine = (channel.lastMessageAuthorId != null && channel.lastMessageAuthorId!.isNotEmpty)
        ? channel.isLastMessageFromMe(
            currentUserName: currentUserName,
            currentPartnerId: currentPartnerId,
            currentUserId: currentUserId,
          )
        : ((cachedMsgs != null && cachedMsgs.isNotEmpty)
            ? ((currentPartnerId != null && cachedMsgs.first.authorId == currentPartnerId) ||
               (currentUserId != null && cachedMsgs.first.authorId == currentUserId))
            : channel.isLastMessageFromMe(
                currentUserName: currentUserName,
                currentPartnerId: currentPartnerId,
                currentUserId: currentUserId,
              ));

    // Watch riêng trạng thái seen của channel này để tự động cập nhật khi có trạng thái đọc mới
    ref.watch(chatV2ReadStateProvider.select((m) => m[channel.id]));
    final readNotifier = ref.watch(chatV2ReadStateProvider.notifier);
    final hasUnread = !isMine &&
        effectiveLastMsg != null &&
        effectiveLastMsg.trim().isNotEmpty &&
        readNotifier.isChannelUnread(
          channelId: channel.id,
          serverUnreadCount: channel.unreadCount,
          lastMessageDate: effectiveLastDate,
        );

    // Tự động phân giải avatar URL của đối phương nếu channel.avatarUrl chưa có và là chat 1-1
    String? resolvedAvatarUrl = channel.avatarUrl;
    if (resolvedAvatarUrl == null || resolvedAvatarUrl.isEmpty) {
      if (!isGroup && !channel.isChannel) {
        final currentPartnerId = odooApiClient.session?.partnerId?.toString();
        final currentUserId = odooApiClient.session?.uid.toString();
        if (cachedMsgs != null && cachedMsgs.isNotEmpty) {
          final otherMsg = cachedMsgs.firstWhereOrNull((m) =>
              !m.isMine &&
              (currentPartnerId == null || m.authorId?.toString() != currentPartnerId) &&
              (currentUserId == null || m.authorId?.toString() != currentUserId) &&
              m.authorAvatar != null &&
              m.authorAvatar!.isNotEmpty);
          if (otherMsg != null) {
            resolvedAvatarUrl = otherMsg.authorAvatar;
          }
        }
        if (resolvedAvatarUrl == null || resolvedAvatarUrl.isEmpty) {
          final otherMember = channel.members.firstWhereOrNull((m) =>
              !m.isMe &&
              (currentPartnerId == null || m.id != currentPartnerId) &&
              (currentUserId == null || m.id != currentUserId) &&
              (currentUserName == null || !ChatV2Channel.matchesUser(m.name, currentUserName)) &&
              m.avatarUrl != null &&
              m.avatarUrl!.isNotEmpty);
          if (otherMember != null) {
            resolvedAvatarUrl = otherMember.avatarUrl;
          }
        }
      }
    }

    return RepaintBoundary(
      child: Material(
        color: hasUnread
            ? (isDark
                ? const Color(0xFF1E293B)
                : Colors.white)
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
                          if (resolvedAvatarUrl != null &&
                              resolvedAvatarUrl.isNotEmpty)
                            Image.network(
                              resolvedAvatarUrl,
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                              cacheWidth: (50 * MediaQuery.devicePixelRatioOf(context)).round(),
                              cacheHeight: (50 * MediaQuery.devicePixelRatioOf(context)).round(),
                              gaplessPlayback: true,
                              headers: odooApiClient.authHeaders,
                              errorBuilder: (context, error, stackTrace) =>
                                  const SizedBox.shrink(),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (channel.isZaloOA)
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
                            color: Color(0xFF0068FF),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            LucideIcons.messageCircle,
                            size: 11,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    )
                  else if (channel.isChannel)
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
                            color: Color(0xFF0284C7),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            LucideIcons.hash,
                            size: 11,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    )
                  else if (isGroup)
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
                  else if (channel.imStatus == 'online' ||
                      channel.directPartnerStatus == 'online' ||
                      (channel.partnerId != null &&
                          ref.watch(chatV2PresenceProvider.select((m) => m[channel.partnerId])) == 'online') ||
                      (channel.directPartnerId != null &&
                          ref.watch(chatV2PresenceProvider.select((m) => m[channel.directPartnerId])) == 'online'))
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: const Color(0xFF22C55E),
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
                          child: Row(
                            children: [
                              Flexible(
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
                              if (ChatV2ChannelLocalCache.isUserPinned(channel.id))
                                const Padding(
                                  padding: EdgeInsets.only(left: 6),
                                  child: Icon(
                                    LucideIcons.pin,
                                    size: 14,
                                    color: Color(0xFF00C83A),
                                  ),
                                ),
                              if (ChatV2ChannelLocalCache.isUserMuted(channel.id))
                                const Padding(
                                  padding: EdgeInsets.only(left: 6),
                                  child: Icon(
                                    LucideIcons.bellOff,
                                    size: 14,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                            ],
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

  String _getAttachmentFallbackText(ChatV2Attachment att) {
    final lower = att.name.toLowerCase().trim();
    final isAudio = att.isAudio ||
        (att.mimetype?.startsWith('audio/') ?? false) ||
        lower.endsWith('.webm') ||
        lower.endsWith('.mp3') ||
        lower.endsWith('.m4a') ||
        lower.endsWith('.wav') ||
        lower.endsWith('.aac') ||
        lower.endsWith('.ogg') ||
        lower.endsWith('.opus') ||
        lower.endsWith('.flac') ||
        lower.endsWith('.amr') ||
        lower.startsWith('voice_');
    if (isAudio) return '[Ghi âm]';

    final isImg = att.isImage ||
        (att.mimetype?.startsWith('image/') ?? false) ||
        lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.svg') ||
        lower.endsWith('.bmp') ||
        lower.endsWith('.ico') ||
        lower.endsWith('.heic') ||
        lower.endsWith('.heif') ||
        lower.endsWith('.tiff') ||
        lower.endsWith('.tif') ||
        lower.startsWith('scaled_') ||
        lower.startsWith('image_picker_');
    if (isImg) return '[Hình ảnh]';

    return '[Tập tin]';
  }

  Widget _buildLastMessageSnippet(
      WidgetRef ref, bool isDark, bool hasUnread, String cleanName) {
    final cachedMsgs = ChatV2MessageLocalCache.get(channel.id);
    final effectiveLastMsg = (channel.lastMessage != null && channel.lastMessage!.isNotEmpty)
        ? channel.lastMessage
        : (cachedMsgs != null && cachedMsgs.isNotEmpty
            ? (cachedMsgs.first.content.isNotEmpty
                ? cachedMsgs.first.content
                : (cachedMsgs.first.attachments.isNotEmpty
                    ? _getAttachmentFallbackText(cachedMsgs.first.attachments.first)
                    : null))
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
    final isMine = (channel.lastMessageAuthorId != null && channel.lastMessageAuthorId!.isNotEmpty)
        ? channel.isLastMessageFromMe(
            currentUserName: currentUserName,
            currentPartnerId: currentPartnerId,
            currentUserId: currentUserId,
          )
        : ((cachedMsgs != null && cachedMsgs.isNotEmpty)
            ? ((currentPartnerId != null && cachedMsgs.first.authorId == currentPartnerId) ||
               (currentUserId != null && cachedMsgs.first.authorId == currentUserId))
            : channel.isLastMessageFromMe(
                currentUserName: currentUserName,
                currentPartnerId: currentPartnerId,
                currentUserId: currentUserId,
              ));

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
    final isUrl = lower.startsWith('http://') ||
        lower.startsWith('https://') ||
        lower.startsWith('www.') ||
        lower.contains('://');

    final isImageFilename = !isUrl &&
        (lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.svg') ||
        lower.endsWith('.bmp') ||
        lower.endsWith('.ico') ||
        lower.endsWith('.heic') ||
        lower.endsWith('.heif') ||
        lower.endsWith('.tiff') ||
        lower.endsWith('.tif') ||
        lower.startsWith('scaled_') ||
        lower.startsWith('image_picker_') ||
        lower.startsWith('[hình ảnh]') ||
        lower == 'hình ảnh' ||
        lower == '[hình ảnh]');

    final isVoice = !isUrl &&
        (lower.endsWith('.webm') ||
        lower.endsWith('.mp3') ||
        lower.endsWith('.m4a') ||
        lower.endsWith('.wav') ||
        lower.endsWith('.aac') ||
        lower.endsWith('.ogg') ||
        lower.endsWith('.opus') ||
        lower.endsWith('.flac') ||
        lower.endsWith('.amr') ||
        lower.startsWith('voice_') ||
        lower.contains('voice_') ||
        lower.contains('audio_') ||
        lower.startsWith('[ghi âm]') ||
        lower.startsWith('[tin nhắn thoại]') ||
        lower == 'ghi âm' ||
        lower == '[ghi âm]' ||
        lower == 'tin nhắn thoại' ||
        lower == '[tin nhắn thoại]');

    final isDoc = !isUrl &&
        (lower.endsWith('.docx') ||
        lower.endsWith('.pdf') ||
        lower.endsWith('.xlsx') ||
        lower.endsWith('.xls') ||
        lower.endsWith('.doc') ||
        lower.endsWith('.zip') ||
        lower.endsWith('.txt') ||
        lower.endsWith('.md') ||
        lower.endsWith('.markdown') ||
        lower.endsWith('.csv') ||
        lower.endsWith('.json') ||
        lower.endsWith('.xml') ||
        lower.endsWith('.rar') ||
        lower.endsWith('.7z') ||
        lower.endsWith('.tar') ||
        lower.endsWith('.gz') ||
        lower.endsWith('.apk') ||
        lower.endsWith('.ipa') ||
        lower.endsWith('.sql') ||
        lower.endsWith('.log') ||
        lower.endsWith('.pptx') ||
        lower.endsWith('.ppt') ||
        lower.endsWith('.rtf') ||
        lower.endsWith('.odt') ||
        lower.endsWith('.ods') ||
        lower.endsWith('.odp') ||
        lower.endsWith('.p8') ||
        lower.endsWith('.cer') ||
        lower.endsWith('.key') ||
        lower.endsWith('.bin') ||
        lower.endsWith('.sh') ||
        lower.endsWith('.py') ||
        lower.endsWith('.dart') ||
        lower.endsWith('.ts') ||
        lower.endsWith('.js') ||
        lower.endsWith('.yaml') ||
        lower.endsWith('.yml') ||
        lower.startsWith('[tập tin]') ||
        lower.startsWith('[tài liệu]') ||
        lower.startsWith('[tệp tin]') ||
        lower == 'tệp tin' ||
        lower == '[tệp tin]' ||
        lower == 'tài liệu' ||
        lower == '[tài liệu]');

    final isMissedCall = lower.contains('nhỡ') || lower.startsWith('❌') || lower.contains('cuộc gọi nhỡ');
    final isVoiceCall = (lower.contains('cuộc gọi thoại') || lower.startsWith('📞')) && !isMissedCall;
    final isRejectedCall = lower.contains('từ chối') || lower.startsWith('🚫');
    final isCancelledCall = lower.contains('hủy') || lower.startsWith('📵');
    final isAnyCall = isMissedCall || isVoiceCall || isRejectedCall || isCancelledCall;

    // Chuyển đổi tên file kỹ thuật sang text hiển thị chuyên nghiệp (chuẩn Zalo / Messenger)
    String displayText = msg;
    if (isImageFilename) {
      displayText = '[Hình ảnh]';
    } else if (isVoice) {
      displayText = '[Ghi âm]';
    } else if (isDoc && !msg.startsWith('[Tập tin]') && !msg.startsWith('[Tài liệu]') && !msg.startsWith('[Tệp tin]')) {
      displayText = '[Tập tin]';
    } else if (isMissedCall) {
      displayText = isMine ? '[Cuộc gọi nhỡ đi]' : '[Cuộc gọi nhỡ]';
    } else if (isVoiceCall) {
      displayText = '[Cuộc gọi thoại]';
    } else if (isRejectedCall) {
      displayText = '[Cuộc gọi bị từ chối]';
    } else if (isCancelledCall) {
      displayText = '[Cuộc gọi đã hủy]';
    }

    // Lấy trạng thái tin nhắn cuối từ Local Cache (phần tử .first là tin mới nhất)
    String lastMsgStatus = 'sent';
    if (cachedMsgs != null && cachedMsgs.isNotEmpty) {
      lastMsgStatus = cachedMsgs.first.status;
    }

    final isAlertRed = !isMine && (isMissedCall || isRejectedCall || isCancelledCall);

    // Kiểm tra xem tin nhắn cuối có @tag nhắc đến tôi không (chỉ áp dụng trong nhóm/kênh)
    final isMentionedMe = isGroup &&
        !isMine &&
        hasUnread &&
        currentUserName != null &&
        currentUserName!.isNotEmpty &&
        (lower.contains('@${currentUserName!.toLowerCase()}') ||
         lower.contains('@all') ||
         lower.contains('@everyone'));

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isMentionedMe) ...[
          Container(
            margin: const EdgeInsets.only(right: 6),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: const Color(0xFFEF4444).withValues(alpha: 0.35),
                width: 0.8,
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  LucideIcons.atSign,
                  size: 11,
                  color: Color(0xFFEF4444),
                ),
                SizedBox(width: 2),
                Text(
                  'Nhắc đến bạn',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFEF4444),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Hiển thị trạng thái tin nhắn gửi đi đồng bộ với chi tiết (1 tích = đã gửi, 2 tích = đối phương đã xem)
        if (isMine && !isAnyCall) ...[
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

        if (isMissedCall) ...[
          Icon(
            isMine ? LucideIcons.phoneOutgoing : LucideIcons.phoneMissed,
            size: 14,
            color: isAlertRed
                ? const Color(0xFFEF4444)
                : (isDark ? const Color(0xFF8696A0) : const Color(0xFF667781)),
          ),
          const SizedBox(width: 4),
        ] else if (isVoiceCall) ...[
          const Icon(
            LucideIcons.phone,
            size: 14,
            color: Color(0xFF10B981),
          ),
          const SizedBox(width: 4),
        ] else if (isRejectedCall || isCancelledCall) ...[
          Icon(
            isMine ? LucideIcons.phoneOff : LucideIcons.phoneMissed,
            size: 14,
            color: isAlertRed
                ? const Color(0xFFEF4444)
                : (isDark ? const Color(0xFF8696A0) : const Color(0xFF667781)),
          ),
          const SizedBox(width: 4),
        ] else if (isDoc) ...[
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
        ] else if (isVoice) ...[
          Icon(
            LucideIcons.mic,
            size: 14,
            color: hasUnread ? const Color(0xFF00C83A) : const Color(0xFF10B981),
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
              fontWeight: isAlertRed
                  ? FontWeight.w600
                  : (hasUnread ? FontWeight.w600 : FontWeight.normal),
              color: isAlertRed
                  ? const Color(0xFFEF4444)
                  : (hasUnread
                      ? (isDark ? Colors.white : const Color(0xFF1E293B))
                      : (isDark ? const Color(0xFF8696A0) : const Color(0xFF667781))),
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

class _SyncStatusBanner extends StatelessWidget {
  const _SyncStatusBanner({
    required this.status,
    required this.isDark,
    required this.onRetry,
  });

  final ChatV2SyncStatus status;
  final bool isDark;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (status == ChatV2SyncStatus.synced) {
      return const SizedBox.shrink();
    }

    if (status == ChatV2SyncStatus.connecting) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: isDark ? Colors.white70 : const Color(0xFF64748B),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Đang kết nối...',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white70 : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      );
    }

    // ChatV2SyncStatus.offline
    return GestureDetector(
      onTap: onRetry,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? const Color(0xFF78350F) : const Color(0xFFFDE68A),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              LucideIcons.alertTriangle,
              size: 14,
              color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706),
            ),
            const SizedBox(width: 6),
            Text(
              'Đang ngoại tuyến — Chạm để thử lại',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


