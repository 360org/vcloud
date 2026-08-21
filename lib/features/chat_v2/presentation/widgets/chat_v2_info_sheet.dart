import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/api/odoo_api_client.dart';
import '../../../../core/utils/file_download.dart';
import '../../../../core/utils/local_attachment_cache.dart';
import '../../application/chat_v2_channels_controller.dart';
import '../../data/chat_v2_repository.dart';
import '../../data/models/chat_v2_channel.dart';
import '../../data/models/chat_v2_message.dart';
import '../screens/chat_v2_image_viewer_screen.dart';
import 'chat_v2_message_item.dart';

class ChatV2InfoSheet extends ConsumerStatefulWidget {
  final ChatV2Channel channel;
  final String? currentUserName;
  final List<ChatV2Message> messages;
  final VoidCallback? onSearchTap;

  const ChatV2InfoSheet({
    super.key,
    required this.channel,
    this.currentUserName,
    this.messages = const [],
    this.onSearchTap,
  });

  static const List<List<Color>> _avatarGradients = [
    [Color(0xFF00C83A), Color(0xFF009D2E)],
    [Color(0xFF2563EB), Color(0xFF1D4ED8)],
    [Color(0xFF7C3AED), Color(0xFF6D28D9)],
    [Color(0xFFEA580C), Color(0xFFC2410C)],
    [Color(0xFF0D9488), Color(0xFF0F766E)],
    [Color(0xFFE11D48), Color(0xFFBE123C)],
    [Color(0xFF4F46E5), Color(0xFF4338CA)],
    [Color(0xFF059669), Color(0xFF047857)],
  ];

  static List<Color> getAvatarGradient(String name) {
    if (name.isEmpty) return _avatarGradients[0];
    final hash = name.codeUnits.fold(0, (acc, c) => acc + c);
    return _avatarGradients[hash % _avatarGradients.length];
  }

  static String getInitial(String name) {
    final clean = name.trim();
    if (clean.isEmpty) return 'U';
    final parts = clean.split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return clean[0].toUpperCase();
  }

  @override
  ConsumerState<ChatV2InfoSheet> createState() => _ChatV2InfoSheetState();
}

class _ChatV2InfoSheetState extends ConsumerState<ChatV2InfoSheet> {
  bool _isMuted = false;
  bool _isPinned = false;
  bool _isLeaving = false;
  bool _isLoadingMembers = false;

  List<ChatV2Member> _members = [];
  int _memberCount = 0;

  // Extracted media collections
  final List<ChatV2Attachment> _images = [];
  final List<ChatV2Attachment> _files = [];
  final List<String> _links = [];

  @override
  void initState() {
    super.initState();
    _isPinned = ChatV2ChannelLocalCache.isUserPinned(widget.channel.id);
    _initMembers();
    _extractMedia();
    _loadRemoteMembers();
  }

  void _initMembers() {
    if (widget.channel.members.isNotEmpty) {
      _members = List.from(widget.channel.members);
    } else if (widget.channel.memberNames.isNotEmpty) {
      _members = widget.channel.memberNames
          .map((name) => ChatV2Member(id: '', name: name))
          .toList();
    }
    _memberCount = widget.channel.memberCount > _members.length
        ? widget.channel.memberCount
        : _members.length;
  }

  Future<void> _loadRemoteMembers() async {
    final isGroup = widget.channel.getActualIsGroup(widget.currentUserName);
    if (!isGroup) return;

    // 1. Khởi tạo ngay từ local cache nếu channel đã có danh sách members/memberNames
    final cached = ChatV2ChannelLocalCache.cached
        .firstWhereOrNull((c) => c.id == widget.channel.id);
    if (cached != null) {
      if (cached.members.isNotEmpty && _members.length < cached.members.length) {
        setState(() {
          _members = List.from(cached.members);
          _memberCount = _members.length;
        });
      } else if (cached.memberNames.isNotEmpty && _members.isEmpty) {
        setState(() {
          _members = cached.memberNames
              .map((n) => ChatV2Member(id: '', name: n))
              .toList();
          _memberCount = _members.length;
        });
      }
    }

    setState(() => _isLoadingMembers = true);
    try {
      final remoteMembers = await ref
          .read(chatV2RepositoryProvider)
          .fetchChannelMembers(widget.channel.id);
      if (mounted && remoteMembers.isNotEmpty) {
        setState(() {
          _members = remoteMembers;
          _memberCount = remoteMembers.length;
          _isLoadingMembers = false;
        });
      }
    } catch (_) {
      // Ignored
    } finally {
      if (mounted) {
        setState(() => _isLoadingMembers = false);
      }
    }
  }

  void _extractMedia() {
    final linkRegex = RegExp(
      r'((?:https?:\/\/|www\.)[^\s<]+|(?:[a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}(?:\/[^\s<]*)?)',
      caseSensitive: false,
    );
    final imgTagRegex = RegExp(
      r'<img[^>]+src=["' "'" r']([^"' "'" r']+)["' "'" r']',
      caseSensitive: false,
    );

    for (final msg in widget.messages) {
      // 1. Formal Attachments
      for (final att in msg.attachments) {
        final existingBytes = att.bytes ??
            ChatV2AttachmentImage.imageCache[att.id] ??
            ChatV2AttachmentImage.imageCache[att.name] ??
            ChatV2AttachmentImage.imageCache[msg.id] ??
            LocalAttachmentCache.get(att.id.isNotEmpty ? att.id : null, altKey: att.name);
        final resolvedAtt = existingBytes != null && (att.bytes == null || att.bytes!.isEmpty)
            ? att.copyWith(bytes: existingBytes)
            : att;

        if (resolvedAtt.isImage) {
          if (!_images.any((x) =>
              (x.id.isNotEmpty && resolvedAtt.id.isNotEmpty && x.id == resolvedAtt.id))) {
            _images.add(resolvedAtt);
          }
        } else {
          if (!_files.any((x) =>
              (x.id.isNotEmpty && resolvedAtt.id.isNotEmpty && x.id == resolvedAtt.id))) {
            _files.add(resolvedAtt);
          }
        }
      }

      // 2. Filename-based content (Images / Documents stored as message text)
      if (msg.attachments.isEmpty) {
        final cleanName = msg.content.trim();
        final memoryBytes = ChatV2AttachmentImage.imageCache[cleanName] ??
            ChatV2AttachmentImage.imageCache[msg.id] ??
            LocalAttachmentCache.get(null, altKey: cleanName);

        if (msg.isImageFilename) {
          final att = ChatV2Attachment(
            id: msg.id,
            name: cleanName,
            url: '',
            bytes: memoryBytes,
            mimetype: 'image/jpeg',
          );
          if (!_images.any((x) => x.name == att.name || (x.id.isNotEmpty && x.id == att.id))) {
            _images.add(att);
          }
        } else if (msg.isDocumentFilename) {
          final att = ChatV2Attachment(
            id: msg.id,
            name: cleanName,
            url: '',
            bytes: memoryBytes,
            mimetype: 'application/octet-stream',
          );
          if (!_files.any((x) => x.name == att.name || (x.id.isNotEmpty && x.id == att.id))) {
            _files.add(att);
          }
        }
      }

      // 3. HTML <img> tags in body
      final imgMatches = imgTagRegex.allMatches(msg.content);
      for (final m in imgMatches) {
        final src = m.group(1);
        if (src != null && src.isNotEmpty && !_images.any((x) => x.url == src)) {
          _images.add(
            ChatV2Attachment(
              id: '',
              name: 'Hình ảnh',
              url: src,
              mimetype: 'image/jpeg',
            ),
          );
        }
      }

      // 4. Links in text
      if (!msg.isImageFilename && !msg.isDocumentFilename) {
        final matches = linkRegex.allMatches(msg.content);
        for (final m in matches) {
          var url = m.group(0);
          if (url != null) {
            final punctRegex = RegExp(r'[.,!?:;)"\x27\]]+$');
            final punctMatch = punctRegex.firstMatch(url);
            if (punctMatch != null) {
              url = url.substring(0, url.length - punctMatch.group(0)!.length);
            }

            final cleanUrl = url.trim();
            final lower = cleanUrl.toLowerCase();

            final isFileExt = lower.endsWith('.csv') ||
                lower.endsWith('.pdf') ||
                lower.endsWith('.doc') ||
                lower.endsWith('.docx') ||
                lower.endsWith('.xls') ||
                lower.endsWith('.xlsx') ||
                lower.endsWith('.ppt') ||
                lower.endsWith('.pptx') ||
                lower.endsWith('.zip') ||
                lower.endsWith('.txt');

            final isDirectImgUrl = lower.endsWith('.png') ||
                lower.endsWith('.jpg') ||
                lower.endsWith('.jpeg') ||
                lower.endsWith('.webp') ||
                lower.endsWith('.gif') ||
                lower.endsWith('.svg');

            if (isDirectImgUrl) {
              final fileName = cleanUrl.split('/').last;
              if (!_images.any((x) => x.url == cleanUrl || x.name == fileName)) {
                _images.add(
                  ChatV2Attachment(
                    id: '',
                    name: fileName,
                    url: cleanUrl,
                    mimetype: 'image/jpeg',
                  ),
                );
              }
            } else if (!isFileExt && cleanUrl.isNotEmpty) {
              if (!_links.contains(cleanUrl)) {
                _links.add(cleanUrl);
              }
            }
          }
        }
      }
    }
  }

  void _toggleMute() {
    HapticFeedback.lightImpact();
    setState(() {
      _isMuted = !_isMuted;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isMuted
              ? 'Đã tắt thông báo cuộc trò chuyện'
              : 'Đã bật thông báo cuộc trò chuyện',
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _togglePin() {
    HapticFeedback.lightImpact();
    ChatV2ChannelLocalCache.toggleUserPin(widget.channel.id);
    setState(() {
      _isPinned = !_isPinned;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isPinned
              ? 'Đã ghim cuộc trò chuyện lên đầu'
              : 'Đã bỏ ghim cuộc trò chuyện',
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _copyChannelLink() {
    HapticFeedback.lightImpact();
    final link = 'https://vuahethong.net/chat/${widget.channel.id}';
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã sao chép liên kết cuộc trò chuyện'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _openMediaHub() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatV2MediaHubScreen(
          channelName: widget.channel.getCleanName(widget.currentUserName),
          images: _images,
          files: _files,
          links: _links,
        ),
      ),
    );
  }

  Future<void> _handleLeaveGroup() async {
    final cleanName = widget.channel.getCleanName(widget.currentUserName);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(LucideIcons.logOut, color: Color(0xFFEF4444), size: 22),
            SizedBox(width: 8),
            Text('Rời nhóm?', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
          ],
        ),
        content: Text(
          'Bạn có chắc chắn muốn rời khỏi nhóm "$cleanName" không? Bạn sẽ không còn nhận được thông báo hay tin nhắn từ nhóm này.',
          style: const TextStyle(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Rời nhóm', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLeaving = true);
    try {
      final repo = ref.read(chatV2RepositoryProvider);
      await repo.leaveChannel(widget.channel.id);

      if (mounted) {
        ref.invalidate(chatV2ChannelsProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã rời khỏi nhóm trò chuyện thành công'),
            backgroundColor: Color(0xFF00C83A),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
        // Pop info sheet & navigate back to chat list
        Navigator.of(context).pop();
        if (context.mounted) context.go('/chat');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể rời nhóm: $e'),
            backgroundColor: const Color(0xFFEF4444),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLeaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isGroup = widget.channel.getActualIsGroup(widget.currentUserName);
    final cleanName = widget.channel.getCleanName(widget.currentUserName);
    final avatarGrad = ChatV2InfoSheet.getAvatarGradient(cleanName);
    final isOnline = widget.channel.imStatus == 'online';

    final effectiveMemberCount = _members.length > _memberCount
        ? _members.length
        : (_memberCount > 0 ? _memberCount : _members.length);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B1120) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            LucideIcons.arrowLeft,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(
          isGroup ? 'Tùy chọn nhóm' : 'Tùy chọn hội thoại',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              LucideIcons.pencil,
              size: 19,
              color: isDark ? Colors.white70 : const Color(0xFF475569),
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Tính năng đổi tên & ảnh nhóm đang sẵn sàng'),
                  duration: Duration(seconds: 2),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(
            height: 1,
            thickness: 1,
            color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── 1. HEADER PROFILE CARD ──
              Center(
                child: Column(
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: avatarGrad,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: avatarGrad.first.withValues(alpha: 0.3),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
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
                                    cleanName.isNotEmpty ? cleanName[0].toUpperCase() : 'C',
                                    style: const TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                if (widget.channel.avatarUrl != null &&
                                    widget.channel.avatarUrl!.isNotEmpty)
                                  Image.network(
                                    widget.channel.avatarUrl!,
                                    width: 84,
                                    height: 84,
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
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                LucideIcons.users,
                                size: 14,
                                color: Color(0xFF00C83A),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Name
                    Text(
                      cleanName,
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // Subtitle
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!isGroup) ...[
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color: isOnline ? const Color(0xFF22C55E) : Colors.grey,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isOnline ? 'Đang trực tuyến' : 'Ngoại tuyến',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                              color: isOnline
                                  ? const Color(0xFF22C55E)
                                  : (isDark ? Colors.white60 : const Color(0xFF64748B)),
                            ),
                          ),
                        ] else ...[
                          Icon(
                            LucideIcons.users,
                            size: 14,
                            color: isDark ? Colors.white60 : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Nhóm trò chuyện • $effectiveMemberCount thành viên',
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white60 : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // ── 2. QUICK ACTION BUTTONS ROW ──
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildCircularAction(
                    isDark: isDark,
                    icon: LucideIcons.search,
                    label: 'Tìm tin nhắn',
                    onTap: () {
                      Navigator.maybePop(context);
                      widget.onSearchTap?.call();
                    },
                  ),
                  _buildCircularAction(
                    isDark: isDark,
                    icon: _isMuted ? LucideIcons.bellOff : LucideIcons.bell,
                    label: _isMuted ? 'Đã tắt chuông' : 'Tắt thông báo',
                    isActive: _isMuted,
                    onTap: _toggleMute,
                  ),
                  if (isGroup)
                    _buildCircularAction(
                      isDark: isDark,
                      icon: LucideIcons.userPlus,
                      label: 'Thêm thành viên',
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Tính năng mời thành viên mới đang mở'),
                            duration: Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                  _buildCircularAction(
                    isDark: isDark,
                    icon: LucideIcons.link,
                    label: 'Chia sẻ link',
                    onTap: _copyChannelLink,
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // ── 3. GROUPED CARD 1: ẢNH, FILE, LINK ĐÃ GỬI ──
              _buildCardContainer(
                isDark: isDark,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: _openMediaHub,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Ảnh, file, link đã gửi',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF00C83A),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_images.length} ảnh, ${_files.length} file, ${_links.length} link',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w500,
                                      color: isDark ? Colors.white60 : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              LucideIcons.chevronRight,
                              size: 18,
                              color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Image Preview Row (if any images exist)
                    if (_images.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                        child: SizedBox(
                          height: 64,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _images.length > 6 ? 6 : _images.length,
                            separatorBuilder: (_, _) => const SizedBox(width: 8),
                            itemBuilder: (ctx, idx) {
                              final img = _images[idx];
                              final memBytes = img.bytes ??
                                  ChatV2AttachmentImage.imageCache[img.id] ??
                                  ChatV2AttachmentImage.imageCache[img.name] ??
                                  LocalAttachmentCache.get(img.id.isNotEmpty ? img.id : null, altKey: img.name);
                              final fullUrl = img.resolveFullUrl(odooApiClient.absoluteUrl(''));

                              return GestureDetector(
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => ChatV2ImageViewerScreen(
                                        imageUrl: fullUrl,
                                        title: img.name,
                                        bytes: memBytes,
                                        attachmentId: img.id.isNotEmpty ? img.id : null,
                                      ),
                                    ),
                                  );
                                },
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    width: 64,
                                    height: 64,
                                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                    child: memBytes != null && memBytes.isNotEmpty
                                        ? Image.memory(
                                            memBytes,
                                            fit: BoxFit.cover,
                                            gaplessPlayback: true,
                                          )
                                        : (fullUrl.isNotEmpty
                                            ? Image.network(
                                                fullUrl,
                                                fit: BoxFit.cover,
                                                headers: odooApiClient.authHeaders,
                                                errorBuilder: (c, e, s) => _buildImageThumbnailFallback(isDark),
                                                loadingBuilder: (_, child, progress) {
                                                  if (progress == null) return child;
                                                  return const Center(
                                                    child: SizedBox(
                                                      width: 14,
                                                      height: 14,
                                                      child: CircularProgressIndicator(strokeWidth: 2),
                                                    ),
                                                  );
                                                },
                                              )
                                            : _buildImageThumbnailFallback(isDark)),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // ── 4. GROUPED CARD 2: DANH SÁCH THÀNH VIÊN (CHỈ DÀNH CHO GROUP) ──
              if (isGroup) ...[
                _buildCardContainer(
                  isDark: isDark,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Danh sách thành viên ($effectiveMemberCount)',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF00C83A),
                              ),
                            ),
                            Icon(
                              LucideIcons.users,
                              size: 16,
                              color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                            ),
                          ],
                        ),
                      ),

                      // Add member button row
                      ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFF00C83A).withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(LucideIcons.userPlus, color: Color(0xFF00C83A), size: 20),
                        ),
                        title: const Text(
                          'Thêm thành viên mới',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        trailing: Icon(
                          LucideIcons.chevronRight,
                          size: 18,
                          color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                        ),
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Tính năng thêm thành viên vào nhóm đang mở'),
                              duration: Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),

                      if (_members.isNotEmpty) ...[
                        const Divider(height: 1, indent: 68),
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _members.length,
                          separatorBuilder: (_, _) => const Divider(height: 1, indent: 68),
                          itemBuilder: (ctx, idx) {
                            final member = _members[idx];
                            final memberGrad = ChatV2InfoSheet.getAvatarGradient(member.name);
                            final isMe = member.isMe ||
                                (widget.currentUserName != null &&
                                    widget.currentUserName!.trim().isNotEmpty &&
                                    member.name.trim().toLowerCase() ==
                                        widget.currentUserName!.trim().toLowerCase());
                            final isOnline = member.imStatus == 'online';
                            final isLeader = idx == 0;

                            return ListTile(
                              leading: Stack(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: memberGrad,
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    alignment: Alignment.center,
                                    child: member.avatarUrl != null && member.avatarUrl!.isNotEmpty
                                        ? ClipOval(
                                            child: Image.network(
                                              member.avatarUrl!,
                                              width: 40,
                                              height: 40,
                                              fit: BoxFit.cover,
                                              headers: odooApiClient.authHeaders,
                                              errorBuilder: (c, e, s) => Text(
                                                ChatV2InfoSheet.getInitial(member.name),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 15,
                                                ),
                                              ),
                                            ),
                                          )
                                        : Text(
                                            ChatV2InfoSheet.getInitial(member.name),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 15,
                                            ),
                                          ),
                                  ),
                                  if (isOnline)
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        width: 11,
                                        height: 11,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF22C55E),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              title: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      isMe ? '${member.name} (Bạn)' : member.name,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: isMe ? FontWeight.w700 : FontWeight.w600,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isLeader) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF00C83A).withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'Trưởng nhóm',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF00C83A),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              subtitle: Text(
                                isOnline ? 'Đang trực tuyến' : 'Ngoại tuyến',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isOnline
                                      ? const Color(0xFF22C55E)
                                      : (isDark ? Colors.white54 : const Color(0xFF94A3B8)),
                                ),
                              ),
                            );
                          },
                        ),
                      ] else if (_isLoadingMembers) ...[
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // ── 5. GROUPED CARD 3: CÀI ĐẶT & TÙY CHỌN ──
              _buildCardContainer(
                isDark: isDark,
                child: Column(
                  children: [
                    SwitchListTile.adaptive(
                      value: _isPinned,
                      onChanged: (val) => _togglePin(),
                      activeTrackColor: const Color(0xFF00C83A),
                      secondary: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          LucideIcons.pin,
                          size: 18,
                          color: _isPinned ? const Color(0xFF00C83A) : (isDark ? Colors.white70 : const Color(0xFF475569)),
                        ),
                      ),
                      title: const Text('Ghim trò chuyện', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    ),
                    const Divider(height: 1, indent: 56),
                    SwitchListTile.adaptive(
                      value: _isMuted,
                      onChanged: (val) => _toggleMute(),
                      activeTrackColor: const Color(0xFFEF4444),
                      secondary: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _isMuted ? LucideIcons.bellOff : LucideIcons.bell,
                          size: 18,
                          color: _isMuted ? const Color(0xFFEF4444) : (isDark ? Colors.white70 : const Color(0xFF475569)),
                        ),
                      ),
                      title: const Text('Thông báo cuộc trò chuyện', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── 6. DANGER ACTION: RỜI NHÓM (CHO GROUP) HOẶC ẨN HỘI THOẠI ──
              if (isGroup) ...[
                InkWell(
                  onTap: _isLeaving ? null : _handleLeaveGroup,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: _isLeaving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFFEF4444),
                            ),
                          )
                        : const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(LucideIcons.logOut, color: Color(0xFFEF4444), size: 18),
                              SizedBox(width: 8),
                              Text(
                                'Rời nhóm',
                                style: TextStyle(
                                  color: Color(0xFFEF4444),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ] else ...[
                InkWell(
                  onTap: () async {
                    final repo = ref.read(chatV2RepositoryProvider);
                    await repo.archiveChannel(widget.channel.id);
                    if (context.mounted) {
                      ref.invalidate(chatV2ChannelsProvider);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Đã ẩn cuộc trò chuyện'),
                          duration: Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      Navigator.of(context).pop();
                      if (context.mounted) context.go('/chat');
                    }
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.archive, color: Color(0xFFEF4444), size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Ẩn cuộc trò chuyện',
                          style: TextStyle(
                            color: Color(0xFFEF4444),
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageThumbnailFallback(bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
      child: const Center(
        child: Icon(LucideIcons.image, color: Color(0xFF00C83A), size: 20),
      ),
    );
  }

  Widget _buildCardContainer({required bool isDark, required Widget child}) {
    return Material(
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      elevation: isDark ? 0 : 0.5,
      shadowColor: Colors.black.withValues(alpha: 0.04),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
          ),
        ),
        child: child,
      ),
    );
  }

  Widget _buildCircularAction({
    required bool isDark,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFFEF4444).withValues(alpha: 0.12)
                    : (isDark ? const Color(0xFF1E293B) : Colors.white),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isActive
                      ? const Color(0xFFEF4444).withValues(alpha: 0.4)
                      : (isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                icon,
                size: 22,
                color: isActive
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF00C83A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : const Color(0xFF334155),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CHAT V2 MEDIA HUB SCREEN (ẢNH, TÀI LIỆU, LIÊN KẾT)
// ─────────────────────────────────────────────────────────────────────────────

class ChatV2MediaHubScreen extends StatefulWidget {
  final String channelName;
  final List<ChatV2Attachment> images;
  final List<ChatV2Attachment> files;
  final List<String> links;

  const ChatV2MediaHubScreen({
    super.key,
    required this.channelName,
    required this.images,
    required this.files,
    required this.links,
  });

  @override
  State<ChatV2MediaHubScreen> createState() => _ChatV2MediaHubScreenState();
}

class _ChatV2MediaHubScreenState extends State<ChatV2MediaHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0B1120) : const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            LucideIcons.arrowLeft,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ảnh, file, link đã gửi',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            Text(
              widget.channelName,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: isDark ? Colors.white60 : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF00C83A),
          unselectedLabelColor: isDark ? Colors.white60 : const Color(0xFF64748B),
          indicatorColor: const Color(0xFF00C83A),
          indicatorWeight: 2.5,
          tabs: [
            Tab(text: 'Ảnh (${widget.images.length})'),
            Tab(text: 'Tài liệu (${widget.files.length})'),
            Tab(text: 'Liên kết (${widget.links.length})'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 1. Images Grid
          widget.images.isEmpty
              ? _buildEmptyState(isDark, LucideIcons.image, 'Chưa có hình ảnh nào')
              : GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: widget.images.length,
                  itemBuilder: (context, idx) {
                    final img = widget.images[idx];
                    final memBytes = img.bytes ??
                        ChatV2AttachmentImage.imageCache[img.id] ??
                        ChatV2AttachmentImage.imageCache[img.name] ??
                        LocalAttachmentCache.get(img.id.isNotEmpty ? img.id : null, altKey: img.name);
                    final fullUrl = img.resolveFullUrl(odooApiClient.absoluteUrl(''));

                    return GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ChatV2ImageViewerScreen(
                              imageUrl: fullUrl,
                              title: img.name,
                              bytes: memBytes,
                              attachmentId: img.id.isNotEmpty ? img.id : null,
                            ),
                          ),
                        );
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                          child: memBytes != null && memBytes.isNotEmpty
                              ? Image.memory(
                                  memBytes,
                                  fit: BoxFit.cover,
                                  gaplessPlayback: true,
                                )
                              : (fullUrl.isNotEmpty
                                  ? Image.network(
                                      fullUrl,
                                      fit: BoxFit.cover,
                                      headers: odooApiClient.authHeaders,
                                      errorBuilder: (c, e, s) => _buildEmptyMediaBox(isDark, LucideIcons.image),
                                      loadingBuilder: (_, child, progress) {
                                        if (progress == null) return child;
                                        return const Center(
                                          child: SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          ),
                                        );
                                      },
                                    )
                                  : _buildEmptyMediaBox(isDark, LucideIcons.image)),
                        ),
                      ),
                    );
                  },
                ),

          // 2. Files List
          widget.files.isEmpty
              ? _buildEmptyState(isDark, LucideIcons.fileText, 'Chưa có tài liệu nào')
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: widget.files.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, idx) {
                    final file = widget.files[idx];
                    final ext = file.name.contains('.') ? file.name.split('.').last.toUpperCase() : 'FILE';
                    final cachedBytes = file.bytes ??
                        LocalAttachmentCache.get(file.id) ??
                        LocalAttachmentCache.get(file.name);
                    final size = file.fileSize ?? cachedBytes?.lengthInBytes;
                    final sizeStr = size != null ? _formatFileSize(size) : null;

                    return InkWell(
                      onTap: () async {
                        if (cachedBytes != null && cachedBytes.isNotEmpty) {
                          await saveBytesToFile(cachedBytes, file.name);
                          return;
                        }

                        String fullUrl = '';
                        if (file.downloadUrl != null && file.downloadUrl!.isNotEmpty) {
                          fullUrl = file.downloadUrl!.startsWith('http')
                              ? file.downloadUrl!
                              : odooApiClient.absoluteUrl(file.downloadUrl!);
                        } else if (file.url != null && file.url!.isNotEmpty) {
                          fullUrl = file.resolveFullUrl(odooApiClient.absoluteUrl(''));
                        } else if (int.tryParse(file.id) != null && file.id.isNotEmpty) {
                          fullUrl = odooApiClient.absoluteUrl('/web/content/${file.id}/${file.name}');
                        }

                        if (fullUrl.isNotEmpty) {
                          openDownloadUrl(fullUrl);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Tệp đính kèm chưa sẵn sàng để tải về.'),
                              duration: Duration(seconds: 2),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Row(
                          children: [
                            FoldedPageIcon(
                              ext: ext,
                              color: _getFileAccentColor(ext),
                              width: 34,
                              height: 42,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    file.name,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    sizeStr != null ? '$sizeStr • $ext' : '$ext File',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w400,
                                      color: isDark ? Colors.white60 : const Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.1)
                                    : const Color(0xFF00C83A).withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: const Icon(
                                LucideIcons.download,
                                size: 15,
                                color: Color(0xFF00C83A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),

          // 3. Links List
          widget.links.isEmpty
              ? _buildEmptyState(isDark, LucideIcons.link, 'Chưa có liên kết nào')
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: widget.links.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, idx) {
                    final url = widget.links[idx];
                    return InkWell(
                      onTap: () async {
                        final targetUrl = url.contains('://') ? url : 'https://$url';
                        final uri = Uri.tryParse(targetUrl);
                        if (uri != null) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B).withValues(alpha: 0.5) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              LucideIcons.globe,
                              color: Color(0xFF00C83A),
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                url,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF2563EB),
                                  decoration: TextDecoration.underline,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildEmptyMediaBox(bool isDark, IconData icon) {
    return Center(
      child: Icon(icon, color: const Color(0xFF00C83A), size: 24),
    );
  }

  Widget _buildEmptyState(bool isDark, IconData icon, String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 36,
            color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Color _getFileAccentColor(String ext) {
    switch (ext.toUpperCase()) {
      case 'PDF':
        return const Color(0xFFEF4444);
      case 'DOC':
      case 'DOCX':
        return const Color(0xFF2563EB);
      case 'XLS':
      case 'XLSX':
      case 'CSV':
        return const Color(0xFF10B981);
      case 'PPT':
      case 'PPTX':
        return const Color(0xFFF97316);
      case 'ZIP':
      case 'RAR':
      case '7Z':
      case 'TAR':
      case 'GZ':
        return const Color(0xFF8B5CF6);
      case 'PNG':
      case 'JPG':
      case 'JPEG':
      case 'WEBP':
      case 'GIF':
      case 'SVG':
        return const Color(0xFF059669);
      case 'TXT':
      case 'LOG':
      case 'JSON':
      case 'XML':
      default:
        return const Color(0xFFF59E0B);
    }
  }
}

typedef ChatV2InfoScreen = ChatV2InfoSheet;
