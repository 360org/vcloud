import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/chat_v2_repository.dart';

/// Quản lý trạng thái đã đọc / chưa đọc của từng cuộc trò chuyện
final chatV2ReadStateProvider =
    NotifierProvider<ChatV2ReadStateNotifier, Map<String, DateTime>>(
  ChatV2ReadStateNotifier.new,
);

class ChatV2ReadStateNotifier extends Notifier<Map<String, DateTime>> {
  static final Map<String, DateTime> _memoryCache = {};

  @override
  Map<String, DateTime> build() {
    return _memoryCache;
  }

  /// Đánh dấu kênh đã được xem vào thời điểm hiện tại
  void markChannelAsRead(String channelId) {
    final now = DateTime.now();
    final updated = {
      ...state,
      channelId: now,
    };
    _memoryCache[channelId] = now;
    state = updated;

    // Đồng bộ lên Odoo Backend (background)
    unawaited(() async {
      try {
        await ref.read(chatV2RepositoryProvider).markAsRead(channelId);
      } catch (_) {}
    }());
  }

  /// Đánh dấu kênh có tin nhắn mới (chuyển sang trạng thái chưa đọc)
  void markChannelAsUnread(String channelId) {
    if (state.containsKey(channelId)) {
      final updated = Map<String, DateTime>.from(state)..remove(channelId);
      _memoryCache.remove(channelId);
      state = updated;
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
      return false;
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
