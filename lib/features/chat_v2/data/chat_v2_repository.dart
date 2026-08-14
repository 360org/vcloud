import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/odoo_api_client.dart';
import 'models/chat_v2_channel.dart';
import 'models/chat_v2_message.dart';

final chatV2RepositoryProvider = Provider<ChatV2Repository>((ref) {
  return ChatV2Repository(odooApiClient);
});

class ChatV2Repository {
  const ChatV2Repository(this._client);

  final OdooApiClient _client;

  Future<List<ChatV2Channel>> getChannels() async {
    final dynamic data = await _client.get('/api/v1/mobile/chat/channels');

    final List<dynamic> list;
    if (data is List) {
      list = data;
    } else if (data is Map && data['channels'] is List) {
      list = data['channels'] as List;
    } else {
      list = const [];
    }

    return list
        .whereType<Map>()
        .map((e) => ChatV2Channel.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<ChatV2Message>> getMessages(
    String channelId, {
    String? currentPartnerId,
    String? currentUserId,
  }) async {
    final dynamic data = await _client.get('/api/v1/mobile/chat/channels/$channelId/messages');

    final List<dynamic> list;
    if (data is Map && data['messages'] is List) {
      list = data['messages'] as List;
    } else if (data is List) {
      list = data;
    } else {
      list = const [];
    }

    return list
        .whereType<Map>()
        .map((m) => ChatV2Message.fromMap(
              Map<String, dynamic>.from(m),
              currentPartnerId: currentPartnerId,
              currentUserId: currentUserId,
            ))
        .toList();
  }

  Future<ChatV2Message> sendMessage(
    String channelId,
    String body, {
    List<int>? attachmentIds,
    String? currentPartnerId,
    String? currentUserId,
    String authorName = 'Tôi',
  }) async {
    final payload = <String, dynamic>{
      'channel_id': int.tryParse(channelId) ?? channelId,
      'body': body,
    };
    if (attachmentIds != null && attachmentIds.isNotEmpty) {
      payload['attachment_ids'] = attachmentIds;
    }

    final dynamic data = await _client.post(
      '/api/v1/mobile/chat/messages',
      body: payload,
    );

    if (data is Map) {
      return ChatV2Message.fromMap(
        Map<String, dynamic>.from(data),
        currentPartnerId: currentPartnerId,
        currentUserId: currentUserId,
      );
    }

    return ChatV2Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      channelId: channelId,
      content: body,
      authorId: currentPartnerId,
      authorName: authorName,
      date: DateTime.now(),
      isMine: true,
      status: 'sent',
    );
  }

  Future<void> markAsRead(String channelId) async {
    try {
      await _client.post('/api/v1/mobile/chat/channels/$channelId/read');
    } catch (_) {
      // Bỏ qua lỗi đánh dấu đã đọc để không chặn UI
    }
  }
}
