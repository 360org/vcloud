import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/api/odoo_api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/local_attachment_cache.dart';
import '../../../../shared/models/profile.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../chat/application/conversations_controller.dart';
import '../../../profile/application/profile_controller.dart';
import '../../../profile/data/models/partner_contact_detail.dart';
import '../../application/chat_v2_channels_controller.dart';
import '../../data/chat_v2_repository.dart';
import '../../data/models/chat_v2_channel.dart';
import '../../data/models/chat_v2_message.dart';
import '../screens/chat_v2_image_viewer_screen.dart';
import 'chat_v2_attachment_viewer.dart';
import 'chat_v2_avatar_action_sheet.dart';
import 'chat_v2_message_item.dart';
import 'chat_v2_mute_duration_sheet.dart';

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

  static ({List<ChatV2Attachment> images, List<ChatV2Attachment> files, List<String> links}) extractMedia(
    List<ChatV2Message> messages,
  ) {
    // ponytail: nested-quantifier fix (ReDoS); matches cùng cấu trúc với chat_bubbles fix
    final linkRegex = RegExp(
      r'((?:https?:\/\/|www\.)[^\s<]+|[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*\.[a-zA-Z]{2,}(?:\/[^\s<]*)?)',
      caseSensitive: false,
    );
    final imgTagRegex = RegExp(
      r'<img[^>]+src=["' "'" r']([^"' "'" r']+)["' "'" r']',
      caseSensitive: false,
    );

    final images = <ChatV2Attachment>[];
    final files = <ChatV2Attachment>[];
    final links = <String>[];

    for (final msg in messages) {
      // 1. Formal Attachments
      for (final att in msg.attachments) {
        final existingBytes = att.bytes ??
            (att.id.isNotEmpty ? ChatV2AttachmentImage.imageCache[att.id] : null) ??
            (msg.id.isNotEmpty ? ChatV2AttachmentImage.imageCache[msg.id] : null) ??
            LocalAttachmentCache.get(att.id.isNotEmpty ? att.id : null);
        final resolvedAtt = existingBytes != null && (att.bytes == null || att.bytes!.isEmpty)
            ? att.copyWith(bytes: existingBytes, messageId: att.messageId ?? msg.id)
            : (att.messageId == null ? att.copyWith(messageId: msg.id) : att);

        if (resolvedAtt.isImage) {
          if (!images.any((x) =>
              (x.id.isNotEmpty && resolvedAtt.id.isNotEmpty && x.id == resolvedAtt.id))) {
            images.add(resolvedAtt);
          }
        } else {
          if (!files.any((x) =>
              (x.id.isNotEmpty && resolvedAtt.id.isNotEmpty && x.id == resolvedAtt.id))) {
            files.add(resolvedAtt);
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
            messageId: msg.id,
          );
          if (!images.any((x) => x.name == att.name || (x.id.isNotEmpty && x.id == att.id))) {
            images.add(att);
          }
        } else if (msg.isDocumentFilename) {
          final att = ChatV2Attachment(
            id: msg.id,
            name: cleanName,
            url: '',
            bytes: memoryBytes,
            mimetype: 'application/octet-stream',
            messageId: msg.id,
          );
          if (!files.any((x) => x.name == att.name || (x.id.isNotEmpty && x.id == att.id))) {
            files.add(att);
          }
        }
      }

      // 3. HTML <img> tags in body
      final bodyForImages = (msg.rawBody != null && msg.rawBody!.isNotEmpty)
          ? msg.rawBody!
          : msg.content;
      final imgMatches = imgTagRegex.allMatches(bodyForImages);
      for (final m in imgMatches) {
        final src = m.group(1);
        if (src != null && src.isNotEmpty && !images.any((x) => x.url == src)) {
          final uriLastSegment = Uri.tryParse(src)?.pathSegments.isNotEmpty == true
              ? Uri.tryParse(src)!.pathSegments.last
              : '';
          final derivedName = uriLastSegment.isNotEmpty ? uriLastSegment : 'Hình ảnh';
          images.add(
            ChatV2Attachment(
              id: '',
              name: derivedName,
              url: src,
              mimetype: 'image/jpeg',
              messageId: msg.id,
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
              if (!images.any((x) => x.url == cleanUrl || x.name == fileName)) {
                images.add(
                  ChatV2Attachment(
                    id: '',
                    name: fileName,
                    url: cleanUrl,
                    mimetype: 'image/jpeg',
                    messageId: msg.id,
                  ),
                );
              }
            } else if (!isFileExt && cleanUrl.isNotEmpty) {
              if (!links.contains(cleanUrl)) {
                links.add(cleanUrl);
              }
            }
          }
        }
      }
    }

    return (images: images, files: files, links: links);
  }

  static Future<String?> openMediaHub(
    BuildContext context, {
    required String channelId,
    required String channelName,
    List<ChatV2Attachment>? images,
    List<ChatV2Attachment>? files,
    List<String>? links,
    List<ChatV2Message>? messages,
    int? totalImages,
    int? totalFiles,
    int? totalLinks,
  }) {
    List<ChatV2Attachment> initialImages = images ?? [];
    List<ChatV2Attachment> initialFiles = files ?? [];
    List<String> initialLinks = links ?? [];

    if (images == null && files == null && links == null && messages != null) {
      final extracted = extractMedia(messages);
      initialImages = extracted.images;
      initialFiles = extracted.files;
      initialLinks = extracted.links;
    }

    return Navigator.of(context).push<String?>(
      MaterialPageRoute(
        builder: (_) => ChatV2MediaHubScreen(
          channelId: channelId,
          channelName: channelName,
          images: initialImages,
          files: initialFiles,
          links: initialLinks,
          totalImages: totalImages ?? initialImages.length,
          totalFiles: totalFiles ?? initialFiles.length,
          totalLinks: totalLinks ?? initialLinks.length,
        ),
      ),
    );
  }

  @override
  ConsumerState<ChatV2InfoSheet> createState() => _ChatV2InfoSheetState();
}

class _ChatV2InfoSheetState extends ConsumerState<ChatV2InfoSheet> {
  bool _isMuted = false;
  bool _isPinned = false;
  bool _isLeaving = false;
  bool _isLoadingMembers = false;
  bool _isUploadingAvatar = false;
  String? _customName;
  String? _customAvatarUrl;

  List<ChatV2Member> _members = [];
  int _memberCount = 0;

  // Extracted media collections
  final List<ChatV2Attachment> _images = [];
  final List<ChatV2Attachment> _files = [];
  final List<String> _links = [];
  int _totalImages = 0;
  int _totalFiles = 0;
  int _totalLinks = 0;

  @override
  void initState() {
    super.initState();
    _isPinned = ChatV2ChannelLocalCache.isUserPinned(widget.channel.id);
    _isMuted = ChatV2ChannelLocalCache.isUserMuted(widget.channel.id);
    _initMembers();
    _extractMedia();
    _totalImages = _images.length;
    _totalFiles = _files.length;
    _totalLinks = _links.length;
    _loadRemoteMedia();
    _loadRemoteMembers();
  }

  Future<void> _loadRemoteMedia() async {
    try {
      final repo = ref.read(chatV2RepositoryProvider);
      final mediaRes = await repo.getChannelMedia(
        widget.channel.id.toString(),
        type: 'all',
        limit: 20,
      );
      if (!mounted) return;

      setState(() {
        if (mediaRes.totalImages > 0) _totalImages = mediaRes.totalImages;
        if (mediaRes.totalFiles > 0) _totalFiles = mediaRes.totalFiles;
        if (mediaRes.totalLinks > 0) _totalLinks = mediaRes.totalLinks;

        for (final img in mediaRes.images) {
          if (!_images.any((x) =>
              (x.id.isNotEmpty && img.id.isNotEmpty && x.id == img.id) ||
              (x.url == img.url && img.url != null))) {
            _images.add(img);
          }
        }
        for (final f in mediaRes.files) {
          if (!_files.any((x) =>
              (x.id.isNotEmpty && f.id.isNotEmpty && x.id == f.id) ||
              (x.url == f.url && f.url != null))) {
            _files.add(f);
          }
        }
        for (final l in mediaRes.links) {
          if (!_links.contains(l)) {
            _links.add(l);
          }
        }
      });
    } catch (_) {}
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
    final isChannel = widget.channel.channelType == 'channel' || widget.channel.channelType == 'group';
    if (!isGroup && !isChannel) return;

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
        ChatV2ChannelLocalCache.updateChannel(
          widget.channel.copyWith(
            members: remoteMembers,
            memberCount: remoteMembers.length,
          ),
          addIfMissing: false,
        );
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
    final extracted = ChatV2InfoSheet.extractMedia(widget.messages);
    _images.addAll(extracted.images);
    _files.addAll(extracted.files);
    _links.addAll(extracted.links);
  }

  String _formatMuteDuration(int minutes) {
    if (minutes <= 60) return '1 giờ';
    if (minutes <= 480) return '8 giờ';
    if (minutes <= 1440) return '24 giờ';
    return 'khi bật lại';
  }

  void _toggleMute() async {
    HapticFeedback.lightImpact();
    if (!_isMuted) {
      final minutes = await showMuteDurationPickerSheet(context);
      if (minutes == null) return;
      if (!mounted) return;

      ChatV2ChannelLocalCache.setUserMuted(widget.channel.id, true);
      setState(() {
        _isMuted = true;
      });
      AppToast.warning(
        context,
        title: 'Đã tắt thông báo',
        message: minutes == -1
            ? 'Bạn sẽ không nhận được thông báo từ cuộc trò chuyện này.'
            : 'Đã tắt thông báo trong ${_formatMuteDuration(minutes)}.',
      );
      // Đồng bộ lên Server Odoo Backend
      try {
        await ref.read(chatV2RepositoryProvider).muteChannel(
              widget.channel.id,
              mute: true,
              duration: minutes,
            );
        ref.invalidate(chatV2ChannelsProvider);
      } catch (_) {}
    } else {
      ChatV2ChannelLocalCache.setUserMuted(widget.channel.id, false);
      setState(() {
        _isMuted = false;
      });
      if (mounted) {
        AppToast.success(
          context,
          title: 'Đã bật thông báo',
          message: 'Bạn sẽ nhận được thông báo khi có tin nhắn mới.',
        );
      }
      // Đồng bộ lên Server Odoo Backend
      try {
        await ref.read(chatV2RepositoryProvider).muteChannel(
              widget.channel.id,
              mute: false,
            );
        ref.invalidate(chatV2ChannelsProvider);
      } catch (_) {}
    }
  }

  void _togglePin() {
    HapticFeedback.lightImpact();
    ChatV2ChannelLocalCache.toggleUserPin(widget.channel.id);
    setState(() {
      _isPinned = !_isPinned;
    });
    if (mounted) {
      if (_isPinned) {
        AppToast.success(
          context,
          title: 'Đã ghim trò chuyện',
          message: 'Cuộc trò chuyện đã được ghim lên đầu danh sách.',
        );
      } else {
        AppToast.info(
          context,
          title: 'Đã bỏ ghim trò chuyện',
          message: 'Cuộc trò chuyện đã được bỏ ghim.',
        );
      }
    }
  }

  Future<void> _copyChannelLink() async {
    HapticFeedback.lightImpact();
    String? link = widget.channel.invitationUrl;
    if (link == null || link.trim().isEmpty) {
      final chUuid = widget.channel.uuid;
      if (chUuid != null && chUuid.trim().isNotEmpty) {
        link = odooApiClient.absoluteUrl('/chat/${widget.channel.id}/$chUuid');
      }
    } else {
      link = odooApiClient.absoluteUrl(link.trim());
    }

    // Lazy fallback: Nếu metadata local chưa có uuid, tự động fetch channel info từ backend
    if (link == null || link.trim().isEmpty) {
      try {
        final repo = ref.read(chatV2RepositoryProvider);
        final freshCh = await repo.getChannel(widget.channel.id);
        if (freshCh != null) {
          if (freshCh.invitationUrl != null && freshCh.invitationUrl!.trim().isNotEmpty) {
            link = odooApiClient.absoluteUrl(freshCh.invitationUrl!.trim());
          } else if (freshCh.uuid != null && freshCh.uuid!.trim().isNotEmpty) {
            link = odooApiClient.absoluteUrl('/chat/${freshCh.id}/${freshCh.uuid}');
          }
        }
      } catch (_) {
        // Ignored fallback
      }
    }

    // ponytail: Khi server backend chưa migrate UUID cho kênh legacy, fallback sang link Odoo Web nội bộ để chống HTTP 404
    if (link == null || link.trim().isEmpty) {
      link = odooApiClient.absoluteUrl('/web#action=mail.action_discuss&active_id=${widget.channel.id}');
    }

    if (!mounted) return;

    if (link.trim().isEmpty) {
      AppToast.error(
        context,
        title: 'Không thể tạo liên kết',
        message: 'Cuộc trò chuyện này chưa có mã bảo mật chia sẻ.',
      );
      return;
    }

    Clipboard.setData(ClipboardData(text: link));
    AppToast.success(
      context,
      title: 'Đã sao chép liên kết',
      message: 'Liên kết cuộc trò chuyện đã được sao chép vào bộ nhớ tạm.',
    );
  }

  Future<void> _openMediaHub() async {
    final targetMsgId = await ChatV2InfoSheet.openMediaHub(
      context,
      channelId: widget.channel.id.toString(),
      channelName: widget.channel.getCleanName(widget.currentUserName),
      images: _images,
      files: _files,
      links: _links,
      totalImages: _totalImages,
      totalFiles: _totalFiles,
      totalLinks: _totalLinks,
    );
    if (targetMsgId != null && targetMsgId.isNotEmpty && mounted) {
      Navigator.of(context).pop(targetMsgId);
    }
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
        AppToast.success(
          context,
          title: 'Đã rời nhóm',
          message: 'Bạn đã rời khỏi nhóm trò chuyện thành công.',
        );
        // Pop info sheet & navigate back to chat list
        Navigator.of(context).pop();
        if (context.mounted) context.go('/chat');
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(
          context,
          title: 'Không thể rời nhóm',
          message: '$e',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLeaving = false);
      }
    }
  }

  void _showGroupAvatarOptions({
    required BuildContext context,
    required bool isDark,
    required String? currentAvatarUrl,
    required String cleanName,
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ảnh đại diện nhóm',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 16),
              if (currentAvatarUrl != null && currentAvatarUrl.isNotEmpty) ...[
                ListTile(
                  leading: const Icon(LucideIcons.eye, color: Color(0xFF00C83A)),
                  title: Text(
                    'Xem ảnh nhóm',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    final fullUrl = currentAvatarUrl.startsWith('http')
                        ? currentAvatarUrl
                        : odooApiClient.absoluteUrl(currentAvatarUrl);
                    Navigator.of(context).push(
                      ChatV2ImageViewerScreen.route(
                        imageUrl: fullUrl,
                        title: cleanName,
                      ),
                    );
                  },
                ),
              ],
              ListTile(
                leading: const Icon(LucideIcons.camera, color: Color(0xFF00C83A)),
                title: Text(
                  'Chụp ảnh mới',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadGroupAvatar(ImageSource.camera);
                },
              ),
              ListTile(
                leading: const Icon(LucideIcons.image, color: Color(0xFF00C83A)),
                title: Text(
                  'Chọn từ thư viện ảnh',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A),
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickAndUploadGroupAvatar(ImageSource.gallery);
                },
              ),
              if (currentAvatarUrl != null && currentAvatarUrl.isNotEmpty) ...[
                ListTile(
                  leading: const Icon(LucideIcons.trash2, color: Color(0xFFEF4444)),
                  title: const Text(
                    'Xóa ảnh đại diện',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFEF4444),
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _removeGroupAvatar();
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndUploadGroupAvatar(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 85,
      );
      if (picked == null) return;

      setState(() => _isUploadingAvatar = true);
      final bytes = await picked.readAsBytes();
      final base64Str = base64Encode(bytes);

      final newUrl = await ref
          .read(chatV2ChannelsProvider.notifier)
          .updateChannelAvatar(widget.channel.id.toString(), base64Image: base64Str);

      if (!mounted) return;
      setState(() {
        _customAvatarUrl = newUrl;
        _isUploadingAvatar = false;
      });

      AppToast.success(
        context,
        title: 'Cập nhật thành công',
        message: 'Đã cập nhật ảnh đại diện nhóm trò chuyện.',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploadingAvatar = false);
      AppToast.error(
        context,
        title: 'Lỗi cập nhật ảnh',
        message: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> _removeGroupAvatar() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(LucideIcons.trash2, color: Color(0xFFEF4444), size: 22),
            SizedBox(width: 8),
            Text('Xóa ảnh đại diện?', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
          ],
        ),
        content: Text(
          'Ảnh đại diện nhóm sẽ được đặt lại về chữ cái mặc định.',
          style: TextStyle(
            fontSize: 14,
            height: 1.4,
            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
          ),
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
            child: const Text('Xóa', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isUploadingAvatar = true);
    try {
      await ref
          .read(chatV2ChannelsProvider.notifier)
          .updateChannelAvatar(widget.channel.id.toString(), isRemove: true);

      if (!mounted) return;
      setState(() {
        _customAvatarUrl = '';
        _isUploadingAvatar = false;
      });

      AppToast.success(
        context,
        title: 'Đã xóa ảnh đại diện',
        message: 'Ảnh đại diện nhóm đã được gỡ bỏ.',
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploadingAvatar = false);
      AppToast.error(
        context,
        title: 'Lỗi gỡ ảnh',
        message: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> _handleRemoveMember(ChatV2Member member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(LucideIcons.userMinus, color: Color(0xFFEF4444), size: 22),
            SizedBox(width: 8),
            Text('Xóa thành viên?', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
          ],
        ),
        content: Text(
          'Bạn có chắc chắn muốn xóa "${member.name}" khỏi nhóm trò chuyện này không?',
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
            child: const Text('Xóa', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final pId = int.tryParse(member.id);
    if (pId == null) return;

    try {
      final repo = ref.read(chatV2RepositoryProvider);
      await repo.removeChannelMember(channelId: widget.channel.id, partnerId: pId);
      setState(() {
        _members.removeWhere((m) => m.id == member.id);
        if (_memberCount > 0) _memberCount--;
      });
      ref.invalidate(chatV2ChannelsProvider);
      if (mounted) {
        AppToast.success(
          context,
          title: 'Đã xóa thành viên',
          message: 'Đã xóa "${member.name}" khỏi nhóm.',
        );
      }
    } catch (e) {
      if (mounted) {
        AppToast.error(
          context,
          title: 'Lỗi',
          message: 'Không thể xóa thành viên: $e',
        );
      }
    }
  }

  void _openAddMemberSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) => _AddGroupMemberBottomSheet(
        channelId: widget.channel.id,
        currentMembers: _members,
        onMembersAdded: (newCount) async {
          await _loadRemoteMembers();
          ref.invalidate(chatV2ChannelsProvider);
          if (mounted) {
            AppToast.success(
              context,
              title: 'Thành công',
              message: 'Đã thêm thành viên vào nhóm trò chuyện.',
            );
          }
        },
      ),
    );
  }

  void _handleRenameTap(BuildContext context, {required bool isGroup, required String currentName}) {
    final currentUser = ref.read(authControllerProvider).valueOrNull;
    final isPortalUser = currentUser?.isPortal == true;

    if (isGroup && isPortalUser) {
      AppToast.error(
        context,
        title: 'Không có quyền',
        message: 'Tài khoản Portal không có quyền đổi tên nhóm nội bộ.',
      );
      return;
    }

    _showRenameDialog(context, isGroup: isGroup, currentName: currentName);
  }

  Future<void> _showRenameDialog(
    BuildContext context, {
    required bool isGroup,
    required String currentName,
  }) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final initialText = currentName == 'Cuộc trò chuyện' ? '' : currentName;
    final textController = TextEditingController(text: initialText);
    textController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: textController.text.length,
    );
    String? errorMessage;
    bool isSaving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: !isSaving,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final title = isGroup ? 'Đổi tên nhóm' : 'Đặt biệt danh';
          final hint = isGroup ? 'Nhập tên nhóm mới' : 'Nhập biệt danh cuộc trò chuyện';
          final helper = isGroup
              ? 'Tên nhóm sẽ hiển thị với tất cả thành viên trong nhóm.'
              : 'Biệt danh này chỉ hiển thị riêng với bạn.';

          Future<void> submit() async {
            final trimmed = textController.text.trim();
            if (trimmed.isEmpty) {
              setDialogState(() {
                errorMessage = isGroup ? 'Tên nhóm không được để trống' : 'Biệt danh không được để trống';
              });
              return;
            }
            if (trimmed.length > 100) {
              setDialogState(() {
                errorMessage = 'Tên không được vượt quá 100 ký tự';
              });
              return;
            }
            if (trimmed == currentName) {
              Navigator.of(dialogCtx).pop();
              return;
            }

            setDialogState(() {
              isSaving = true;
              errorMessage = null;
            });

            try {
              await ref.read(chatV2ChannelsProvider.notifier).renameChannel(
                widget.channel.id,
                trimmed,
                isGroup: isGroup,
              );
              if (dialogCtx.mounted) {
                Navigator.of(dialogCtx).pop();
              }
              if (mounted) {
                setState(() {
                  _customName = trimmed;
                });
                AppToast.success(
                  this.context,
                  title: 'Thành công',
                  message: isGroup ? 'Đã đổi tên nhóm thành công' : 'Đã lưu biệt danh thành công',
                );
              }
            } catch (e) {
              if (dialogCtx.mounted) {
                setDialogState(() {
                  isSaving = false;
                  errorMessage = 'Lỗi cập nhật: ${e.toString().replaceFirst("Exception: ", "")}';
                });
              }
            }
          }

          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(
                  LucideIcons.pencil,
                  color: Color(0xFF00C83A),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    helper,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: textController,
                    autofocus: true,
                    enabled: !isSaving,
                    maxLength: 100,
                    style: TextStyle(
                      fontSize: 15,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    decoration: InputDecoration(
                      hintText: hint,
                      hintStyle: TextStyle(
                        fontSize: 14,
                        color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                      ),
                      errorText: errorMessage,
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: Color(0xFF00C83A),
                          width: 1.5,
                        ),
                      ),
                      suffixIcon: textController.text.isNotEmpty && !isSaving
                          ? IconButton(
                              icon: const Icon(LucideIcons.x, size: 16),
                              onPressed: () {
                                textController.clear();
                                setDialogState(() {
                                  errorMessage = null;
                                });
                              },
                            )
                          : null,
                    ),
                    onChanged: (_) {
                      if (errorMessage != null) {
                        setDialogState(() {
                          errorMessage = null;
                        });
                      }
                    },
                    onSubmitted: (_) => submit(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
                child: Text(
                  'Hủy',
                  style: TextStyle(
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00C83A),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onPressed: isSaving ? null : submit,
                child: isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Lưu',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showMemberNicknameDialog(
    BuildContext context,
    ChatV2Member member,
  ) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentNickname = member.nickname ?? member.customChannelName ?? '';
    final textController = TextEditingController(text: currentNickname);
    textController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: textController.text.length,
    );
    String? errorMessage;
    bool isSaving = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: !isSaving,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> submit() async {
            final trimmed = textController.text.trim();
            if (trimmed == currentNickname) {
              Navigator.of(dialogCtx).pop();
              return;
            }
            if (trimmed.length > 100) {
              setDialogState(() {
                errorMessage = 'Biệt danh không được vượt quá 100 ký tự';
              });
              return;
            }

            setDialogState(() {
              isSaving = true;
              errorMessage = null;
            });

            try {
              final memberId = int.tryParse(member.id);
              final partnerId = member.partnerId;
              await ref.read(chatV2ChannelsProvider.notifier).updateMemberNickname(
                channelId: widget.channel.id,
                memberId: memberId,
                partnerId: partnerId,
                nickname: trimmed,
              );
              if (dialogCtx.mounted) {
                Navigator.of(dialogCtx).pop();
              }
              if (mounted) {
                setState(() {
                  final idx = _members.indexWhere((m) => m.id == member.id);
                  if (idx != -1) {
                    _members[idx] = _members[idx].copyWith(
                      customChannelName: trimmed.isNotEmpty ? trimmed : null,
                      nickname: trimmed.isNotEmpty ? trimmed : null,
                      clearNickname: trimmed.isEmpty,
                    );
                  }
                });
                AppToast.success(
                  this.context,
                  title: 'Thành công',
                  message: trimmed.isNotEmpty
                      ? 'Đã cập nhật biệt danh cho ${member.name}'
                      : 'Đã xóa biệt danh của ${member.name}',
                );
              }
            } catch (e) {
              if (dialogCtx.mounted) {
                setDialogState(() {
                  isSaving = false;
                  errorMessage = 'Lỗi cập nhật: ${e.toString().replaceFirst("Exception: ", "")}';
                });
              }
            }
          }

          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(
                  LucideIcons.pencil,
                  color: Color(0xFF00C83A),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Biệt danh cho ${member.name}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Biệt danh này sẽ đồng bộ trên toàn bộ thiết bị Web & Mobile.',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: textController,
                    autofocus: true,
                    enabled: !isSaving,
                    maxLength: 100,
                    style: TextStyle(
                      fontSize: 15,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    decoration: InputDecoration(
                      hintText: 'Nhập biệt danh (hoặc để trống để xóa)',
                      errorText: errorMessage,
                      filled: true,
                      fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: Color(0xFF00C83A),
                          width: 1.5,
                        ),
                      ),
                      suffixIcon: textController.text.isNotEmpty && !isSaving
                          ? IconButton(
                              icon: const Icon(LucideIcons.x, size: 16),
                              onPressed: () {
                                textController.clear();
                                setDialogState(() {
                                  errorMessage = null;
                                });
                              },
                            )
                          : null,
                    ),
                    onChanged: (_) {
                      if (errorMessage != null) {
                        setDialogState(() {
                          errorMessage = null;
                        });
                      }
                    },
                    onSubmitted: (_) => submit(),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
                child: Text(
                  'Hủy',
                  style: TextStyle(
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00C83A),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onPressed: isSaving ? null : submit,
                child: isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Lưu',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeChannel = ref.watch(chatV2ChannelsProvider.select(
      (async) => async.valueOrNull?.where((c) => c.id == widget.channel.id).firstOrNull,
    )) ?? widget.channel;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isGroup = activeChannel.getActualIsGroup(widget.currentUserName);
    final currentUser = ref.watch(authControllerProvider).valueOrNull;
    final isPortalUser = currentUser?.isPortal == true;
    final cleanName = _customName ?? activeChannel.getCleanName(widget.currentUserName);
    final avatarGrad = ChatV2InfoSheet.getAvatarGradient(cleanName);
    final isOnline = activeChannel.imStatus == 'online';

    final effectiveMemberCount = _members.length > _memberCount
        ? _members.length
        : (_memberCount > 0 ? _memberCount : _members.length);

    // Tự động phân giải avatar URL của đối phương nếu channel.avatarUrl chưa có và là chat 1-1
    String? resolvedAvatarUrl = _customAvatarUrl != null
        ? (_customAvatarUrl!.isNotEmpty ? _customAvatarUrl : null)
        : (activeChannel.avatarUrl ?? widget.channel.avatarUrl);
    if (resolvedAvatarUrl == null || resolvedAvatarUrl.isEmpty) {
      if (!isGroup && !widget.channel.isChannel) {
        final currentPartnerId = odooApiClient.session?.partnerId?.toString();
        final currentUserId = odooApiClient.session?.uid.toString();
        if (widget.messages.isNotEmpty) {
          final otherMsg = widget.messages.firstWhereOrNull((m) =>
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
          final otherMember = _members.firstWhereOrNull((m) =>
              !m.isMe &&
              (currentPartnerId == null || m.id != currentPartnerId) &&
              (currentUserId == null || m.id != currentUserId) &&
              (widget.currentUserName == null || !ChatV2Channel.matchesUser(m.name, widget.currentUserName!)) &&
              m.avatarUrl != null &&
              m.avatarUrl!.isNotEmpty);
          if (otherMember != null) {
            resolvedAvatarUrl = otherMember.avatarUrl;
          }
        }
      }
    }

    int? otherPartnerId;
    if (!isGroup) {
      if (activeChannel.directPartnerId != null) {
        otherPartnerId = int.tryParse(activeChannel.directPartnerId!);
      }
      otherPartnerId ??= int.tryParse(activeChannel.partnerId ?? '');
      if (otherPartnerId == null || otherPartnerId <= 0) {
        final otherMember = _members.firstWhereOrNull((m) => !m.isMe && m.partnerId != null && m.partnerId! > 0);
        otherPartnerId = otherMember?.partnerId;
      }
      if (otherPartnerId == null || otherPartnerId <= 0) {
        final otherMember = _members.firstWhereOrNull((m) => !m.isMe && int.tryParse(m.id) != null);
        otherPartnerId = int.tryParse(otherMember?.id ?? '');
      }
    }

    final partnerDetailAsync = (otherPartnerId != null && otherPartnerId > 0)
        ? ref.watch(partnerContactDetailProvider(otherPartnerId))
        : null;
    final partnerDetail = partnerDetailAsync?.valueOrNull;

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
            tooltip: isGroup ? 'Đổi tên nhóm' : 'Đặt biệt danh',
            onPressed: () => _handleRenameTap(
              context,
              isGroup: isGroup,
              currentName: cleanName,
            ),
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
                        GestureDetector(
                          onTap: () {
                            if (isGroup) {
                              _showGroupAvatarOptions(
                                context: context,
                                isDark: isDark,
                                currentAvatarUrl: resolvedAvatarUrl,
                                cleanName: cleanName,
                              );
                            } else if (resolvedAvatarUrl != null &&
                                resolvedAvatarUrl.isNotEmpty) {
                              final fullUrl = resolvedAvatarUrl.startsWith('http')
                                  ? resolvedAvatarUrl
                                  : odooApiClient.absoluteUrl(resolvedAvatarUrl);
                              Navigator.of(context).push(
                                ChatV2ImageViewerScreen.route(
                                  imageUrl: fullUrl,
                                  title: cleanName,
                                ),
                              );
                            }
                          },
                          child: Container(
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
                                  if (resolvedAvatarUrl != null &&
                                      resolvedAvatarUrl.isNotEmpty)
                                    Image.network(
                                      resolvedAvatarUrl,
                                      width: 84,
                                      height: 84,
                                      fit: BoxFit.cover,
                                      gaplessPlayback: true,
                                      headers: odooApiClient.authHeaders,
                                      errorBuilder: (context, error, stackTrace) =>
                                          const SizedBox.shrink(),
                                    ),
                                  if (_isUploadingAvatar)
                                    Container(
                                      color: Colors.black45,
                                      child: const Center(
                                        child: SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (isGroup)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: GestureDetector(
                              onTap: () => _showGroupAvatarOptions(
                                context: context,
                                isDark: isDark,
                                currentAvatarUrl: resolvedAvatarUrl,
                                cleanName: cleanName,
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00C83A),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isDark ? const Color(0xFF0F172A) : Colors.white,
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.2),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  LucideIcons.camera,
                                  size: 14,
                                  color: Colors.white,
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
                      Navigator.of(context).pop();
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
                  if (isGroup && !isPortalUser)
                    _buildCircularAction(
                      isDark: isDark,
                      icon: LucideIcons.userPlus,
                      label: 'Thêm thành viên',
                      onTap: _openAddMemberSheet,
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

              // ── 2.1 CUSTOMER ERP/CRM QUICK CARD ──
              if (!isGroup && otherPartnerId != null && otherPartnerId > 0) ...[
                _buildCustomerQuickCard(
                  context,
                  isDark: isDark,
                  partnerId: otherPartnerId,
                  cleanName: cleanName,
                  avatarUrl: resolvedAvatarUrl,
                  detail: partnerDetail,
                ),
                const SizedBox(height: 14),
              ],

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
                                    '${_totalImages > _images.length ? _totalImages : _images.length} ảnh, ${_totalFiles > _files.length ? _totalFiles : _files.length} file, ${_totalLinks > _links.length ? _totalLinks : _links.length} link',
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
                                  (img.id.isNotEmpty ? ChatV2AttachmentImage.imageCache[img.id] : null) ??
                                  LocalAttachmentCache.get(img.id.isNotEmpty ? img.id : null);
                              final fullUrl = img.resolveFullUrl(odooApiClient.absoluteUrl(''));

                              final heroTag = 'info_preview_img_${img.id.isNotEmpty ? img.id : (fullUrl.isNotEmpty ? fullUrl : img.name)}';

                              return GestureDetector(
                                onTap: () async {
                                  final targetMsgId = await Navigator.of(context).push<String?>(
                                    ChatV2ImageViewerScreen.route(
                                      images: _images,
                                      initialIndex: idx,
                                      imageUrl: fullUrl,
                                      title: '',
                                      bytes: memBytes,
                                      attachmentId: img.id.isNotEmpty ? img.id : null,
                                      heroTag: heroTag,
                                      messageId: img.messageId,
                                    ),
                                  );
                                  if (targetMsgId != null && targetMsgId.isNotEmpty && context.mounted) {
                                    Navigator.of(context).pop(targetMsgId);
                                  }
                                },
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    width: 64,
                                    height: 64,
                                    color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                                    child: Hero(
                                      tag: heroTag,
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
                      if (!isPortalUser)
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
                        onTap: _openAddMemberSheet,
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
                            final isLeader = member.isLeader ||
                                (idx == 0 && !_members.any((m) => m.isLeader));
                            final amILeader = _members.any((m) => m.isMe && m.isLeader) ||
                                (_members.isNotEmpty && _members.first.isMe && !_members.any((m) => m.isLeader));

                            final hasCustomNickname = (member.nickname != null && member.nickname!.isNotEmpty && member.nickname != member.name) ||
                                (member.customChannelName != null && member.customChannelName!.isNotEmpty && member.customChannelName != member.name);
                            final subtitleText = hasCustomNickname
                                ? '${member.name} • ${isOnline ? "Đang trực tuyến" : "Ngoại tuyến"}'
                                : (isOnline ? 'Đang trực tuyến' : 'Ngoại tuyến');

                            return ListTile(
                              onTap: isMe
                                  ? () => context.push('/profile')
                                  : () => ChatV2AvatarActionSheet.show(
                                        context,
                                        ref,
                                        partnerId: member.partnerId?.toString() ?? member.id,
                                        name: member.displayName,
                                        avatarUrl: member.avatarUrl,
                                        role: isOnline ? 'Đang trực tuyến' : 'Ngoại tuyến',
                                        currentChannel: activeChannel,
                                      ),
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
                                      isMe ? '${member.displayName} (Bạn)' : member.displayName,
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
                                subtitleText,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isOnline
                                      ? const Color(0xFF22C55E)
                                      : (isDark ? Colors.white54 : const Color(0xFF94A3B8)),
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (!isMe)
                                    IconButton(
                                      icon: const Icon(
                                        LucideIcons.pencil,
                                        size: 16,
                                        color: Color(0xFF00C83A),
                                      ),
                                      tooltip: 'Đặt biệt danh',
                                      onPressed: () => _showMemberNicknameDialog(context, member),
                                    ),
                                  if (isGroup && !isMe && amILeader)
                                    IconButton(
                                      icon: const Icon(
                                        LucideIcons.userMinus,
                                        size: 18,
                                        color: Color(0xFFEF4444),
                                      ),
                                      tooltip: 'Xóa khỏi nhóm',
                                      onPressed: () => _handleRemoveMember(member),
                                    ),
                                ],
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
              ],
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCustomerQuickCard(
    BuildContext context, {
    required bool isDark,
    required int partnerId,
    required String cleanName,
    required String? avatarUrl,
    required PartnerContactDetail? detail,
  }) {
    final companyName = detail?.effectiveCompanyName ?? '';
    final vat = detail?.vat ?? '';
    final metrics = detail?.smartMetrics ?? const PartnerSmartMetrics();

    return _buildCardContainer(
      isDark: isDark,
      child: InkWell(
        onTap: () {
          context.push(
            '/profile?partner_id=$partnerId&name=${Uri.encodeComponent(cleanName)}&avatar=${Uri.encodeComponent(avatarUrl ?? "")}',
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0077CD).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      LucideIcons.building2,
                      size: 15,
                      color: Color(0xFF0077CD),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Hồ sơ đối tác ERP / CRM',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0077CD),
                      ),
                    ),
                  ),
                  const Icon(
                    LucideIcons.chevronRight,
                    size: 17,
                    color: Color(0xFF94A3B8),
                  ),
                ],
              ),
              if (detail != null) ...[
                const SizedBox(height: 10),
                if (companyName.isNotEmpty && companyName != cleanName) ...[
                  Row(
                    children: [
                      const Icon(LucideIcons.building, size: 14, color: AppColors.textMuted),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          companyName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],
                if (vat.isNotEmpty) ...[
                  Row(
                    children: [
                      const Icon(LucideIcons.receipt, size: 14, color: AppColors.textMuted),
                      const SizedBox(width: 6),
                      Text(
                        'MST: $vat',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFEA580C),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
                if (metrics.hasAnyMetric) ...[
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      if (metrics.ticketCount > 0)
                        _buildMetricChip(
                          icon: LucideIcons.ticket,
                          color: const Color(0xFFF59E0B),
                          text: '${metrics.ticketCount} vé',
                        ),
                      if (metrics.opportunityCount > 0)
                        _buildMetricChip(
                          icon: LucideIcons.briefcase,
                          color: const Color(0xFF10B981),
                          text: '${metrics.opportunityCount} cơ hội',
                        ),
                      if (metrics.saleOrderCount > 0)
                        _buildMetricChip(
                          icon: LucideIcons.shoppingBag,
                          color: const Color(0xFF6366F1),
                          text: '${metrics.saleOrderCount} đơn',
                        ),
                      if (metrics.taskCount > 0)
                        _buildMetricChip(
                          icon: LucideIcons.checkSquare,
                          color: const Color(0xFF0077CD),
                          text: '${metrics.taskCount} việc',
                        ),
                    ],
                  ),
                ],
              ] else ...[
                const SizedBox(height: 6),
                const Text(
                  'Nhấn để xem thông tin chi tiết công ty, mã số thuế và chỉ số Odoo.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricChip({
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
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

class ChatV2MediaHubScreen extends ConsumerStatefulWidget {
  final String channelId;
  final String channelName;
  final List<ChatV2Attachment> images;
  final List<ChatV2Attachment> files;
  final List<String> links;
  final int? totalImages;
  final int? totalFiles;
  final int? totalLinks;

  const ChatV2MediaHubScreen({
    super.key,
    required this.channelId,
    required this.channelName,
    required this.images,
    required this.files,
    required this.links,
    this.totalImages,
    this.totalFiles,
    this.totalLinks,
  });

  @override
  ConsumerState<ChatV2MediaHubScreen> createState() => _ChatV2MediaHubScreenState();
}

class _ChatV2MediaHubScreenState extends ConsumerState<ChatV2MediaHubScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _imagesScrollController = ScrollController();
  final ScrollController _filesScrollController = ScrollController();
  final ScrollController _linksScrollController = ScrollController();

  late List<ChatV2Attachment> _images;
  late List<ChatV2Attachment> _files;
  late List<String> _links;

  late int _totalImages;
  late int _totalFiles;
  late int _totalLinks;

  bool _isLoadingImages = false;
  bool _isLoadingFiles = false;
  bool _isLoadingLinks = false;

  bool _hasMoreImages = false;
  bool _hasMoreFiles = false;
  bool _hasMoreLinks = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    _images = List.from(widget.images);
    _files = List.from(widget.files);
    _links = List.from(widget.links);

    _totalImages = widget.totalImages ?? _images.length;
    _totalFiles = widget.totalFiles ?? _files.length;
    _totalLinks = widget.totalLinks ?? _links.length;

    _hasMoreImages = _images.length < _totalImages;
    _hasMoreFiles = _files.length < _totalFiles;
    _hasMoreLinks = _links.length < _totalLinks;

    _imagesScrollController.addListener(_onImagesScroll);
    _filesScrollController.addListener(_onFilesScroll);
    _linksScrollController.addListener(_onLinksScroll);

    // Đồng bộ toàn bộ media từ server khi vào màn hình để lấy lịch sử quá khứ
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchInitialMedia();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _imagesScrollController.dispose();
    _filesScrollController.dispose();
    _linksScrollController.dispose();
    super.dispose();
  }

  void _onImagesScroll() {
    if (_imagesScrollController.position.pixels >=
        _imagesScrollController.position.maxScrollExtent - 200) {
      _loadMoreImages();
    }
  }

  void _onFilesScroll() {
    if (_filesScrollController.position.pixels >=
        _filesScrollController.position.maxScrollExtent - 200) {
      _loadMoreFiles();
    }
  }

  void _onLinksScroll() {
    if (_linksScrollController.position.pixels >=
        _linksScrollController.position.maxScrollExtent - 200) {
      _loadMoreLinks();
    }
  }

  Future<void> _fetchInitialMedia() async {
    if (widget.channelId.isEmpty) return;
    try {
      final repo = ref.read(chatV2RepositoryProvider);
      final res = await repo.getChannelMedia(
        widget.channelId,
        type: 'all',
        limit: 50,
        offset: 0,
      );
      if (!mounted) return;
      setState(() {
        if (res.images.isNotEmpty || res.totalImages > 0) {
          _images = res.images;
          _totalImages = res.totalImages;
          _hasMoreImages = res.images.length < res.totalImages;
        }
        if (res.files.isNotEmpty || res.totalFiles > 0) {
          _files = res.files;
          _totalFiles = res.totalFiles;
          _hasMoreFiles = res.files.length < res.totalFiles;
        }
        if (res.links.isNotEmpty || res.totalLinks > 0) {
          _links = res.links;
          _totalLinks = res.totalLinks;
          _hasMoreLinks = res.links.length < res.totalLinks;
        }
      });
    } catch (e) {
      debugPrint('[ChatV2MediaHub] _fetchInitialMedia error: $e');
    }
  }

  Future<void> _refreshImages() async {
    if (widget.channelId.isEmpty) return;
    try {
      final repo = ref.read(chatV2RepositoryProvider);
      final res = await repo.getChannelMedia(
        widget.channelId,
        type: 'image',
        limit: 50,
        offset: 0,
      );
      if (!mounted) return;
      setState(() {
        _images = res.images;
        _totalImages = res.totalImages;
        _hasMoreImages = res.hasMore;
      });
    } catch (e) {
      debugPrint('[ChatV2MediaHub] _refreshImages error: $e');
    }
  }

  Future<void> _loadMoreImages() async {
    if (_isLoadingImages || !_hasMoreImages || widget.channelId.isEmpty) return;
    setState(() => _isLoadingImages = true);
    try {
      final repo = ref.read(chatV2RepositoryProvider);
      final res = await repo.getChannelMedia(
        widget.channelId,
        type: 'image',
        limit: 50,
        offset: _images.length,
      );
      if (!mounted) return;
      setState(() {
        final existingIds = _images.map((e) => e.id).where((id) => id.isNotEmpty).toSet();
        final newItems = res.images.where((e) => e.id.isEmpty || !existingIds.contains(e.id)).toList();
        _images.addAll(newItems);
        _totalImages = res.totalImages > _images.length ? res.totalImages : _images.length;
        _hasMoreImages = res.hasMore;
      });
    } catch (e) {
      debugPrint('[ChatV2MediaHub] _loadMoreImages error: $e');
    } finally {
      if (mounted) setState(() => _isLoadingImages = false);
    }
  }

  Future<void> _refreshFiles() async {
    if (widget.channelId.isEmpty) return;
    try {
      final repo = ref.read(chatV2RepositoryProvider);
      final res = await repo.getChannelMedia(
        widget.channelId,
        type: 'file',
        limit: 50,
        offset: 0,
      );
      if (!mounted) return;
      setState(() {
        _files = res.files;
        _totalFiles = res.totalFiles;
        _hasMoreFiles = res.hasMore;
      });
    } catch (e) {
      debugPrint('[ChatV2MediaHub] _refreshFiles error: $e');
    }
  }

  Future<void> _loadMoreFiles() async {
    if (_isLoadingFiles || !_hasMoreFiles || widget.channelId.isEmpty) return;
    setState(() => _isLoadingFiles = true);
    try {
      final repo = ref.read(chatV2RepositoryProvider);
      final res = await repo.getChannelMedia(
        widget.channelId,
        type: 'file',
        limit: 50,
        offset: _files.length,
      );
      if (!mounted) return;
      setState(() {
        final existingIds = _files.map((e) => e.id).where((id) => id.isNotEmpty).toSet();
        final newItems = res.files.where((e) => e.id.isEmpty || !existingIds.contains(e.id)).toList();
        _files.addAll(newItems);
        _totalFiles = res.totalFiles > _files.length ? res.totalFiles : _files.length;
        _hasMoreFiles = res.hasMore;
      });
    } catch (e) {
      debugPrint('[ChatV2MediaHub] _loadMoreFiles error: $e');
    } finally {
      if (mounted) setState(() => _isLoadingFiles = false);
    }
  }

  Future<void> _refreshLinks() async {
    if (widget.channelId.isEmpty) return;
    try {
      final repo = ref.read(chatV2RepositoryProvider);
      final res = await repo.getChannelMedia(
        widget.channelId,
        type: 'link',
        limit: 50,
        offset: 0,
      );
      if (!mounted) return;
      setState(() {
        _links = res.links;
        _totalLinks = res.totalLinks;
        _hasMoreLinks = res.hasMore;
      });
    } catch (e) {
      debugPrint('[ChatV2MediaHub] _refreshLinks error: $e');
    }
  }

  Future<void> _loadMoreLinks() async {
    if (_isLoadingLinks || !_hasMoreLinks || widget.channelId.isEmpty) return;
    setState(() => _isLoadingLinks = true);
    try {
      final repo = ref.read(chatV2RepositoryProvider);
      final res = await repo.getChannelMedia(
        widget.channelId,
        type: 'link',
        limit: 50,
        offset: _links.length,
      );
      if (!mounted) return;
      setState(() {
        final existingLinks = _links.toSet();
        final newLinks = res.links.where((l) => !existingLinks.contains(l)).toList();
        _links.addAll(newLinks);
        _totalLinks = res.totalLinks > _links.length ? res.totalLinks : _links.length;
        _hasMoreLinks = res.hasMore;
      });
    } catch (e) {
      debugPrint('[ChatV2MediaHub] _loadMoreLinks error: $e');
    } finally {
      if (mounted) setState(() => _isLoadingLinks = false);
    }
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
            Text(
              'Ảnh, file, link đã gửi',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
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
            Tab(text: 'Ảnh ($_totalImages)'),
            Tab(text: 'Tài liệu ($_totalFiles)'),
            Tab(text: 'Liên kết ($_totalLinks)'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 1. Images Grid với Infinite Scroll & Refresh
          RefreshIndicator(
            color: const Color(0xFF00C83A),
            onRefresh: _refreshImages,
            child: _images.isEmpty
                ? SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: SizedBox(
                      height: MediaQuery.of(context).size.height * 0.6,
                      child: _buildEmptyState(isDark, LucideIcons.image, 'Chưa có hình ảnh nào'),
                    ),
                  )
                : CustomScrollView(
                    controller: _imagesScrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.all(16),
                        sliver: SliverGrid(
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                          delegate: SliverChildBuilderDelegate(
                            (context, idx) {
                              final img = _images[idx];
                              final memBytes = img.bytes ??
                                  (img.id.isNotEmpty ? ChatV2AttachmentImage.imageCache[img.id] : null) ??
                                  LocalAttachmentCache.get(img.id.isNotEmpty ? img.id : null);
                              final fullUrl = img.resolveFullUrl(odooApiClient.absoluteUrl(''));

                              final heroTag = 'info_gallery_img_${img.id.isNotEmpty ? img.id : (fullUrl.isNotEmpty ? fullUrl : img.name)}_hub_$idx';

                              return GestureDetector(
                                onTap: () async {
                                  final targetMsgId = await Navigator.of(context).push<String?>(
                                    ChatV2ImageViewerScreen.route(
                                      images: _images,
                                      initialIndex: idx,
                                      imageUrl: fullUrl,
                                      title: '',
                                      bytes: memBytes,
                                      attachmentId: img.id.isNotEmpty ? img.id : null,
                                      heroTag: heroTag,
                                      messageId: img.messageId,
                                    ),
                                  );
                                  if (targetMsgId != null && targetMsgId.isNotEmpty && context.mounted) {
                                    Navigator.of(context).pop(targetMsgId);
                                  }
                                },
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                                    child: Hero(
                                      tag: heroTag,
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
                                ),
                              );
                            },
                            childCount: _images.length,
                          ),
                        ),
                      ),
                      if (_isLoadingImages)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00C83A)),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
          ),

          // 2. Files List với Infinite Scroll & Refresh
          RefreshIndicator(
            color: const Color(0xFF00C83A),
            onRefresh: _refreshFiles,
            child: _files.isEmpty
                ? SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: SizedBox(
                      height: MediaQuery.of(context).size.height * 0.6,
                      child: _buildEmptyState(isDark, LucideIcons.fileText, 'Chưa có tài liệu nào'),
                    ),
                  )
                : ListView.separated(
                    controller: _filesScrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: _files.length + (_isLoadingFiles ? 1 : 0),
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, idx) {
                      if (idx == _files.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00C83A)),
                              ),
                            ),
                          ),
                        );
                      }
                      final file = _files[idx];
                      final ext = file.name.contains('.') ? file.name.split('.').last.toUpperCase() : 'FILE';
                      final cachedBytes = file.bytes ??
                          LocalAttachmentCache.get(file.id) ??
                          LocalAttachmentCache.get(file.name);
                      final size = file.fileSize ?? cachedBytes?.lengthInBytes;
                      final sizeStr = size != null ? _formatFileSize(size) : null;

                      return InkWell(
                        onTap: () async {
                          final targetPath = (file.downloadUrl != null && file.downloadUrl!.isNotEmpty)
                              ? file.downloadUrl!
                              : ((file.url != null && file.url!.isNotEmpty)
                                  ? file.url!
                                  : ((int.tryParse(file.id) != null && file.id.isNotEmpty)
                                      ? '/web/content/${file.id}/${file.name}'
                                      : ''));

                          await ChatV2AttachmentViewer.open(
                            context: context,
                            filename: file.name,
                            attachmentId: int.tryParse(file.id),
                            downloadUrl: targetPath.isNotEmpty ? targetPath : null,
                            directBytes: cachedBytes,
                          );
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
          ),

          // 3. Links List với Infinite Scroll & Refresh
          RefreshIndicator(
            color: const Color(0xFF00C83A),
            onRefresh: _refreshLinks,
            child: _links.isEmpty
                ? SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: SizedBox(
                      height: MediaQuery.of(context).size.height * 0.6,
                      child: _buildEmptyState(isDark, LucideIcons.link, 'Chưa có liên kết nào'),
                    ),
                  )
                : ListView.separated(
                    controller: _linksScrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: _links.length + (_isLoadingLinks ? 1 : 0),
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, idx) {
                      if (idx == _links.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00C83A)),
                              ),
                            ),
                          ),
                        );
                      }
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

/// BottomSheet chọn và thêm thành viên vào nhóm chat
class _AddGroupMemberBottomSheet extends ConsumerStatefulWidget {
  final String channelId;
  final List<ChatV2Member> currentMembers;
  final ValueChanged<int>? onMembersAdded;

  const _AddGroupMemberBottomSheet({
    required this.channelId,
    required this.currentMembers,
    this.onMembersAdded,
  });

  @override
  ConsumerState<_AddGroupMemberBottomSheet> createState() =>
      _AddGroupMemberBottomSheetState();
}

class _AddGroupMemberBottomSheetState
    extends ConsumerState<_AddGroupMemberBottomSheet> {
  final Set<String> _selectedPartnerIds = {};
  String _searchQuery = '';
  bool _submitting = false;

  late final _usersFuture = FutureProvider.autoDispose<List<Profile>>((ref) async {
    final repo = ref.read(chatRepositoryProvider);
    return repo.allUsers();
  });

  Future<void> _submitAddMembers(List<Profile> allProfiles) async {
    if (_selectedPartnerIds.isEmpty) return;

    final targetPartnerIds = _selectedPartnerIds
        .map(int.tryParse)
        .whereType<int>()
        .toList();

    if (targetPartnerIds.isEmpty) {
      AppToast.warning(
        context,
        title: 'Chưa chọn thành viên',
        message: 'Vui lòng chọn ít nhất một thành viên hợp lệ để thêm.',
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final res = await ref.read(chatV2RepositoryProvider).addChannelMembers(
            channelId: widget.channelId,
            partnerIds: targetPartnerIds,
          );

      if (mounted) {
        Navigator.of(context).pop();
        final count = (res['member_count'] as int?) ??
            (widget.currentMembers.length + targetPartnerIds.length);
        widget.onMembersAdded?.call(count);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        AppToast.error(
          context,
          title: 'Không thể thêm thành viên',
          message: '$e',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final usersAsync = ref.watch(_usersFuture);
    final existingMemberIds = widget.currentMembers
        .map((m) => m.id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();
    final existingMemberNames = widget.currentMembers
        .map((m) => m.name.trim().toLowerCase())
        .where((n) => n.isNotEmpty)
        .toSet();

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.85,
      child: Material(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar & Header
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Thêm thành viên mới',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      LucideIcons.x,
                      size: 20,
                      color: isDark ? Colors.white70 : const Color(0xFF64748B),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Divider(
              height: 1,
              color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
            ),

            // Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
                decoration: InputDecoration(
                  prefixIcon: Icon(
                    LucideIcons.search,
                    size: 18,
                    color: isDark ? Colors.white60 : const Color(0xFF64748B),
                  ),
                  hintText: 'Tìm theo tên hoặc email...',
                  hintStyle: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                  ),
                  filled: true,
                  fillColor: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFF1F5F9),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark ? Colors.white10 : const Color(0xFFE2E8F0),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF00C83A),
                      width: 1.5,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 11),
                ),
                onChanged: (v) => setState(() => _searchQuery = v.trim()),
              ),
            ),

            // Selected Chips
            if (_selectedPartnerIds.isNotEmpty)
              usersAsync.maybeWhen(
                data: (allUsers) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: SizedBox(
                      width: double.infinity,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          for (final pid in _selectedPartnerIds)
                            InputChip(
                              label: Text(
                                allUsers
                                    .firstWhereOrNull((u) =>
                                        u.partnerId == pid || u.id == pid)
                                    ?.displayName ??
                                    'Thành viên',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF0F172A),
                                ),
                              ),
                              backgroundColor: isDark
                                  ? const Color(0xFF1E293B)
                                  : const Color(0xFFE2E8F0),
                              deleteIconColor: isDark
                                  ? Colors.white60
                                  : const Color(0xFF64748B),
                              onDeleted: () => setState(() => _selectedPartnerIds.remove(pid)),
                            ),
                        ],
                      ),
                    ),
                  );
                },
                orElse: () => const SizedBox.shrink(),
              ),

            // User List
            Expanded(
              child: usersAsync.when(
                loading: () => const LoadingView(),
                error: (err, _) => Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Lỗi tải danh sách người dùng: $err',
                      style: const TextStyle(color: Color(0xFFEF4444)),
                    ),
                  ),
                ),
                data: (allUsers) {
                  // Lọc bỏ những người đã là thành viên trong nhóm
                  final availableUsers = allUsers.where((u) {
                    final pId = u.partnerId?.trim() ?? '';
                    final uId = u.id.trim();
                    final name = u.displayName.trim().toLowerCase();

                    final isAlreadyMember = (pId.isNotEmpty && existingMemberIds.contains(pId)) ||
                        (uId.isNotEmpty && existingMemberIds.contains(uId)) ||
                        (name.isNotEmpty && existingMemberNames.contains(name));
                    return !isAlreadyMember && !u.isPortal;
                  }).toList();

                  final rawQ = _searchQuery.trim();
                  final searchQ = rawQ.startsWith('@') ? rawQ.substring(1).trim().toLowerCase() : rawQ.toLowerCase();
                  final filtered = searchQ.isEmpty
                      ? availableUsers
                      : availableUsers.where((u) {
                          final nameMatch = u.displayName.toLowerCase().contains(searchQ);
                          final emailUser = u.email.contains('@')
                              ? u.email.split('@').first.toLowerCase()
                              : u.email.toLowerCase();
                          final emailMatch = emailUser.contains(searchQ);
                          final roleMatch = (u.isPortal ? 'khách hàng portal' : 'nội bộ nhân viên').contains(searchQ);
                          return nameMatch || emailMatch || roleMatch;
                        }).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          _searchQuery.isEmpty
                              ? 'Tất cả đồng nghiệp đã tham gia nhóm'
                              : 'Không tìm thấy người dùng phù hợp',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.white60 : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: filtered.length,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    separatorBuilder: (_, _) => Divider(
                      height: 1,
                      indent: 72,
                      endIndent: 16,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : const Color(0xFFE2E8F0),
                    ),
                    itemBuilder: (context, idx) {
                      final u = filtered[idx];
                      final targetPid = (u.partnerId != null && u.partnerId!.isNotEmpty)
                          ? u.partnerId!
                          : u.id;
                      final isSelected = _selectedPartnerIds.contains(targetPid);

                      return CheckboxListTile(
                        value: isSelected,
                        activeColor: const Color(0xFF00C83A),
                        checkColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 2,
                        ),
                        secondary: UserAvatar(
                          userId: u.id,
                          displayName: u.displayName,
                          email: u.email,
                          avatarUrl: u.avatarUrl,
                          size: 40,
                        ),
                        title: Row(
                          children: [
                            Flexible(
                              child: Text(
                                u.displayName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                ),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Text(
                          u.email,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isDark ? Colors.white60 : const Color(0xFF64748B),
                          ),
                        ),
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedPartnerIds.add(targetPid);
                            } else {
                              _selectedPartnerIds.remove(targetPid);
                            }
                          });
                        },
                      );
                    },
                  );
                },
              ),
            ),

            // Submit Button
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton.icon(
                  onPressed: (_selectedPartnerIds.isEmpty || _submitting)
                      ? null
                      : () {
                          final allUsers = usersAsync.valueOrNull ?? [];
                          _submitAddMembers(allUsers);
                        },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF00C83A),
                    disabledBackgroundColor: isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFE2E8F0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(LucideIcons.userPlus, size: 18),
                  label: Text(
                    _submitting
                        ? 'Đang thêm...'
                        : 'Thêm vào nhóm (${_selectedPartnerIds.length})',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ));
  }
}
