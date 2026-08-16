import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../../../core/utils/local_attachment_cache.dart';
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
        ChatV2MessageLocalCache.append(channelId, newMsg);
        final currentList = state.valueOrNull ?? const [];
        if (!currentList.any((m) => m.id == newMsg.id)) {
          state = AsyncData([...currentList, newMsg]);
        }
      }
    });

    // Polling thích ứng (Adaptive Polling): Chạy nhẹ (12s) khi WebSocket active, chạy nhanh (1.5s) khi WebSocket offline
    bool isDisposed = false;

    void scheduleNextPoll() {
      if (isDisposed) return;
      _pollingTimer?.cancel();
      _pollingTimer = Timer(const Duration(milliseconds: 3500), () async {
        if (!state.isLoading && state.hasValue) {
          // Nếu WebSocket đang kết nối ổn định, chỉ fetch ngẫu nhiên hoặc sau chu kỳ dài
          final isWsActive = realtime.isConnected;
          final now = DateTime.now().millisecondsSinceEpoch;
          // Bỏ qua lượt poll nếu WS đang active và chưa tới 15s
          if (isWsActive && (now % 15000 > 3600)) {
            scheduleNextPoll();
            return;
          }

          try {
            debugPrint('🟢 [TRACE] ChatV2MessagesNotifier.polling getMessages() START');
            final latest = await repo.getMessages(
              channelId,
              currentPartnerId: partnerId,
              currentUserId: userId,
            );
            debugPrint('🔴 [TRACE] ChatV2MessagesNotifier.polling getMessages() END - length: ${latest.length}');
            if (latest.isNotEmpty) {
              final currentList = state.valueOrNull ?? const [];
              final currentIds = currentList.map((m) => m.id).toSet();
              final hasNew = latest.any((m) => !currentIds.contains(m.id));
              final hasPending = currentList.any((m) => m.status == 'pending');

              if (hasNew || hasPending || currentList.length != latest.length) {
                ChatV2MessageLocalCache.set(channelId, latest);
                state = AsyncData(latest);
              }
            }
          } catch (e, st) {
            debugPrint('❌ [ERROR] ChatV2MessagesNotifier.polling: $e\n$st');
          }
        }
        scheduleNextPoll();
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
          ChatV2MessageLocalCache.set(channelId, fresh);
          state = AsyncData(fresh);
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

  Future<void> sendMessage(String text, {List<int>? attachmentIds, String? parentId}) async {
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
    );

    final previousState = state.valueOrNull ?? const [];
    state = AsyncData([...previousState, tempMsg]);

    try {
      final sentMsg = await repo.sendMessage(
        channelId,
        trimmed,
        attachmentIds: attachmentIds,
        currentPartnerId: partnerId,
        currentUserId: userId,
        authorName: userName,
      );

      // Cập nhật lại tin nhắn trong danh sách
      final currentList = state.valueOrNull ?? const [];
      final updatedList = currentList.map((m) {
        if (m.id == tempId) {
          return sentMsg.copyWith(isMine: true, status: 'sent');
        }
        return m;
      }).toList();

      // Nếu không tìm thấy tempId để thay thế, thêm vào cuối
      if (!updatedList.any((m) => m.id == sentMsg.id)) {
        updatedList.removeWhere((m) => m.id == tempId);
        updatedList.add(sentMsg.copyWith(isMine: true, status: 'sent'));
      }

      ChatV2MessageLocalCache.set(channelId, updatedList);
      state = AsyncData(updatedList);

      // Báo sự kiện realtime
      ref.read(chatV2RealtimeServiceProvider).notifyMessageSent(channelId, sentMsg);
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
    state = AsyncData([...previousState, tempMsg]);

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
      ChatV2AttachmentImage.cacheBytes(att.id.toString(), bytes);
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

      // Cập nhật trạng thái sent ngay lập tức cho tin nhắn tạm
      final currentList = state.valueOrNull ?? const [];
      final updatedList = currentList.map((m) {
        if (m.id == tempId) {
          return sentMsg.copyWith(
            isMine: true,
            status: 'sent',
            attachments: [att],
          );
        }
        return m;
      }).toList();

      ChatV2MessageLocalCache.set(channelId, updatedList);
      state = AsyncData(updatedList);

      ref.read(chatV2LastSentTrackerProvider.notifier).recordSent(channelId, bodyText);
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
}
