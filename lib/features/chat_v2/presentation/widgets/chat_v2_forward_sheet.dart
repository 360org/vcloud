import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../../../core/api/odoo_api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/application/auth_controller.dart';
import '../../application/chat_v2_channels_controller.dart';
import '../../application/chat_v2_messages_controller.dart';
import '../../data/chat_v2_repository.dart';
import '../../data/models/chat_v2_channel.dart';
import '../../data/models/chat_v2_message.dart';

/// Sheet chuyển tiếp tin nhắn (Forward Message) sang cuộc trò chuyện khác
class ChatV2ForwardSheet extends ConsumerStatefulWidget {
  final ChatV2Message message;

  const ChatV2ForwardSheet({
    super.key,
    required this.message,
  });

  @override
  ConsumerState<ChatV2ForwardSheet> createState() => _ChatV2ForwardSheetState();
}

class _ChatV2ForwardSheetState extends ConsumerState<ChatV2ForwardSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  final Set<String> _sendingChannelIds = {};

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _forwardToChannel(ChatV2Channel targetChannel) async {
    final targetChannelId = targetChannel.id;
    if (_sendingChannelIds.contains(targetChannelId)) return;

    setState(() {
      _sendingChannelIds.add(targetChannelId);
    });

    try {
      final repo = ref.read(chatV2RepositoryProvider);
      final user = ref.read(authControllerProvider).valueOrNull;
      final meta = user?.userMetadata;
      final partnerId = meta?['partner_id']?.toString() ??
          meta?['partner']?['id']?.toString();
      final userId = user?.id;
      final userName = meta?['name']?.toString() ?? 'Tôi';

      final attachmentIds = widget.message.attachments
          .map((a) => int.tryParse(a.id))
          .whereType<int>()
          .toList();

      final sent = await repo.sendMessage(
        targetChannelId,
        widget.message.content,
        attachmentIds: attachmentIds.isNotEmpty ? attachmentIds : null,
        currentPartnerId: partnerId,
        currentUserId: userId,
        authorName: userName,
      );

      final snippet = widget.message.content.isNotEmpty
          ? widget.message.content
          : (widget.message.attachments.isNotEmpty ? '[Đính kèm]' : '');

      ChatV2ChannelLocalCache.updateChannelLastMessage(
        targetChannelId,
        lastMessage: snippet,
        lastMessageDate: DateTime.now(),
        authorId: partnerId ?? userId,
        authorName: userName,
        unreadCount: 0,
      );

      try {
        ref.read(chatV2ChannelsProvider.notifier).updateChannelSnippet(
              targetChannelId,
              lastMessage: snippet,
              lastMessageDate: DateTime.now(),
              authorId: partnerId ?? userId,
              authorName: userName,
            );
      } catch (_) {}

      ChatV2MessageLocalCache.prepend(targetChannelId, sent);

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã chuyển tiếp tin nhắn thành công'),
          backgroundColor: AppColors.primary,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sendingChannelIds.remove(targetChannelId);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi khi chuyển tiếp: $e'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final channelsAsync = ref.watch(chatV2ChannelsProvider);
    final allChannels = channelsAsync.valueOrNull ?? ChatV2ChannelLocalCache.cached;

    final filteredChannels = allChannels.where((c) {
      if (c.id == widget.message.channelId) return false;
      if (_query.isEmpty) return true;
      final name = c.name.toLowerCase();
      return name.contains(_query.toLowerCase());
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Chuyển tiếp tin nhắn',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.x, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  LucideIcons.forward,
                  size: 16,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.message.content.isNotEmpty
                        ? widget.message.content
                        : (widget.message.attachments.isNotEmpty
                            ? '[Tệp đính kèm]'
                            : 'Tin nhắn'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              onChanged: (val) {
                setState(() {
                  _query = val.trim();
                });
              },
              decoration: InputDecoration(
                hintText: 'Tìm kiếm cuộc trò chuyện...',
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
                prefixIcon: const Icon(LucideIcons.search, size: 18),
                filled: true,
                fillColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: filteredChannels.isEmpty
                ? Center(
                    child: Text(
                      _query.isEmpty
                          ? 'Không có cuộc trò chuyện nào gần đây'
                          : 'Không tìm thấy cuộc trò chuyện phù hợp',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: filteredChannels.length,
                    separatorBuilder: (_, _) => const Divider(
                      height: 1,
                      indent: 68,
                    ),
                    itemBuilder: (context, index) {
                      final channel = filteredChannels[index];
                      final isSending = _sendingChannelIds.contains(channel.id);
                      final avatarUrl = channel.avatarUrl ?? channel.directPartnerAvatar;
                      final displayName = channel.name.isNotEmpty
                          ? channel.name
                          : 'Trò chuyện';

                      return ListTile(
                        leading: CircleAvatar(
                          radius: 20,
                          backgroundColor: channel.isGroup
                              ? const Color(0xFF3B82F6)
                              : const Color(0xFF10B981),
                          backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                              ? NetworkImage(
                                  avatarUrl,
                                  headers: odooApiClient.authHeaders,
                                )
                              : null,
                          child: (avatarUrl == null || avatarUrl.isEmpty)
                              ? (channel.isGroup
                                  ? const Icon(LucideIcons.users, size: 18, color: Colors.white)
                                  : Text(
                                      displayName.isNotEmpty
                                          ? displayName[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ))
                              : null,
                        ),
                        title: Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: channel.lastMessage != null && channel.lastMessage!.isNotEmpty
                            ? Text(
                                channel.lastMessage!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: isDark ? Colors.white54 : Colors.black54,
                                ),
                              )
                            : null,
                        trailing: isSending
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : ElevatedButton(
                                onPressed: () => _forwardToChannel(channel),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  visualDensity: VisualDensity.compact,
                                ),
                                child: const Text(
                                  'Gửi',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                        onTap: isSending ? null : () => _forwardToChannel(channel),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
