import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../data/chat_v2_repository.dart';

/// Quản lý trạng thái đã đọc / chưa đọc của từng cuộc trò chuyện
final chatV2ReadStateProvider =
    NotifierProvider<ChatV2ReadStateNotifier, Map<String, DateTime>>(
  ChatV2ReadStateNotifier.new,
);

class ChatV2ReadStateNotifier extends Notifier<Map<String, DateTime>> {
  static const _storageKey = 'vcloud_chat_seen_channels_v2';
  static Map<String, DateTime> _memoryCache = {};
  static const _storage = FlutterSecureStorage();

  @override
  Map<String, DateTime> build() {
    if (_memoryCache.isNotEmpty) {
      return _memoryCache;
    }

    // Load async từ Storage để giữ trạng thái sau khi F5 / Reload
    unawaited(() async {
      try {
        final raw = await _storage.read(key: _storageKey);
        if (raw != null && raw.isNotEmpty) {
          final Map<String, dynamic> decoded = jsonDecode(raw);
          final loaded = <String, DateTime>{};
          decoded.forEach((k, v) {
            final dt = DateTime.tryParse(v.toString());
            if (dt != null) loaded[k] = dt;
          });
          if (loaded.isNotEmpty) {
            _memoryCache = {..._memoryCache, ...loaded};
            state = {...state, ...loaded};
          }
        }
      } catch (_) {}
    }());

    return _memoryCache;
  }

  /// Đánh dấu kênh đã được xem vào thời điểm hiện tại
  void markChannelAsRead(String channelId) {
    final now = DateTime.now();
    final updated = {
      ...state,
      channelId: now,
    };
    _memoryCache = updated;
    state = updated;

    // Lưu vào Storage và gọi Odoo Backend
    unawaited(() async {
      try {
        final mapToSave = <String, String>{};
        updated.forEach((k, v) => mapToSave[k] = v.toIso8601String());
        await _storage.write(key: _storageKey, value: jsonEncode(mapToSave));
        await ref.read(chatV2RepositoryProvider).markAsRead(channelId);
      } catch (_) {}
    }());
  }

  /// Đánh dấu kênh có tin nhắn mới (chuyển sang trạng thái chưa đọc)
  void markChannelAsUnread(String channelId) {
    if (state.containsKey(channelId)) {
      final updated = Map<String, DateTime>.from(state)..remove(channelId);
      _memoryCache = updated;
      state = updated;

      unawaited(() async {
        try {
          final mapToSave = <String, String>{};
          updated.forEach((k, v) => mapToSave[k] = v.toIso8601String());
          await _storage.write(key: _storageKey, value: jsonEncode(mapToSave));
        } catch (_) {}
      }());
    }
  }

  /// Kiểm tra xem kênh có tin nhắn chưa đọc hay không
  bool isChannelUnread({
    required String channelId,
    required int serverUnreadCount,
    required DateTime? lastMessageDate,
  }) {
    if (serverUnreadCount > 0) return true;
    if (lastMessageDate == null) return false;

    final lastSeen = state[channelId] ?? _memoryCache[channelId];
    if (lastSeen == null) {
      // Chưa từng bấm vào xem trong phiên làm việc này
      return true;
    }

    // So sánh thời gian UTC epoch để tránh lệch timezone
    return lastMessageDate.toUtc().millisecondsSinceEpoch >
        lastSeen.toUtc().millisecondsSinceEpoch;
  }
}

/// Quản lý tin nhắn cuối do chính mình gửi đi trong phiên làm việc
final chatV2LastSentTrackerProvider =
    NotifierProvider<ChatV2LastSentTrackerNotifier, Map<String, String>>(
  ChatV2LastSentTrackerNotifier.new,
);

class ChatV2LastSentTrackerNotifier extends Notifier<Map<String, String>> {
  @override
  Map<String, String> build() => {};

  void recordSent(String channelId, String messageText) {
    state = {
      ...state,
      channelId: messageText,
    };
  }

  void clear(String channelId) {
    if (state.containsKey(channelId)) {
      final copy = Map<String, String>.from(state)..remove(channelId);
      state = copy;
    }
  }
}
