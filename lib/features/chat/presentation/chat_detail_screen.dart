import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../../core/api/auth_user.dart';
import '../../../core/api/mobile_attachment_repository.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/utils/file_download.dart';
import '../../../shared/models/conversation.dart';
import '../../../shared/models/message.dart';
import '../../../shared/models/profile.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/html_network_image.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../../shared/widgets/ui_kit.dart';
import '../../auth/application/auth_controller.dart';
import '../application/conversations_controller.dart';
import '../application/messages_controller.dart';
import 'forward_conversation_sheet.dart';
import 'image_viewer_screen.dart';

const _incomingBubbleColor = Color(0xFFE7F8E7);
const _incomingBubbleBorder = Color(0xFFC8EFD0);

class ChatDetailScreen extends ConsumerStatefulWidget {
  const ChatDetailScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends ConsumerState<ChatDetailScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(markAsReadActionProvider).markAsRead(widget.conversationId);
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(sendMessageActionProvider)
          .send(widget.conversationId, text);
      _input.clear();
      _scrollToBottom();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gửi thất bại: $e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _sendAttachment(MobileAttachmentUpload attachment) async {
    setState(() => _sending = true);
    try {
      await ref
          .read(sendAttachmentActionProvider)
          .send(widget.conversationId, attachment);
      _scrollToBottom();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã gửi ${attachment.filename}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gửi file thất bại: $e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.minScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authControllerProvider).value;
    final myId = currentUser?.id ?? '';
    final myIdentityIds = _myIdentityIds(currentUser);
    final messages = ref.watch(messagesProvider(widget.conversationId));
    final details = ref.watch(
      conversationDetailsProvider(widget.conversationId),
    );
    final fallbackTitle = _summaryTitle(
      ref,
      widget.conversationId,
      currentUser,
    );
    final fallbackAvatarUrl = _summaryAvatarUrl(ref, widget.conversationId);
    final conversation = details.valueOrNull;
    final title = _chatTitle(conversation, fallbackTitle, myIdentityIds);
    final senderProfiles = _senderProfiles(conversation);
    final pinnedMessage = _pinnedMessage(messages.valueOrNull);

    return Scaffold(
      extendBodyBehindAppBar: true,
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFFDDF3D9),
      body: Stack(
        children: [
          const Positioned.fill(child: _ChatWallpaper()),
          SafeArea(
            child: Column(
              children: [
                _FloatingChatHeader(
                  conversationId: widget.conversationId,
                  title: title,
                  conversation: conversation,
                  currentIdentityIds: myIdentityIds,
                  fallbackAvatarUrl: fallbackAvatarUrl,
                  onOpenInfo: () => _openChatInfo(
                    context,
                    title: title,
                    conversation: conversation,
                    currentIdentityIds: myIdentityIds,
                    messages: messages.valueOrNull ?? const [],
                  ),
                ),
                if (pinnedMessage != null)
                  _PinnedMessageBanner(message: pinnedMessage),
                Expanded(
                  child: messages.when(
                    data: (list) {
                      if (list.isEmpty) {
                        return const _EmptyConversation();
                      }
                      WidgetsBinding.instance.addPostFrameCallback(
                        (_) => _scrollToBottom(),
                      );
                      final lastReadOwnMessageId = _lastReadOwnMessageId(
                        list,
                        currentUser,
                        myIdentityIds,
                      );
                      return ListView.builder(
                        controller: _scroll,
                        reverse: true,
                        padding: const EdgeInsets.fromLTRB(10, 10, 10, 18),
                        itemCount: list.length,
                        itemBuilder: (_, index) {
                          final listIndex = list.length - 1 - index;
                          final message = list[listIndex];
                          final older = listIndex == 0
                              ? null
                              : list[listIndex - 1];
                          final newer = listIndex == list.length - 1
                              ? null
                              : list[listIndex + 1];
                          final showDate =
                              older == null ||
                              !_sameDay(older.createdAt, message.createdAt);
                          final mine = _isMine(
                            message,
                            currentUser,
                            myIdentityIds,
                          );
                          final showAvatar =
                              !mine &&
                              (newer == null ||
                                  newer.senderId != message.senderId ||
                                  !_sameDay(
                                    newer.createdAt,
                                    message.createdAt,
                                  ));

                          return Column(
                            children: [
                              if (showDate)
                                _DateSeparator(date: message.createdAt),
                              _Bubble(
                                message: message,
                                mine: mine,
                                sender: senderProfiles[message.senderId],
                                showAvatar: showAvatar,
                                readBy:
                                    mine && message.id == lastReadOwnMessageId
                                    ? _readerProfilesForMessage(
                                        message,
                                        conversation,
                                        myId,
                                      )
                                    : const [],
                              ),
                            ],
                          );
                        },
                      );
                    },
                    loading: () => const LoadingView(),
                    error: (e, _) => ErrorView(
                      error: e,
                      onRetry: () {
                        ref.invalidate(messagesProvider(widget.conversationId));
                        ref.invalidate(
                          conversationDetailsProvider(widget.conversationId),
                        );
                      },
                    ),
                  ),
                ),
                _ComposerWithAttachments(
                  controller: _input,
                  sending: _sending,
                  onSubmit: _send,
                  onAttachment: _sendAttachment,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _sameDay(DateTime a, DateTime b) {
    final localA = a.toLocal();
    final localB = b.toLocal();
    return localA.year == localB.year &&
        localA.month == localB.month &&
        localA.day == localB.day;
  }

  bool _isRead(Message message) {
    return message.isReadByMe ||
        message.readByCount > 0 ||
        message.status == 'read' ||
        message.readAt != null;
  }

  Message? _pinnedMessage(List<Message>? messages) {
    if (messages == null) return null;
    final pinned = messages.where((message) => message.pinnedAt != null).toList()
      ..sort((a, b) => b.pinnedAt!.compareTo(a.pinnedAt!));
    return pinned.isEmpty ? null : pinned.first;
  }

  String _summaryTitle(
    WidgetRef ref,
    String conversationId,
    AuthUser? currentUser,
  ) {
    return ref
        .watch(conversationsProvider)
        .maybeWhen(
          data: (list) {
            for (final conversation in list) {
              if (conversation.id == conversationId) {
                return _titleForCurrentUser(conversation.title, currentUser);
              }
            }
            return 'Chat';
          },
          orElse: () => 'Chat',
        );
  }

  String? _summaryAvatarUrl(WidgetRef ref, String conversationId) {
    return ref
        .watch(conversationsProvider)
        .maybeWhen(
          data: (list) {
            for (final conversation in list) {
              if (conversation.id == conversationId) {
                return conversation.avatarUrl;
              }
            }
            return null;
          },
          orElse: () => null,
        );
  }

  String _chatTitle(
    Conversation? conversation,
    String fallbackTitle,
    Set<String> myIdentityIds,
  ) {
    final detailTitle = conversation?.displayTitleFor(myIdentityIds).trim();
    if (detailTitle == null || detailTitle.isEmpty || detailTitle == 'Chat') {
      return fallbackTitle;
    }
    if (_isSelfLabel(detailTitle, myIdentityIds) && fallbackTitle != 'Chat') {
      return fallbackTitle;
    }
    return detailTitle;
  }

  String _titleForCurrentUser(String rawTitle, AuthUser? currentUser) {
    final title = rawTitle.trim();
    if (title.isEmpty || currentUser == null || !title.contains(',')) {
      return title.isEmpty ? 'Chat' : title;
    }

    final currentLabels = <String>{
      currentUser.id,
      currentUser.email ?? '',
      currentUser.email?.split('@').first ?? '',
      currentUser.userMetadata['display_name']?.toString() ?? '',
      currentUser.userMetadata['partner_id']?.toString() ?? '',
      'You',
      'Bạn',
      'Ban',
    }.map(_identityText).where((label) => label.isNotEmpty).toSet();

    final others = title
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .where((part) => !currentLabels.contains(_identityText(part)))
        .toList();
    return others.isEmpty ? title : others.join(', ');
  }

  String? _lastReadOwnMessageId(
    List<Message> messages,
    AuthUser? currentUser,
    Set<String> myIdentityIds,
  ) {
    for (final message in messages.reversed) {
      if (_isMine(message, currentUser, myIdentityIds)) {
        return _isRead(message) ? message.id : null;
      }
    }
    return null;
  }

  List<Profile> _readerProfilesForMessage(
    Message message,
    Conversation? conversation,
    String myId,
  ) {
    final profilesById = <String, Profile>{
      for (final member
          in conversation?.members ?? const <ConversationMember>[])
        member.profile.id: member.profile,
    };

    if (message.readBy.isNotEmpty) {
      return message.readBy
          .where((id) => id != myId && id != message.senderId)
          .map((id) {
            return profilesById[id] ??
                Profile(id: id, email: '', displayName: 'Nguoi doc');
          })
          .take(3)
          .toList();
    }

    final members = conversation?.members
        .where(
          (member) =>
              member.profile.id != myId &&
              member.profile.id != message.senderId,
        )
        .map((member) => member.profile)
        .take(message.readByCount.clamp(0, 3))
        .toList();
    if (members != null && members.isNotEmpty) return members;
    if (message.readByCount <= 0) return const [];

    return <Profile>[
      Profile(id: 'read-${message.id}', email: '', displayName: 'Da doc'),
    ];
  }

  Map<String, Profile> _senderProfiles(Conversation? conversation) {
    if (conversation == null) return const {};
    return {
      for (final member in conversation.members)
        member.profile.id: member.profile,
    };
  }

  Set<String> _myIdentityIds(AuthUser? user) {
    if (user == null) return const {};
    return {
      if (user.id.isNotEmpty) user.id,
      if (user.userMetadata['partner_id'] != null)
        user.userMetadata['partner_id'].toString(),
      if (user.email != null) user.email!,
      if (user.email != null) user.email!.split('@').first,
      if (user.userMetadata['display_name'] != null)
        user.userMetadata['display_name'].toString(),
    };
  }

  bool _isSelfLabel(String label, Set<String> myIdentityIds) {
    final normalized = _identityText(label);
    return normalized == 'you' ||
        normalized == 'ban' ||
        normalized == 'bạn' ||
        myIdentityIds.map(_identityText).contains(normalized);
  }

  bool _isMine(Message message, AuthUser? user, Set<String> myIdentityIds) {
    if (message.authoredByMe) return true;
    if (myIdentityIds.contains(message.senderId)) return true;

    final senderName = _identityText(message.senderName);
    if (senderName.isEmpty || user == null) return false;

    final email = _identityText(user.email);
    final displayName = _identityText(user.userMetadata['display_name']);
    return senderName == email || senderName == displayName;
  }

  String _identityText(Object? value) {
    if (value == null || value == false) return '';
    return value.toString().trim().toLowerCase();
  }

  void _openChatInfo(
    BuildContext context, {
    required String title,
    required Conversation? conversation,
    required Set<String> currentIdentityIds,
    required List<Message> messages,
  }) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ChatInfoSheet(
        title: title,
        conversation: conversation,
        currentIdentityIds: currentIdentityIds,
        messages: messages,
      ),
    );
  }
}

class _ChatWallpaper extends StatelessWidget {
  const _ChatWallpaper();

  static const _icons = [
    LucideIcons.messageCircle,
    LucideIcons.image,
    LucideIcons.camera,
    LucideIcons.paperclip,
    LucideIcons.send,
    LucideIcons.smile,
    LucideIcons.star,
    LucideIcons.cloud,
    LucideIcons.coffee,
    LucideIcons.heart,
    LucideIcons.mapPin,
    LucideIcons.calendar,
  ];

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFE8F5B8), Color(0xFFBFE9C9), Color(0xFF8ED8BE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = (constraints.maxWidth / 72).ceil() + 1;
          final rows = (constraints.maxHeight / 72).ceil() + 1;
          return Stack(
            children: [
              for (var row = 0; row < rows; row++)
                for (var col = 0; col < columns; col++)
                  Positioned(
                    left: col * 72.0 + (row.isEven ? 4 : 38),
                    top: row * 72.0,
                    child: Transform.rotate(
                      angle: ((row + col) % 5 - 2) * 0.14,
                      child: Icon(
                        _icons[(row * columns + col) % _icons.length],
                        size: 30 + ((row + col) % 3) * 5,
                        color: AppColors.midnight.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}

bool _isCurrentProfile(Profile profile, Set<String> currentIdentityIds) {
  final labels = currentIdentityIds
      .map((label) => label.trim().toLowerCase())
      .where((label) => label.isNotEmpty)
      .toSet();
  if (labels.isEmpty) return false;
  return labels.contains(profile.id.trim().toLowerCase()) ||
      labels.contains(profile.email.trim().toLowerCase()) ||
      labels.contains(profile.displayName.trim().toLowerCase());
}

class _FrostedSurface extends StatelessWidget {
  const _FrostedSurface({
    required this.child,
    this.height,
    this.padding,
    this.radius = 28,
  });

  final Widget child;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.58),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.72),
              width: 1.1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x140F172A),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _FloatingChatHeader extends StatelessWidget {
  const _FloatingChatHeader({
    required this.conversationId,
    required this.title,
    required this.conversation,
    required this.currentIdentityIds,
    required this.fallbackAvatarUrl,
    required this.onOpenInfo,
  });

  final String conversationId;
  final String title;
  final Conversation? conversation;
  final Set<String> currentIdentityIds;
  final String? fallbackAvatarUrl;
  final VoidCallback onOpenInfo;

  @override
  Widget build(BuildContext context) {
    final other = _otherProfile();
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
      child: Row(
        children: [
          _RoundIconButton(
            tooltip: 'Quay lại',
            icon: LucideIcons.chevronLeft,
            onTap: () => Navigator.maybePop(context),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: PressableScale(
              onTap: onOpenInfo,
              scale: 0.99,
              child: _FrostedSurface(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                radius: 999,
                child: Row(
                  children: [
                    _HeaderAvatar(
                      conversation: conversation,
                      title: title,
                      other: other,
                      fallbackAvatarUrl: fallbackAvatarUrl,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Hero(
                            tag: 'chat-title-$conversationId',
                            child: Material(
                              color: Colors.transparent,
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            conversation?.isGroup == true
                                ? 'Nhóm trò chuyện'
                                : 'Đang hoạt động',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      LucideIcons.chevronRight,
                      color: AppColors.textSecondary,
                      size: 17,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Profile? _otherProfile() {
    final current = conversation;
    if (current == null || current.isGroup) return null;
    for (final member in current.members) {
      if (!_isCurrentProfile(member.profile, currentIdentityIds)) {
        return member.profile;
      }
    }
    return null;
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: PressableScale(
        onTap: onTap,
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.62),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
              ),
              child: Icon(icon, color: AppColors.textPrimary, size: 24),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderAvatar extends StatelessWidget {
  const _HeaderAvatar({
    required this.conversation,
    required this.title,
    required this.other,
    required this.fallbackAvatarUrl,
  });

  final Conversation? conversation;
  final String title;
  final Profile? other;
  final String? fallbackAvatarUrl;

  @override
  Widget build(BuildContext context) {
    if (conversation?.isGroup == true) {
      return Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          gradient: AppColors.chatGrad,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(LucideIcons.users, color: Colors.white, size: 18),
      );
    }
    return UserAvatar(
      userId: other?.id ?? title,
      displayName: other?.displayName ?? title,
      email: other?.email,
      avatarUrl: other?.avatarUrl ?? fallbackAvatarUrl,
      size: 34,
    );
  }
}

class _ChatInfoSheet extends ConsumerStatefulWidget {
  const _ChatInfoSheet({
    required this.title,
    required this.conversation,
    required this.currentIdentityIds,
    required this.messages,
  });

  final String title;
  final Conversation? conversation;
  final Set<String> currentIdentityIds;
  final List<Message> messages;

  @override
  ConsumerState<_ChatInfoSheet> createState() => _ChatInfoSheetState();
}

class _ChatInfoSheetState extends ConsumerState<_ChatInfoSheet> {
  int _tab = 0;

  Profile? get _otherProfile {
    final conversation = widget.conversation;
    if (conversation == null || conversation.isGroup) return null;
    for (final member in conversation.members) {
      if (!_isCurrentProfile(member.profile, widget.currentIdentityIds)) {
        return member.profile;
      }
    }
    return null;
  }

  List<_MediaInfo> get _mediaItems {
    final items = <_MediaInfo>[];
    for (final message in widget.messages) {
      if (message.attachmentIds.isNotEmpty) {
        final fileName = _attachmentFileName(message);
        if (_isImageAttachment(message, fileName)) {
          final attachmentId = message.attachmentIds.first;
          items.add(
            _MediaInfo(
              url: ref
                  .read(downloadAttachmentActionProvider)
                  .contentUrl(attachmentId, url: message.attachmentUrl),
              isImage: true,
              isVideo: false,
              label: fileName,
              attachmentId: attachmentId,
            ),
          );
          continue;
        }
      }

      final media = _MediaInfo.fromContent(message.content);
      if (media != null) items.add(media);
    }
    return items.reversed.toList();
  }

  List<String> get _links {
    final pattern = RegExp(r'https?:\/\/[^\s]+');
    return widget.messages
        .expand((message) => pattern.allMatches(message.content))
        .map((match) => match.group(0)!)
        .toSet()
        .toList();
  }

  List<_FileInfo> get _files {
    final files = <_FileInfo>[];
    final seen = <String>{};
    for (final message in widget.messages) {
      if (message.attachmentIds.isEmpty) continue;
      final fileName = _attachmentFileName(message);
      if (_isImageAttachment(message, fileName)) continue;

      final attachmentId = message.attachmentIds.first;
      if (!seen.add(attachmentId)) continue;
      files.add(
        _FileInfo(
          attachmentId: attachmentId,
          name: fileName,
          sizeLabel: _formatFileSize(message.attachmentSize),
        ),
      );
    }
    return files.reversed.toList();
  }

  @override
  Widget build(BuildContext context) {
    final other = _otherProfile;
    final shareLink = 'vcloud://chat/${widget.conversation?.id ?? 'direct'}';
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.5,
      maxChildSize: 0.96,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF6F6FA),
            borderRadius: BorderRadius.vertical(top: Radius.circular(34)),
          ),
          clipBehavior: Clip.antiAlias,
          child: CustomScrollView(
            controller: scrollController,
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
                  child: Column(
                    children: [
                      Container(
                        width: 46,
                        height: 5,
                        decoration: BoxDecoration(
                          color: AppColors.border,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                      const SizedBox(height: 22),
                      _LargeChatAvatar(
                        title: widget.title,
                        conversation: widget.conversation,
                        other: other,
                      ),
                      const SizedBox(height: 18),
                      Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Row(
                        children: [
                          Expanded(
                            child: _InfoActionTile(
                              icon: LucideIcons.bellOff,
                              label: 'Tắt thông báo',
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: _InfoActionTile(
                              icon: LucideIcons.search,
                              label: 'Tìm kiếm',
                            ),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: _InfoActionTile(
                              icon: LucideIcons.moreHorizontal,
                              label: 'Thêm',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _ShareLinkCard(link: shareLink),
                      const SizedBox(height: 18),
                      _InfoSegmentedTabs(
                        selected: _tab,
                        onChanged: (value) => setState(() => _tab = value),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 24),
                sliver: _buildTabContent(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTabContent() {
    return switch (_tab) {
      0 => _MediaGrid(items: _mediaItems),
      1 => _SimpleInfoList(
        icon: LucideIcons.link,
        emptyText: 'Chưa có liên kết',
        items: _links,
      ),
      _ => _FileInfoList(items: _files),
    };
  }
}

class _LargeChatAvatar extends StatelessWidget {
  const _LargeChatAvatar({
    required this.title,
    required this.conversation,
    required this.other,
  });

  final String title;
  final Conversation? conversation;
  final Profile? other;

  @override
  Widget build(BuildContext context) {
    if (conversation?.isGroup == true) {
      return Container(
        width: 118,
        height: 118,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [Color(0xFF2DD4BF), Color(0xFF3B82F6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Icon(LucideIcons.users, color: Colors.white, size: 48),
      );
    }
    return UserAvatar(
      userId: other?.id ?? title,
      displayName: other?.displayName ?? title,
      email: other?.email,
      avatarUrl: other?.avatarUrl,
      size: 112,
    );
  }
}

class _InfoActionTile extends StatelessWidget {
  const _InfoActionTile({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 78,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F0F172A),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.primary, size: 24),
          const SizedBox(height: 7),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareLinkCard extends StatelessWidget {
  const _ShareLinkCard({required this.link});

  final String link;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Liên kết chia sẻ',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  link,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          const Icon(LucideIcons.qrCode, color: AppColors.primary, size: 26),
        ],
      ),
    );
  }
}

class _InfoSegmentedTabs extends StatelessWidget {
  const _InfoSegmentedTabs({required this.selected, required this.onChanged});

  final int selected;
  final ValueChanged<int> onChanged;

  static const _labels = ['Media', 'Links', 'File'];

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(999),
          boxShadow: const [
            BoxShadow(
              color: Color(0x120F172A),
              blurRadius: 18,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 0; index < _labels.length; index++)
              PressableScale(
                onTap: () => onChanged(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: selected == index
                        ? const Color(0xFFE6E7EB)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _labels[index],
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MediaGrid extends StatelessWidget {
  const _MediaGrid({required this.items});

  final List<_MediaInfo> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SliverToBoxAdapter(
        child: _InfoEmptyState(icon: LucideIcons.image, text: 'Chưa có media'),
      );
    }
    return SliverGrid.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 1,
        crossAxisSpacing: 1,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return PressableScale(
          onTap: item.isImage
              ? () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ImageViewerScreen(
                        imageUrl: item.url,
                        fileName: item.displayLabel,
                        attachmentId: item.attachmentIntId,
                      ),
                    ),
                  );
                }
              : null,
          child: ClipRect(
            child: item.isImage
                ? ColoredBox(
                    color: AppColors.soft(AppColors.chat),
                    child: _NetworkPreviewImage(
                      url: item.url,
                      fit: BoxFit.cover,
                      fallback: _MediaFallback(media: item),
                      attachmentId: item.attachmentId,
                    ),
                  )
                : const ColoredBox(
                    color: Color(0x1434D399),
                    child: Center(
                      child: Icon(
                        LucideIcons.video,
                        color: AppColors.textSecondary,
                        size: 32,
                      ),
                    ),
                  ),
          ),
        );
      },
    );
  }
}

class _FileInfoList extends ConsumerWidget {
  const _FileInfoList({required this.items});

  final List<_FileInfo> items;

  Future<void> _download(
    BuildContext context,
    WidgetRef ref,
    _FileInfo item,
  ) async {
    try {
      final url = await ref
          .read(downloadAttachmentActionProvider)
          .downloadUrl(item.attachmentId);
      final opened = openDownloadUrl(url);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            opened
                ? 'Đang tải ${item.name}'
                : 'Tải xuống hiện chỉ hỗ trợ trên web.',
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không thể tải tệp: $e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (items.isEmpty) {
      return const SliverToBoxAdapter(
        child: _InfoEmptyState(icon: LucideIcons.fileText, text: 'Chưa có tệp'),
      );
    }
    return SliverList.separated(
      itemCount: items.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = items[index];
        final accent = _fileAccentColor(item.name);
        return Material(
          color: Colors.white,
          child: InkWell(
            onTap: () => _download(context, ref, item),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.soft(accent),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(LucideIcons.fileText, color: accent, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.sizeLabel,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    LucideIcons.download,
                    color: AppColors.textMuted,
                    size: 19,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SimpleInfoList extends StatelessWidget {
  const _SimpleInfoList({
    required this.icon,
    required this.emptyText,
    required this.items,
  });

  final IconData icon;
  final String emptyText;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return SliverToBoxAdapter(
        child: _InfoEmptyState(icon: icon, text: emptyText),
      );
    }
    return SliverList.separated(
      itemCount: items.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          color: Colors.white,
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  items[index],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InfoEmptyState extends StatelessWidget {
  const _InfoEmptyState({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 26),
      child: Column(
        children: [
          Icon(icon, color: AppColors.textMuted, size: 34),
          const SizedBox(height: 10),
          Text(
            text,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PinnedMessageBanner extends StatelessWidget {
  const _PinnedMessageBanner({required this.message});

  final Message message;

  @override
  Widget build(BuildContext context) {
    final preview = message.attachmentIds.isNotEmpty
        ? _attachmentFileName(message)
        : message.content.trim();
    final media = _MediaInfo.fromContent(preview);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: _FrostedSurface(
        height: 64,
        padding: const EdgeInsets.fromLTRB(12, 8, 14, 8),
        radius: 28,
        child: Row(
          children: [
            Container(
              width: 3,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.soft(AppColors.chat),
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: media?.isImage == true
                  ? Image.network(media!.url, fit: BoxFit.cover)
                  : Icon(
                      media?.isVideo == true
                          ? LucideIcons.video
                          : LucideIcons.messageCircle,
                      color: AppColors.chat,
                      size: 22,
                    ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tin nhắn ghim',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    media == null ? preview : media.displayLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(LucideIcons.pin, color: AppColors.textPrimary, size: 22),
          ],
        ),
      ),
    );
  }
}

class _EmptyConversation extends StatelessWidget {
  const _EmptyConversation();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.68),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.soft(AppColors.chat),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                LucideIcons.messageCircle,
                color: AppColors.chat,
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Chưa có tin nhắn nào',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Gửi lời chào để bắt đầu trao đổi.',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateSeparator extends StatelessWidget {
  const _DateSeparator({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.midnight.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            Dates.date(date),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _Bubble extends ConsumerWidget {
  const _Bubble({
    required this.message,
    required this.mine,
    required this.sender,
    required this.showAvatar,
    required this.readBy,
  });

  final Message message;
  final bool mine;
  final Profile? sender;
  final bool showAvatar;
  final List<Profile> readBy;

  void _openImageViewer(BuildContext context, String url) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ImageViewerScreen(
          imageUrl: url,
          fileName: _attachmentFileName(message),
          attachmentId: message.attachmentIds.isEmpty
              ? null
              : int.tryParse(message.attachmentIds.first),
        ),
      ),
    );
  }

  Future<void> _forwardAttachment(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final target = await showForwardConversationPicker(context);
    if (target == null) return;
    try {
      await ref
          .read(forwardAttachmentActionProvider)
          .forward(target.id, message.attachmentIds.first);
      messenger.showSnackBar(
        SnackBar(content: Text('Đã chuyển tiếp đến ${target.title}')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Chuyển tiếp thất bại: $e')),
      );
    }
  }

  Future<void> _togglePin(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final pinned = message.pinnedAt != null;
    try {
      if (pinned) {
        await ref
            .read(pinMessageActionProvider)
            .unpin(message.conversationId, message.id);
        messenger.showSnackBar(
          const SnackBar(content: Text('Đã bỏ ghim tin nhắn')),
        );
      } else {
        await ref
            .read(pinMessageActionProvider)
            .pin(message.conversationId, message.id);
        messenger.showSnackBar(
          const SnackBar(content: Text('Đã ghim tin nhắn')),
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Không thể cập nhật ghim: $e')),
      );
    }
  }

  /// The image URL to show in the full-screen viewer, or null when this bubble
  /// isn't an image (text, document, video, etc).
  String? _imagePreviewUrl(WidgetRef ref, _MediaInfo? media) {
    if (message.attachmentIds.isNotEmpty) {
      final fileName = _attachmentFileName(message);
      if (!_isImageAttachment(message, fileName)) return null;
      final id = message.attachmentIds.first;
      return ref
          .read(downloadAttachmentActionProvider)
          .contentUrl(id, url: message.attachmentUrl);
    }
    if (media == null || !media.isImage) return null;
    return media.url;
  }

  void _showContextMenu(BuildContext context, WidgetRef ref) {
    HapticFeedback.mediumImpact();
    final canForwardAttachment = message.attachmentIds.isNotEmpty;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          elevation: 12,
          shadowColor: const Color(0x220F172A),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    leading: const Icon(LucideIcons.copy),
                    title: const Text('Sao chép'),
                    onTap: () {
                      Navigator.pop(context);
                      Clipboard.setData(ClipboardData(text: message.content));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Đã sao chép tin nhắn')),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(LucideIcons.pin),
                    title: Text(
                      message.pinnedAt == null
                          ? 'Ghim tin nhắn'
                          : 'Bỏ ghim tin nhắn',
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _togglePin(context, ref);
                    },
                  ),
                  ListTile(
                    leading: const Icon(LucideIcons.forward),
                    title: const Text('Chuyển tiếp'),
                    onTap: () {
                      Navigator.pop(context);
                      if (!canForwardAttachment) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Chuyển tiếp tin nhắn sắp có'),
                          ),
                        );
                        return;
                      }
                      _forwardAttachment(context, ref);
                    },
                  ),
                  if (mine)
                    ListTile(
                      leading: const Icon(
                        LucideIcons.trash2,
                        color: AppColors.danger,
                      ),
                      title: const Text(
                        'Xóa',
                        style: TextStyle(color: AppColors.danger),
                      ),
                      onTap: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Xóa tin nhắn sắp có')),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media = _MediaInfo.fromContent(message.content);
    final maxWidth = MediaQuery.of(context).size.width * 0.72;
    final imagePreviewUrl = _imagePreviewUrl(ref, media);

    return Padding(
      padding: EdgeInsets.only(
        top: 3,
        bottom: readBy.isNotEmpty ? 2 : (showAvatar || mine ? 5 : 1),
      ),
      child: Column(
        crossAxisAlignment: mine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: mine
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!mine) ...[
                SizedBox(
                  width: 34,
                  child: showAvatar
                      ? UserAvatar(
                          userId: sender?.id ?? message.senderId,
                          displayName: sender?.displayName ?? 'Bạn',
                          email: sender?.email,
                          avatarUrl:
                              sender?.avatarUrl ?? message.senderAvatarUrl,
                          size: 30,
                        )
                      : const SizedBox(width: 30),
                ),
                const SizedBox(width: 6),
              ],
              GestureDetector(
                onTap: imagePreviewUrl == null
                    ? null
                    : () => _openImageViewer(context, imagePreviewUrl),
                onLongPress: () => _showContextMenu(context, ref),
                child: message.attachmentIds.isNotEmpty
                    ? _AttachmentBubble(
                        message: message,
                        mine: mine,
                        maxWidth: maxWidth,
                      )
                    : media == null
                    ? _TextBubble(
                        message: message,
                        mine: mine,
                        maxWidth: maxWidth,
                      )
                    : _MediaBubble(
                        message: message,
                        media: media,
                        mine: mine,
                        maxWidth: maxWidth,
                      ),
              ),
            ],
          ),
          if (readBy.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 3, right: 8),
              child: _ReadAvatars(readers: readBy),
            ),
        ],
      ),
    );
  }
}

class _TextBubble extends StatelessWidget {
  const _TextBubble({
    required this.message,
    required this.mine,
    required this.maxWidth,
  });

  final Message message;
  final bool mine;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final bubbleColor = mine ? AppColors.primary : _incomingBubbleColor;
    final textColor = mine ? Colors.white : AppColors.textPrimary;
    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: const EdgeInsets.fromLTRB(13, 9, 10, 7),
      decoration: BoxDecoration(
        color: bubbleColor,
        border: mine
            ? null
            : Border.all(color: _incomingBubbleBorder.withValues(alpha: 0.7)),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(mine ? 18 : 6),
          topRight: Radius.circular(mine ? 6 : 18),
          bottomLeft: const Radius.circular(18),
          bottomRight: const Radius.circular(18),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F172A),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Wrap(
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.end,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8, bottom: 2),
            child: Text(
              message.content,
              style: TextStyle(color: textColor, fontSize: 15, height: 1.35),
            ),
          ),
          _Timestamp(
            message: message,
            mine: mine,
            color: textColor.withValues(alpha: 0.62),
          ),
        ],
      ),
    );
  }
}

class _AttachmentBubble extends ConsumerStatefulWidget {
  const _AttachmentBubble({
    required this.message,
    required this.mine,
    required this.maxWidth,
  });

  final Message message;
  final bool mine;
  final double maxWidth;

  @override
  ConsumerState<_AttachmentBubble> createState() => _AttachmentBubbleState();
}

class _AttachmentBubbleState extends ConsumerState<_AttachmentBubble> {
  bool _downloading = false;

  Future<void> _download() async {
    if (_downloading || widget.message.attachmentIds.isEmpty) return;
    setState(() => _downloading = true);
    try {
      final url = await ref
          .read(downloadAttachmentActionProvider)
          .downloadUrl(widget.message.attachmentIds.first);
      final opened = openDownloadUrl(url);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            opened
                ? 'Đang tải ${_attachmentFileName(widget.message)}'
                : 'Tải xuống hiện chỉ hỗ trợ trên web.',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Không thể tải tệp: $e')));
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mine = widget.mine;
    final message = widget.message;
    final bubbleColor = mine ? AppColors.primary : _incomingBubbleColor;
    final textColor = mine ? Colors.white : AppColors.textPrimary;
    final mutedColor = textColor.withValues(alpha: mine ? 0.76 : 0.62);
    final fileName = _attachmentFileName(message);
    final extension = _fileExtension(fileName).toUpperCase();
    final iconColor = _fileAccentColor(fileName);
    final innerColor = mine
        ? Colors.white.withValues(alpha: 0.15)
        : AppColors.primary.withValues(alpha: 0.10);
    final attachmentId = message.attachmentIds.isEmpty
        ? null
        : message.attachmentIds.first;
    final previewUrl = attachmentId == null
        ? null
        : ref
              .read(downloadAttachmentActionProvider)
              .contentUrl(attachmentId, url: message.attachmentUrl);

    if (_isImageAttachment(message, fileName) && previewUrl != null) {
      return _ImageAttachmentBubble(
        message: message,
        mine: mine,
        maxWidth: widget.maxWidth,
        imageUrl: previewUrl,
      );
    }

    return Container(
      width: widget.maxWidth.clamp(270.0, 340.0),
      padding: const EdgeInsets.fromLTRB(9, 9, 10, 7),
      decoration: BoxDecoration(
        color: bubbleColor,
        border: mine
            ? null
            : Border.all(color: _incomingBubbleBorder.withValues(alpha: 0.7)),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(mine ? 20 : 7),
          topRight: Radius.circular(mine ? 7 : 20),
          bottomLeft: const Radius.circular(20),
          bottomRight: const Radius.circular(20),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x160F172A),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: innerColor,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: mine
                    ? Colors.white.withValues(alpha: 0.08)
                    : AppColors.primary.withValues(alpha: 0.10),
              ),
            ),
            child: Row(
              children: [
                _DocumentPreviewThumb(
                  label: extension,
                  color: iconColor,
                  previewUrl: _documentThumbnailUrl(message),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 15,
                          height: 1.18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        message.attachmentIds.length == 1
                            ? _formatFileSize(message.attachmentSize)
                            : '${message.attachmentIds.length} tệp đính kèm',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: mutedColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Tooltip(
                  message: 'Tải xuống',
                  child: PressableScale(
                    onTap: _downloading ? null : _download,
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: mine
                            ? Colors.white.withValues(alpha: 0.20)
                            : AppColors.primary.withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                      ),
                      child: _downloading
                          ? Padding(
                              padding: const EdgeInsets.all(10),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: mine ? Colors.white : AppColors.primary,
                              ),
                            )
                          : Icon(
                              LucideIcons.download,
                              color: mine ? Colors.white : AppColors.primary,
                              size: 20,
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 5),
          _Timestamp(message: message, mine: mine, color: mutedColor),
        ],
      ),
    );
  }
}

class _ImageAttachmentBubble extends StatelessWidget {
  const _ImageAttachmentBubble({
    required this.message,
    required this.mine,
    required this.maxWidth,
    required this.imageUrl,
  });

  final Message message;
  final bool mine;
  final double maxWidth;
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: maxWidth.clamp(220.0, 318.0),
      decoration: BoxDecoration(
        color: mine ? AppColors.primary : _incomingBubbleColor,
        border: mine
            ? null
            : Border.all(color: _incomingBubbleBorder.withValues(alpha: 0.7)),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(mine ? 20 : 7),
          topRight: Radius.circular(mine ? 7 : 20),
          bottomLeft: const Radius.circular(20),
          bottomRight: const Radius.circular(20),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x160F172A),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          AspectRatio(
            aspectRatio: 0.74,
            child: _NetworkPreviewImage(
              url: imageUrl,
              fit: BoxFit.cover,
              attachmentId: message.attachmentIds.isEmpty
                  ? null
                  : message.attachmentIds.first,
              fallback: _ImageAttachmentFallback(
                fileName: _attachmentFileName(message),
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.all(8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.46),
              borderRadius: BorderRadius.circular(999),
            ),
            child: _Timestamp(
              message: message,
              mine: mine,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageAttachmentFallback extends StatelessWidget {
  const _ImageAttachmentFallback({required this.fileName});

  final String fileName;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primary.withValues(alpha: 0.10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(LucideIcons.image, color: AppColors.primary, size: 36),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Text(
              fileName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NetworkPreviewImage extends ConsumerWidget {
  const _NetworkPreviewImage({
    required this.url,
    required this.fallback,
    this.fit = BoxFit.cover,
    this.attachmentId,
  });

  final String url;
  final Widget fallback;
  final BoxFit fit;
  final String? attachmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (kIsWeb) {
      final htmlImage = buildHtmlNetworkImage(url: url, fit: fit);
      if (htmlImage != null) return htmlImage;
    }

    final id = attachmentId;
    if (id != null) {
      return FutureBuilder<Uint8List>(
        future: ref.read(downloadAttachmentActionProvider).bytes(id),
        builder: (context, snapshot) {
          final bytes = snapshot.data;
          if (bytes != null) {
            return Image.memory(bytes, fit: fit, gaplessPlayback: true);
          }
          if (snapshot.hasError) return fallback;
          return ColoredBox(
            color: AppColors.soft(AppColors.chat),
            child: const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
      );
    }

    return Image.network(url, fit: fit, errorBuilder: (_, _, _) => fallback);
  }
}

class _DocumentPreviewThumb extends StatelessWidget {
  const _DocumentPreviewThumb({
    required this.label,
    required this.color,
    required this.previewUrl,
  });

  final String label;
  final Color color;
  final String? previewUrl;

  @override
  Widget build(BuildContext context) {
    final url = previewUrl;
    return Container(
      width: 88,
      height: 78,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140F172A),
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: url == null
                ? _DocumentPreviewLines(color: color)
                : _NetworkPreviewImage(
                    url: url,
                    fit: BoxFit.cover,
                    attachmentId: null,
                    fallback: _DocumentPreviewLines(color: color),
                  ),
          ),
          Positioned(
            left: 7,
            bottom: 7,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Text(
                label.isEmpty ? 'FILE' : label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentPreviewLines extends StatelessWidget {
  const _DocumentPreviewLines({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 42, height: 5, color: color.withValues(alpha: 0.22)),
          const SizedBox(height: 7),
          for (final width in const [64.0, 58.0, 68.0, 52.0, 61.0]) ...[
            Container(
              width: width,
              height: 3,
              decoration: BoxDecoration(
                color: AppColors.textMuted.withValues(alpha: 0.24),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(height: 5),
          ],
        ],
      ),
    );
  }
}

class _MediaBubble extends StatelessWidget {
  const _MediaBubble({
    required this.message,
    required this.media,
    required this.mine,
    required this.maxWidth,
  });

  final Message message;
  final _MediaInfo media;
  final bool mine;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      decoration: BoxDecoration(
        color: mine ? AppColors.primary : _incomingBubbleColor,
        border: mine
            ? null
            : Border.all(color: _incomingBubbleBorder.withValues(alpha: 0.7)),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(mine ? 18 : 6),
          topRight: Radius.circular(mine ? 6 : 18),
          bottomLeft: const Radius.circular(18),
          bottomRight: const Radius.circular(18),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x160F172A),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: media.isImage
                ? _NetworkPreviewImage(
                    url: media.url,
                    fit: BoxFit.cover,
                    fallback: _MediaFallback(media: media),
                    attachmentId: media.attachmentId,
                  )
                : _MediaFallback(media: media),
          ),
          if (media.isVideo)
            const Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0x99000000),
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Icon(LucideIcons.play, color: Colors.white, size: 26),
                ),
              ),
            ),
          Container(
            margin: const EdgeInsets.all(7),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.48),
              borderRadius: BorderRadius.circular(999),
            ),
            child: _Timestamp(
              message: message,
              mine: mine,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaFallback extends StatelessWidget {
  const _MediaFallback({required this.media});

  final _MediaInfo media;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.soft(AppColors.chat),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            media.isVideo ? LucideIcons.video : LucideIcons.image,
            color: AppColors.chat,
            size: 34,
          ),
          const SizedBox(height: 8),
          Text(
            media.displayLabel,
            style: const TextStyle(
              color: AppColors.chat,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _Timestamp extends StatelessWidget {
  const _Timestamp({
    required this.message,
    required this.mine,
    required this.color,
  });

  final Message message;
  final bool mine;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          Dates.time(message.createdAt),
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (mine) ...[
          const SizedBox(width: 4),
          MessageStatusIcon(status: message.status, size: 14, color: color),
        ],
      ],
    );
  }
}

class _MediaInfo {
  const _MediaInfo({
    required this.url,
    required this.isImage,
    required this.isVideo,
    this.label,
    this.attachmentId,
  });

  final String url;
  final bool isImage;
  final bool isVideo;
  final String? label;
  final String? attachmentId;

  String get displayLabel => label ?? (isVideo ? 'Video' : 'Ảnh');
  int? get attachmentIntId =>
      attachmentId == null ? null : int.tryParse(attachmentId!);

  static _MediaInfo? fromContent(String content) {
    final uri = Uri.tryParse(content.trim());
    if (uri == null || !uri.hasAbsolutePath) return null;
    if (uri.scheme != 'http' && uri.scheme != 'https') return null;
    final path = uri.path.toLowerCase();
    final isImage =
        path.endsWith('.jpg') ||
        path.endsWith('.jpeg') ||
        path.endsWith('.png') ||
        path.endsWith('.gif') ||
        path.endsWith('.webp');
    final isVideo =
        path.endsWith('.mp4') ||
        path.endsWith('.mov') ||
        path.endsWith('.m4v') ||
        path.endsWith('.webm');
    if (!isImage && !isVideo) return null;
    return _MediaInfo(url: content.trim(), isImage: isImage, isVideo: isVideo);
  }
}

class _FileInfo {
  const _FileInfo({
    required this.attachmentId,
    required this.name,
    required this.sizeLabel,
  });

  final String attachmentId;
  final String name;
  final String sizeLabel;
}

class _ReadAvatars extends StatelessWidget {
  const _ReadAvatars({required this.readers});

  final List<Profile> readers;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final reader in readers)
          Padding(
            padding: const EdgeInsets.only(left: 3),
            child: Container(
              width: 19,
              height: 19,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.surface, width: 1.5),
              ),
              child: ClipOval(
                child: UserAvatar(
                  userId: reader.id,
                  displayName: reader.displayName,
                  email: reader.email,
                  avatarUrl: reader.avatarUrl,
                  size: 19,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ignore: unused_element
class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.sending,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSubmit;

  void _openAttachmentSheet(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => QuickAttachmentSheet(
        title: 'Thêm nội dung',
        onSelected: (action) {
          Navigator.pop(sheetContext);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('${action.label} sắp có')));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0.34),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _ComposerCircleButton(
              tooltip: 'Thêm nội dung',
              icon: LucideIcons.plus,
              onTap: () => _openAttachmentSheet(context),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _FrostedSurface(
                radius: 26,
                child: TextField(
                  controller: controller,
                  enabled: !sending,
                  minLines: 1,
                  maxLines: 5,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSubmit(),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Message',
                    hintStyle: TextStyle(
                      color: AppColors.textMuted.withValues(alpha: 0.9),
                      fontSize: 20,
                      fontWeight: FontWeight.w400,
                    ),
                    suffixIcon: IconButton(
                      tooltip: 'Biểu tượng',
                      onPressed: () {},
                      icon: const Icon(LucideIcons.smile, size: 23),
                      color: AppColors.textSecondary,
                    ),
                    filled: false,
                    contentPadding: const EdgeInsets.fromLTRB(18, 12, 6, 12),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedBuilder(
              animation: controller,
              builder: (context, _) {
                final hasText = controller.text.trim().isNotEmpty;
                if (!hasText) return const SizedBox.shrink();
                return _ComposerCircleButton(
                  tooltip: 'Gửi',
                  icon: LucideIcons.send,
                  loading: sending,
                  onTap: sending ? null : onSubmit,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ComposerCircleButton extends StatelessWidget {
  const _ComposerCircleButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.loading = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: PressableScale(
        onTap: onTap,
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.62),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
              ),
              child: loading
                  ? const Padding(
                      padding: EdgeInsets.all(15),
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: AppColors.primary,
                      ),
                    )
                  : Icon(icon, color: AppColors.textPrimary, size: 27),
            ),
          ),
        ),
      ),
    );
  }
}

class _ComposerWithAttachments extends StatelessWidget {
  const _ComposerWithAttachments({
    required this.controller,
    required this.sending,
    required this.onSubmit,
    required this.onAttachment,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSubmit;
  final Future<void> Function(MobileAttachmentUpload attachment) onAttachment;

  Future<void> _pickImage(BuildContext context, ImageSource source) async {
    try {
      final image = await ImagePicker().pickImage(
        source: source,
        imageQuality: 86,
        maxWidth: 2200,
      );
      if (!context.mounted || image == null) return;
      await onAttachment(
        MobileAttachmentUpload(
          filename: image.name,
          bytes: await image.readAsBytes(),
          mimetype: _mimetypeForName(image.name),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không mở được camera/gallery: $e')),
      );
    }
  }

  Future<void> _pickDocument(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        withData: true,
        type: FileType.custom,
        allowedExtensions: const <String>[
          'pdf',
          'doc',
          'docx',
          'xls',
          'xlsx',
          'ppt',
          'pptx',
          'txt',
          'png',
          'jpg',
          'jpeg',
        ],
      );
      final file = result?.files.single;
      if (!context.mounted || file == null) return;
      final bytes = file.bytes;
      if (bytes == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không đọc được nội dung tài liệu.')),
        );
        return;
      }
      await onAttachment(
        MobileAttachmentUpload(
          filename: file.name,
          bytes: bytes,
          mimetype: _mimetypeForName(file.name),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không mở được tài liệu: $e')));
    }
  }

  void _showComingSoon(BuildContext context, String label) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('$label sắp có')));
  }

  void _openAttachmentSheet(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => _AttachmentPickerSheet(
        onSelected: (action) async {
          Navigator.pop(sheetContext);
          switch (action.type) {
            case _AttachmentType.gallery:
              await _pickImage(context, ImageSource.gallery);
            case _AttachmentType.camera:
              await _pickImage(context, ImageSource.camera);
            case _AttachmentType.document:
              await _pickDocument(context);
            case _AttachmentType.poll:
              _openPollSheet(context);
            case _AttachmentType.location:
              _showComingSoon(context, 'Vị trí');
            case _AttachmentType.contact:
              _showComingSoon(context, 'Liên hệ');
          }
        },
      ),
    );
  }

  void _openPollSheet(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const _PollSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withValues(alpha: 0),
            Colors.white.withValues(alpha: 0.34),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _ComposerCircleButton(
              tooltip: 'Thêm nội dung',
              icon: LucideIcons.plus,
              onTap: () => _openAttachmentSheet(context),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _FrostedSurface(
                radius: 26,
                child: TextField(
                  controller: controller,
                  enabled: !sending,
                  minLines: 1,
                  maxLines: 5,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSubmit(),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Message',
                    hintStyle: TextStyle(
                      color: AppColors.textMuted.withValues(alpha: 0.9),
                      fontSize: 20,
                      fontWeight: FontWeight.w400,
                    ),
                    suffixIcon: IconButton(
                      tooltip: 'Biểu tượng',
                      onPressed: () {},
                      icon: const Icon(LucideIcons.smile, size: 23),
                      color: AppColors.textSecondary,
                    ),
                    filled: false,
                    contentPadding: const EdgeInsets.fromLTRB(18, 12, 6, 12),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            AnimatedBuilder(
              animation: controller,
              builder: (context, _) {
                final hasText = controller.text.trim().isNotEmpty;
                if (!hasText) return const SizedBox.shrink();
                return _ComposerCircleButton(
                  tooltip: 'Gửi',
                  icon: LucideIcons.send,
                  loading: sending,
                  onTap: sending ? null : onSubmit,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ignore: unused_element
class _CreateProkSheet extends StatefulWidget {
  const _CreateProkSheet();

  @override
  State<_CreateProkSheet> createState() => _CreateProkSheetState();
}

class _CreateProkSheetState extends State<_CreateProkSheet> {
  final _nameController = TextEditingController();
  final _noteController = TextEditingController();
  int _category = 0;
  int _priority = 1;

  static const _categories = ['ERP', 'CRM', 'Support', 'Meeting'];
  static const _priorities = ['Thấp', 'Vừa', 'Cao'];

  @override
  void dispose() {
    _nameController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 12,
          right: 12,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 10,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(
                color: Color(0x260F172A),
                blurRadius: 24,
                offset: Offset(0, -8),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: AppColors.chatGrad,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        LucideIcons.plus,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Create prok',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Tạo nhanh công việc từ cuộc trò chuyện',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _CreateProkField(
                  controller: _nameController,
                  hintText: 'Tên prok',
                  icon: LucideIcons.clipboardList,
                ),
                const SizedBox(height: 10),
                _CreateProkField(
                  controller: _noteController,
                  hintText: 'Mô tả ngắn',
                  icon: LucideIcons.alignLeft,
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                const _CreateProkLabel('Loại công việc'),
                const SizedBox(height: 8),
                _CreateProkChips(
                  labels: _categories,
                  selected: _category,
                  onChanged: (value) => setState(() => _category = value),
                ),
                const SizedBox(height: 16),
                const _CreateProkLabel('Ưu tiên'),
                const SizedBox(height: 8),
                _CreateProkChips(
                  labels: _priorities,
                  selected: _priority,
                  onChanged: (value) => setState(() => _priority = value),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: GradientButton(
                    label: 'Tạo prok',
                    icon: LucideIcons.plus,
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Create prok sẽ được nối dữ liệu sau.'),
                        ),
                      );
                    },
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

class _CreateProkField extends StatelessWidget {
  const _CreateProkField({
    required this.controller,
    required this.hintText,
    required this.icon,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 20),
        hintText: hintText,
        hintStyle: const TextStyle(
          color: AppColors.textMuted,
          fontWeight: FontWeight.w500,
        ),
        filled: true,
        fillColor: const Color(0xFFF3F6FC),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _CreateProkLabel extends StatelessWidget {
  const _CreateProkLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 13,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _CreateProkChips extends StatelessWidget {
  const _CreateProkChips({
    required this.labels,
    required this.selected,
    required this.onChanged,
  });

  final List<String> labels;
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var index = 0; index < labels.length; index++)
          PressableScale(
            onTap: () => onChanged(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: selected == index
                    ? AppColors.primary
                    : const Color(0xFFF3F6FC),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                labels[index],
                style: TextStyle(
                  color: selected == index
                      ? Colors.white
                      : AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _PollSheet extends StatefulWidget {
  const _PollSheet();

  @override
  State<_PollSheet> createState() => _PollSheetState();
}

class _PollSheetState extends State<_PollSheet> {
  final _questionController = TextEditingController();
  final _optionControllers = [TextEditingController(), TextEditingController()];
  bool _multipleChoice = false;
  bool _anonymous = true;

  @override
  void dispose() {
    _questionController.dispose();
    for (final controller in _optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    if (_optionControllers.length >= 8) return;
    setState(() => _optionControllers.add(TextEditingController()));
  }

  void _removeOption(int index) {
    if (_optionControllers.length <= 2) return;
    final controller = _optionControllers.removeAt(index);
    controller.dispose();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 12,
          right: 12,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 10,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(
                color: Color(0x260F172A),
                blurRadius: 24,
                offset: Offset(0, -8),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        gradient: AppColors.chatGrad,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        LucideIcons.barChart3,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Tạo bình chọn',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Gửi câu hỏi để mọi người cùng bỏ phiếu',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _PollTextField(
                  controller: _questionController,
                  hintText: 'Câu hỏi bình chọn',
                  icon: LucideIcons.circleHelp,
                ),
                const SizedBox(height: 16),
                const _PollLabel('Lựa chọn'),
                const SizedBox(height: 8),
                for (var index = 0; index < _optionControllers.length; index++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _PollOptionField(
                      controller: _optionControllers[index],
                      index: index,
                      canRemove: _optionControllers.length > 2,
                      onRemove: () => _removeOption(index),
                    ),
                  ),
                PressableScale(
                  onTap: _addOption,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          LucideIcons.plus,
                          color: AppColors.primary,
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Thêm lựa chọn',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _PollSwitchTile(
                  icon: LucideIcons.listChecks,
                  title: 'Cho phép chọn nhiều đáp án',
                  value: _multipleChoice,
                  onChanged: (value) => setState(() => _multipleChoice = value),
                ),
                const SizedBox(height: 8),
                _PollSwitchTile(
                  icon: LucideIcons.eyeOff,
                  title: 'Bình chọn ẩn danh',
                  value: _anonymous,
                  onChanged: (value) => setState(() => _anonymous = value),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: GradientButton(
                    label: 'Tạo bình chọn',
                    icon: LucideIcons.send,
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Bình chọn sẽ được nối dữ liệu sau.'),
                        ),
                      );
                    },
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

class _PollTextField extends StatelessWidget {
  const _PollTextField({
    required this.controller,
    required this.hintText,
    required this.icon,
  });

  final TextEditingController controller;
  final String hintText;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 20),
        hintText: hintText,
        hintStyle: const TextStyle(
          color: AppColors.textMuted,
          fontWeight: FontWeight.w500,
        ),
        filled: true,
        fillColor: const Color(0xFFF3F6FC),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _PollOptionField extends StatelessWidget {
  const _PollOptionField({
    required this.controller,
    required this.index,
    required this.canRemove,
    required this.onRemove,
  });

  final TextEditingController controller;
  final int index;
  final bool canRemove;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        prefixIcon: Center(
          widthFactor: 1,
          child: Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Text(
              '${index + 1}',
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        suffixIcon: canRemove
            ? IconButton(
                tooltip: 'Xóa lựa chọn',
                onPressed: onRemove,
                icon: const Icon(LucideIcons.x, size: 18),
                color: AppColors.textMuted,
              )
            : null,
        hintText: 'Lựa chọn ${index + 1}',
        hintStyle: const TextStyle(
          color: AppColors.textMuted,
          fontWeight: FontWeight.w500,
        ),
        filled: true,
        fillColor: const Color(0xFFF3F6FC),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _PollLabel extends StatelessWidget {
  const _PollLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppColors.textPrimary,
        fontSize: 13,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _PollSwitchTile extends StatelessWidget {
  const _PollSwitchTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F6FC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Switch.adaptive(
            value: value,
            activeThumbColor: AppColors.primary,
            activeTrackColor: AppColors.primary.withValues(alpha: 0.28),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

enum _AttachmentType { gallery, camera, document, poll, location, contact }

class _AttachmentAction {
  const _AttachmentAction({
    required this.type,
    required this.label,
    required this.icon,
  });

  final _AttachmentType type;
  final String label;
  final IconData icon;
}

class _AttachmentPickerSheet extends StatefulWidget {
  const _AttachmentPickerSheet({required this.onSelected});

  final ValueChanged<_AttachmentAction> onSelected;

  @override
  State<_AttachmentPickerSheet> createState() => _AttachmentPickerSheetState();
}

class _AttachmentPickerSheetState extends State<_AttachmentPickerSheet> {
  _AttachmentType _selected = _AttachmentType.gallery;

  static const _actions = [
    _AttachmentAction(
      type: _AttachmentType.gallery,
      label: 'Ảnh',
      icon: LucideIcons.image,
    ),
    _AttachmentAction(
      type: _AttachmentType.camera,
      label: 'Camera',
      icon: LucideIcons.camera,
    ),
    _AttachmentAction(
      type: _AttachmentType.document,
      label: 'Tài liệu',
      icon: LucideIcons.fileText,
    ),
    _AttachmentAction(
      type: _AttachmentType.poll,
      label: 'Bình chọn',
      icon: LucideIcons.barChart3,
    ),
    _AttachmentAction(
      type: _AttachmentType.location,
      label: 'Vị trí',
      icon: LucideIcons.mapPin,
    ),
    _AttachmentAction(
      type: _AttachmentType.contact,
      label: 'Liên hệ',
      icon: LucideIcons.contact,
    ),
  ];

  static const _tileColors = [
    Color(0xFF111827),
    Color(0xFFEFF6FF),
    Color(0xFF8ED8BE),
    Color(0xFFFEE2E2),
    Color(0xFFF0FDFA),
    Color(0xFFE0E7FF),
    Color(0xFFFFEDD5),
    Color(0xFFE2E8F0),
    Color(0xFFDBEAFE),
  ];

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.64;
    return SafeArea(
      top: false,
      child: Container(
        height: height,
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(26),
          boxShadow: const [
            BoxShadow(
              color: Color(0x260F172A),
              blurRadius: 20,
              offset: Offset(0, -6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Column(
              children: [
                const _AttachmentSheetHeader(),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.only(bottom: 76),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          mainAxisSpacing: 1,
                          crossAxisSpacing: 1,
                        ),
                    itemCount: 24,
                    itemBuilder: (context, index) {
                      return _RecentTile(
                        index: index,
                        color: _tileColors[index % _tileColors.length],
                        selected: index == 2 || index == 6,
                        onTap: () => HapticFeedback.selectionClick(),
                      );
                    },
                  ),
                ),
              ],
            ),
            Positioned(
              left: 18,
              right: 18,
              bottom: 14,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.78),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.84),
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x180F172A),
                          blurRadius: 14,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        for (final action in _actions)
                          Expanded(
                            child: _AttachmentActionButton(
                              action: action,
                              selected: action.type == _selected,
                              onTap: () {
                                setState(() => _selected = action.type);
                                widget.onSelected(action);
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachmentSheetHeader extends StatelessWidget {
  const _AttachmentSheetHeader();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 9,
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Gần đây',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(width: 5),
              Icon(
                LucideIcons.chevronDown,
                color: AppColors.textSecondary,
                size: 18,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RecentTile extends StatelessWidget {
  const _RecentTile({
    required this.index,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final int index;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final icon = switch (index % 6) {
      0 => LucideIcons.camera,
      1 => LucideIcons.fileText,
      2 => LucideIcons.image,
      3 => LucideIcons.map,
      4 => LucideIcons.qrCode,
      _ => LucideIcons.galleryHorizontalEnd,
    };

    return PressableScale(
      onTap: onTap,
      scale: 0.99,
      child: Stack(
        fit: StackFit.expand,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color.lerp(color, Colors.white, 0.18)!, color],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Icon(
              icon,
              color: AppColors.midnight.withValues(alpha: 0.34),
              size: 34,
            ),
          ),
          Positioned(
            right: 10,
            top: 10,
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2.2),
              ),
              child: selected
                  ? const Icon(Icons.check, color: Colors.white, size: 20)
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _AttachmentActionButton extends StatelessWidget {
  const _AttachmentActionButton({
    required this.action,
    required this.selected,
    required this.onTap,
  });

  final _AttachmentAction action;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              action.icon,
              color: selected ? AppColors.primary : AppColors.textPrimary,
              size: 22,
            ),
            const SizedBox(height: 3),
            Text(
              action.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? AppColors.primary : AppColors.textPrimary,
                fontSize: 10,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String? _mimetypeForName(String name) {
  final extension = name.split('.').last.toLowerCase();
  return switch (extension) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'pdf' => 'application/pdf',
    'doc' => 'application/msword',
    'docx' =>
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls' => 'application/vnd.ms-excel',
    'xlsx' =>
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'ppt' => 'application/vnd.ms-powerpoint',
    'pptx' =>
      'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'txt' => 'text/plain',
    _ => null,
  };
}

String _attachmentFileName(Message message) {
  final metaName = message.attachmentName?.trim();
  if (metaName != null && metaName.isNotEmpty) return metaName;
  final content = message.content.trim();
  if (content.isNotEmpty) return content;
  if (message.attachmentIds.length == 1) {
    return 'Tệp đính kèm ${message.attachmentIds.single}';
  }
  return '${message.attachmentIds.length} tệp đính kèm';
}

String _fileExtension(String name) {
  final parts = name.split('.');
  if (parts.length < 2) return 'file';
  final ext = parts.last.trim();
  return ext.isEmpty ? 'file' : ext;
}

Color _fileAccentColor(String name) {
  return switch (_fileExtension(name).toLowerCase()) {
    'pdf' => const Color(0xFFE53935),
    'doc' || 'docx' => const Color(0xFF2563EB),
    'xls' || 'xlsx' => const Color(0xFF16A34A),
    'ppt' || 'pptx' => const Color(0xFFF97316),
    'jpg' || 'jpeg' || 'png' => AppColors.chat,
    'txt' => AppColors.primary,
    _ => AppColors.ticket,
  };
}

bool _isImageAttachment(Message message, String fileName) {
  final mimetype = message.attachmentMimeType?.toLowerCase();
  if (mimetype?.startsWith('image/') == true) return true;
  return switch (_fileExtension(fileName).toLowerCase()) {
    'jpg' || 'jpeg' || 'png' || 'gif' || 'webp' => true,
    _ => false,
  };
}

String? _documentThumbnailUrl(Message message) {
  final url = message.attachmentUrl;
  if (url == null) return null;
  final lower = url.toLowerCase();
  final looksLikeImage =
      lower.contains('/image/') ||
      lower.contains('thumbnail') ||
      lower.endsWith('.png') ||
      lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.webp');
  return looksLikeImage ? url : null;
}

String _formatFileSize(int? bytes) {
  if (bytes == null || bytes <= 0) return 'Tệp đính kèm';
  const kb = 1024;
  const mb = kb * 1024;
  if (bytes >= mb) {
    final value = bytes / mb;
    return '${value.toStringAsFixed(value >= 10 ? 0 : 1)} MB';
  }
  final value = bytes / kb;
  return '${value.toStringAsFixed(value >= 10 ? 0 : 1)} KB';
}
