import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/chat_v2_repository.dart';
import '../domain/models/chat_v2_inbox_item.dart';

enum ChatV2InboxTabType {
  inbox,
  starred,
  history,
}

class ChatV2InboxState {
  const ChatV2InboxState({
    this.inboxItems = const [],
    this.starredItems = const [],
    this.historyItems = const [],
    this.isLoading = false,
    this.error,
    this.activeTab = ChatV2InboxTabType.inbox,
    this.inboxTotal = 0,
  });

  final List<ChatV2InboxItem> inboxItems;
  final List<ChatV2InboxItem> starredItems;
  final List<ChatV2InboxItem> historyItems;
  final bool isLoading;
  final String? error;
  final ChatV2InboxTabType activeTab;
  final int inboxTotal;

  ChatV2InboxState copyWith({
    List<ChatV2InboxItem>? inboxItems,
    List<ChatV2InboxItem>? starredItems,
    List<ChatV2InboxItem>? historyItems,
    bool? isLoading,
    String? error,
    ChatV2InboxTabType? activeTab,
    int? inboxTotal,
  }) {
    return ChatV2InboxState(
      inboxItems: inboxItems ?? this.inboxItems,
      starredItems: starredItems ?? this.starredItems,
      historyItems: historyItems ?? this.historyItems,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      activeTab: activeTab ?? this.activeTab,
      inboxTotal: inboxTotal ?? this.inboxTotal,
    );
  }
}

final chatV2InboxControllerProvider =
    NotifierProvider<ChatV2InboxController, ChatV2InboxState>(
  ChatV2InboxController.new,
);

class ChatV2InboxController extends Notifier<ChatV2InboxState> {
  @override
  ChatV2InboxState build() {
    // Tự động load Inbox lần đầu
    Future.microtask(() => loadActiveTab());
    return const ChatV2InboxState(isLoading: true);
  }

  void switchTab(ChatV2InboxTabType tab) {
    if (state.activeTab == tab) return;
    state = state.copyWith(activeTab: tab);
    loadActiveTab();
  }

  Future<void> loadActiveTab({bool refresh = false}) async {
    switch (state.activeTab) {
      case ChatV2InboxTabType.inbox:
        await loadInbox(refresh: refresh);
        break;
      case ChatV2InboxTabType.starred:
        await loadStarred(refresh: refresh);
        break;
      case ChatV2InboxTabType.history:
        await loadHistory(refresh: refresh);
        break;
    }
  }

  Future<void> loadInbox({bool refresh = false}) async {
    if (state.inboxItems.isNotEmpty && !refresh) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final repo = ref.read(chatV2RepositoryProvider);
      final items = await repo.fetchInboxMessages(limit: 50);
      state = state.copyWith(
        inboxItems: items,
        inboxTotal: items.length,
        isLoading: false,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ChatV2InboxController] loadInbox error: $e');
      }
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> loadStarred({bool refresh = false}) async {
    if (state.starredItems.isNotEmpty && !refresh) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final repo = ref.read(chatV2RepositoryProvider);
      final items = await repo.fetchStarredMessages(limit: 50);
      state = state.copyWith(
        starredItems: items,
        isLoading: false,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ChatV2InboxController] loadStarred error: $e');
      }
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> loadHistory({bool refresh = false}) async {
    if (state.historyItems.isNotEmpty && !refresh) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final repo = ref.read(chatV2RepositoryProvider);
      final items = await repo.fetchHistoryMessages(limit: 50);
      state = state.copyWith(
        historyItems: items,
        isLoading: false,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ChatV2InboxController] loadHistory error: $e');
      }
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Toggle star (Optimistic update)
  Future<void> toggleStar(ChatV2InboxItem item) async {
    final newStarred = !item.isStarred;
    final updatedItem = item.copyWith(isStarred: newStarred);

    // Cập nhật optimistic trên cả 3 danh sách
    final updatedInbox = state.inboxItems.map((m) => m.id == item.id ? updatedItem : m).toList();
    final updatedStarred = List<ChatV2InboxItem>.from(state.starredItems);
    if (newStarred) {
      if (!updatedStarred.any((m) => m.id == item.id)) {
        updatedStarred.insert(0, updatedItem);
      }
    } else {
      updatedStarred.removeWhere((m) => m.id == item.id);
    }
    final updatedHistory = state.historyItems.map((m) => m.id == item.id ? updatedItem : m).toList();

    state = state.copyWith(
      inboxItems: updatedInbox,
      starredItems: updatedStarred,
      historyItems: updatedHistory,
    );

    try {
      final repo = ref.read(chatV2RepositoryProvider);
      await repo.toggleStarMessage(item.id, star: newStarred);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ChatV2InboxController] toggleStar rollback: $e');
      }
      // Rollback nếu gọi backend lỗi
      loadActiveTab(refresh: true);
    }
  }

  /// Đánh dấu tin nhắn đã xong (Mark Done -> Chuyển từ Inbox sang History)
  Future<void> markDone(ChatV2InboxItem item) async {
    final updatedInbox = state.inboxItems.where((m) => m.id != item.id).toList();
    final updatedHistory = [item.copyWith(isNeedaction: false), ...state.historyItems];
    final newTotal = (state.inboxTotal > 0) ? state.inboxTotal - 1 : updatedInbox.length;

    state = state.copyWith(
      inboxItems: updatedInbox,
      historyItems: updatedHistory,
      inboxTotal: newTotal,
    );

    try {
      final repo = ref.read(chatV2RepositoryProvider);
      await repo.markMessageDone(item.id);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ChatV2InboxController] markDone rollback: $e');
      }
      loadInbox(refresh: true);
    }
  }

  /// Đánh dấu tất cả tin nhắn trong Inbox đã xong (Mark All Done)
  Future<void> markAllDone() async {
    final previousInbox = state.inboxItems;
    final previousTotal = state.inboxTotal;

    state = state.copyWith(
      inboxItems: const [],
      inboxTotal: 0,
      historyItems: [...previousInbox, ...state.historyItems],
    );

    try {
      final repo = ref.read(chatV2RepositoryProvider);
      await repo.markAllInboxDone();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[ChatV2InboxController] markAllDone rollback: $e');
      }
      state = state.copyWith(
        inboxItems: previousInbox,
        inboxTotal: previousTotal,
      );
    }
  }
}
