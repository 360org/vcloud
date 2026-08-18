import 'dart:async';
import 'dart:convert';
import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../../../core/utils/local_attachment_cache.dart';
import '../domain/models/chat_v2_poll_model.dart';
import '../data/chat_v2_realtime_service.dart';
import '../data/chat_v2_repository.dart';
import '../data/models/chat_v2_message.dart';
import '../presentation/widgets/chat_v2_message_item.dart';
import 'chat_v2_channels_controller.dart';
import 'chat_v2_read_state_controller.dart';

final chatV2MessagesProvider = AutoDisposeAsyncNotifierProviderFamily<
    ChatV2MessagesNotifier, List<ChatV2Message>, String>(
  ChatV2MessagesNotifier.new,
);

class ChatV2MessageLocalCache {
  static final Map<String, Map<String, ChatV2Message>> _cache = {};

  static List<ChatV2Message>? get(String channelId) {
    final map = _cache[channelId];
    if (map == null || map.isEmpty) return null;
    return map.values.toList(growable: false);
  }

  static void set(String channelId, List<ChatV2Message> messages, {bool persist = true}) {
    final map = <String, ChatV2Message>{};
    for (final m in messages) {
      map[m.id] = m;
    }
    _cache[channelId] = map;
  }

  static void prepend(String channelId, ChatV2Message msg) {
    final map = _cache[channelId];
    if (map == null) {
      _cache[channelId] = {msg.id: msg};
    } else {
      _cache[channelId] = {msg.id: msg, ...map};
    }
  }

  static void append(String channelId, ChatV2Message msg) {
    final map = _cache.putIfAbsent(channelId, () => <String, ChatV2Message>{});
    map[msg.id] = msg;
  }
}

class ChatV2MessagesNotifier
    extends AutoDisposeFamilyAsyncNotifier<List<ChatV2Message>, String> {
  Timer? _pollingTimer;
  StreamSubscription? _wsSub;

  @override
  FutureOr<List<ChatV2Message>> build(String arg) async {
    debugPrint('🟢 [TRACE] ChatV2MessagesNotifier.build() START - channel: $arg');
    final channelId = arg;
    final repo = ref.watch(chatV2RepositoryProvider);
    final user = ref.watch(authControllerProvider).valueOrNull;
    final realtime = ref.watch(chatV2RealtimeServiceProvider);

    final meta = user?.userMetadata;
    final partnerId = meta?['partner_id']?.toString() ??
        meta?['partner']?['id']?.toString();
    final userId = user?.id;

    // Tự động đánh dấu đã đọc
    unawaited(repo.markAsRead(channelId));

    // Lắng nghe tin nhắn Realtime qua WebSocket
    _wsSub?.cancel();
    _wsSub = realtime.onMessageReceived.listen((newMsg) {
      if (newMsg.channelId == channelId) {
        ChatV2MessageLocalCache.prepend(channelId, newMsg);
        final currentList = state.valueOrNull ?? const [];
        if (!currentList.any((m) => m.id == newMsg.id)) {
          state = AsyncData([newMsg, ...currentList]);
        }
      }
    });

    // Smart Sequential Polling (2.5s): Chạy tuần tự, chỉ poll khi người dùng đang ở trong phòng chat
    bool isDisposed = false;

    void scheduleNextPoll() {
      if (isDisposed) return;
      _pollingTimer?.cancel();
      _pollingTimer = Timer(const Duration(milliseconds: 2500), () async {
        if (isDisposed) return;
        if (!state.isLoading && state.hasValue) {
          try {
            final latest = await repo.getMessages(
              channelId,
              currentPartnerId: partnerId,
              currentUserId: userId,
            );
            if (!isDisposed && latest.isNotEmpty) {
              final currentList = state.valueOrNull ?? const [];
              final merged = _mergeMessages(currentList, latest);

              if (_hasDifferences(currentList, merged)) {
                ChatV2MessageLocalCache.set(channelId, merged);
                state = AsyncData(merged);
              }
            }
          } catch (_) {}
        }
        if (!isDisposed) {
          scheduleNextPoll();
        }
      });
    }

    scheduleNextPoll();

    ref.onDispose(() {
      isDisposed = true;
      _wsSub?.cancel();
      _pollingTimer?.cancel();
    });

    // SWR Cache: Nếu đã có tin nhắn trong Memory Cache -> Trả về tức thì 0.001s
    final cached = ChatV2MessageLocalCache.get(channelId);
    if (cached != null && cached.isNotEmpty) {
      unawaited(() async {
        try {
          debugPrint('🟢 [TRACE] ChatV2MessagesNotifier.build SWR getMessages() START');
          final fresh = await repo.getMessages(
            channelId,
            currentPartnerId: partnerId,
            currentUserId: userId,
          );
          debugPrint('🔴 [TRACE] ChatV2MessagesNotifier.build SWR getMessages() END');
          
          final currentList = state.valueOrNull ?? cached;
          final merged = _mergeMessages(currentList, fresh);

          if (_hasDifferences(currentList, merged)) {
            ChatV2MessageLocalCache.set(channelId, merged);
            state = AsyncData(merged);
          }
        } catch (e, st) {
          debugPrint('❌ [ERROR] ChatV2MessagesNotifier.build SWR: $e\n$st');
        }
      }());
      debugPrint('🔴 [TRACE] ChatV2MessagesNotifier.build() END (Returned Cached)');
      return cached;
    }

    debugPrint('🟢 [TRACE] ChatV2MessagesNotifier.build Initial getMessages() START');
    final fresh = await repo.getMessages(
      channelId,
      currentPartnerId: partnerId,
      currentUserId: userId,
    );
    debugPrint('🔴 [TRACE] ChatV2MessagesNotifier.build Initial getMessages() END');
    ChatV2MessageLocalCache.set(channelId, fresh);
    debugPrint('🔴 [TRACE] ChatV2MessagesNotifier.build() END (Returned Fresh)');
    return fresh;
  }

  static List<ChatV2Message> _mergeMessages(
    List<ChatV2Message> currentList,
    List<ChatV2Message> freshList,
  ) {
    if (freshList.isEmpty) return currentList;
    if (currentList.isEmpty) return freshList;

    final currentIds = currentList.map((m) => m.id).toSet();
    final freshById = {for (final m in freshList) m.id: m};

    // 1. Tìm các tin nhắn mới tinh từ server (chưa có trong currentList)
    final brandNew = freshList.where((m) => !currentIds.contains(m.id)).map((m) {
      final replyInfo = ChatV2ReplyCache.get(m.id);
      return m.copyWith(
        parentId: m.parentId ?? replyInfo?['parent_id'],
        parentBody: m.parentBody ?? replyInfo?['parent_body'],
        parentAuthorName: m.parentAuthorName ?? replyInfo?['parent_author_name'],
      );
    }).toList();

    // 2. Cập nhật các tin nhắn hiện có mà không làm mất các tin nhắn cũ đã loadMore
    final updatedExisting = currentList.map((m) {
      final fresh = freshById[m.id];
      if (fresh != null) {
        final replyInfo = ChatV2ReplyCache.get(fresh.id);
        return fresh.copyWith(
          parentId: fresh.parentId ?? m.parentId ?? replyInfo?['parent_id'],
          parentBody: fresh.parentBody ?? m.parentBody ?? replyInfo?['parent_body'],
          parentAuthorName: fresh.parentAuthorName ?? m.parentAuthorName ?? replyInfo?['parent_author_name'],
        );
      }
      return m; // Giữ nguyên các trang tin nhắn cũ đã tải về
    }).toList();

    return [...brandNew, ...updatedExisting];
  }

  static bool _hasDifferences(List<ChatV2Message> a, List<ChatV2Message> b) {
    if (a.length != b.length) return true;
    for (int i = 0; i < a.length; i++) {
      final ma = a[i];
      final mb = b[i];
      if (ma.id != mb.id ||
          ma.content != mb.content ||
          ma.status != mb.status ||
          ma.attachments.length != mb.attachments.length) {
        return true;
      }
    }
    return false;
  }

  bool _isLoadingMore = false;
  bool get isLoadingMore => _isLoadingMore;

  Future<void> loadMore() async {
    if (_isLoadingMore) return;
    
    final currentMessages = state.valueOrNull ?? [];
    if (currentMessages.isEmpty) return;

    // Tin nhắn cũ nhất nằm ở cuối danh sách vì danh sách đã được sắp xếp giảm dần theo thời gian (hoặc ID)
    final oldestMessage = currentMessages.last;
    // Bỏ qua temp messages
    if (oldestMessage.id.startsWith('temp_')) return;

    _isLoadingMore = true;
    try {
      final channelId = arg;
      final repo = ref.read(chatV2RepositoryProvider);
      final user = ref.read(authControllerProvider).valueOrNull;

      final meta = user?.userMetadata;
      final partnerId = meta?['partner_id']?.toString() ??
          meta?['partner']?['id']?.toString();
      final userId = user?.id;

      final moreMessages = await repo.getMessages(
        channelId,
        currentPartnerId: partnerId,
        currentUserId: userId,
        beforeId: oldestMessage.id,
      );

      if (moreMessages.isNotEmpty) {
        final newMessages = [...currentMessages, ...moreMessages];
        ChatV2MessageLocalCache.set(channelId, newMessages);
        state = AsyncData(newMessages);
      }
    } catch (e) {
      // Ignore or handle error
    } finally {
      _isLoadingMore = false;
    }
  }

  Future<void> sendMessage(
    String text, {
    List<int>? attachmentIds,
    String? parentId,
    String? parentBody,
    String? parentAuthorName,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty && (attachmentIds == null || attachmentIds.isEmpty)) {
      return;
    }

    final channelId = arg;
    final repo = ref.read(chatV2RepositoryProvider);
    final user = ref.read(authControllerProvider).valueOrNull;

    final meta = user?.userMetadata;
    final partnerId = meta?['partner_id']?.toString() ??
        meta?['partner']?['id']?.toString();
    final userId = user?.id;
    final userName = meta?['name']?.toString() ?? 'Tôi';

    // Tạo tin nhắn tạm (optimistic update)
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final tempMsg = ChatV2Message(
      id: tempId,
      channelId: channelId,
      content: trimmed,
      authorId: partnerId ?? userId,
      authorName: userName,
      createdAt: DateTime.now(),
      isMine: true,
      status: 'pending',
      parentId: parentId,
      parentBody: parentBody,
      parentAuthorName: parentAuthorName,
    );

    if (parentId != null) {
      ChatV2ReplyCache.set(
        tempId,
        parentId: parentId,
        parentBody: parentBody,
        parentAuthorName: parentAuthorName,
      );
    }

    final previousState = state.valueOrNull ?? const [];
    state = AsyncData([tempMsg, ...previousState]);
    ChatV2MessageLocalCache.prepend(channelId, tempMsg);

    try {
      final sentMsg = await repo.sendMessage(
        channelId,
        trimmed,
        attachmentIds: attachmentIds,
        currentPartnerId: partnerId,
        currentUserId: userId,
        authorName: userName,
        parentId: parentId,
        parentBody: parentBody,
        parentAuthorName: parentAuthorName,
      );

      final resolvedSentMsg = sentMsg.copyWith(
        isMine: true,
        status: 'sent',
        parentId: sentMsg.parentId ?? parentId,
        parentBody: sentMsg.parentBody ?? parentBody,
        parentAuthorName: sentMsg.parentAuthorName ?? parentAuthorName,
      );

      if (parentId != null) {
        ChatV2ReplyCache.set(
          resolvedSentMsg.id,
          parentId: parentId,
          parentBody: parentBody,
          parentAuthorName: parentAuthorName,
        );
      }

      // Cập nhật lại tin nhắn trong danh sách
      final currentList = state.valueOrNull ?? const [];
      final updatedList = currentList.map((m) {
        if (m.id == tempId) {
          return resolvedSentMsg;
        }
        return m;
      }).toList();

      // Nếu không tìm thấy tempId để thay thế, đưa lên đầu
      if (!updatedList.any((m) => m.id == resolvedSentMsg.id)) {
        updatedList.removeWhere((m) => m.id == tempId);
        updatedList.insert(0, resolvedSentMsg);
      }

      ChatV2MessageLocalCache.set(channelId, updatedList);
      state = AsyncData(updatedList);

      // Báo sự kiện realtime
      ref.read(chatV2RealtimeServiceProvider).notifyMessageSent(channelId, resolvedSentMsg);
      ref.read(chatV2LastSentTrackerProvider.notifier).recordSent(channelId, trimmed);
      ref.read(chatV2ReadStateProvider.notifier).markChannelAsRead(channelId);

      // Invalidate danh sách kênh để cập nhật last message
      ref.invalidate(chatV2ChannelsProvider);
    } catch (e) {
      // Đánh dấu tin nhắn lỗi
      final currentList = state.valueOrNull ?? const [];
      state = AsyncData(
        currentList.map((m) {
          if (m.id == tempId) {
            return m.copyWith(status: 'error');
          }
          return m;
        }).toList(),
      );
    }
  }

  Future<void> sendImage({
    required String filename,
    required Uint8List bytes,
    String? mimetype,
    String? caption,
  }) async {
    await sendAttachment(
      filename: filename,
      bytes: bytes,
      mimetype: mimetype ?? 'image/jpeg',
      caption: caption,
    );
  }

  Future<void> sendFile({
    required String filename,
    required Uint8List bytes,
    String? mimetype,
    String? caption,
  }) async {
    await sendAttachment(
      filename: filename,
      bytes: bytes,
      mimetype: mimetype ?? 'application/octet-stream',
      caption: caption,
    );
  }

  Future<void> sendAttachment({
    required String filename,
    required Uint8List bytes,
    required String mimetype,
    String? caption,
  }) async {
    final channelId = arg;
    final repo = ref.read(chatV2RepositoryProvider);
    final user = ref.read(authControllerProvider).valueOrNull;

    final meta = user?.userMetadata;
    final partnerId = meta?['partner_id']?.toString() ??
        meta?['partner']?['id']?.toString();
    final userId = user?.id;
    final userName = meta?['name']?.toString() ?? 'Tôi';

    // 1. Optimistic message cập nhật ngay lập tức lên UI
    final tempId = 'temp_att_${DateTime.now().millisecondsSinceEpoch}';
    ChatV2AttachmentImage.cacheBytes(tempId, bytes);
    LocalAttachmentCache.save(filename, bytes);
    LocalAttachmentCache.save(tempId, bytes);

    final tempMsg = ChatV2Message(
      id: tempId,
      channelId: channelId,
      content: (caption != null && caption.isNotEmpty) ? caption : filename,
      authorId: partnerId ?? userId,
      authorName: userName,
      createdAt: DateTime.now(),
      isMine: true,
      status: 'pending',
      attachments: [
        ChatV2Attachment(
          id: tempId,
          name: filename,
          mimetype: mimetype,
          bytes: bytes,
        ),
      ],
    );

    final previousState = state.valueOrNull ?? const [];
    state = AsyncData([tempMsg, ...previousState]);
    ChatV2MessageLocalCache.prepend(channelId, tempMsg);

    try {
      // 2. Upload attachment lên Odoo backend
      final att = await repo.uploadAttachment(
        filename: filename,
        bytes: bytes,
        mimetype: mimetype,
      );

      final attIdInt = int.tryParse(att.id);
      if (attIdInt == null) {
        throw Exception('ID đính kèm tệp không hợp lệ.');
      }
      final attachedWithBytes = att.copyWith(bytes: bytes);
      ChatV2AttachmentImage.cacheBytes(att.id.toString(), bytes);
      ChatV2AttachmentImage.cacheBytes(filename, bytes);
      LocalAttachmentCache.save(att.id, bytes);
      LocalAttachmentCache.save(filename, bytes);

      // 3. Gửi tin nhắn với attachment ID vào Odoo Chatter
      final bodyText = (caption != null && caption.isNotEmpty) ? caption : filename;
      final sentMsg = await repo.sendMessage(
        channelId,
        bodyText,
        attachmentIds: [attIdInt],
        currentPartnerId: partnerId,
        currentUserId: userId,
        authorName: userName,
      );

      ChatV2AttachmentImage.cacheBytes(sentMsg.id.toString(), bytes);
      LocalAttachmentCache.save(sentMsg.id, bytes);

      // Cập nhật trạng thái sent ngay lập tức cho tin nhắn tạm, bảo tồn nguyên vẹn byte nhị phân
      final currentList = state.valueOrNull ?? const [];
      final updatedList = currentList.map((m) {
        if (m.id == tempId) {
          return sentMsg.copyWith(
            isMine: true,
            status: 'sent',
            attachments: [attachedWithBytes],
          );
        }
        return m;
      }).toList();

      if (!updatedList.any((m) => m.id == sentMsg.id)) {
        updatedList.removeWhere((m) => m.id == tempId);
        updatedList.insert(0, sentMsg.copyWith(isMine: true, status: 'sent', attachments: [attachedWithBytes]));
      }

      ChatV2MessageLocalCache.set(channelId, updatedList);
      state = AsyncData(updatedList);

      final cleanForTracker = mimetype.startsWith('image/')
          ? ((caption != null && caption.isNotEmpty) ? caption : '[Hình ảnh]')
          : bodyText;
      ref.read(chatV2LastSentTrackerProvider.notifier).recordSent(channelId, cleanForTracker);
      ref.read(chatV2ReadStateProvider.notifier).markChannelAsRead(channelId);

      // 5. Invalidate channels để cập nhật preview
      ref.invalidate(chatV2ChannelsProvider);
    } catch (e) {
      // Đánh dấu tin nhắn tạm bị lỗi
      final currentList = state.valueOrNull ?? const [];
      state = AsyncData(
        currentList.map((m) {
          if (m.id == tempId) {
            return m.copyWith(status: 'error');
          }
          return m;
        }).toList(),
      );
    }
  }

  Future<void> editMessage(String messageId, String newBody) async {
    final repo = ref.read(chatV2RepositoryProvider);
    try {
      await repo.editMessage(messageId, newBody);
      // Update locally
      final current = state.valueOrNull ?? [];
      final idx = current.indexWhere((m) => m.id == messageId);
      if (idx != -1) {
        final newMsg = current[idx].copyWith(content: newBody);
        final nextList = List<ChatV2Message>.from(current);
        nextList[idx] = newMsg;
        state = AsyncData(nextList);
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteMessage(String messageId) async {
    final repo = ref.read(chatV2RepositoryProvider);
    try {
      await repo.deleteMessage(messageId);
      // Update locally
      final current = state.valueOrNull ?? [];
      final idx = current.indexWhere((m) => m.id == messageId);
      if (idx != -1) {
        final nextList = List<ChatV2Message>.from(current);
        nextList.removeAt(idx);
        state = AsyncData(nextList);
      }
    } catch (e) {
      rethrow;
    }
  }

  Future<void> sendPoll({
    required String question,
    required List<String> options,
    bool allowMultiple = false,
  }) async {
    final channelId = arg;
    final repo = ref.read(chatV2RepositoryProvider);
    final user = ref.read(authControllerProvider).valueOrNull;

    final meta = user?.userMetadata;
    final partnerId = meta?['partner_id']?.toString() ??
        meta?['partner']?['id']?.toString();
    final userId = user?.id;
    final userName = meta?['name']?.toString() ?? 'Tôi';

    final sentMsg = await repo.sendPoll(
      channelId: channelId,
      question: question,
      options: options,
      allowMultiple: allowMultiple,
      currentPartnerId: partnerId,
      currentUserId: userId,
      authorName: userName,
    );

    final currentList = state.valueOrNull ?? const [];
    final updatedList = [sentMsg, ...currentList.where((m) => m.id != sentMsg.id)];
    ChatV2MessageLocalCache.set(channelId, updatedList);
    state = AsyncData(updatedList);

    ref.read(chatV2LastSentTrackerProvider.notifier).recordSent(channelId, '📊 [Bình chọn] $question');
    ref.read(chatV2ReadStateProvider.notifier).markChannelAsRead(channelId);
    ref.invalidate(chatV2ChannelsProvider);
  }

  Future<void> votePoll(String messageId, int optionId) async {
    final channelId = arg;
    final repo = ref.read(chatV2RepositoryProvider);
    final user = ref.read(authControllerProvider).valueOrNull;

    final meta = user?.userMetadata;
    final partnerIdStr = meta?['partner_id']?.toString() ??
        meta?['partner']?['id']?.toString();
    final partnerId = int.tryParse(partnerIdStr ?? '');
    final partnerName = meta?['name']?.toString() ?? 'Tôi';

    // 1. Optimistic Update locally
    final currentList = state.valueOrNull ?? const [];
    final targetMsg = currentList.firstWhereOrNull((m) => m.id == messageId);
    if (targetMsg != null && targetMsg.isPollMessage && targetMsg.poll != null) {
      final currentPoll = targetMsg.poll!;
      final updatedOptions = <ChatV2PollOption>[];
      final isMulti = currentPoll.allowMultiple;
      final alreadyVoted = currentPoll.options.firstWhereOrNull((o) => o.id == optionId)?.hasVoted(partnerId) ?? false;

      for (final opt in currentPoll.options) {
        if (opt.id == optionId) {
          final newVoters = List<int>.from(opt.voterIds);
          final newNames = List<String>.from(opt.voterNames);
          if (alreadyVoted) {
            final idx = newVoters.indexOf(partnerId!);
            if (idx >= 0) {
              newVoters.removeAt(idx);
              if (idx < newNames.length) newNames.removeAt(idx);
            }
          } else if (partnerId != null) {
            newVoters.add(partnerId);
            newNames.add(partnerName);
          }
          updatedOptions.add(opt.copyWith(
            voterIds: newVoters,
            voterNames: newNames,
            voteCount: newVoters.length,
          ));
        } else {
          if (!isMulti && !alreadyVoted && partnerId != null) {
            // Remove user from other options
            final newVoters = List<int>.from(opt.voterIds);
            final newNames = List<String>.from(opt.voterNames);
            final idx = newVoters.indexOf(partnerId);
            if (idx >= 0) {
              newVoters.removeAt(idx);
              if (idx < newNames.length) newNames.removeAt(idx);
            }
            updatedOptions.add(opt.copyWith(
              voterIds: newVoters,
              voterNames: newNames,
              voteCount: newVoters.length,
            ));
          } else {
            updatedOptions.add(opt);
          }
        }
      }

      final newTotalVotes = updatedOptions.fold(0, (sum, o) => sum + o.voteCount);
      final newPoll = ChatV2Poll(
        id: currentPoll.id,
        question: currentPoll.question,
        options: updatedOptions,
        allowMultiple: currentPoll.allowMultiple,
        creatorId: currentPoll.creatorId,
        creatorName: currentPoll.creatorName,
        totalVotes: newTotalVotes,
        totalVoters: updatedOptions.map((o) => o.voterIds).expand((x) => x).toSet().length,
      );

      final newBody = '<!-- POLL_DATA:${json.encode(newPoll.toJson())} -->';
      final updatedMsg = targetMsg.copyWith(content: newBody);

      final optimisticList = currentList.map((m) => m.id == messageId ? updatedMsg : m).toList();
      state = AsyncData(optimisticList);
      ChatV2MessageLocalCache.set(channelId, optimisticList);
    }

    try {
      final updatedPoll = await repo.votePoll(messageId: messageId, optionId: optionId);
      if (updatedPoll != null) {
        final newBody = '<!-- POLL_DATA:${json.encode(updatedPoll.toJson())} -->';
        final freshList = (state.valueOrNull ?? const []).map((m) {
          if (m.id == messageId) {
            return m.copyWith(content: newBody);
          }
          return m;
        }).toList();
        state = AsyncData(freshList);
        ChatV2MessageLocalCache.set(channelId, freshList);
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Vote poll error: $e');
      }
    }
  }
}
