import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/odoo_api_client.dart';

/// Background isolate function to parse Odoo channel list and extract
/// per-channel unread counts without blocking the main UI thread.
Map<int, int> _parseChannelUnreadCounts(String rawJson) {
  try {
    final decoded = jsonDecode(rawJson);
    if (decoded is! List) return const <int, int>{};
    final map = <int, int>{};
    for (final item in decoded) {
      if (item is Map) {
        final rawId = item['id'];
        final rawUnread = item['unread_count'];
        final parsedId =
            rawId is num ? rawId.toInt() : int.tryParse(rawId?.toString() ?? '');
        final parsedUnread = rawUnread is num
            ? rawUnread.toInt()
            : int.tryParse(rawUnread?.toString() ?? '') ?? 0;
        if (parsedId != null) {
          map[parsedId] = parsedUnread < 0 ? 0 : parsedUnread;
        }
      }
    }
    return map;
  } catch (e, stackTrace) {
    if (kDebugMode) {
      print('❌ [_parseChannelUnreadCounts] Parsing error: $e');
      print(stackTrace);
    }
    rethrow;
  }
}

/// Immutable state holding total and per-channel unread message metrics.
@immutable
class UnreadChatState {
  const UnreadChatState({
    this.totalUnreadCount = 0,
    this.channelUnreadCounts = const <int, int>{},
    this.isLoading = false,
    this.errorMessage,
  });

  final int totalUnreadCount;
  final Map<int, int> channelUnreadCounts;
  final bool isLoading;
  final String? errorMessage;

  UnreadChatState copyWith({
    int? totalUnreadCount,
    Map<int, int>? channelUnreadCounts,
    bool? isLoading,
    String? errorMessage,
  }) {
    return UnreadChatState(
      totalUnreadCount: totalUnreadCount ?? this.totalUnreadCount,
      channelUnreadCounts: channelUnreadCounts ?? this.channelUnreadCounts,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

/// StateNotifier class responsible for managing chat unread state and
/// syncing read status with Odoo Backend (/api/v1/mobile/chat/*).
class UnreadChatNotifier extends StateNotifier<UnreadChatState> {
  UnreadChatNotifier({OdooApiClient? client})
      : _client = client ?? odooApiClient,
        super(const UnreadChatState()) {
    loadUnreadCount();
    startRealtimeSync();
  }

  final OdooApiClient _client;
  Timer? _periodicTimer;
  int _consecutiveFailures = 0;
  bool _isRefreshing = false;

  /// Starts real-time periodic sync to refresh unread message counts dynamically.
  void startRealtimeSync([Duration cadence = const Duration(seconds: 2)]) {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(cadence, (_) {
      loadUnreadCount();
    });
  }

  @override
  void dispose() {
    _periodicTimer?.cancel();
    super.dispose();
  }

  /// Fetches channels list from Odoo API and computes total unread count.
  /// Implements retry & exponential backoff on socket connection resets.
  Future<void> loadUnreadCount() async {
    if (_isRefreshing) return;
    _isRefreshing = true;
    try {
      final res = await _client.get('/api/v1/mobile/chat/channels');
      final rawJson = jsonEncode(res);
      final channelCounts = await compute(_parseChannelUnreadCounts, rawJson);
      final total = channelCounts.values.fold(0, (sum, count) => sum + count);

      if (_consecutiveFailures > 0) {
        _consecutiveFailures = 0;
        startRealtimeSync(const Duration(seconds: 2));
      }

      state = state.copyWith(
        totalUnreadCount: total,
        channelUnreadCounts: channelCounts,
        isLoading: false,
        errorMessage: null,
      );
    } catch (e) {
      _consecutiveFailures++;
      if (kDebugMode && _consecutiveFailures <= 2) {
        debugPrint('⚠️ [UnreadChatNotifier] Sync attempt $_consecutiveFailures failed: $e');
      }
      // Dynamic fallback: backoff periodic sync cadence if backend connection resets
      if (_consecutiveFailures == 3) {
        startRealtimeSync(const Duration(seconds: 6));
      } else if (_consecutiveFailures >= 6) {
        startRealtimeSync(const Duration(seconds: 12));
      }
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    } finally {
      _isRefreshing = false;
    }
  }

  /// Optimistically marks channel [channelId] as read on the local UI state,
  /// then posts to Odoo `/api/v1/mobile/chat/channels/<id>/mark-read`.
  /// Reverts state if the network call fails.
  Future<void> markAsRead(int channelId) async {
    final previousCounts = Map<int, int>.from(state.channelUnreadCounts);
    final previousTotal = state.totalUnreadCount;

    // 1. Reactive optimistic UI update
    final updatedCounts = Map<int, int>.from(previousCounts);
    updatedCounts[channelId] = 0;
    final newTotal = updatedCounts.values.fold(0, (sum, count) => sum + count);

    state = state.copyWith(
      totalUnreadCount: newTotal,
      channelUnreadCounts: updatedCounts,
    );

    // 2. Call Odoo backend API
    try {
      await _client.post(
        '/api/v1/mobile/chat/channels/$channelId/mark-read',
      );
      await loadUnreadCount();
    } catch (e) {
      // Rollback on failure
      state = state.copyWith(
        totalUnreadCount: previousTotal,
        channelUnreadCounts: previousCounts,
        errorMessage: e.toString(),
      );
    }
  }
}

/// Main StateNotifierProvider for UnreadChatNotifier.
final unreadChatControllerProvider =
    StateNotifierProvider<UnreadChatNotifier, UnreadChatState>((ref) {
  return UnreadChatNotifier();
});

/// Convenience Provider to expose totalUnreadCount directly for badge displays.
final totalUnreadCountProvider = Provider<int>((ref) {
  return ref.watch(unreadChatControllerProvider).totalUnreadCount;
});
