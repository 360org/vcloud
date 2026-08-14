import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../../../core/theme/app_theme.dart';
import '../../application/chat_v2_channels_controller.dart';
import '../../application/chat_v2_messages_controller.dart';
import '../widgets/chat_v2_input_bar.dart';
import '../widgets/chat_v2_message_item.dart';

class ChatV2DetailScreen extends ConsumerStatefulWidget {
  const ChatV2DetailScreen({
    super.key,
    required this.channelId,
    this.title,
  });

  final String channelId;
  final String? title;

  @override
  ConsumerState<ChatV2DetailScreen> createState() => _ChatV2DetailScreenState();
}

class _ChatV2DetailScreenState extends ConsumerState<ChatV2DetailScreen> {
  late final ScrollController _scrollController;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _handleSendMessage(String text) async {
    setState(() => _isSending = true);
    try {
      await ref
          .read(chatV2MessagesProvider(widget.channelId).notifier)
          .sendMessage(text);

      // Đợi frame build xong rồi cuộn xuống cuối
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
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _handleSendImage({
    required Uint8List bytes,
    required String filename,
    String? mimetype,
    String? caption,
  }) async {
    setState(() => _isSending = true);
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
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(chatV2MessagesProvider(widget.channelId));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Lấy thông tin kênh từ cache nếu có
    final channels = ref.watch(chatV2ChannelsProvider).valueOrNull ?? const [];
    final currentChannel = channels.where((c) => c.id == widget.channelId).firstOrNull;
    final displayTitle = widget.title ?? currentChannel?.name ?? 'Trò chuyện';

    return Scaffold(
      appBar: AppBar(
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => context.pop(),
        ),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: (currentChannel?.avatarUrl != null && currentChannel!.avatarUrl!.isNotEmpty)
                  ? ClipOval(
                      child: Image.network(
                        currentChannel.avatarUrl!,
                        width: 36,
                        height: 36,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Text(
                          displayTitle.isNotEmpty ? displayTitle[0].toUpperCase() : 'C',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    )
                  : Text(
                      displayTitle.isNotEmpty ? displayTitle[0].toUpperCase() : 'C',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    currentChannel?.isGroup == true
                        ? '${currentChannel?.memberNames.length ?? 0} thành viên'
                        : 'Trực tuyến',
                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.rotateCw, size: 20),
            tooltip: 'Làm mới',
            onPressed: () => ref.refresh(chatV2MessagesProvider(widget.channelId)),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Container(
                color: isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
                child: messagesAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  error: (error, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(LucideIcons.alertCircle, size: 40, color: Colors.redAccent),
                          const SizedBox(height: 8),
                          Text(
                            'Lỗi tải tin nhắn: $error',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 13, color: Colors.grey),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: () => ref.refresh(chatV2MessagesProvider(widget.channelId)),
                            child: const Text('Thử lại'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  data: (messages) {
                    if (messages.isEmpty) {
                      return const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.messageSquare, size: 48, color: Colors.grey),
                            SizedBox(height: 8),
                            Text(
                              'Chưa có tin nhắn nào',
                              style: TextStyle(color: Colors.grey, fontSize: 14),
                            ),
                          ],
                        ),
                      );
                    }

                    // Tự động cuộn xuống cuối khi nạp xong danh sách
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (_scrollController.hasClients &&
                          _scrollController.position.pixels == 0) {
                        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
                      }
                    });

                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        return ChatV2MessageItem(
                          message: msg,
                          showSenderName: currentChannel?.isGroup ?? false,
                        );
                      },
                    );
                  },
                ),
              ),
            ),
            ChatV2InputBar(
              onSend: _handleSendMessage,
              onSendImage: _handleSendImage,
              isSending: _isSending,
            ),
          ],
        ),
      ),
    );
  }
}
