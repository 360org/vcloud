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
    final lastSeen = state[channelId] ?? _memoryCache[channelId];

    // 1. Ưu tiên Local State: Nếu đã click xem trong phiên làm việc này
    if (lastSeen != null && lastMessageDate != null) {
      // Chỉ tính là chưa đọc nếu có tin nhắn gửi ĐẾN SAU thời điểm mình vừa xem
      if (lastMessageDate.toUtc().millisecondsSinceEpoch >
          lastSeen.toUtc().millisecondsSinceEpoch) {
        return true;
      }
      // Nếu tin nhắn cuối đã cũ hơn hoặc bằng thời điểm mình xem -> Chắc chắn ĐÃ ĐỌC
      // (Bỏ qua serverUnreadCount vì server có thể gửi về số cũ do polling chậm)
      return false;
    }

    // 2. Nếu chưa từng click xem trong phiên này, tin cậy hoàn toàn vào Server
    if (serverUnreadCount > 0) return true;

    return false;
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
