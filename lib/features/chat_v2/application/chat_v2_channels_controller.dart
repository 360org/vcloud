import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import 'chat_v2_read_state_controller.dart';
import '../data/chat_v2_realtime_service.dart';
import '../data/chat_v2_repository.dart';
import '../data/models/chat_v2_channel.dart';

final chatV2ChannelsProvider =
    AsyncNotifierProvider.autoDispose<ChatV2ChannelsNotifier, List<ChatV2Channel>>(
  ChatV2ChannelsNotifier.new,
);

class ChatV2ChannelLocalCache {
  static List<ChatV2Channel> _cached = const [];

  static List<ChatV2Channel> get cached => _cached;

  static void set(List<ChatV2Channel> channels) {
    _cached = List.unmodifiable(channels);
  }
}

class ChatV2ChannelsNotifier
    extends AutoDisposeAsyncNotifier<List<ChatV2Channel>> {
  StreamSubscription? _wsUpdateSub;
  StreamSubscription? _wsMessageSub;
  Timer? _pollingTimer;
  Timer? _debounceTimer;
  bool _isFetching = false;

  @override
  FutureOr<List<ChatV2Channel>> build() async {
    final repo = ref.watch(chatV2RepositoryProvider);
    final realtime = ref.watch(chatV2RealtimeServiceProvider);
    final user = ref.watch(authControllerProvider).valueOrNull;

    final meta = user?.userMetadata;
    final partnerId = meta?['partner_id']?.toString() ??
        meta?['partner']?['id']?.toString();
    final userId = user?.id;

    bool isDisposed = false;

    bool hasChannelsChanged(List<ChatV2Channel> oldList, List<ChatV2Channel> newList) {
      if (oldList.length != newList.length) return true;
      for (int i = 0; i < oldList.length; i++) {
        final a = oldList[i];
        final b = newList[i];
        if (a.id != b.id ||
            a.lastMessage != b.lastMessage ||
            a.lastMessageDate != b.lastMessageDate ||
            a.unreadCount != b.unreadCount) {
          return true;
        }
      }
      return false;
    }

    // Fetch channels từ server với In-Flight Lock
    Future<void> fetchFreshChannels() async {
      if (_isFetching || isDisposed) return;
      _isFetching = true;
      try {
        final fresh = await repo.getChannels();
        if (isDisposed) return;
        final current = state.valueOrNull ?? ChatV2ChannelLocalCache.cached;
        if (hasChannelsChanged(current, fresh)) {
          ChatV2ChannelLocalCache.set(fresh);
          state = AsyncData(fresh);
        }
      } catch (_) {
      } finally {
        _isFetching = false;
      }
    }

    // 1. DELTA LOCAL UPDATE: Nhận tin nhắn mới từ WebSocket -> Cập nhật trực tiếp Local State (0 HTTP GET)
    _wsMessageSub?.cancel();
    _wsMessageSub = realtime.onMessageReceived.listen((msg) {
      if (isDisposed || msg.channelId.isEmpty) return;

      final current = state.valueOrNull ?? ChatV2ChannelLocalCache.cached;
      final chIndex = current.indexWhere((c) => c.id == msg.channelId);

      final isMine = (partnerId != null && msg.authorId == partnerId) ||
          (userId != null && msg.authorId == userId);

      if (isMine) {
        ref.read(chatV2ReadStateProvider.notifier).markChannelAsRead(msg.channelId);
      } else {
        ref.read(chatV2LastSentTrackerProvider.notifier).clear(msg.channelId);
        ref.read(chatV2ReadStateProvider.notifier).markChannelAsUnread(msg.channelId);
      }

      if (chIndex != -1) {
        // Kênh đã tồn tại -> Cập nhật delta tin nhắn cuối và đẩy lên đầu danh sách
        final target = current[chIndex];
        final updatedChannel = target.copyWith(
          lastMessage: msg.content.isNotEmpty ? msg.content : (msg.attachments.isNotEmpty ? '[Đính kèm]' : null),
          lastMessageDate: msg.createdAt,
          lastMessageAuthorId: msg.authorId,
          lastMessageAuthorName: msg.authorName,
          unreadCount: isMine ? target.unreadCount : (target.unreadCount + 1),
        );

        final reordered = <ChatV2Channel>[
          updatedChannel,
          for (int i = 0; i < current.length; i++)
            if (i != chIndex) current[i],
        ];

        ChatV2ChannelLocalCache.set(reordered);
        state = AsyncData(reordered);
      } else {
        // Kênh mới chưa có trong danh sách -> Debounce fetch sau 900ms
        _debounceTimer?.cancel();
        _debounceTimer = Timer(const Duration(milliseconds: 900), fetchFreshChannels);
      }
    });

    // 2. IN-FLIGHT LOCK & DEBOUNCE FALLBACK: Gom bão event từ onChannelUpdated (800ms - 1000ms)
    _wsUpdateSub?.cancel();
    _wsUpdateSub = realtime.onChannelUpdated.listen((chId) {
      if (isDisposed) return;
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 900), fetchFreshChannels);
    });

    // 3. BACKGROUND POLLING NHẸ NHÀNG CHO DANH SÁCH KÊNH (8s/lần)
    void scheduleNextPoll() {
      if (isDisposed) return;
      _pollingTimer?.cancel();
      _pollingTimer = Timer(const Duration(seconds: 8), () async {
        if (isDisposed) return;
        if (!state.isLoading && state.hasValue) {
          await fetchFreshChannels();
        }
        if (!isDisposed) {
          scheduleNextPoll();
        }
      });
    }

    scheduleNextPoll();

    ref.onDispose(() {
      isDisposed = true;
      _wsUpdateSub?.cancel();
      _wsMessageSub?.cancel();
      _pollingTimer?.cancel();
      _debounceTimer?.cancel();
    });

    final cached = ChatV2ChannelLocalCache.cached;
    if (cached.isNotEmpty) {
      unawaited(fetchFreshChannels());
      return cached;
    }

    final fresh = await repo.getChannels();
    ChatV2ChannelLocalCache.set(fresh);
    return fresh;
  }

  Future<void> refresh() async {
    final repo = ref.read(chatV2RepositoryProvider);
    final fresh = await repo.getChannels();
    ChatV2ChannelLocalCache.set(fresh);
    state = AsyncData(fresh);
  }
}

final chatV2TotalUnreadProvider = Provider.autoDispose<int>((ref) {
  final channelsState = ref.watch(chatV2ChannelsProvider);
  final readNotifier = ref.watch(chatV2ReadStateProvider.notifier);
  ref.watch(chatV2ReadStateProvider); // Watch thay đổi để tự cập nhật badge khi đọc tin

  final currentUser = ref.watch(authControllerProvider).valueOrNull;
  final meta = currentUser?.userMetadata;
  final currentUserName = (meta?['name'] ??
          meta?['display_name'] ??
          meta?['partner_name'] ??
          meta?['partner']?['name']) as String?;
  final currentPartnerId = meta?['partner_id']?.toString() ??
      meta?['partner']?['id']?.toString();
  final currentUserId = currentUser?.id;
  final lastSentMap = ref.watch(chatV2LastSentTrackerProvider);

  return channelsState.maybeWhen(
    data: (channels) {
      return channels.where((c) {
        final lastSentText = lastSentMap[c.id];
        final isMineFromTracker = lastSentText != null &&
            c.lastMessage?.trim() == lastSentText.trim();

        final isMine = isMineFromTracker ||
            c.isLastMessageFromMe(
              currentUserName: currentUserName,
              currentPartnerId: currentPartnerId,
              currentUserId: currentUserId,
            );

        return !isMine &&
            readNotifier.isChannelUnread(
              channelId: c.id,
              serverUnreadCount: c.unreadCount,
              lastMessageDate: c.lastMessageDate,
            );
      }).length;
    },
    orElse: () => 0,
  );
});
