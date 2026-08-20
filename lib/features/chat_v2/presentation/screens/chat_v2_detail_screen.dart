import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../application/chat_v2_channels_controller.dart';
import '../../application/chat_v2_messages_controller.dart';
import '../../application/chat_v2_read_state_controller.dart';
import '../../data/models/chat_v2_channel.dart';
import '../../data/models/chat_v2_message.dart';
import '../../application/chat_v2_typing_controller.dart';
import '../../application/chat_v2_presence_controller.dart';
import '../../data/chat_v2_realtime_service.dart';
import '../../../auth/application/auth_controller.dart';
import '../widgets/chat_v2_input_bar.dart';
import '../widgets/chat_v2_message_item.dart';
import '../widgets/chat_v2_info_sheet.dart';

class ChatV2DetailScreen extends ConsumerStatefulWidget {
  const ChatV2DetailScreen({
    super.key,
    required this.channelId,
    this.title,
    this.initialAvatarUrl,
    this.initialPartnerId,
  });

  final String channelId;
  final String? title;
  final String? initialAvatarUrl;
  final String? initialPartnerId;

  @override
  ConsumerState<ChatV2DetailScreen> createState() => _ChatV2DetailScreenState();
}

class _ChatV2DetailScreenState extends ConsumerState<ChatV2DetailScreen> {
  late final ScrollController _scrollController;
  final bool _isSending = false;
  ChatV2Message? _replyingTo;
  ChatV2Message? _editingMsg;
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();

  String? _highlightedMessageId;
  Timer? _highlightTimer;
  bool _showScrollToBottom = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(chatV2ReadStateProvider.notifier).markChannelAsRead(widget.channelId);
      if (widget.title != null && widget.title!.isNotEmpty) {
        final existing = ChatV2ChannelLocalCache.getPinnedDirectChannel(widget.channelId);
        final directCh = ChatV2Channel(
          id: widget.channelId,
          name: widget.title!,
          channelType: 'chat',
          isGroup: false,
          memberCount: 2,
          avatarUrl: widget.initialAvatarUrl ?? existing?.avatarUrl,
          directPartnerId: widget.initialPartnerId ?? existing?.directPartnerId,
          directPartnerName: widget.title,
          lastMessage: existing?.lastMessage,
          lastMessageDate: existing?.lastMessageDate ?? DateTime.now(),
          lastMessageAuthorId: existing?.lastMessageAuthorId,
          lastMessageAuthorName: existing?.lastMessageAuthorName,
          unreadCount: 0,
        );
        ChatV2ChannelLocalCache.pinDirectChannel(directCh);
      }
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      final notifier = ref.read(chatV2MessagesProvider(widget.channelId).notifier);
      if (!notifier.isLoadingMore) {
        notifier.loadMore();
      }
    }

    final showBtn = _scrollController.position.pixels > 300;
    if (_showScrollToBottom != showBtn) {
      setState(() {
        _showScrollToBottom = showBtn;
      });
    }
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _jumpToMessage(String targetId) {
    if (targetId.isEmpty) return;
    final messages = ref.read(chatV2MessagesProvider(widget.channelId)).valueOrNull ?? [];
    final targetIndex = messages.indexWhere((m) => m.id == targetId);

    if (targetIndex != -1) {
      // Trong ListView reverse: true, index 0 ở dưới cùng (offset 0.0)
      if (_scrollController.hasClients) {
        final maxScroll = _scrollController.position.maxScrollExtent;
        final targetOffset = (targetIndex * 85.0).clamp(0.0, maxScroll);
        _scrollController.animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOutCubic,
        );
      }

      // Kích hoạt hiệu ứng nổi bật trong 1.5 giây
      setState(() {
        _highlightedMessageId = targetId;
      });
      _highlightTimer?.cancel();
      _highlightTimer = Timer(const Duration(milliseconds: 1500), () {
        if (mounted) {
          setState(() {
            _highlightedMessageId = null;
          });
        }
      });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tin nhắn gốc đã cũ, đang tải thêm...'),
            duration: Duration(seconds: 1),
          ),
        );
      }
      ref.read(chatV2MessagesProvider(widget.channelId).notifier).loadMore();
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _handleSendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final replying = _replyingTo;
    final replyingId = replying?.id;
    final replyingAuthor = replying?.authorName;
    final replyingBody = replying?.content.isNotEmpty == true
        ? replying!.content
        : (replying?.attachments.isNotEmpty == true ? replying!.attachments.first.name : null);

    final editing = _editingMsg;
    setState(() {
      _replyingTo = null;
      _editingMsg = null;
    });

    _scrollToBottom();

    try {
      if (editing != null) {
        await ref
            .read(chatV2MessagesProvider(widget.channelId).notifier)
            .editMessage(editing.id, text);
      } else {
        unawaited(ref
            .read(chatV2MessagesProvider(widget.channelId).notifier)
            .sendMessage(
              text,
              parentId: replyingId,
              parentBody: replyingBody,
              parentAuthorName: replyingAuthor,
            ));
      }

      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi gửi tin nhắn: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _handleSendImage({
    required Uint8List bytes,
    required String filename,
    String? mimetype,
    String? caption,
  }) async {
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    try {
      await ref
          .read(chatV2MessagesProvider(widget.channelId).notifier)
          .sendImage(
            filename: filename,
            bytes: bytes,
            mimetype: mimetype,
            caption: caption,
          );

      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi gửi hình ảnh: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _handleSendFile({
    required Uint8List bytes,
    required String filename,
    String? mimetype,
    String? caption,
  }) async {
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    try {
      await ref
          .read(chatV2MessagesProvider(widget.channelId).notifier)
          .sendFile(
            filename: filename,
            bytes: bytes,
            mimetype: mimetype,
            caption: caption,
          );

      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi gửi tệp tin: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  bool _isSameDay(DateTime? d1, DateTime? d2) {
    if (d1 == null || d2 == null) return false;
    return d1.year == d2.year && d1.month == d2.month && d1.day == d2.day;
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return 'Hôm nay';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (date.year == yesterday.year &&
        date.month == yesterday.month &&
        date.day == yesterday.day) {
      return 'Hôm qua';
    }
    return DateFormat('dd/MM/yyyy').format(date);
  }

  Widget _buildDateSeparator(DateTime date, bool isDark) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : const Color(0xFFE2E8F0).withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          _formatDateHeader(date),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white70 : const Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(chatV2MessagesProvider(widget.channelId));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Lấy thông tin user hiện tại để hiển thị tên sạch của người đối diện
    final currentUser = ref.watch(authControllerProvider).valueOrNull;
    final currentUserName = (currentUser?.userMetadata['name'] ??
        currentUser?.userMetadata['display_name'] ??
        currentUser?.userMetadata['login'] ??
        '') as String?;
    final currentUserId = currentUser?.id;
    final currentPartnerId = currentUser?.userMetadata['partner_id']?.toString() ??
        currentUser?.userMetadata['partner']?['id']?.toString();

    // Lấy thông tin kênh từ cache nếu có (chỉ watch duy nhất kênh hiện tại)
    final currentChannel = ref.watch(chatV2ChannelsProvider.select(
      (async) => async.valueOrNull?.where((c) => c.id == widget.channelId).firstOrNull,
    ));
    final rawTitle = widget.title ?? currentChannel?.name ?? 'Trò chuyện';
    final displayTitle = currentChannel != null
        ? currentChannel.getCleanName(currentUserName)
        : (rawTitle.contains(',')
            ? rawTitle
                .split(',')
                .map((s) => s.trim())
                .where((s) =>
                    s.isNotEmpty &&
                    s.toLowerCase() != (currentUserName ?? '').toLowerCase())
                .firstOrNull ??
                rawTitle
            : rawTitle);

    final headerTextColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final messages = messagesAsync.valueOrNull ??
        ChatV2MessageLocalCache.get(widget.channelId) ??
        const [];

    // Fallback các cấp độ an toàn để xác định avatar của đối phương (tuyệt đối không lấy avatar của bản thân):
    String? resolvedAvatarUrl = currentChannel?.avatarUrl;
    if (resolvedAvatarUrl == null || resolvedAvatarUrl.isEmpty) {
      resolvedAvatarUrl = widget.initialAvatarUrl;
    }
    if (resolvedAvatarUrl == null || resolvedAvatarUrl.isEmpty) {
      final isGroup = currentChannel?.isGroup == true ||
          (currentChannel != null && currentChannel.getActualIsGroup(currentUserName));
      if (!isGroup && messages.isNotEmpty) {
        final otherMsg = messages.firstWhereOrNull((m) {
          if (m.isMine) return false;
          if (currentUserId != null && m.authorId == currentUserId) return false;
          if (currentPartnerId != null && m.authorId == currentPartnerId) return false;
          if (currentUserName != null && currentUserName.isNotEmpty) {
            if (m.authorName.trim().toLowerCase() == currentUserName.trim().toLowerCase()) return false;
          }
          return (m.authorAvatar != null && m.authorAvatar!.isNotEmpty);
        });
        if (otherMsg != null) {
          resolvedAvatarUrl = otherMsg.authorAvatar;
        }
      }
    }

    return PopScope(
      canPop: context.canPop(),
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          // ref.invalidate(chatV2ChannelsProvider);
        } else {
          // ref.invalidate(chatV2ChannelsProvider);
          context.go('/chat');
        }
      },
      child: Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        foregroundColor: headerTextColor,
        iconTheme: IconThemeData(color: headerTextColor),
        actionsIconTheme: IconThemeData(
          color: isDark ? Colors.white70 : const Color(0xFF475569),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : const Color(0xFFE2E8F0),
          ),
        ),
        leading: IconButton(
          icon: Icon(
            LucideIcons.chevronLeft,
            size: 24,
            color: headerTextColor,
          ),
          onPressed: () {
            // ref.invalidate(chatV2ChannelsProvider);
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/chat');
            }
          },
          tooltip: 'Quay lại',
        ),
        titleSpacing: 0,
        title: InkWell(
          onTap: () => _handleHeaderTap(context, currentChannel, isDark),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00C83A), Color(0xFF009D2E)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00C83A).withValues(alpha: 0.2),
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
                            displayTitle.isNotEmpty
                                ? displayTitle[0].toUpperCase()
                                : 'C',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        if (resolvedAvatarUrl != null && resolvedAvatarUrl.isNotEmpty)
                          Image.network(
                            resolvedAvatarUrl,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                            errorBuilder: (context, error, stackTrace) =>
                                const SizedBox.shrink(),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        displayTitle,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Consumer(
                        builder: (context, ref, _) {
                          final isActualGroup = currentChannel?.isGroup == true ||
                              (currentChannel != null &&
                                  currentChannel.getActualIsGroup(currentUserName));

                          if (isActualGroup) {
                            final count = (currentChannel?.memberCount ?? 0) > 0
                                ? currentChannel!.memberCount
                                : 2;
                            return Row(
                              children: [
                                Icon(
                                  LucideIcons.users,
                                  size: 13,
                                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$count thành viên',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            );
                          }

                          final partnerId = currentChannel?.partnerId;
                          final liveImStatus = partnerId != null
                              ? ref.watch(chatV2PresenceProvider.select((m) => m[partnerId]))
                              : null;
                          final imStatus = liveImStatus ?? (currentChannel?.imStatus ?? 'offline');
                          final Color statusColor;
                          final String statusLabel;

                          if (imStatus == 'online') {
                            statusColor = const Color(0xFF10B981);
                            statusLabel = 'Trực tuyến';
                          } else if (imStatus == 'away' || imStatus == 'idle') {
                            statusColor = const Color(0xFFF59E0B);
                            statusLabel = 'Tạm vắng';
                          } else {
                            statusColor = isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);
                            statusLabel = 'Ngoại tuyến';
                          }

                          return Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: statusColor,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                statusLabel,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? Colors.white60 : const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Container(
        color: isDark ? const Color(0xFF0B141B) : const Color(0xFFEFEAE2),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: WhatsAppDoodlePainter(isDark: isDark),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 760),
                        child: messagesAsync.when(
                          skipLoadingOnReload: true,
                          data: (messages) {
                            if (messages.isEmpty) {
                              return Center(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 68,
                                      height: 68,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF00C83A).withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        LucideIcons.messageSquare,
                                        color: Color(0xFF00C83A),
                                        size: 30,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Chưa có tin nhắn nào',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 32),
                                      child: Text(
                                        'Gửi tin nhắn hoặc chia sẻ hình ảnh, tài liệu để bắt đầu cuộc trò chuyện',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: isDark
                                              ? Colors.white60
                                              : const Color(0xFF64748B),
                                          height: 1.4,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            return ListView.builder(
                              controller: _scrollController,
                              reverse: true,
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                              itemCount: messages.length,
                              itemBuilder: (context, index) {
                                try {
                                  final message = messages[index];
                                  final isMine = message.isMine;
                                  final isActualGroup = currentChannel?.isGroup == true ||
                                      (currentChannel != null &&
                                          currentChannel.getActualIsGroup(currentUserName));

                                  // Tin nhắn cũ hơn (ở trên trong ListView reverse: true)
                                  final olderMsg = index < messages.length - 1
                                      ? messages[index + 1]
                                      : null;
                                  final showSenderName = isActualGroup &&
                                      !isMine &&
                                      (olderMsg == null ||
                                          olderMsg.authorId != message.authorId ||
                                          olderMsg.authorName != message.authorName);

                                  // Tin nhắn mới hơn (ở dưới trong ListView reverse: true)
                                  final newerMsg = index > 0
                                      ? messages[index - 1]
                                      : null;
                                  final showAvatar = isActualGroup &&
                                      !isMine &&
                                      (newerMsg == null ||
                                          newerMsg.authorId != message.authorId ||
                                          newerMsg.authorName != message.authorName);

                                  // Kiểm tra xem có cần chèn Date Separator không
                                  final isFirstOfGroup = olderMsg == null ||
                                      !_isSameDay(message.createdAt, olderMsg.createdAt);

                                  final itemWidget = ChatV2MessageItem(
                                    key: ValueKey('msg_${message.id}'),
                                    message: message,
                                    showSenderName: showSenderName,
                                    showAvatar: showAvatar,
                                    isGroup: isActualGroup,
                                    isHighlighted: message.id == _highlightedMessageId,
                                    onReplyTap: (parentId) {
                                      if (parentId != null) {
                                        _jumpToMessage(parentId);
                                      }
                                    },
                                    onLongPress: () {
                                      if (message.content.isEmpty) return;
                                    showModalBottomSheet(
                                      context: context,
                                      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                                      shape: const RoundedRectangleBorder(
                                        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                                      ),
                                      builder: (sheetContext) {
                                        return SafeArea(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              ListTile(
                                                leading: Icon(LucideIcons.reply, color: isDark ? Colors.white : Colors.black),
                                                title: Text('Trả lời', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                                                onTap: () {
                                                  Navigator.pop(sheetContext);
                                                  setState(() {
                                                    _editingMsg = null;
                                                    _replyingTo = message;
                                                    _inputFocusNode.requestFocus();
                                                  });
                                                },
                                              ),
                                              ListTile(
                                                leading: Icon(LucideIcons.copy, color: isDark ? Colors.white : Colors.black),
                                                title: Text('Sao chép văn bản', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                                                onTap: () {
                                                  Navigator.pop(sheetContext);
                                                  Clipboard.setData(ClipboardData(text: message.content));
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(content: Text('Đã sao chép văn bản')),
                                                  );
                                                },
                                              ),
                                              if (message.isMine)
                                                ListTile(
                                                  leading: Icon(LucideIcons.edit2, color: isDark ? Colors.white : Colors.black),
                                                  title: Text('Chỉnh sửa', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                                                  onTap: () {
                                                    Navigator.pop(sheetContext);
                                                    setState(() {
                                                      _replyingTo = null;
                                                      _editingMsg = message;
                                                      _inputController.text = message.content;
                                                      _inputFocusNode.requestFocus();
                                                    });
                                                  },
                                                ),
                                              if (message.isMine)
                                                ListTile(
                                                  leading: const Icon(LucideIcons.trash2, color: Colors.red),
                                                  title: const Text('Thu hồi', style: TextStyle(color: Colors.red)),
                                                  onTap: () async {
                                                    final messenger = ScaffoldMessenger.of(context);
                                                    Navigator.pop(sheetContext);
                                                    final confirmed = await showDialog<bool>(
                                                      context: context,
                                                      builder: (dialogCtx) => AlertDialog(
                                                        title: const Text('Thu hồi tin nhắn?'),
                                                        content: const Text(
                                                          'Bạn có chắc chắn muốn thu hồi tin nhắn này? Tin nhắn sẽ bị thu hồi đối với tất cả mọi người trong cuộc trò chuyện.',
                                                        ),
                                                        actions: [
                                                          TextButton(
                                                            onPressed: () => Navigator.pop(dialogCtx, false),
                                                            child: const Text('Hủy'),
                                                          ),
                                                          ElevatedButton(
                                                            style: ElevatedButton.styleFrom(
                                                              backgroundColor: Colors.red,
                                                              foregroundColor: Colors.white,
                                                            ),
                                                            onPressed: () => Navigator.pop(dialogCtx, true),
                                                            child: const Text('Thu hồi'),
                                                          ),
                                                        ],
                                                      ),
                                                    );

                                                    if (confirmed != true || !mounted) return;

                                                    try {
                                                      await ref.read(chatV2MessagesProvider(widget.channelId).notifier).deleteMessage(message.id);
                                                    } catch (e) {
                                                      if (mounted) {
                                                        messenger.showSnackBar(
                                                          SnackBar(content: Text('Lỗi thu hồi: $e')),
                                                        );
                                                      }
                                                    }
                                                  },
                                                ),
                                            ],
                                          ),
                                        );
                                      },
                                    );
                                  },
                                );

                                  if (isFirstOfGroup && message.createdAt != null) {
                                    return Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _buildDateSeparator(message.createdAt!, isDark),
                                        itemWidget,
                                      ],
                                    );
                                  }

                                  return itemWidget;
                                } catch (e, stack) {
                                  return Container(
                                    padding: const EdgeInsets.all(16),
                                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.red.shade200),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.error_outline, color: Colors.red, size: 32),
                                        const SizedBox(height: 8),
                                        Text(
                                          'Lỗi hiển thị tin nhắn:\n$e',
                                          style: const TextStyle(color: Colors.red, fontSize: 12),
                                          maxLines: 4,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 8),
                                        ElevatedButton.icon(
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                          icon: const Icon(Icons.copy, size: 16, color: Colors.white),
                                          label: const Text('Copy Lỗi', style: TextStyle(color: Colors.white)),
                                          onPressed: () {
                                            Clipboard.setData(ClipboardData(text: 'ItemBuilder Error:\n$e\n$stack'));
                                          },
                                        )
                                      ],
                                    ),
                                  );
                                }
                              },
                            );
                          },
                          loading: () => _buildSkeletonBubbles(isDark),
                          error: (error, stack) => Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    error.toString().contains('channel_not_found')
                                        ? LucideIcons.messageSquareDashed
                                        : LucideIcons.alertCircle,
                                    size: 40,
                                    color: error.toString().contains('channel_not_found')
                                        ? Colors.amber
                                        : Colors.redAccent,
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    error.toString().contains('channel_not_found')
                                        ? 'Cuộc hội thoại không tồn tại'
                                        : 'Không thể tải tin nhắn',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    error.toString().contains('channel_not_found')
                                        ? 'Kênh chat này không tồn tại trên hệ thống máy chủ hiện tại hoặc đã được dọn dẹp.'
                                        : '$error',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (error.toString().contains('channel_not_found'))
                                        ElevatedButton.icon(
                                          onPressed: () {
                                            ChatV2ChannelLocalCache.remove(widget.channelId);
                                            if (context.canPop()) {
                                              context.pop();
                                            } else {
                                              context.go('/chat');
                                            }
                                          },
                                          icon: const Icon(LucideIcons.arrowLeft, size: 16),
                                          label: const Text('Về danh sách'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF00C83A),
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                          ),
                                        )
                                      else ...[
                                        ElevatedButton.icon(
                                          onPressed: () {
                                            ref.invalidate(chatV2MessagesProvider(widget.channelId));
                                          },
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
                                        const SizedBox(width: 8),
                                        ElevatedButton.icon(
                                          onPressed: () {
                                            Clipboard.setData(ClipboardData(text: 'Lỗi tải tin nhắn: $error\n$stack'));
                                          },
                                          icon: const Icon(Icons.copy, size: 16),
                                          label: const Text('Copy Lỗi'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Consumer(
                    builder: (context, ref, _) {
                      final typingUsers = ref.watch(chatV2TypingProvider(widget.channelId));
                      if (typingUsers.isEmpty) return const SizedBox.shrink();
                      
                      final text = typingUsers.length == 1
                          ? '${typingUsers.first} đang gõ...'
                          : '${typingUsers.join(', ')} đang gõ...';
                          
                      return Padding(
                        padding: const EdgeInsets.only(left: 16, bottom: 4, top: 4),
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              text,
                              style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  if (_replyingTo != null || _editingMsg != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      color: isDark ? const Color(0xFF1E293B) : Colors.grey[100],
                      child: Row(
                        children: [
                          Icon(
                            _editingMsg != null ? LucideIcons.edit2 : LucideIcons.reply,
                            size: 16,
                            color: const Color(0xFF00C83A),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _editingMsg != null ? 'Đang sửa tin nhắn' : 'Đang trả lời ${_replyingTo!.authorName}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: Color(0xFF00C83A),
                                  ),
                                ),
                                Text(
                                  _editingMsg != null ? _editingMsg!.content : _replyingTo!.content,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isDark ? Colors.white70 : Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(LucideIcons.x, size: 18),
                            onPressed: () {
                              setState(() {
                                _replyingTo = null;
                                _editingMsg = null;
                                _inputController.clear();
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ChatV2InputBar(
                    channelId: widget.channelId,
                    controller: _inputController,
                    focusNode: _inputFocusNode,
                    onSend: _handleSendMessage,
                    onSendImage: _handleSendImage,
                    onSendFile: _handleSendFile,
                    isSending: _isSending,
                    onTyping: (isTyping) {
                      ref.read(chatV2RealtimeServiceProvider).sendTypingStatus(widget.channelId, isTyping);
                    },
                  ),
                ],
              ),
            ),
            if (_showScrollToBottom)
              Positioned(
                right: 16,
                bottom: 80,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _scrollToBottom,
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.18),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                        border: Border.all(
                          color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        LucideIcons.chevronDown,
                        size: 22,
                        color: isDark ? const Color(0xFF00C83A) : const Color(0xFF00A82D),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildSkeletonBubbles(bool isDark) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildSkeletonRow(isRight: false, widthFactor: 0.55, isDark: isDark),
        const SizedBox(height: 12),
        _buildSkeletonRow(isRight: false, widthFactor: 0.75, isDark: isDark),
        const SizedBox(height: 12),
        _buildSkeletonRow(isRight: true, widthFactor: 0.45, isDark: isDark),
        const SizedBox(height: 12),
        _buildSkeletonRow(isRight: true, widthFactor: 0.65, isDark: isDark),
        const SizedBox(height: 12),
        _buildSkeletonRow(isRight: false, widthFactor: 0.5, isDark: isDark),
      ],
    );
  }

  Widget _buildSkeletonRow({
    required bool isRight,
    required double widthFactor,
    required bool isDark,
  }) {
    final baseColor = isDark
        ? const Color(0xFF1E293B)
        : const Color(0xFFE2E8F0);
    return Row(
      mainAxisAlignment: isRight ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        if (!isRight) ...[
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: baseColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
        ],
        Container(
          width: MediaQuery.of(context).size.width * widthFactor,
          height: 38,
          decoration: BoxDecoration(
            color: isRight
                ? (isDark
                    ? const Color(0xFF00C83A).withValues(alpha: 0.2)
                    : const Color(0xFFDCFCE7))
                : baseColor,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ],
    );
  }

  void _handleHeaderTap(BuildContext context, ChatV2Channel? channel, bool isDark) {
    if (channel == null) return;
    final currentUser = ref.read(authControllerProvider).valueOrNull;
    final currentUserName = (currentUser?.userMetadata['name'] ??
        currentUser?.userMetadata['display_name'] ??
        currentUser?.userMetadata['login'] ??
        '') as String?;
    final messagesAsync = ref.read(chatV2MessagesProvider(widget.channelId));
    final currentMessages = messagesAsync.valueOrNull ??
        ChatV2MessageLocalCache.get(widget.channelId) ??
        [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return ChatV2InfoSheet(
          channel: channel,
          currentUserName: currentUserName,
          messages: currentMessages,
          onSearchTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Tính năng tìm kiếm trong hội thoại đang sẵn sàng'),
                duration: Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        );
      },
    );
  }
}

class WhatsAppDoodlePainter extends CustomPainter {
  final bool isDark;
  const WhatsAppDoodlePainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isDark
          ? Colors.white.withValues(alpha: 0.022)
          : const Color(0xFF4A5568).withValues(alpha: 0.045)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    const patternW = 180.0;
    const patternH = 180.0;

    for (double x = 0; x < size.width; x += patternW) {
      for (double y = 0; y < size.height; y += patternH) {
        canvas.save();
        canvas.translate(x, y);
        _drawCluster(canvas, paint);
        canvas.restore();
      }
    }
  }

  void _drawCluster(Canvas canvas, Paint paint) {
    // 1. Chat bubble
    final pathBubble = Path()
      ..moveTo(20, 20)
      ..lineTo(44, 20)
      ..quadraticBezierTo(50, 20, 50, 26)
      ..lineTo(50, 40)
      ..quadraticBezierTo(50, 46, 44, 46)
      ..lineTo(28, 46)
      ..lineTo(20, 54)
      ..lineTo(20, 46)
      ..quadraticBezierTo(14, 46, 14, 40)
      ..lineTo(14, 26)
      ..quadraticBezierTo(14, 20, 20, 20);
    canvas.drawPath(pathBubble, paint);

    // 2. Star
    final pathStar = Path()
      ..moveTo(90, 25)
      ..lineTo(94, 35)
      ..lineTo(105, 36)
      ..lineTo(97, 43)
      ..lineTo(100, 53)
      ..lineTo(90, 47)
      ..lineTo(80, 53)
      ..lineTo(83, 43)
      ..lineTo(75, 36)
      ..lineTo(86, 35)
      ..close();
    canvas.drawPath(pathStar, paint);

    // 3. Coffee cup
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(135, 25, 22, 18),
        const Radius.circular(4),
      ),
      paint,
    );
    canvas.drawArc(
      const Rect.fromLTWH(153, 28, 9, 12),
      -1.5,
      3.0,
      false,
      paint,
    );

    // 4. Paper plane
    final pathPlane = Path()
      ..moveTo(30, 95)
      ..lineTo(60, 80)
      ..lineTo(45, 115)
      ..lineTo(40, 100)
      ..close();
    canvas.drawPath(pathPlane, paint);

    // 5. Music note
    canvas.drawCircle(const Offset(100, 105), 4, paint);
    canvas.drawCircle(const Offset(118, 100), 4, paint);
    canvas.drawLine(const Offset(104, 105), const Offset(104, 85), paint);
    canvas.drawLine(const Offset(122, 100), const Offset(122, 80), paint);
    canvas.drawLine(const Offset(104, 85), const Offset(122, 80), paint);

    // 6. Smile emoji
    canvas.drawCircle(const Offset(150, 95), 11, paint);
    canvas.drawCircle(const Offset(146, 92), 1.5, paint);
    canvas.drawCircle(const Offset(154, 92), 1.5, paint);
    canvas.drawArc(
      const Rect.fromLTWH(145, 94, 10, 7),
      0.2,
      2.7,
      false,
      paint,
    );

    // 7. Cloud
    final pathCloud = Path()
      ..moveTo(30, 155)
      ..quadraticBezierTo(25, 145, 35, 140)
      ..quadraticBezierTo(45, 130, 60, 140)
      ..quadraticBezierTo(70, 142, 68, 155)
      ..close();
    canvas.drawPath(pathCloud, paint);

    // 8. Clock
    canvas.drawCircle(const Offset(110, 150), 9, paint);
    canvas.drawLine(const Offset(110, 150), const Offset(110, 145), paint);
    canvas.drawLine(const Offset(110, 150), const Offset(114, 150), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
