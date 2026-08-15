import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/chat_v2_realtime_service.dart';

/// Lưu danh sách partner_name đang gõ trong một channel
final chatV2TypingProvider = StateNotifierProvider.family<ChatV2TypingNotifier, List<String>, String>((ref, channelId) {
  return ChatV2TypingNotifier(ref, channelId);
});

class ChatV2TypingNotifier extends StateNotifier<List<String>> {
  ChatV2TypingNotifier(this.ref, this.channelId) : super([]) {
    _init();
  }

  final Ref ref;
  final String channelId;
  StreamSubscription? _sub;
  final Map<String, Timer> _typingTimers = {};

  void _init() {
    final realtime = ref.read(chatV2RealtimeServiceProvider);
    _sub = realtime.onTypingStatusChanged.listen((payload) {
      final cid = payload['channel_id']?.toString() ?? payload['id']?.toString();
      if (cid != channelId) return;

      final partnerName = payload['partner_name']?.toString() ?? 'Ai đó';
      final isTyping = payload['is_typing'] == true;
      final partnerId = payload['partner_id']?.toString() ?? partnerName;

      if (isTyping) {
        if (!state.contains(partnerName)) {
          state = [...state, partnerName];
        }
        // Auto clear sau 10s nếu không nhận được event mới
        _typingTimers[partnerId]?.cancel();
        _typingTimers[partnerId] = Timer(const Duration(seconds: 10), () {
          _removeTyping(partnerName);
        });
      } else {
        _typingTimers[partnerId]?.cancel();
        _removeTyping(partnerName);
      }
    });
  }

  void _removeTyping(String name) {
    if (state.contains(name)) {
      state = state.where((n) => n != name).toList();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    for (final t in _typingTimers.values) {
      t.cancel();
    }
    super.dispose();
  }
}
