import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/api/odoo_api_client.dart';
import '../../../../core/utils/file_download.dart';
import '../../../../core/utils/local_attachment_cache.dart';
import '../../data/models/chat_v2_channel.dart';
import '../../data/models/chat_v2_message.dart';
import '../screens/chat_v2_image_viewer_screen.dart';
import 'chat_v2_message_item.dart';

class ChatV2InfoSheet extends StatefulWidget {
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

  @override
  State<ChatV2InfoSheet> createState() => _ChatV2InfoSheetState();
}

class _ChatV2InfoSheetState extends State<ChatV2InfoSheet>
    with SingleTickerProviderStateMixin {
  bool _isMuted = false;
  late TabController _tabController;

  // Extracted media collections
  final List<ChatV2Attachment> _images = [];
  final List<ChatV2Attachment> _files = [];
  final List<String> _links = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _extractMedia();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
        if (att.isImage) {
          if (!_images.any((x) => x.id == att.id || (x.url != null && x.url == att.url))) {
            _images.add(att);
          }
        } else {
          if (!_files.any((x) => x.id == att.id || x.name == att.name)) {
            _files.add(att);
          }
        }
      }

      // 2. Filename-based content (Images / Documents stored as message text)
      if (msg.attachments.isEmpty) {
        if (msg.isImageFilename) {
          final att = ChatV2Attachment(
            id: '',
            name: msg.content.trim(),
            url: '',
            mimetype: 'image/jpeg',
          );
          if (!_images.any((x) => x.name == att.name)) {
            _images.add(att);
          }
        } else if (msg.isDocumentFilename) {
          final att = ChatV2Attachment(
            id: '',
            name: msg.content.trim(),
            url: '',
            mimetype: 'application/octet-stream',
          );
          if (!_files.any((x) => x.name == att.name)) {
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

      // 4. Links in text (only if message is not just a raw image/document filename)
      if (!msg.isImageFilename && !msg.isDocumentFilename) {
        final matches = linkRegex.allMatches(msg.content);
        for (final m in matches) {
          var url = m.group(0);
          if (url != null) {
            // Remove trailing punctuation
            final punctRegex = RegExp(r'[.,!?:;)"\x27\]]+$');
            final punctMatch = punctRegex.firstMatch(url);
            if (punctMatch != null) {
              url = url.substring(0, url.length - punctMatch.group(0)!.length);
            }

            final cleanUrl = url.trim();
            final lower = cleanUrl.toLowerCase();

            // Exclude document / data files that look like domain names (e.g. Passwords.csv, report.pdf)
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isGroup = widget.channel.getActualIsGroup(widget.currentUserName);
    final cleanName = widget.channel.getCleanName(widget.currentUserName);
    final avatarGrad = ChatV2InfoSheet.getAvatarGradient(cleanName);
    final isOnline = widget.channel.imStatus == 'online';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 4.5,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 16),

          // Header Info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                // Avatar
                Stack(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: avatarGrad,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
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
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            if (widget.channel.avatarUrl != null &&
                                widget.channel.avatarUrl!.isNotEmpty)
                              Image.network(
                                widget.channel.avatarUrl!,
                                width: 72,
                                height: 72,
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
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            LucideIcons.users,
                            size: 14,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                      )
                    else if (isOnline)
                      Positioned(
                        right: 2,
                        bottom: 2,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: const Color(0xFF22C55E),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark ? const Color(0xFF0F172A) : Colors.white,
                              width: 2.5,
                            ),
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
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),

                // Subtitle (Status or Member count)
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
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isOnline
                              ? const Color(0xFF22C55E)
                              : (isDark ? Colors.white60 : const Color(0xFF64748B)),
                        ),
                      ),
                    ] else ...[
                      Icon(
                        LucideIcons.users,
                        size: 13,
                        color: isDark ? Colors.white60 : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Nhóm trò chuyện • ${widget.channel.memberCount} thành viên',
                        style: TextStyle(
                          fontSize: 13,
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
          const SizedBox(height: 18),

          // Quick Action Buttons Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildQuickAction(
                  isDark: isDark,
                  icon: LucideIcons.search,
                  label: 'Tìm kiếm',
                  onTap: () {
                    Navigator.pop(context);
                    widget.onSearchTap?.call();
                  },
                ),
                _buildQuickAction(
                  isDark: isDark,
                  icon: _isMuted ? LucideIcons.bellOff : LucideIcons.bell,
                  label: _isMuted ? 'Đã tắt chuông' : 'Thông báo',
                  isActive: _isMuted,
                  onTap: _toggleMute,
                ),
                _buildQuickAction(
                  isDark: isDark,
                  icon: LucideIcons.link,
                  label: 'Sao chép link',
                  onTap: _copyChannelLink,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, thickness: 1),

          // Tab Bar for Content (Members if group, Media, Files, Links)
          Expanded(
            child: isGroup
                ? _buildGroupContent(isDark)
                : _buildDirectChatContent(isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAction({
    required bool isDark,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0x1FEF4444)
                    : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 20,
                color: isActive
                    ? const Color(0xFFEF4444)
                    : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isActive
                    ? const Color(0xFFEF4444)
                    : (isDark ? Colors.white70 : const Color(0xFF334155)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupContent(bool isDark) {
    final memberCount = widget.channel.members.isNotEmpty
        ? widget.channel.members.length
        : (widget.channel.memberNames.isNotEmpty
            ? widget.channel.memberNames.length
            : widget.channel.memberCount);

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            indicatorColor: const Color(0xFF00C83A),
            indicatorWeight: 2.5,
            labelColor: isDark ? Colors.white : const Color(0xFF0F172A),
            unselectedLabelColor: isDark ? Colors.white54 : const Color(0xFF64748B),
            labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            tabs: [
              Tab(text: 'Thành viên ($memberCount)'),
              const Tab(text: 'Ảnh & Tài liệu'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildMembersList(isDark),
                _buildMediaHub(isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDirectChatContent(bool isDark) {
    return _buildMediaHub(isDark);
  }

  Widget _buildMembersList(bool isDark) {
    final members = widget.channel.members.isNotEmpty
        ? widget.channel.members
        : widget.channel.memberNames
            .map((name) => ChatV2Member(id: '', name: name))
            .toList();

    if (members.isEmpty) {
      return Center(
        child: Text(
          'Chưa có thông tin danh sách thành viên',
          style: TextStyle(
            color: isDark ? Colors.white54 : const Color(0xFF94A3B8),
            fontSize: 13.5,
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      itemCount: members.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, idx) {
        final member = members[idx];
        final name = member.name;
        final isMe = member.isMe ||
            (widget.currentUserName != null &&
                name.toLowerCase().trim() == widget.currentUserName!.toLowerCase().trim());
        final avatarGrad = ChatV2InfoSheet.getAvatarGradient(name);
        final isLeader = idx == 0;
        final isOnline = member.imStatus == 'online';

        return Container(
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
              // Member Avatar
              Stack(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: avatarGrad),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: ClipOval(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Center(
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : 'M',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          if (member.avatarUrl != null &&
                              member.avatarUrl!.isNotEmpty)
                            Image.network(
                              member.avatarUrl!,
                              width: 38,
                              height: 38,
                              fit: BoxFit.cover,
                              gaplessPlayback: true,
                              errorBuilder: (ctx, err, stack) =>
                                  const SizedBox.shrink(),
                            ),
                        ],
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
                          color: const Color(0xFF00C83A),
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
              const SizedBox(width: 12),

              // Member Name & Role
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name + (isMe ? ' (Bạn)' : ''),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isMe ? FontWeight.w700 : FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (member.email != null && member.email!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        member.email!,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? Colors.white54 : const Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ] else if (isLeader) ...[
                      const SizedBox(height: 2),
                      const Text(
                        'Trưởng nhóm',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF00C83A),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMediaHub(bool isDark) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF00C83A),
          indicatorWeight: 2,
          labelColor: isDark ? Colors.white : const Color(0xFF0F172A),
          unselectedLabelColor: isDark ? Colors.white54 : const Color(0xFF64748B),
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: [
            Tab(text: 'Ảnh (${_images.length})'),
            Tab(text: 'Tài liệu (${_files.length})'),
            Tab(text: 'Liên kết (${_links.length})'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // Images Grid
              _images.isEmpty
                  ? _buildEmptyMediaState(isDark, LucideIcons.image, 'Chưa có hình ảnh nào')
                  : GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: _images.length,
                      itemBuilder: (context, idx) {
                        final img = _images[idx];
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: ChatV2AttachmentImage(
                            attachment: img,
                            fallback: Container(
                              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                              child: const Center(
                                child: Icon(
                                  LucideIcons.image,
                                  color: Color(0xFF00C83A),
                                  size: 24,
                                ),
                              ),
                            ),
                            onTap: () {
                              final fullUrl = img.resolveFullUrl(odooApiClient.absoluteUrl(''));
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ChatV2ImageViewerScreen(
                                    imageUrl: fullUrl,
                                    title: img.name,
                                    bytes: img.bytes ??
                                        ChatV2AttachmentImage.imageCache[img.id] ??
                                        ChatV2AttachmentImage.imageCache[img.name],
                                    attachmentId: img.id.isNotEmpty ? img.id : null,
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),

              // Files List
              _files.isEmpty
                  ? _buildEmptyMediaState(isDark, LucideIcons.fileText, 'Chưa có tài liệu nào')
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _files.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, idx) {
                        final file = _files[idx];
                        final ext = file.name.contains('.') ? file.name.split('.').last.toUpperCase() : 'FILE';
                        final cachedBytes = file.bytes ??
                            LocalAttachmentCache.get(file.id) ??
                            LocalAttachmentCache.get(file.name);
                        final size = file.fileSize ?? cachedBytes?.lengthInBytes;
                        final sizeStr = size != null ? _formatFileSize(size) : null;

                        return InkWell(
                          onTap: () async {
                            // 1. Kiểm tra cache tệp cục bộ (Bộ nhớ / LocalStorage / Disk)
                            if (cachedBytes != null && cachedBytes.isNotEmpty) {
                              await saveBytesToFile(cachedBytes, file.name);
                              return;
                            }

                            // 2. Mở URL tải về hợp lệ từ Odoo
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

              // Links List
              _links.isEmpty
                  ? _buildEmptyMediaState(isDark, LucideIcons.link, 'Chưa có liên kết nào')
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _links.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, idx) {
                        final url = _links[idx];
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
        ),
      ],
    );
  }

  Widget _buildEmptyMediaState(bool isDark, IconData icon, String message) {
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
