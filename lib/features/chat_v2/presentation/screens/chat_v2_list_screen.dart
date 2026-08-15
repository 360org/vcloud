import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../../../core/utils/date_format.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/html_avatar_image.dart';
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
  String _searchQuery = '';
  late int _selectedFilterIndex; // 0: Tất cả, 1: Chưa đọc, 2: Cá nhân, 3: Nhóm

  final List<String> _filters = ['Tất cả', 'Chưa đọc', 'Cá nhân', 'Nhóm'];

  int _resolveFilterIndex(String? filter) {
    if (filter == 'unread' || filter == 'chuadoc') return 1;
    if (filter == 'direct' || filter == 'dm' || filter == 'canhan') return 2;
    if (filter == 'group' || filter == 'nhom') return 3;
    return 0;
  }

  @override
  void initState() {
    super.initState();
    _selectedFilterIndex = _resolveFilterIndex(widget.initialFilter);
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
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
                    Text(
                      'Trò chuyện',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        letterSpacing: -0.5,
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
                          padding: EdgeInsets.all(8),
                          child: Icon(
                            LucideIcons.plus,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // ── 2. Search Bar ───────────────────────────────────────────
                Container(
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
                    onChanged: (val) {
                      setState(() => _searchQuery = val.trim().toLowerCase());
                    },
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
                const SizedBox(height: 12),
                // ── 3. Filter Chips với số lượng thống kê ───────────────────
                channelsAsync.maybeWhen(
                  data: (channels) {
                    final readNotifier =
                        ref.watch(chatV2ReadStateProvider.notifier);
                    final allCount = channels.length;
                    final unreadCount = channels.where((c) {
                      final isMine = c.isLastMessageFromMe(
                        currentUserName: currentUserName,
                        currentPartnerId: currentPartnerId,
                        currentUserId: currentUserId,
                      );
                      return !isMine &&
                          readNotifier.isChannelUnread(
                            channelId: c.id,
                            serverUnreadCount: c.unreadCount,
                            lastMessageDate: c.lastMessageDate,
                          );
                    }).length;
                    final directCount = channels
                        .where((c) => !c.getActualIsGroup(currentUserName))
                        .length;
                    final groupCount = channels
                        .where((c) => c.getActualIsGroup(currentUserName))
                        .length;

                    final counts = [allCount, unreadCount, directCount, groupCount];

                    return SizedBox(
                      height: 34,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _filters.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 8),
                        itemBuilder: (context, idx) {
                          final isSelected = _selectedFilterIndex == idx;
                          final count = counts[idx];

                          return ChoiceChip(
                            showCheckmark: false,
                            label: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(_filters[idx]),
                                const SizedBox(width: 5),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? Colors.white.withValues(alpha: 0.25)
                                        : (isDark
                                            ? Colors.white12
                                            : const Color(0xFFE2E8F0)),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    count.toString(),
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected
                                          ? Colors.white
                                          : (isDark
                                              ? Colors.white70
                                              : const Color(0xFF64748B)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            selected: isSelected,
                            onSelected: (_) {
                              setState(() => _selectedFilterIndex = idx);
                            },
                            selectedColor: const Color(0xFF00C83A),
                            backgroundColor: isDark
                                ? const Color(0xFF0F172A)
                                : const Color(0xFFF1F5F9),
                            labelStyle: TextStyle(
                              fontSize: 12.5,
                              fontWeight:
                                  isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected
                                  ? Colors.white
                                  : (isDark
                                      ? Colors.white70
                                      : const Color(0xFF64748B)),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            side: BorderSide(
                              color: isSelected
                                  ? Colors.transparent
                                  : (isDark
                                      ? Colors.white10
                                      : const Color(0xFFE2E8F0)),
                              width: 0.8,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            visualDensity: VisualDensity.compact,
                          );
                        },
                      ),
                    );
                  },
                  orElse: () => const SizedBox.shrink(),
                ),
              ],
            ),
          ),

          // ── 4. Channels List ────────────────────────────────────────────
          Expanded(
            child: RefreshIndicator(
              color: const Color(0xFF00C83A),
              onRefresh: () async => ref.refresh(chatV2ChannelsProvider.future),
              child: channelsAsync.when(
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
                    final isActuallyGroup = c.getActualIsGroup(currentUserName);

                    if (_searchQuery.isNotEmpty) {
                      final matchName = cleanName.toLowerCase().contains(_searchQuery) ||
                          c.name.toLowerCase().contains(_searchQuery);
                      final matchMsg = (c.lastMessage ?? '')
                          .toLowerCase()
                          .contains(_searchQuery);
                      if (!matchName && !matchMsg) return false;
                    }
                    if (_selectedFilterIndex == 1) {
                      final readNotifier =
                          ref.watch(chatV2ReadStateProvider.notifier);
                      final isMine = c.isLastMessageFromMe(
                        currentUserName: currentUserName,
                        currentPartnerId: currentPartnerId,
                        currentUserId: currentUserId,
                      );
                      final isUnread = !isMine &&
                          readNotifier.isChannelUnread(
                            channelId: c.id,
                            serverUnreadCount: c.unreadCount,
                            lastMessageDate: c.lastMessageDate,
                          );
                      if (!isUnread) return false;
                    }
                    if (_selectedFilterIndex == 2 && isActuallyGroup) {
                      return false;
                    }
                    if (_selectedFilterIndex == 3 && !isActuallyGroup) {
                      return false;
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
                          _searchQuery.isNotEmpty
                              ? 'Không tìm thấy cuộc trò chuyện nào'
                              : (_selectedFilterIndex == 1
                                  ? 'Không có tin nhắn chưa đọc'
                                  : 'Chưa có cuộc trò chuyện nào'),
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

                  return ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: filtered.length,
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
                      final channel = filtered[index];
                      return _ChannelListItem(
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
}

class _ChannelListItem extends ConsumerWidget {
  const _ChannelListItem({
    required this.channel,
    this.currentUserName,
    this.currentPartnerId,
    this.currentUserId,
  });

  final ChatV2Channel channel;
  final String? currentUserName;
  final String? currentPartnerId;
  final String? currentUserId;

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cleanName = channel.getCleanName(currentUserName);
    final isGroup = channel.getActualIsGroup(currentUserName);
    final timeStr = channel.lastMessageDate != null
        ? _formatDate(channel.lastMessageDate!)
        : '';
    final avatarGrad = _getAvatarGradient(cleanName);

    // Kiểm tra trạng thái chưa đọc từ ReadState Tracker
    final readNotifier = ref.watch(chatV2ReadStateProvider.notifier);
    final lastSentText = ref.watch(chatV2LastSentTrackerProvider)[channel.id];
    final isMineFromTracker = lastSentText != null &&
        channel.lastMessage?.trim() == lastSentText.trim();

    final isMine = isMineFromTracker ||
        channel.isLastMessageFromMe(
          currentUserName: currentUserName,
          currentPartnerId: currentPartnerId,
          currentUserId: currentUserId,
        );

    final hasUnread = !isMine &&
        readNotifier.isChannelUnread(
          channelId: channel.id,
          serverUnreadCount: channel.unreadCount,
          lastMessageDate: channel.lastMessageDate,
        );

    return Material(
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
                      gradient: (channel.avatarUrl != null &&
                              channel.avatarUrl!.isNotEmpty)
                          ? null
                          : LinearGradient(
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
                    child: (channel.avatarUrl != null &&
                            channel.avatarUrl!.isNotEmpty)
                        ? ClipOval(
                            child: SizedBox(
                              width: 50,
                              height: 50,
                              child: buildHtmlAvatarImage(
                                    url: channel.avatarUrl!,
                                    fallback: Text(
                                      cleanName.isNotEmpty
                                          ? cleanName[0].toUpperCase()
                                          : 'C',
                                      style: const TextStyle(
                                        fontSize: 19,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ) ??
                                  Image.network(
                                    channel.avatarUrl!,
                                    width: 50,
                                    height: 50,
                                    cacheWidth: 100,
                                    cacheHeight: 100,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => Text(
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
                            ),
                          )
                        : Text(
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
    );
  }

  Widget _buildLastMessageSnippet(
      WidgetRef ref, bool isDark, bool hasUnread, String cleanName) {
    final msg = channel.lastMessage;
    if (msg == null || msg.isEmpty) {
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

    // Kiểm tra xem tin nhắn có phải do mình vừa gửi không
    final lastSentText = ref.watch(chatV2LastSentTrackerProvider)[channel.id];
    final isMineFromTracker =
        lastSentText != null && msg.trim() == lastSentText.trim();

    final isMine = isMineFromTracker ||
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
        author = channel.lastMessageAuthorName!.split(' ').last;
      } else {
        // Kiểm tra từ Local Cache của tin nhắn kênh nếu đã nạp
        final cachedMsgs = ChatV2MessageLocalCache.get(channel.id);
        if (cachedMsgs != null && cachedMsgs.isNotEmpty) {
          final lastMsgObj = cachedMsgs.last;
          if (!lastMsgObj.isMine && lastMsgObj.authorName.isNotEmpty) {
            author = lastMsgObj.authorName.split(' ').last;
          }
        }
      }
      if (author.isNotEmpty &&
          author.toLowerCase() != (currentUserName ?? '').toLowerCase()) {
        prefix = '$author: ';
      }
    }

    final lower = msg.toLowerCase();
    final isDoc = lower.endsWith('.docx') ||
        lower.endsWith('.pdf') ||
        lower.endsWith('.xlsx') ||
        lower.endsWith('.doc') ||
        lower.endsWith('.zip') ||
        lower.contains('tệp tin') ||
        lower.contains('tài liệu');

    final isImg = lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.webp') ||
        lower.contains('hình ảnh') ||
        lower.contains('ảnh chụp');

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Hiển thị 2 dấu tích xanh đã xem nếu tin nhắn đã được đọc
        if (!hasUnread) ...[
          const Icon(
            LucideIcons.checkCheck,
            size: 15,
            color: Color(0xFF10B981), // Xanh ngọc thể hiện Đã xem
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
        ] else if (isImg) ...[
          Icon(
            LucideIcons.image,
            size: 14,
            color: hasUnread ? const Color(0xFFEA580C) : const Color(0xFFFB923C),
          ),
          const SizedBox(width: 4),
        ],
        Expanded(
          child: Text(
            '$prefix$msg',
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

