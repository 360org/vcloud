import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/api/odoo_api_client.dart';
import '../../../auth/application/auth_controller.dart';
import '../../application/chat_v2_call_controller.dart';
import '../../application/chat_v2_channels_controller.dart';
import '../../data/models/chat_v2_channel.dart';
import '../../domain/models/chat_v2_call_session.dart';
import '../screens/chat_v2_call_screen.dart';
import '../screens/chat_v2_image_viewer_screen.dart';

/// Modal BottomSheet chứa Quick Action Menu cho Avatar người khác trong Chat V2.
/// Cung cấp 4 thao tác nhanh:
/// 1. Xem Profile đối tác (`/profile?partner_id=...`)
/// 2. Nhắn tin cá nhân (Tái sử dụng kênh 1-1 cũ: Cache 0ms ➔ Server fallback)
/// 3. Gọi thoại trực tiếp (WebRTC 1-1)
/// 4. Phóng to ảnh đại diện (Lightbox Pinch-to-Zoom + Lưu vào Thư viện)
class ChatV2AvatarActionSheet extends ConsumerStatefulWidget {
  final String partnerId;
  final String name;
  final String? avatarUrl;
  final String? role;
  final ChatV2Channel? currentChannel;

  const ChatV2AvatarActionSheet({
    super.key,
    required this.partnerId,
    required this.name,
    this.avatarUrl,
    this.role,
    this.currentChannel,
  });

  /// Hiển thị Action Sheet với cấu hình chống tràn viền toàn diện
  static Future<void> show(
    BuildContext context,
    WidgetRef ref, {
    required String partnerId,
    required String name,
    String? avatarUrl,
    String? role,
    ChatV2Channel? currentChannel,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChatV2AvatarActionSheet(
        partnerId: partnerId,
        name: name,
        avatarUrl: avatarUrl,
        role: role,
        currentChannel: currentChannel,
      ),
    );
  }

  /// Tái sử dụng hoặc tạo mới kênh Direct Chat theo cơ chế 2 tầng:
  /// Tầng 1: Local Cache (0ms) -> Tầng 2: Server Fallback (POST /api/v1/mobile/chat/direct)
  static Future<void> openDirectChat(
    BuildContext context,
    WidgetRef ref, {
    required String partnerId,
    required String name,
    String? avatarUrl,
  }) async {
    final targetPid = partnerId.trim();
    if (targetPid.isEmpty) return;

    try {
      // ── TẦNG 1: Local Cache (0ms) ──
      final cached = ChatV2ChannelLocalCache.cached;
      final existing = cached.where((c) {
        if (c.isGroup) return false;
        if (c.channelType != 'chat' && c.channelType != 'direct') return false;
        final pId = c.directPartnerId ?? c.partnerId;
        if (pId == targetPid) return true;
        return c.members.any((m) =>
            !m.isMe &&
            (m.partnerId?.toString() == targetPid || m.id == targetPid));
      }).firstOrNull;

      if (existing != null) {
        final qParams = <String, String>{
          if (name.isNotEmpty) 'name': name,
          if (avatarUrl != null && avatarUrl.isNotEmpty) 'avatar': avatarUrl,
          'partner_id': targetPid,
        };
        final qStr =
            qParams.isNotEmpty ? '?${Uri(queryParameters: qParams).query}' : '';
        context.push('/chat/${existing.id}$qStr');
        return;
      }

      // ── TẦNG 2: Server Fallback (POST /api/v1/mobile/chat/direct) ──
      final pIdInt = int.tryParse(targetPid);
      if (pIdInt == null) {
        throw Exception('ID đối tác không hợp lệ: $targetPid');
      }

      final res = await odooApiClient.post(
        '/api/v1/mobile/chat/direct',
        body: {'partner_id': pIdInt},
      );

      final map = (res is Map && res['data'] is Map)
          ? res['data']
          : (res is Map && res['result'] is Map ? res['result'] : res);

      if (map is! Map) throw Exception('Phản hồi tạo chat không hợp lệ');

      final channelId = map['id']?.toString() ?? map['channel_id']?.toString();
      if (channelId == null || channelId.isEmpty) {
        throw Exception('Phản hồi tạo chat thiếu channel ID');
      }

      final directCh = ChatV2Channel(
        id: channelId,
        name: name.isNotEmpty ? name : 'Trò chuyện',
        channelType: 'chat',
        isGroup: false,
        memberCount: 2,
        avatarUrl: avatarUrl,
        directPartnerId: targetPid,
        directPartnerName: name,
      );
      ChatV2ChannelLocalCache.pinDirectChannel(directCh);
      ChatV2ChannelLocalCache.updateChannel(directCh);

      final qParams = <String, String>{
        if (name.isNotEmpty) 'name': name,
        if (avatarUrl != null && avatarUrl.isNotEmpty) 'avatar': avatarUrl,
        'partner_id': targetPid,
      };
      final qStr =
          qParams.isNotEmpty ? '?${Uri(queryParameters: qParams).query}' : '';
      if (!context.mounted) return;
      context.push('/chat/$channelId$qStr');
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Không thể mở chat: ${e.toString().replaceAll("Exception: ", "")}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Khởi tạo cuộc gọi thoại 1-1 WebRTC trực tiếp tới thành viên
  static Future<void> startDirectCall(
    BuildContext context,
    WidgetRef ref, {
    required String partnerId,
    required String name,
    String? avatarUrl,
    ChatV2Channel? currentChannel,
  }) async {
    final currentCall = ref.read(chatV2CallControllerProvider);
    if (currentCall != null && currentCall.state != ChatV2CallState.idle) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bạn đang trong một cuộc gọi khác.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (!kIsWeb) {
      final micStatus = await Permission.microphone.request();
      if (!context.mounted) return;
      if (micStatus.isPermanentlyDenied) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
                'Ứng dụng cần quyền Micro để đàm thoại. Vui lòng mở Cài đặt thiết bị để cấp quyền.'),
            action: SnackBarAction(
              label: 'Cài đặt',
              onPressed: () => openAppSettings(),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      if (!micStatus.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Quyền Micro bị từ chối, không thể bắt đầu cuộc gọi thoại.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    final targetPid = partnerId.trim();
    final receiverId = int.tryParse(targetPid) ?? 0;
    if (receiverId == 0) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không thể xác định đối phương để kết nối cuộc gọi.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    int channelIdInt = 0;
    if (currentChannel != null && !currentChannel.isGroup) {
      channelIdInt = int.tryParse(currentChannel.id) ?? 0;
    }

    if (channelIdInt == 0) {
      final cached = ChatV2ChannelLocalCache.cached;
      final existing = cached.where((c) =>
          !c.isGroup &&
          (c.channelType == 'chat' || c.channelType == 'direct') &&
          (c.directPartnerId == targetPid || c.partnerId == targetPid)).firstOrNull;
      if (existing != null) {
        channelIdInt = int.tryParse(existing.id) ?? 0;
      }
    }

    if (channelIdInt == 0) {
      try {
        final res = await odooApiClient.post(
          '/api/v1/mobile/chat/direct',
          body: {'partner_id': receiverId},
        );
        final map = (res is Map && res['data'] is Map)
            ? res['data']
            : (res is Map && res['result'] is Map ? res['result'] : res);
        if (map is Map) {
          channelIdInt = int.tryParse(
                  map['id']?.toString() ?? map['channel_id']?.toString() ?? '0') ??
              0;
        }
      } catch (_) {}
    }

    final currentUser = ref.read(authControllerProvider).valueOrNull;
    final currentUserName = (currentUser?.userMetadata['name'] ??
        currentUser?.userMetadata['display_name'] ??
        currentUser?.userMetadata['login'] ??
        'Tôi') as String;
    final meta = currentUser?.userMetadata;
    final currentUserAvatar = meta?['avatar_128_url']?.toString() ??
        meta?['image_128_url']?.toString() ??
        (currentUser != null ? '/api/v1/mobile/avatar/users/${currentUser.id}' : null);

    if (!context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const ChatV2CallScreen(),
      ),
    );

    ref.read(chatV2CallControllerProvider.notifier).startCall(
          channelId: channelIdInt,
          callerName: currentUserName,
          callerAvatar: currentUserAvatar,
          receiverId: receiverId,
          receiverName: name,
          receiverAvatar: avatarUrl,
        );
  }

  @override
  ConsumerState<ChatV2AvatarActionSheet> createState() =>
      _ChatV2AvatarActionSheetState();
}

class _ChatV2AvatarActionSheetState
    extends ConsumerState<ChatV2AvatarActionSheet> {
  bool _isOpeningChat = false;
  bool _isDialing = false;

  String? _resolveFullAvatarUrl() {
    String? targetUrl = widget.avatarUrl;
    if (targetUrl == null || targetUrl.isEmpty) {
      if (widget.partnerId.isNotEmpty) {
        targetUrl = '/api/v1/mobile/avatar/res.partner/${widget.partnerId}';
      }
    }
    if (targetUrl == null || targetUrl.isEmpty) return null;
    return targetUrl.startsWith('http')
        ? targetUrl
        : odooApiClient.absoluteUrl(targetUrl);
  }

  void _openAvatarZoom(BuildContext context) {
    final fullUrl = _resolveFullAvatarUrl();
    if (fullUrl == null || fullUrl.isEmpty) return;

    Navigator.of(context).push(
      ChatV2ImageViewerScreen.route(
        imageUrl: fullUrl,
        title: widget.name,
      ),
    );
  }

  void _openProfile(BuildContext context) {
    Navigator.of(context).pop();
    final queryParams = <String, String>{
      'partner_id': widget.partnerId,
      if (widget.name.isNotEmpty) 'name': widget.name,
      if (widget.avatarUrl != null && widget.avatarUrl!.isNotEmpty)
        'avatar': widget.avatarUrl!,
      if (widget.role != null && widget.role!.isNotEmpty)
        'role': widget.role!,
    };
    final qStr = Uri(queryParameters: queryParams).query;
    context.push('/profile?$qStr');
  }

  Future<void> _openDirectChat(BuildContext context) async {
    if (_isOpeningChat) return;
    setState(() => _isOpeningChat = true);
    Navigator.of(context).pop();
    await ChatV2AvatarActionSheet.openDirectChat(
      context,
      ref,
      partnerId: widget.partnerId,
      name: widget.name,
      avatarUrl: widget.avatarUrl,
    );
  }

  Future<void> _startDirectCall(BuildContext context) async {
    if (_isDialing) return;
    setState(() => _isDialing = true);
    Navigator.of(context).pop();
    await ChatV2AvatarActionSheet.startDirectCall(
      context,
      ref,
      partnerId: widget.partnerId,
      name: widget.name,
      avatarUrl: widget.avatarUrl,
      currentChannel: widget.currentChannel,
    );
  }

  Widget _buildActionTile(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool isDark,
    bool isLoading = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDark ? 0.2 : 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: isLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(color),
                          ),
                        )
                      : Icon(icon, color: color, size: 22),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
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
              Icon(
                LucideIcons.chevronRight,
                size: 18,
                color: isDark ? Colors.white30 : const Color(0xFF94A3B8),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final initial = widget.name.trim().isNotEmpty
        ? widget.name.trim()[0].toUpperCase()
        : 'U';
    final colors = [const Color(0xFF0077CD), const Color(0xFF00C83A)];

    return SafeArea(
      child: SingleChildScrollView(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: () => _openAvatarZoom(context),
                      child: Stack(
                        children: [
                          Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: colors,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: colors.first.withValues(alpha: 0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  Center(
                                    child: Text(
                                      initial,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 28,
                                      ),
                                    ),
                                  ),
                                  if (widget.avatarUrl != null &&
                                      widget.avatarUrl!.isNotEmpty)
                                    Image.network(
                                      widget.avatarUrl!,
                                      width: 76,
                                      height: 76,
                                      fit: BoxFit.cover,
                                      headers: odooApiClient.authHeaders,
                                      gaplessPlayback: true,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              const SizedBox.shrink(),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: const BoxDecoration(
                                color: Color(0xFF00C83A),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                LucideIcons.maximize2,
                                size: 11,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.name,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.role ?? 'Thành viên · 360 CORP',
                      style: TextStyle(
                        fontSize: 13,
                        color:
                            isDark ? Colors.white60 : const Color(0xFF64748B),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Divider(
                height: 1,
                thickness: 1,
                color:
                    isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
              ),
              const SizedBox(height: 6),
              _buildActionTile(
                context,
                icon: LucideIcons.user,
                color: const Color(0xFF2563EB),
                title: 'Xem hồ sơ',
                subtitle: 'Xem chi tiết thông tin cá nhân',
                onTap: () => _openProfile(context),
                isDark: isDark,
              ),
              _buildActionTile(
                context,
                icon: LucideIcons.messageSquare,
                color: const Color(0xFF00C83A),
                title: 'Nhắn tin cá nhân',
                subtitle: 'Trò chuyện trực tiếp 1-1',
                isLoading: _isOpeningChat,
                onTap: () => _openDirectChat(context),
                isDark: isDark,
              ),
              _buildActionTile(
                context,
                icon: LucideIcons.phone,
                color: const Color(0xFF0D9488),
                title: 'Gọi thoại',
                subtitle: 'Cuộc gọi đàm thoại WebRTC 1-1',
                isLoading: _isDialing,
                onTap: () => _startDirectCall(context),
                isDark: isDark,
              ),
              _buildActionTile(
                context,
                icon: LucideIcons.image,
                color: const Color(0xFF8B5CF6),
                title: 'Xem ảnh đại diện',
                subtitle: 'Phóng to và lưu ảnh vào máy',
                onTap: () => _openAvatarZoom(context),
                isDark: isDark,
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
