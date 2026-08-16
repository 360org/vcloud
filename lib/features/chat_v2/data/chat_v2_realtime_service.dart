import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/odoo_api_client.dart';
import '../../auth/application/auth_controller.dart';
import 'models/chat_v2_message.dart';

/// Provider quản lý Realtime Event Hub & Action Bus của Chat V2
final chatV2RealtimeServiceProvider = Provider<ChatV2RealtimeService>((ref) {
  final user = ref.watch(authControllerProvider).valueOrNull;

  final meta = user?.userMetadata;
  final partnerId = meta?['partner_id']?.toString() ??
      (meta?['partner'] is Map ? meta!['partner']['id']?.toString() : null);

  final service = ChatV2RealtimeService(
    baseUrl: odooApiClient.absoluteUrl(''),
    partnerId: partnerId,
    sessionToken: odooApiClient.session?.accessToken,
  );

  ref.onDispose(() {
    service.dispose();
  });

  return service;
});

/// Service quản lý Event Hub nội bộ và REST API actions của Chat V2
/// (Hoạt động hoàn toàn thuần HTTP REST + In-memory Event Bus để tối ưu 100% cho Mobile)
class ChatV2RealtimeService {
  ChatV2RealtimeService({
    required this.baseUrl,
    this.partnerId,
    this.sessionToken,
  });

  final String baseUrl;
  final String? partnerId;
  final String? sessionToken;

  final _messageStreamController = StreamController<ChatV2Message>.broadcast();
  final _channelUpdateController = StreamController<String>.broadcast();
  final _typingStreamController = StreamController<Map<String, dynamic>>.broadcast();
  final _presenceStreamController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<ChatV2Message> get onMessageReceived => _messageStreamController.stream;
  Stream<String> get onChannelUpdated => _channelUpdateController.stream;
  Stream<Map<String, dynamic>> get onTypingStatusChanged => _typingStreamController.stream;
  Stream<Map<String, dynamic>> get onPresenceChanged => _presenceStreamController.stream;
  bool get isConnected => false;

  /// Gửi trạng thái typing qua REST API
  Future<void> sendTypingStatus(String channelId, bool isTyping) async {
    try {
      await odooApiClient.post(
        '/api/v1/mobile/chat/channels/$channelId/typing',
        body: {'is_typing': isTyping},
      );
    } catch (_) {}
  }

  /// Thông báo nội bộ khi có tin nhắn gửi thành công (Optimistic UI update)
  void notifyMessageSent(String channelId, ChatV2Message msg) {
    _messageStreamController.add(msg);
    _channelUpdateController.add(channelId);
  }

  void dispose() {
    _messageStreamController.close();
    _channelUpdateController.close();
    _typingStreamController.close();
    _presenceStreamController.close();
  }
}
