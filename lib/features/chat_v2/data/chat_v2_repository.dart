import 'dart:convert';
import 'dart:typed_data';

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

  String resolveUrl(String path, {String? accessToken}) =>
      _client.authenticatedUrl(path, accessToken: accessToken);

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

    final channels = list
        .whereType<Map>()
        .map((e) => ChatV2Channel.fromMap(Map<String, dynamic>.from(e)))
        .toList();

    // Sắp xếp kênh có tin nhắn mới nhất / hoạt động gần nhất lên đầu
    channels.sort((a, b) {
      if (a.lastMessageDate == null && b.lastMessageDate == null) {
        final aId = int.tryParse(a.id) ?? 0;
        final bId = int.tryParse(b.id) ?? 0;
        return bId.compareTo(aId);
      }
      if (a.lastMessageDate == null) return 1;
      if (b.lastMessageDate == null) return -1;
      return b.lastMessageDate!.compareTo(a.lastMessageDate!);
    });

    return channels;
  }

  Future<List<ChatV2Message>> getMessages(
    String channelId, {
    String? currentPartnerId,
    String? currentUserId,
    int limit = 35,
    String? beforeId,
  }) async {
    dynamic data;
    final queryParams = <String, dynamic>{'limit': limit.toString()};
    if (beforeId != null && beforeId.isNotEmpty) {
      queryParams['before_id'] = beforeId;
    }

    try {
      data = await _client.get(
        '/api/v1/mobile/chat/channels/$channelId/messages',
        query: queryParams,
      );
    } catch (_) {
      // Retry 1 lần nếu gặp lỗi mạng tạm thời
      data = await _client.get(
        '/api/v1/mobile/chat/channels/$channelId/messages',
        query: queryParams,
      );
    }

    final List<dynamic> list;
    if (data is Map && data['messages'] is List) {
      list = data['messages'] as List;
    } else if (data is List) {
      list = data;
    } else {
      list = const [];
    }

    final List<ChatV2Message> messages = list
        .whereType<Map>()
        .map((m) => ChatV2Message.fromMap(
              Map<String, dynamic>.from(m),
              currentPartnerId: currentPartnerId,
              currentUserId: currentUserId,
            ))
        .toList();

    // Tự động quét và nạp attachments cho các tin nhắn gửi ảnh từ Web Odoo (body rỗng)
    final emptyMsgIds = messages
        .where((m) => m.content.isEmpty && m.attachments.isEmpty)
        .map((m) => int.tryParse(m.id))
        .whereType<int>()
        .toList();

    if (emptyMsgIds.isNotEmpty) {
      try {
        final dynamic readRes = await _client.post(
          '/web/dataset/call_kw/mail.message/read',
          body: {
            'jsonrpc': '2.0',
            'method': 'call',
            'params': {
              'model': 'mail.message',
              'method': 'read',
              'args': [emptyMsgIds, ['id', 'attachment_ids']],
              'kwargs': {},
            },
          },
          auth: true,
        );

        final rawResult = readRes is Map ? readRes['result'] : null;
        if (rawResult is List) {
          final attMap = <String, List<int>>{};
          final allAttIds = <int>[];
          for (final item in rawResult) {
            if (item is Map && item['attachment_ids'] is List) {
              final mId = item['id'].toString();
              final aIds = (item['attachment_ids'] as List)
                  .map((a) => a is int ? a : int.tryParse(a.toString()))
                  .whereType<int>()
                  .toList();
              if (aIds.isNotEmpty) {
                attMap[mId] = aIds;
                allAttIds.addAll(aIds);
              }
            }
          }

          if (allAttIds.isNotEmpty) {
            final dynamic attDetailsRes = await _client.post(
              '/web/dataset/call_kw/ir.attachment/read',
              body: {
                'jsonrpc': '2.0',
                'method': 'call',
                'params': {
                  'model': 'ir.attachment',
                  'method': 'read',
                  'args': [allAttIds, ['id', 'name', 'mimetype', 'file_size']],
                  'kwargs': {},
                },
              },
              auth: true,
            );

            final attDetailsList = attDetailsRes is Map ? attDetailsRes['result'] : null;
            final attachmentObjects = <int, ChatV2Attachment>{};
            if (attDetailsList is List) {
              for (final attItem in attDetailsList) {
                if (attItem is Map && attItem['id'] != null) {
                  final aid = attItem['id'] as int;
                  final aName = (attItem['name'] ?? 'image.png').toString();
                  final aMime = attItem['mimetype']?.toString();
                  final aSize = attItem['file_size'] is int ? attItem['file_size'] as int : null;
                  attachmentObjects[aid] = ChatV2Attachment(
                    id: aid.toString(),
                    name: aName,
                    mimetype: aMime,
                    fileSize: aSize,
                    url: '/web/image/$aid',
                    downloadUrl: '/web/content/$aid/$aName',
                  );
                }
              }
            }

            for (int i = 0; i < messages.length; i++) {
              final msg = messages[i];
              if (attMap.containsKey(msg.id)) {
                final targetAttIds = attMap[msg.id]!;
                final attachedList = targetAttIds
                    .map((aid) => attachmentObjects[aid] ?? ChatV2Attachment(
                          id: aid.toString(),
                          name: 'image.png',
                          url: '/web/image/$aid',
                          mimetype: 'image/png',
                        ))
                    .toList();
                messages[i] = msg.copyWith(attachments: attachedList);
              }
            }
          }
        }
      } catch (_) {}
    }

    return messages;
  }

  Future<ChatV2Attachment> uploadAttachment({
    required String filename,
    required Uint8List bytes,
    String? mimetype,
  }) async {
    final base64Str = base64Encode(bytes);
    final payload = <String, dynamic>{
      'filename': filename,
      'base64': base64Str,
      if (mimetype != null && mimetype.isNotEmpty) 'mimetype': mimetype,
    };

    final dynamic data = await _client.post(
      '/api/v1/mobile/attachments/upload',
      body: payload,
    );

    if (data is Map) {
      return ChatV2Attachment.fromMap(Map<String, dynamic>.from(data));
    }
    throw Exception('Phản hồi upload ảnh không hợp lệ từ máy chủ Odoo.');
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
      createdAt: DateTime.now(),
      isMine: true,
      status: 'sent',
    );
  }

  Future<void> markAsRead(String channelId) async {
    try {
      await _client.post('/api/v1/mobile/chat/channels/$channelId/mark-read');
    } catch (_) {
      try {
        await _client.post('/api/v1/mobile/chat/channels/$channelId/seen');
      } catch (_) {}
    }
  }

  Future<void> editMessage(String messageId, String newBody) async {
    await _client.post(
      '/api/v1/mobile/chat/messages/$messageId/edit',
      body: {'body': newBody},
    );
  }

  Future<void> deleteMessage(String messageId) async {
    await _client.post(
      '/api/v1/mobile/chat/messages/$messageId/delete',
      body: {},
    );
  }
}
