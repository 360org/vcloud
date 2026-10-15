import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../application/livechat_controller.dart';
import '../../data/models/livechat_channel_model.dart';
import '../../data/models/livechat_session_model.dart';
import '../../../chat_v2/application/chat_v2_channels_controller.dart';

class LivechatSelectionBottomSheet extends ConsumerStatefulWidget {
  const LivechatSelectionBottomSheet({super.key});

  /// Phương thức tĩnh mở BottomSheet nhanh chóng và tiện lợi
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const LivechatSelectionBottomSheet(),
    );
  }

  @override
  ConsumerState<LivechatSelectionBottomSheet> createState() => _LivechatSelectionBottomSheetState();
}

class _LivechatSelectionBottomSheetState extends ConsumerState<LivechatSelectionBottomSheet> {
  int? _connectingChannelId;

  Future<void> _handleChannelSelect(LivechatChannelModel channel) async {
    if (_connectingChannelId != null) return;

    setState(() => _connectingChannelId = channel.id);

    try {
      final LivechatSessionModel session = await ref.read(livechatControllerProvider).openSession(
            channelId: channel.id,
          );

      if (!mounted) return;

      // Đóng BottomSheet
      Navigator.of(context).pop();

      // Cập nhật danh sách kênh chat
      ref.invalidate(chatV2ChannelsProvider);

      // Điều hướng 1-Touch thẳng vào phòng chat
      final encodedName = Uri.encodeComponent(session.channelName);
      final encodedAvatar = Uri.encodeComponent(session.avatarUrl ?? '');
      context.push('/chat/${session.channelId}?name=$encodedName&avatar=$encodedAvatar');
    } catch (e) {
      if (!mounted) return;
      setState(() => _connectingChannelId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể kết nối kênh hỗ trợ: ${e.toString().replaceAll("Exception: ", "")}'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final channelsAsync = ref.watch(livechatChannelsProvider);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header Title & Close Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'TRUNG TÂM HỖ TRỢ TRỰC TUYẾN',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: Color(0xFF0F172A), // Slate 900
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Vui lòng chọn bộ phận tiếp nhận để được hỗ trợ tốt nhất',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(LucideIcons.x, size: 20, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.of(context).pop(),
                    splashRadius: 20,
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            // Channel List
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: channelsAsync.when(
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: CircularProgressIndicator(color: Color(0xFF0077CD)),
                  ),
                ),
                error: (err, _) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Column(
                    children: [
                      Icon(LucideIcons.circleAlert, size: 40, color: Colors.orange.shade400),
                      const SizedBox(height: 12),
                      Text(
                        'Không thể tải danh sách kênh hỗ trợ',
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () => ref.refresh(livechatChannelsProvider),
                        icon: const Icon(LucideIcons.refreshCw, size: 16),
                        label: const Text('Thử lại'),
                      ),
                    ],
                  ),
                ),
                data: (channels) {
                  if (channels.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Column(
                        children: [
                          Icon(LucideIcons.messageSquareDashed, size: 44, color: Colors.grey.shade400),
                          const SizedBox(height: 12),
                          Text(
                            'Hiện chưa có kênh hỗ trợ trực tuyến nào được kích hoạt',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    );
                  }

                  return Column(
                    children: channels.map((channel) {
                      final isConnecting = _connectingChannelId == channel.id;
                      return _buildChannelCard(context, channel, isConnecting);
                    }).toList(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChannelCard(
    BuildContext context,
    LivechatChannelModel channel,
    bool isConnecting,
  ) {
    final isOnline = channel.isAvailable;
    final statusColor = isOnline ? const Color(0xFF00CE2C) : const Color(0xFF94A3B8); // Digital Green vs Slate 400
    final statusText = isOnline
        ? '🟢 Đang có chuyên viên trực ca • Phản hồi ~2 phút'
        : '⚪ Tiếp nhận 24/7 • Phản hồi qua thông báo';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC), // Slate 50
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)), // Slate 200
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: isConnecting ? null : () => _handleChannelSelect(channel),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar / Icon Kênh
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE), // Light Tech Blue
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Icon(
                      channel.name.toLowerCase().contains('tech')
                          ? LucideIcons.wrench
                          : LucideIcons.headset,
                      color: const Color(0xFF0077CD), // Tech Royal Blue
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Nội dung thông tin kênh
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              channel.name,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        channel.description,
                        style: const TextStyle(
                          fontSize: 12.5,
                          height: 1.35,
                          color: Color(0xFF475569), // Slate 600
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Divider(height: 1, color: Color(0xFFE2E8F0)),
                      const SizedBox(height: 8),
                      Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: isOnline ? const Color(0xFF059669) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),

                // Indicator kết nối
                if (isConnecting)
                  const Padding(
                    padding: EdgeInsets.only(left: 8, top: 10),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF0077CD),
                      ),
                    ),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.only(left: 8, top: 10),
                    child: Icon(
                      LucideIcons.chevronRight,
                      size: 18,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
