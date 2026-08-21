import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import 'chat_v2_read_state_controller.dart';
import '../data/chat_v2_realtime_service.dart';
import '../data/chat_v2_repository.dart';
import '../data/models/chat_v2_channel.dart';
import 'chat_v2_messages_controller.dart';

final chatV2ChannelsProvider =
    AsyncNotifierProvider<ChatV2ChannelsNotifier, List<ChatV2Channel>>(
  ChatV2ChannelsNotifier.new,
);

class ChatV2ChannelLocalCache {
  static List<ChatV2Channel> _cached = const [];
  static final Map<String, ChatV2Channel> _pinnedDirectChannels = {};
  static const _storage = FlutterSecureStorage();
  static const _storageKey = 'pinned_direct_channels_v2';
  static const _channelsCacheKey = 'cached_channels_v3';
  static const _unreadCacheKey = 'cached_unread_count_v3';
  static bool _initialized = false;

  static List<ChatV2Channel> get cached => _cached;
  static String? _mergeLastMessage(ChatV2Channel local, ChatV2Channel api) {
    if (local.lastMessage == null || local.lastMessage!.isEmpty) return api.lastMessage;
    if (api.lastMessage == null || api.lastMessage!.isEmpty) return local.lastMessage;
    if (local.lastMessageDate == null) return api.lastMessage;
    if (api.lastMessageDate == null) return local.lastMessage;
    
    if (api.lastMessageDate!.isAfter(local.lastMessageDate!)) {
      return api.lastMessage;
    }
    return local.lastMessage;
  }

  static DateTime? _mergeLastMessageDate(ChatV2Channel local, ChatV2Channel api) {
    if (local.lastMessage == null || local.lastMessage!.isEmpty) return api.lastMessageDate ?? local.lastMessageDate;
    if (local.lastMessageDate == null) return api.lastMessageDate;
    if (api.lastMessageDate == null) return local.lastMessageDate;
    
    return api.lastMessageDate!.isAfter(local.lastMessageDate!) 
        ? api.lastMessageDate 
        : local.lastMessageDate;
  }

  static ChatV2Channel? getPinnedDirectChannel(String id) => _pinnedDirectChannels[id];

  static Future<void> init() async {
    if (_initialized) return;
    try {
      final data = await _storage.read(key: _storageKey);
      if (data != null && data.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(data);
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            final ch = ChatV2Channel.fromJson(item);
            _pinnedDirectChannels[ch.id] = ch;
          }
        }
      }

      final channelsData = await _storage.read(key: _channelsCacheKey);
      if (channelsData != null && channelsData.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(channelsData);
        final loaded = <ChatV2Channel>[];
        for (final item in decoded) {
          if (item is Map<String, dynamic>) {
            loaded.add(ChatV2Channel.fromJson(item));
          }
        }
        if (loaded.isNotEmpty) {
          set(loaded);
        }
      }

      final unreadData = await _storage.read(key: _unreadCacheKey);
      if (unreadData != null && unreadData.isNotEmpty) {
        _lastKnownUnread = int.tryParse(unreadData) ?? _lastKnownUnread;
      }
    } catch (_) {}
    _initialized = true;
  }

  static VoidCallback? onCacheUpdated;

  static void pinDirectChannel(ChatV2Channel channel) {
    _pinnedDirectChannels[channel.id] = channel;
    set(_cached.isNotEmpty ? _cached : [channel]);
    _saveToStorage();
    onCacheUpdated?.call();
  }

  static void updateChannelLastMessage(
    String channelId, {
    required String lastMessage,
    required DateTime lastMessageDate,
    String? authorId,
    String? authorName,
    int? unreadCount,
  }) {
    if (_pinnedDirectChannels.containsKey(channelId)) {
      final old = _pinnedDirectChannels[channelId]!;
      _pinnedDirectChannels[channelId] = old.copyWith(
        lastMessage: lastMessage,
        lastMessageDate: lastMessageDate,
        lastMessageAuthorId: authorId ?? old.lastMessageAuthorId,
        lastMessageAuthorName: authorName ?? old.lastMessageAuthorName,
        unreadCount: unreadCount ?? 0,
      );
    }
    final currentCached = List<ChatV2Channel>.from(_cached);
    final idx = currentCached.indexWhere((c) => c.id == channelId);
    if (idx != -1) {
      final old = currentCached[idx];
      currentCached[idx] = old.copyWith(
        lastMessage: lastMessage,
        lastMessageDate: lastMessageDate,
        lastMessageAuthorId: authorId ?? old.lastMessageAuthorId,
        lastMessageAuthorName: authorName ?? old.lastMessageAuthorName,
        unreadCount: unreadCount ?? (authorId != null ? 0 : old.unreadCount),
      );
      set(currentCached);
    } else if (_pinnedDirectChannels.containsKey(channelId)) {
      set(_cached);
    }
    _saveToStorage();
    onCacheUpdated?.call();
  }

  static void markChannelAsRead(String channelId) {
    if (_pinnedDirectChannels.containsKey(channelId)) {
      final old = _pinnedDirectChannels[channelId]!;
      _pinnedDirectChannels[channelId] = old.copyWith(unreadCount: 0);
    }
    final currentCached = List<ChatV2Channel>.from(_cached);
    final idx = currentCached.indexWhere((c) => c.id == channelId);
    if (idx != -1) {
      currentCached[idx] = currentCached[idx].copyWith(unreadCount: 0);
      set(currentCached);
    } else if (_pinnedDirectChannels.containsKey(channelId)) {
      set(_cached);
    }
    _saveToStorage();
    onCacheUpdated?.call();
  }

  static Future<void> _saveToStorage() async {
    try {
      final list = _pinnedDirectChannels.values.map((c) => c.toMap()).toList();
      await _storage.write(key: _storageKey, value: jsonEncode(list));
    } catch (_) {}
  }

  static Future<void> _saveCachedChannelsToStorage() async {
    try {
      final topChannels = _cached.take(300).map((c) => c.toMap()).toList();
      await _storage.write(key: _channelsCacheKey, value: jsonEncode(topChannels));
      if (_lastKnownUnread > 0) {
        await _storage.write(key: _unreadCacheKey, value: _lastKnownUnread.toString());
      }
    } catch (_) {}
  }

  static void saveUnreadCount(int unread) {
    _lastKnownUnread = unread;
    _storage.write(key: _unreadCacheKey, value: unread.toString()).catchError((_) {});
  }

  static void set(List<ChatV2Channel> channels) {
    final map = <String, ChatV2Channel>{};
    for (final c in channels) {
      map[c.id] = c;
    }
    for (final c in _pinnedDirectChannels.values) {
      if (map.containsKey(c.id)) {
        final existing = map[c.id]!;
        map[c.id] = existing.copyWith(
          name: (c.name.isNotEmpty && c.name != 'Trò chuyện') ? c.name : existing.name,
          channelType: 'chat',
          isGroup: false,
          memberCount: 2,
          avatarUrl: (existing.avatarUrl != null && existing.avatarUrl!.isNotEmpty)
              ? existing.avatarUrl
              : c.avatarUrl,
          directPartnerId: (existing.directPartnerId != null && existing.directPartnerId!.isNotEmpty)
              ? existing.directPartnerId
              : c.directPartnerId,
          directPartnerName: (existing.directPartnerName != null && existing.directPartnerName!.isNotEmpty)
              ? existing.directPartnerName
              : c.directPartnerName,
          lastMessage: _mergeLastMessage(c, existing),
          lastMessageDate: _mergeLastMessageDate(c, existing),
        );
      } else {
        map[c.id] = c;
      }
    }
    final merged = map.values.toList();
    merged.sort((a, b) {
      final da = a.lastMessageDate ?? DateTime.fromMillisecondsSinceEpoch(0);
      final db = b.lastMessageDate ?? DateTime.fromMillisecondsSinceEpoch(0);
      return db.compareTo(da);
    });
    _cached = List.unmodifiable(merged);
    _saveCachedChannelsToStorage();
  }

  static void remove(String channelId) {
    _pinnedDirectChannels.remove(channelId);
    _cached = List.unmodifiable(_cached.where((c) => c.id != channelId).toList());
    _saveToStorage();
    _saveCachedChannelsToStorage();
    onCacheUpdated?.call();
  }

  static void clear() {
    _pinnedDirectChannels.clear();
    _cached = const [];
    _saveToStorage();
    _saveCachedChannelsToStorage();
    onCacheUpdated?.call();
  }
}

class ChatV2ChannelsNotifier
    extends AsyncNotifier<List<ChatV2Channel>> {
  StreamSubscription? _wsMessageSub;
  StreamSubscription? _wsUpdateSub;
  Timer? _pollingTimer;
  Timer? _debounceTimer;
  bool _isFetching = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;

  @override
  Future<List<ChatV2Channel>> build() async {
    ref.keepAlive();
    debugPrint('🟢 [LIFECYCLE] ChatV2ChannelsNotifier: BUILD (Provider created)');
    await ChatV2ChannelLocalCache.init();
    await ChatV2MessageLocalCache.init();
    final repo = ref.read(chatV2RepositoryProvider);
    final realtime = ref.read(chatV2RealtimeServiceProvider);
    var isDisposed = false;

    ChatV2ChannelLocalCache.onCacheUpdated = () {
      if (!isDisposed) {
        state = AsyncData(ChatV2ChannelLocalCache.cached);
      }
    };

    bool hasChannelsChanged(List<ChatV2Channel> currentList, List<ChatV2Channel> freshList) {
      if (freshList.isEmpty && currentList.isNotEmpty) return false;
      if (currentList.isEmpty && freshList.isNotEmpty) return true;
      if (currentList.length != freshList.length) return true;
      final currentMap = {for (final c in currentList) c.id: c};
      for (final freshItem in freshList) {
        final match = currentMap[freshItem.id];
        if (match == null ||
            match.lastMessage != freshItem.lastMessage ||
            match.lastMessageDate != freshItem.lastMessageDate ||
            match.unreadCount != freshItem.unreadCount) {
          return true;
        }
      }
      return false;
    }

    Future<void> fetchFreshChannels() async {
      if (_isFetching || isDisposed) return;
      _isFetching = true;
      try {
        final fresh = await repo.getChannels(limit: 80);
        if (isDisposed) return;
        final current = state.valueOrNull ?? ChatV2ChannelLocalCache.cached;
        if (fresh.isNotEmpty && hasChannelsChanged(current, fresh)) {
          ChatV2ChannelLocalCache.set(fresh);
          state = AsyncData(ChatV2ChannelLocalCache.cached);
        }
      } catch (_) {
      } finally {
        _isFetching = false;
      }
    }

    _wsMessageSub?.cancel();
    _wsMessageSub = realtime.onMessageReceived.listen((msg) {
      if (isDisposed || msg.channelId.isEmpty) return;

      final current = state.valueOrNull ?? ChatV2ChannelLocalCache.cached;
      final chIndex = current.indexWhere((c) => c.id == msg.channelId);

      final currentUser = ref.read(authControllerProvider).valueOrNull;
      final meta = currentUser?.userMetadata;
      final partnerId = meta?['partner_id']?.toString() ?? meta?['partner']?['id']?.toString();
      final userId = currentUser?.id;
      final isMine = (partnerId != null && msg.authorId == partnerId) ||
          (userId != null && msg.authorId == userId);

      if (isMine) {
        ref.read(chatV2ReadStateProvider.notifier).markChannelAsRead(msg.channelId);
      } else {
        ref.read(chatV2LastSentTrackerProvider.notifier).clear(msg.channelId);
        ref.read(chatV2ReadStateProvider.notifier).markChannelAsUnread(msg.channelId);
      }

      if (chIndex != -1) {
        final target = current[chIndex];
        final updatedChannel = target.copyWith(
          lastMessage: msg.content.isNotEmpty ? msg.content : (msg.attachments.isNotEmpty ? '[Đính kèm]' : null),
          lastMessageDate: msg.createdAt,
          lastMessageAuthorId: msg.authorId,
          lastMessageAuthorName: msg.authorName,
          unreadCount: isMine ? 0 : (target.unreadCount + 1),
        );

        final reordered = <ChatV2Channel>[
          updatedChannel,
          for (int i = 0; i < current.length; i++)
            if (i != chIndex) current[i],
        ];

        ChatV2ChannelLocalCache.set(reordered);
        state = AsyncData(reordered);
      } else {
        _debounceTimer?.cancel();
        _debounceTimer = Timer(const Duration(milliseconds: 900), fetchFreshChannels);
      }
    });

    _wsUpdateSub?.cancel();
    _wsUpdateSub = realtime.onChannelUpdated.listen((chId) {
      if (isDisposed) return;
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 900), fetchFreshChannels);
    });

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
      ChatV2ChannelLocalCache.onCacheUpdated = null;
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

    try {
      final fresh = await repo.getChannels(limit: 80, offset: 0);
      ChatV2ChannelLocalCache.set(fresh);
    } catch (e) {
      debugPrint('ChatV2ChannelsNotifier: initial fetch error: $e');
    }
    return ChatV2ChannelLocalCache.cached;
  }

  Future<void> refresh() async {
    _hasMore = true;
    final repo = ref.read(chatV2RepositoryProvider);
    final fresh = await repo.getChannels(limit: 80, offset: 0);
    ChatV2ChannelLocalCache.set(fresh);
    state = AsyncData(ChatV2ChannelLocalCache.cached);
  }

  Future<void> loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    _isLoadingMore = true;
    try {
      final current = state.valueOrNull ?? [];
      final repo = ref.read(chatV2RepositoryProvider);
      final nextItems = await repo.getChannels(
        limit: 50,
        offset: current.length,
      );

      if (nextItems.isEmpty || nextItems.length < 50) {
        _hasMore = false;
      }

      if (nextItems.isNotEmpty) {
        final map = <String, ChatV2Channel>{};
        for (final c in current) {
          map[c.id] = c;
        }
        for (final c in nextItems) {
          map[c.id] = c;
        }
        final merged = map.values.toList();
        merged.sort((a, b) {
          final da = a.lastMessageDate ?? DateTime.fromMillisecondsSinceEpoch(0);
          final db = b.lastMessageDate ?? DateTime.fromMillisecondsSinceEpoch(0);
          return db.compareTo(da);
        });

        ChatV2ChannelLocalCache.set(merged);
        state = AsyncData(merged);
      }
    } catch (_) {
    } finally {
      _isLoadingMore = false;
    }
  }
}

int _lastKnownUnread = 0;

final chatV2TotalUnreadProvider = Provider<int>((ref) {
  ref.keepAlive();

  final channelsState = ref.watch(chatV2ChannelsProvider);
  final readNotifier = ref.watch(chatV2ReadStateProvider.notifier);
  ref.watch(chatV2ReadStateProvider);

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
      final unread = channels.where((c) {
        final cachedMsgs = ChatV2MessageLocalCache.get(c.id);
        final effectiveLastMsg = (c.lastMessage != null && c.lastMessage!.isNotEmpty)
            ? c.lastMessage
            : (cachedMsgs != null && cachedMsgs.isNotEmpty
                ? cachedMsgs.first.content
                : null);

        // Kênh chưa có tin nhắn nào thì không tính vào badge chưa đọc
        if (effectiveLastMsg == null || effectiveLastMsg.trim().isEmpty) {
          return false;
        }

        final isFirstMsgMine = cachedMsgs != null &&
            cachedMsgs.isNotEmpty &&
            cachedMsgs.first.isMine;
        final lastSentText = lastSentMap[c.id];
        final isMineFromTracker = lastSentText != null &&
            c.lastMessage?.trim() == lastSentText.trim();

        final isMine = isFirstMsgMine ||
            isMineFromTracker ||
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
      _lastKnownUnread = unread;
      ChatV2ChannelLocalCache.saveUnreadCount(unread);
      return unread;
    },
    orElse: () => _lastKnownUnread,
  );
});
