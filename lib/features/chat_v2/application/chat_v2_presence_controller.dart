import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/chat_v2_realtime_service.dart';

/// Quản lý trạng thái online/offline của user (partnerId -> im_status)
final chatV2PresenceProvider = StateNotifierProvider<ChatV2PresenceNotifier, Map<String, String>>((ref) {
  return ChatV2PresenceNotifier(ref);
});

class ChatV2PresenceNotifier extends StateNotifier<Map<String, String>> {
  ChatV2PresenceNotifier(this.ref) : super({}) {
    _init();
  }

  final Ref ref;
  StreamSubscription? _sub;

  void _init() {
    final realtime = ref.read(chatV2RealtimeServiceProvider);
    _sub = realtime.onPresenceChanged.listen((payload) {
      final partnerId = payload['id']?.toString() ?? payload['partner_id']?.toString();
      final imStatus = payload['im_status']?.toString();

      if (partnerId != null && partnerId.isNotEmpty && imStatus != null) {
        state = {
          ...state,
          partnerId: imStatus,
        };
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
