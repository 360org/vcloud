import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/odoo_api_client.dart';
import 'models/chat_v2_channel.dart';
import 'models/chat_v2_message.dart';

final chatV2RepositoryProvider = Provider<ChatV2Repository>((ref) {
  return ChatV2Repository(odooApiClient);
});

class ChatV2Repository {
  ChatV2Repository(this._client);

  final OdooApiClient _client;

  static final Set<String> _resolvedAttachmentMsgIds = <String>{};
  static final Map<String, List<ChatV2Attachment>> _cachedAttachmentsByMsgId = <String, List<ChatV2Attachment>>{};

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
      final da = a.lastMessageDate ?? DateTime.fromMillisecondsSinceEpoch(0);
      final db = b.lastMessageDate ?? DateTime.fromMillisecondsSinceEpoch(0);
      return db.compareTo(da);
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
        .map((m) {
          var msg = ChatV2Message.fromMap(
            Map<String, dynamic>.from(m),
            currentPartnerId: currentPartnerId,
            currentUserId: currentUserId,
          );

          // Nạp thông tin trích dẫn Reply từ bộ đệm Reply Cache nếu backend chưa có
          final replyInfo = ChatV2ReplyCache.get(msg.id);
          if (replyInfo != null) {
            msg = msg.copyWith(
              parentId: msg.parentId ?? replyInfo['parent_id'],
              parentBody: msg.parentBody ?? replyInfo['parent_body'],
              parentAuthorName: msg.parentAuthorName ?? replyInfo['parent_author_name'],
            );
          }

          if (msg.attachments.isEmpty && _cachedAttachmentsByMsgId.containsKey(msg.id)) {
            return msg.copyWith(attachments: _cachedAttachmentsByMsgId[msg.id]!);
          }
          return msg;
        })
        .toList();

    // Tự động phân giải thông tin tin nhắn trả lời (Reply Parent) nếu thiếu metadata từ backend
    final msgMap = {for (final m in messages) m.id: m};
    for (int i = 0; i < messages.length; i++) {
      final msg = messages[i];
      if (msg.parentId != null && (msg.parentBody == null || msg.parentAuthorName == null)) {
        final parent = msgMap[msg.parentId];
        if (parent != null) {
          final parentContent = parent.content.isNotEmpty
              ? parent.content
              : (parent.attachments.isNotEmpty ? parent.attachments.first.name : 'Đính kèm');
          messages[i] = msg.copyWith(
            parentBody: msg.parentBody ?? parentContent,
            parentAuthorName: msg.parentAuthorName ?? parent.authorName,
          );
        }
      }
    }

    // Tự động quét và nạp attachments cho các tin nhắn gửi ảnh/tệp từ Web Odoo hoặc app
    // Bỏ qua các tin nhắn đã được phân giải attachment trước đó để tránh vòng lặp RPC
    final emptyMsgIds = messages
        .where((m) =>
            (m.content.isEmpty || m.isImageFilename || m.isDocumentFilename) &&
            m.attachments.isEmpty &&
            !_resolvedAttachmentMsgIds.contains(m.id))
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
                  final aName = (attItem['name'] ?? 'file').toString();
                  final aMime = attItem['mimetype']?.toString();
                  final aSize = attItem['file_size'] is int ? attItem['file_size'] as int : null;
                  final isImg = aMime?.startsWith('image/') == true ||
                      aName.endsWith('.png') ||
                      aName.endsWith('.jpg') ||
                      aName.endsWith('.jpeg') ||
                      aName.endsWith('.webp') ||
                      aName.endsWith('.gif');
                  attachmentObjects[aid] = ChatV2Attachment(
                    id: aid.toString(),
                    name: aName,
                    mimetype: aMime,
                    fileSize: aSize,
                    url: isImg ? '/web/image/$aid' : '/web/content/$aid/$aName',
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
                          name: msg.isDocumentFilename ? msg.content : 'file',
                          url: '/web/content/$aid',
                          downloadUrl: '/web/content/$aid',
                          mimetype: 'application/octet-stream',
                        ))
                    .toList();
                messages[i] = msg.copyWith(attachments: attachedList);
                _cachedAttachmentsByMsgId[msg.id] = attachedList;
              }
            }
          }
        }
        _resolvedAttachmentMsgIds.addAll(emptyMsgIds.map((e) => e.toString()));
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
    String? parentId,
    String? parentBody,
    String? parentAuthorName,
  }) async {
    String payloadBody = body;
    if (parentId != null && parentId.isNotEmpty) {
      final safeAuthor = (parentAuthorName != null && parentAuthorName.isNotEmpty)
          ? parentAuthorName
          : 'Tin nhắn';
      final safeBody = (parentBody != null && parentBody.isNotEmpty)
          ? parentBody
          : '...';
      // Đóng gói blockquote chuẩn Odoo discuss để lưu trực tiếp vào database Odoo
      // Cả máy gửi, máy nhận và Odoo web đều xem được 100% vĩnh viễn
      final quoteHtml = '<blockquote data-reply-id="$parentId" data-reply-author="$safeAuthor" data-reply-body="$safeBody">'
          '<small><strong>$safeAuthor:</strong> $safeBody</small>'
          '</blockquote>';
      payloadBody = '$quoteHtml$body';
    }

    final payload = <String, dynamic>{
      'channel_id': int.tryParse(channelId) ?? channelId,
      'body': payloadBody,
    };
    if (attachmentIds != null && attachmentIds.isNotEmpty) {
      payload['attachment_ids'] = attachmentIds;
    }
    if (parentId != null && parentId.isNotEmpty) {
      payload['parent_id'] = int.tryParse(parentId) ?? parentId;
    }

    final dynamic data = await _client.post(
      '/api/v1/mobile/chat/messages',
      body: payload,
    );

    if (data is Map) {
      final parsed = ChatV2Message.fromMap(
        Map<String, dynamic>.from(data),
        currentPartnerId: currentPartnerId,
        currentUserId: currentUserId,
      );
      // Bảo tồn thông tin trích dẫn từ local nếu backend chưa trả về
      // (backend cũ hoặc chưa deploy endpoint mới)
      if (parentId != null && parsed.parentId == null) {
        return parsed.copyWith(
          parentId: parentId,
          parentBody: parsed.parentBody ?? parentBody,
          parentAuthorName: parsed.parentAuthorName ?? parentAuthorName,
        );
      }
      return parsed;
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
      parentId: parentId,
      parentBody: parentBody,
      parentAuthorName: parentAuthorName,
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
    final msgIdInt = int.tryParse(messageId);
    try {
      await _client.post(
        '/api/v1/mobile/chat/messages/$messageId/edit',
        body: {'body': newBody},
      );
    } catch (e) {
      // Fallback 1: Odoo ORM JSON-RPC call_kw mail.message/write
      if (msgIdInt != null) {
        try {
          await _client.post(
            '/web/dataset/call_kw/mail.message/write',
            body: {
              'jsonrpc': '2.0',
              'method': 'call',
              'params': {
                'model': 'mail.message',
                'method': 'write',
                'args': [[msgIdInt], {'body': newBody}],
                'kwargs': {},
              },
            },
            auth: true,
          );
          return;
        } catch (_) {}
      }
      rethrow;
    }
  }

  Future<void> deleteMessage(String messageId) async {
    final msgIdInt = int.tryParse(messageId);
    try {
      await _client.post(
        '/api/v1/mobile/chat/messages/$messageId/delete',
        body: {},
      );
    } catch (e) {
      // Fallback 1: Odoo ORM JSON-RPC call_kw mail.message/unlink
      if (msgIdInt != null) {
        try {
          await _client.post(
            '/web/dataset/call_kw/mail.message/unlink',
            body: {
              'jsonrpc': '2.0',
              'method': 'call',
              'params': {
                'model': 'mail.message',
                'method': 'unlink',
                'args': [[msgIdInt]],
                'kwargs': {},
              },
            },
            auth: true,
          );
          return;
        } catch (_) {
          // Fallback 2: Clear body to recall message if unlink is restricted
          try {
            await _client.post(
              '/web/dataset/call_kw/mail.message/write',
              body: {
                'jsonrpc': '2.0',
                'method': 'call',
                'params': {
                  'model': 'mail.message',
                  'method': 'write',
                  'args': [[msgIdInt], {'body': '<i>Tin nhắn đã được thu hồi</i>'}],
                  'kwargs': {},
                },
              },
              auth: true,
            );
            return;
          } catch (_) {}
        }
      }
      rethrow;
    }
  }
}
