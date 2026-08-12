import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../../core/api/auth_user.dart';
import '../../../core/api/mobile_attachment_repository.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/local_attachment_cache.dart';
import '../../../shared/models/conversation.dart';
import '../../../shared/models/message.dart';
import '../../../shared/models/profile.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../../shared/widgets/ui_kit.dart';
import '../../auth/application/auth_controller.dart';
import '../application/conversations_controller.dart';
import '../application/messages_controller.dart';
import 'widgets/chat_bubbles.dart';
import 'widgets/chat_composer.dart';
import 'widgets/chat_header.dart';
import 'widgets/chat_info_sheet.dart';
import 'widgets/chat_wallpaper.dart';

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
  bool _showScrollToBottom = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScrollChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(markAsReadActionProvider).markAsRead(widget.conversationId);
    });
  }

  void _onScrollChanged() {
    if (!_scroll.hasClients) return;
    final isScrolledUp = _scroll.position.pixels > 160;
    if (isScrolledUp != _showScrollToBottom) {
      setState(() => _showScrollToBottom = isScrolledUp);
    }
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScrollChanged);
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
      _input.value = TextEditingValue.empty;
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
    LocalAttachmentCache.save(attachment.filename, attachment.bytes);
    setState(() => _sending = true);
    try {
      final uploaded = await ref
          .read(sendAttachmentActionProvider)
          .send(widget.conversationId, attachment);
      if (uploaded.attachmentId > 0) {
        LocalAttachmentCache.save(uploaded.attachmentId.toString(), attachment.bytes);
      }
      _scrollToBottom();
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

    ref.listen<AsyncValue<List<Message>>>(
      messagesProvider(widget.conversationId),
      (previous, next) {
        final prevList = previous?.valueOrNull ?? const [];
        final nextList = next.valueOrNull ?? const [];

        if (prevList.isEmpty && nextList.isNotEmpty) {
          _scrollToBottom();
          return;
        }

        if (nextList.length > prevList.length) {
          final newestMsg = nextList.last;
          final mine = _isMine(newestMsg, currentUser, myIdentityIds);
          final isNearBottom =
              !_scroll.hasClients || _scroll.position.pixels < 120;

          if (mine || isNearBottom) {
            _scrollToBottom();
          }
        }
      },
    );

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
          const Positioned.fill(child: ChatWallpaper()),
          SafeArea(
            child: Column(
              children: [
                FloatingChatHeader(
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
                  PinnedMessageBanner(message: pinnedMessage),
                Expanded(
                  child: messages.when(
                    data: (list) {
                      if (list.isEmpty) {
                        return const EmptyConversation();
                      }
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

                          final isBurst = older != null &&
                              older.senderId == message.senderId &&
                              _sameDay(older.createdAt, message.createdAt);
                          final topSpacing = showDate ? 0.0 : (isBurst ? 3.0 : 8.0);

                          return Column(
                            children: [
                              if (showDate)
                                DateSeparator(date: message.createdAt),
                              Bubble(
                                message: message,
                                mine: mine,
                                sender: senderProfiles[message.senderId],
                                showAvatar: showAvatar,
                                topSpacing: topSpacing,
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
                ComposerWithAttachments(
                  controller: _input,
                  sending: _sending,
                  onSubmit: _send,
                  onAttachment: _sendAttachment,
                ),
              ],
            ),
          ),
          if (_showScrollToBottom)
            Positioned(
              bottom: 76,
              right: 16,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: _showScrollToBottom ? 1.0 : 0.0,
                child: PressableScale(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _scrollToBottom();
                  },
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Icon(
                      LucideIcons.chevronDown,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                ),
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

    final messageSenderId = int.tryParse(message.senderId);
    final partnerIdRaw = user?.userMetadata['partner_id'];
    final currentPartnerId = partnerIdRaw != null ? int.tryParse(partnerIdRaw.toString()) : null;
    final currentUserId = user?.id != null ? int.tryParse(user!.id) : null;
    final targetId = currentPartnerId ?? currentUserId;

    if (messageSenderId != null && targetId != null && messageSenderId == targetId) {
      return true;
    }

    if (myIdentityIds.contains(message.senderId)) return true;
    if (partnerIdRaw != null && message.senderId == partnerIdRaw.toString()) return true;

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
      builder: (_) => ChatInfoSheet(
        title: title,
        conversation: conversation,
        currentIdentityIds: currentIdentityIds,
        messages: messages,
      ),
    );
  }
}
