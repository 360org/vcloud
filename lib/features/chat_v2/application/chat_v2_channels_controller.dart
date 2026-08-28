import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:collection/collection.dart';
import '../../auth/application/auth_controller.dart';
import 'chat_v2_presence_controller.dart';
import 'chat_v2_read_state_controller.dart';
import '../data/chat_v2_realtime_service.dart';
import '../data/chat_v2_repository.dart';
import '../data/models/chat_v2_channel.dart';
import '../presentation/widgets/chat_v2_in_app_banner.dart';
import 'chat_v2_messages_controller.dart';

enum ChatV2SyncStatus {
  synced,
  connecting,
  offline,
}

final chatV2SyncStatusProvider = StateProvider<ChatV2SyncStatus>((ref) {
  return ChatV2SyncStatus.synced;
});

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
  static const _pinnedIdsKey = 'user_pinned_channel_ids';
  static const _mutedIdsKey = 'user_muted_channel_ids';
  static bool _initialized = false;
  static List<String> _userPinnedOrder = [];
  static Set<String> _userPinnedIds = {};
  static Set<String> _userMutedIds = {};

  static List<ChatV2Channel> get cached => _cached;
  static String? _mergeLastMessage(ChatV2Channel local, ChatV2Channel api) {
    if (local.lastMessage == null || local.lastMessage!.isEmpty) return api.lastMessage;
    if (api.lastMessage == null || api.lastMessage!.isEmpty) return local.lastMessage;
    if (local.lastMessageDate == null) return api.lastMessage;
    if (api.lastMessageDate == null) return local.lastMessage;

    final localUtc = local.lastMessageDate!.toUtc();
    final apiUtc = api.lastMessageDate!.toUtc();
    if (apiUtc.isAfter(localUtc)) {
      return api.lastMessage;
    }
    return local.lastMessage;
  }

  static DateTime? _mergeLastMessageDate(ChatV2Channel local, ChatV2Channel api) {
    // Nếu channel local có tin nhắn từ cache tin nhắn, lấy thời gian tin nhắn mới nhất
    final cachedMsgs = ChatV2MessageLocalCache.get(local.id);
    final cachedDate = (cachedMsgs != null && cachedMsgs.isNotEmpty) ? cachedMsgs.first.createdAt : null;

    final localDate = cachedDate ?? local.lastMessageDate;
    if (local.lastMessage == null || local.lastMessage!.isEmpty) return api.lastMessageDate ?? localDate;
    if (localDate == null) return api.lastMessageDate;
    if (api.lastMessageDate == null) return localDate;

    final localUtc = localDate.toUtc();
    final apiUtc = api.lastMessageDate!.toUtc();
    return apiUtc.isAfter(localUtc)
        ? api.lastMessageDate
        : localDate;
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

      final pinnedIdsData = await _storage.read(key: _pinnedIdsKey);
      if (pinnedIdsData != null && pinnedIdsData.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(pinnedIdsData);
        _userPinnedOrder = decoded.map((e) => e.toString()).toList();
        _userPinnedIds = _userPinnedOrder.toSet();
      }

      final mutedIdsData = await _storage.read(key: _mutedIdsKey);
      if (mutedIdsData != null && mutedIdsData.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(mutedIdsData);
        _userMutedIds = decoded.map((e) => e.toString()).toSet();
      }
    } catch (_) {}
    _initialized = true;
  }

  static VoidCallback? onCacheUpdated;

  static bool isUserPinned(String channelId) => _userPinnedIds.contains(channelId);

  static int getPinnedIndex(String channelId) {
    final idx = _userPinnedOrder.indexOf(channelId);
    return idx != -1 ? idx : 999999;
  }

  static void toggleUserPin(String channelId) {
    if (_userPinnedIds.contains(channelId)) {
      _userPinnedIds.remove(channelId);
      _userPinnedOrder.remove(channelId);
    } else {
      _userPinnedIds.add(channelId);
      if (!_userPinnedOrder.contains(channelId)) {
        _userPinnedOrder.add(channelId);
      }
    }
    _saveUserPinnedIds();
    // Force re-sort via set()
    set(_cached);
  }

  static Future<void> _saveUserPinnedIds() async {
    try {
      await _storage.write(key: _pinnedIdsKey, value: jsonEncode(_userPinnedOrder));
    } catch (_) {}
  }

  static bool isUserMuted(String channelId) => _userMutedIds.contains(channelId);

  static void toggleUserMute(String channelId) {
    if (_userMutedIds.contains(channelId)) {
      _userMutedIds.remove(channelId);
    } else {
      _userMutedIds.add(channelId);
    }
    _saveUserMutedIds();
    set(_cached);
  }

  static Future<void> _saveUserMutedIds() async {
    try {
      await _storage.write(key: _mutedIdsKey, value: jsonEncode(_userMutedIds.toList()));
    } catch (_) {}
  }

  static void pinDirectChannel(ChatV2Channel channel) {
    _pinnedDirectChannels[channel.id] = channel;
    set(_cached.isNotEmpty ? _cached : [channel]);
    _saveToStorage();
    onCacheUpdated?.call();
  }

  static void updateChannel(ChatV2Channel channel, {bool addIfMissing = true}) {
    final currentCached = List<ChatV2Channel>.from(_cached);
    final idx = currentCached.indexWhere((c) => c.id == channel.id);
    if (idx != -1) {
      currentCached[idx] = channel;
      set(currentCached);
    } else if (addIfMissing) {
      currentCached.add(channel);
      set(currentCached);
    }
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
      final cachedMsgs = ChatV2MessageLocalCache.get(c.id);
      final cachedFirst = (cachedMsgs != null && cachedMsgs.isNotEmpty) ? cachedMsgs.first : null;
      final cachedDate = cachedFirst?.createdAt;
      if (cachedDate != null && (c.lastMessageDate == null || cachedDate.toUtc().isAfter(c.lastMessageDate!.toUtc()))) {
        String? cachedContent;
        if (cachedFirst != null) {
          final contentLower = cachedFirst.content.toLowerCase().trim();
          final isVoice = cachedFirst.hasAudio ||
              contentLower.endsWith('.webm') ||
              contentLower.endsWith('.mp3') ||
              contentLower.endsWith('.m4a') ||
              contentLower.endsWith('.wav') ||
              contentLower.endsWith('.aac') ||
              contentLower.endsWith('.ogg') ||
              contentLower.endsWith('.opus') ||
              contentLower.endsWith('.flac') ||
              contentLower.endsWith('.amr') ||
              contentLower.startsWith('voice_') ||
              contentLower.contains('voice_') ||
              contentLower.contains('audio_') ||
              contentLower == '[ghi âm]' ||
              contentLower == 'ghi âm';
          final isImage = contentLower.endsWith('.png') ||
              contentLower.endsWith('.jpg') ||
              contentLower.endsWith('.jpeg') ||
              contentLower.endsWith('.gif') ||
              contentLower.endsWith('.webp') ||
              contentLower.endsWith('.svg') ||
              contentLower.endsWith('.bmp') ||
              contentLower.endsWith('.ico') ||
              contentLower.endsWith('.heic') ||
              contentLower.endsWith('.heif') ||
              contentLower.startsWith('scaled_') ||
              contentLower.startsWith('image_picker_') ||
              contentLower == '[hình ảnh]' ||
              contentLower == 'hình ảnh';
          final isDoc = contentLower.endsWith('.docx') ||
              contentLower.endsWith('.pdf') ||
              contentLower.endsWith('.xlsx') ||
              contentLower.endsWith('.xls') ||
              contentLower.endsWith('.doc') ||
              contentLower.endsWith('.zip') ||
              contentLower.endsWith('.txt') ||
              contentLower.endsWith('.md') ||
              contentLower.endsWith('.markdown') ||
              contentLower.endsWith('.csv') ||
              contentLower.endsWith('.json') ||
              contentLower.endsWith('.xml') ||
              contentLower.endsWith('.rar') ||
              contentLower.endsWith('.7z') ||
              contentLower.endsWith('.tar') ||
              contentLower.endsWith('.gz') ||
              contentLower.endsWith('.apk') ||
              contentLower.endsWith('.ipa') ||
              contentLower.endsWith('.sql') ||
              contentLower.endsWith('.log') ||
              contentLower.endsWith('.pptx') ||
              contentLower.endsWith('.ppt') ||
              contentLower == '[tập tin]' ||
              contentLower == 'tệp tin' ||
              contentLower == '[tài liệu]' ||
              contentLower == 'tài liệu';
          if (cachedFirst.content.isNotEmpty) {
            if (isVoice) {
              cachedContent = '[Ghi âm]';
            } else if (isImage) {
              cachedContent = '[Hình ảnh]';
            } else if (isDoc) {
              cachedContent = '[Tập tin]';
            } else {
              cachedContent = cachedFirst.content;
            }
          } else if (cachedFirst.attachments.isNotEmpty) {
            final att = cachedFirst.attachments.first;
            final attNameLower = att.name.toLowerCase().trim();
            final isAudioAtt = att.isAudio ||
                (att.mimetype != null && att.mimetype!.startsWith('audio/')) ||
                attNameLower.endsWith('.webm') ||
                attNameLower.endsWith('.mp3') ||
                attNameLower.endsWith('.m4a') ||
                attNameLower.endsWith('.wav') ||
                attNameLower.endsWith('.aac') ||
                attNameLower.endsWith('.ogg') ||
                attNameLower.endsWith('.opus') ||
                attNameLower.startsWith('voice_');
            final isImageAtt = att.isImage ||
                (att.mimetype != null && att.mimetype!.startsWith('image/')) ||
                attNameLower.endsWith('.png') ||
                attNameLower.endsWith('.jpg') ||
                attNameLower.endsWith('.jpeg') ||
                attNameLower.endsWith('.gif') ||
                attNameLower.endsWith('.webp') ||
                attNameLower.endsWith('.svg') ||
                attNameLower.endsWith('.bmp') ||
                attNameLower.endsWith('.ico') ||
                attNameLower.endsWith('.heic') ||
                attNameLower.startsWith('scaled_') ||
                attNameLower.startsWith('image_picker_');
            cachedContent = isAudioAtt
                ? '[Ghi âm]'
                : (isImageAtt ? '[Hình ảnh]' : '[Tập tin]');
          }
        }
        map[c.id] = c.copyWith(
          lastMessageDate: cachedDate,
          lastMessage: cachedContent ?? c.lastMessage,
        );
      } else {
        map[c.id] = c;
      }
    }
    for (final c in _pinnedDirectChannels.values) {
      if (map.containsKey(c.id)) {
        final existing = map[c.id]!;
        // Giữ nguyên channelType/isGroup/memberCount từ API (hoặc từ pinned nếu API chưa có)
        map[c.id] = existing.copyWith(
          name: (c.name.isNotEmpty && c.name != 'Trò chuyện') ? c.name : existing.name,
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
      // Ghim lên đầu theo đúng thứ tự ghim cố định (1, 2, 3, 4, 5)
      final aPinned = _userPinnedIds.contains(a.id);
      final bPinned = _userPinnedIds.contains(b.id);
      if (aPinned && !bPinned) return -1;
      if (!aPinned && bPinned) return 1;
      if (aPinned && bPinned) {
        final idxA = _userPinnedOrder.indexOf(a.id);
        final idxB = _userPinnedOrder.indexOf(b.id);
        return (idxA != -1 ? idxA : 999999).compareTo(idxB != -1 ? idxB : 999999);
      }
      final da = (a.lastMessageDate ?? DateTime.fromMillisecondsSinceEpoch(0)).toUtc();
      final db = (b.lastMessageDate ?? DateTime.fromMillisecondsSinceEpoch(0)).toUtc();
      return db.compareTo(da);
    });
    _cached = List.unmodifiable(merged);
    _saveCachedChannelsToStorage();
  }

  static void archive(String channelId) {
    _cached = List.unmodifiable(_cached.where((c) => c.id != channelId).toList());
    _saveCachedChannelsToStorage();
    onCacheUpdated?.call();
  }

  static void remove(String channelId) {
    _pinnedDirectChannels.remove(channelId);
    _cached = List.unmodifiable(_cached.where((c) => c.id != channelId).toList());
    _saveToStorage();
    _saveCachedChannelsToStorage();
    onCacheUpdated?.call();
  }

  static void updateSingleChannel(ChatV2Channel updated) {
    final list = _cached.toList();
    final idx = list.indexWhere((c) => c.id == updated.id);
    if (idx != -1) {
      list[idx] = updated;
    } else {
      list.add(updated);
    }
    _cached = List.unmodifiable(list);
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
  Timer? _resumeRetryTimer;
  int _resumeRetryAttempt = 0;
  bool _isResumeRefreshing = false;
  bool _isDisposed = false;
  bool _isFetching = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;

  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;

  @override
  Future<List<ChatV2Channel>> build() async {
    ref.keepAlive();
    debugPrint('🟢 [LIFECYCLE] ChatV2ChannelsNotifier: BUILD (Provider created)');
    _isDisposed = false;
    await ChatV2ChannelLocalCache.init();
    await ChatV2MessageLocalCache.init();
    final repo = ref.read(chatV2RepositoryProvider);
    final realtime = ref.read(chatV2RealtimeServiceProvider);

    ChatV2ChannelLocalCache.onCacheUpdated = () {
      if (!_isDisposed) {
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
            match.unreadCount != freshItem.unreadCount ||
            match.imStatus != freshItem.imStatus) {
          return true;
        }
      }
      return false;
    }

    Future<void> fetchFreshChannels() async {
      if (_isFetching || _isDisposed) return;
      _isFetching = true;
      try {
        final fresh = await repo.getChannels(limit: 80);
        if (_isDisposed) return;
        if (fresh.isNotEmpty) {
          final presenceNotifier = ref.read(chatV2PresenceProvider.notifier);
          for (final f in fresh) {
            final pId = f.partnerId ?? f.directPartnerId;
            if (pId != null && pId.isNotEmpty && f.imStatus.isNotEmpty) {
              presenceNotifier.updatePresence(pId, f.imStatus);
            }
            if (f.members.isNotEmpty) {
              presenceNotifier.updateMembersPresence(f.members);
            }
          }
        }
        final current = state.valueOrNull ?? ChatV2ChannelLocalCache.cached;
        if (fresh.isNotEmpty && hasChannelsChanged(current, fresh)) {
          // Hiển thị in-app banner khi phát hiện có tin nhắn mới gửi đến
          final currentMap = {for (final c in current) c.id: c};
          for (final f in fresh) {
            final old = currentMap[f.id];
            if (old != null &&
                f.unreadCount > old.unreadCount &&
                (f.lastMessage != null && f.lastMessage!.isNotEmpty)) {
              final isMuted = ChatV2ChannelLocalCache.isUserMuted(f.id);
              if (!isMuted) {
                ref.read(inAppNotificationProvider.notifier).show(
                  title: f.directPartnerName ?? f.name,
                  body: f.lastMessage ?? '',
                  channelId: f.id,
                );
              }
            }
          }

          // Giữ lại imStatus cũ nếu fresh trả offline nhưng cũ đang online
          // tránh nhấp nháy indicator do latency poll
          final merged = fresh.map((f) {
            final old = currentMap[f.id];
            if (old != null && old.imStatus == 'online' && f.imStatus == 'offline') {
              return f.copyWith(imStatus: 'online');
            }
            return f;
          }).toList();
          ChatV2ChannelLocalCache.set(merged);
          state = AsyncData(ChatV2ChannelLocalCache.cached);
        }
      } catch (_) {
      } finally {
        _isFetching = false;
      }
    }

    _wsMessageSub?.cancel();
    _wsMessageSub = realtime.onMessageReceived.listen((msg) {
      if (_isDisposed || msg.channelId.isEmpty) return;

      final current = state.valueOrNull ?? ChatV2ChannelLocalCache.cached;
      final chIndex = current.indexWhere((c) => c.id == msg.channelId);

      final currentUser = ref.read(authControllerProvider).valueOrNull;
      final meta = currentUser?.userMetadata;
      final partnerId = meta?['partner_id']?.toString() ?? meta?['partner']?['id']?.toString();
      final userId = currentUser?.id;
      final isMine = (partnerId != null && msg.authorId == partnerId) ||
          (userId != null && msg.authorId == userId);
      final isMuted = ChatV2ChannelLocalCache.isUserMuted(msg.channelId);

      if (!isMine && !isMuted) {
        HapticFeedback.heavyImpact();
        ref.read(inAppNotificationProvider.notifier).show(
          title: msg.authorName.isNotEmpty ? msg.authorName : 'Tin nhắn mới',
          body: msg.content.isNotEmpty ? msg.content : (msg.attachments.isNotEmpty ? '[Đính kèm]' : ''),
          channelId: msg.channelId,
        );
      }

      if (isMine) {
        ref.read(chatV2ReadStateProvider.notifier).markChannelAsRead(msg.channelId);
      } else {
        ref.read(chatV2LastSentTrackerProvider.notifier).clear(msg.channelId);
        if (!isMuted) {
          ref.read(chatV2ReadStateProvider.notifier).markChannelAsUnread(msg.channelId);
        }
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
      if (_isDisposed) return;
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 900), fetchFreshChannels);
    });

    void scheduleNextPoll() {
      if (_isDisposed) return;
      _pollingTimer?.cancel();
      _pollingTimer = Timer(const Duration(seconds: 8), () async {
        if (_isDisposed) return;
        if (!state.isLoading && state.hasValue) {
          await fetchFreshChannels();
        }
        if (!_isDisposed) {
          scheduleNextPoll();
        }
      });
    }

    scheduleNextPoll();

    ref.onDispose(() {
      ChatV2ChannelLocalCache.onCacheUpdated = null;
      _isDisposed = true;
      _resumeRetryTimer?.cancel();
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
      ref.read(chatV2SyncStatusProvider.notifier).state = ChatV2SyncStatus.connecting;
      final fresh = await repo.getChannels(limit: 80, offset: 0);
      if (fresh.isNotEmpty) {
        final presenceNotifier = ref.read(chatV2PresenceProvider.notifier);
        for (final f in fresh) {
          final pId = f.partnerId ?? f.directPartnerId;
          if (pId != null && pId.isNotEmpty && f.imStatus.isNotEmpty) {
            presenceNotifier.updatePresence(pId, f.imStatus);
          }
          if (f.members.isNotEmpty) {
            presenceNotifier.updateMembersPresence(f.members);
          }
        }
      }
      ChatV2ChannelLocalCache.set(fresh);
      ref.read(chatV2SyncStatusProvider.notifier).state = ChatV2SyncStatus.synced;
      return ChatV2ChannelLocalCache.cached;
    } catch (e) {
      ref.read(chatV2SyncStatusProvider.notifier).state = ChatV2SyncStatus.offline;
      rethrow;
    }
  }

  bool _isTransientError(Object error) {
    final errStr = error.toString().toLowerCase();

    // 1. Non-transient errors (4xx client errors, auth failures, business validation) -> NO RETRY
    if (errStr.contains('401') ||
        errStr.contains('403') ||
        errStr.contains('404') ||
        errStr.contains('400') ||
        errStr.contains('422') ||
        errStr.contains('unauthorized') ||
        errStr.contains('access_denied') ||
        errStr.contains('multiple_tenants') ||
        errStr.contains('tenant_not_found') ||
        errStr.contains('invalid_credentials')) {
      return false;
    }

    // 2. Transient network/server errors (SocketException, Timeout, 5xx, Network loss) -> RETRY
    return true;
  }

  Future<void> resumeRefresh() async {
    if (_isResumeRefreshing) {
      // Single-flight lock: Tránh gọi chồng nhiều worker song song
      return;
    }
    _resumeRetryTimer?.cancel();
    _resumeRetryAttempt = 0;
    await _executeResumeRefresh();
  }

  Future<void> _executeResumeRefresh() async {
    if (_isDisposed) return;
    _isResumeRefreshing = true;
    try {
      final repo = ref.read(chatV2RepositoryProvider);
      final fresh = await repo.getChannels(limit: 80, offset: 0);

      if (_isDisposed) return;

      if (fresh.isNotEmpty) {
        final presenceNotifier = ref.read(chatV2PresenceProvider.notifier);
        for (final f in fresh) {
          final pId = f.partnerId ?? f.directPartnerId;
          if (pId != null && pId.isNotEmpty && f.imStatus.isNotEmpty) {
            presenceNotifier.updatePresence(pId, f.imStatus);
          }
          if (f.members.isNotEmpty) {
            presenceNotifier.updateMembersPresence(f.members);
          }
        }
      }

      ChatV2ChannelLocalCache.set(fresh);
      state = AsyncData(ChatV2ChannelLocalCache.cached);
      _resumeRetryAttempt = 0;
      ref.read(chatV2SyncStatusProvider.notifier).state = ChatV2SyncStatus.synced;
    } catch (e) {
      if (_isDisposed) return;

      if (!_isTransientError(e)) {
        // Lỗi 4xx/Auth không retry tự động
        ref.read(chatV2SyncStatusProvider.notifier).state = ChatV2SyncStatus.synced;
        return;
      }

      // Giới hạn retry tối đa 3 lần theo Exponential Backoff: ~2s, ~4s, ~8s rồi dừng
      if (_resumeRetryAttempt < 3) {
        _resumeRetryAttempt++;
        final delays = [2, 4, 8];
        final delaySeconds = delays[(_resumeRetryAttempt - 1).clamp(0, delays.length - 1)];
        ref.read(chatV2SyncStatusProvider.notifier).state = ChatV2SyncStatus.connecting;

        _resumeRetryTimer?.cancel();
        _resumeRetryTimer = Timer(Duration(seconds: delaySeconds), () {
          _executeResumeRefresh();
        });
      } else {
        ref.read(chatV2SyncStatusProvider.notifier).state = ChatV2SyncStatus.offline;
      }
    } finally {
      _isResumeRefreshing = false;
    }
  }

  Future<void> refresh() async {
    _hasMore = true;
    _resumeRetryTimer?.cancel();
    _resumeRetryAttempt = 0;
    ref.read(chatV2SyncStatusProvider.notifier).state = ChatV2SyncStatus.connecting;
    try {
      final repo = ref.read(chatV2RepositoryProvider);
      final fresh = await repo.getChannels(limit: 80, offset: 0);
      ChatV2ChannelLocalCache.set(fresh);
      state = AsyncData(ChatV2ChannelLocalCache.cached);
      ref.read(chatV2SyncStatusProvider.notifier).state = ChatV2SyncStatus.synced;
    } catch (e) {
      if (state.hasValue && (state.valueOrNull?.isNotEmpty ?? false)) {
        // Đã có data trong bộ nhớ -> Giữ nguyên data cũ, chỉ bật banner offline
        ref.read(chatV2SyncStatusProvider.notifier).state = ChatV2SyncStatus.offline;
      } else {
        ref.read(chatV2SyncStatusProvider.notifier).state = ChatV2SyncStatus.offline;
        state = AsyncError(e, StackTrace.current);
      }
    }
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
          final da = (a.lastMessageDate ?? DateTime.fromMillisecondsSinceEpoch(0)).toUtc();
          final db = (b.lastMessageDate ?? DateTime.fromMillisecondsSinceEpoch(0)).toUtc();
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

  Future<void> archiveChannel(String channelId) async {
    try {
      await ref.read(chatV2RepositoryProvider).archiveChannel(channelId);
      ChatV2ChannelLocalCache.remove(channelId);
      final current = state.valueOrNull ?? ChatV2ChannelLocalCache.cached;
      final updated = current.where((c) => c.id != channelId).toList();
      ChatV2ChannelLocalCache.set(updated);
      state = AsyncData(updated);
      ref.invalidate(chatV2ArchivedChannelsProvider);
    } catch (_) {}
  }

  void updateLocalChannel(ChatV2Channel updated) {
    ChatV2ChannelLocalCache.updateSingleChannel(updated);
    state = AsyncData(ChatV2ChannelLocalCache.cached);
  }

  Future<List<ChatV2Member>> fetchChannelMembers(String channelId) async {
    final members = await ref.read(chatV2RepositoryProvider).fetchChannelMembers(channelId);
    if (members.isNotEmpty) {
      ref.read(chatV2PresenceProvider.notifier).updateMembersPresence(members);
      final current = state.valueOrNull?.firstWhereOrNull((c) => c.id == channelId);
      if (current != null) {
        final otherMember = members.firstWhereOrNull((m) => !m.isMe);
        final updatedCh = current.copyWith(
          members: members,
          memberCount: members.length,
          partnerId: current.partnerId ?? otherMember?.id,
          directPartnerId: current.directPartnerId ?? otherMember?.id,
          directPartnerName: current.directPartnerName ?? otherMember?.name,
          directPartnerStatus: otherMember?.imStatus ?? current.directPartnerStatus,
          imStatus: otherMember?.imStatus ?? current.imStatus,
        );
        updateLocalChannel(updatedCh);
      }
    }
    return members;
  }

  Future<void> unarchiveChannel(String channelId) async {
    try {
      await ref.read(chatV2RepositoryProvider).unarchiveChannel(channelId);
      await refresh(); // Reload channels from API to get it back
      ref.invalidate(chatV2ArchivedChannelsProvider);
    } catch (_) {}
  }
}

final chatV2ArchivedChannelsProvider = FutureProvider.autoDispose<List<ChatV2Channel>>((ref) async {
  final repo = ref.read(chatV2RepositoryProvider);
  return repo.getChannels(showArchived: true, limit: 100);
});

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
