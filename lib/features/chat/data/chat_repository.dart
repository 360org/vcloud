import 'dart:async';

import '../../../core/api/odoo_api_client.dart';
import '../../../core/error/failure.dart';
import '../../../shared/models/conversation.dart';
import '../../../shared/models/message.dart';
import '../../../shared/models/profile.dart';

class ChatRepository {
  ChatRepository({OdooApiClient? client}) : _client = client ?? odooApiClient;

  final OdooApiClient _client;

  Stream<List<ConversationSummary>> watchConversations() {
    final controller = StreamController<List<ConversationSummary>>();

    Future<void> refresh() async {
      try {
        final res = await _client.get('/api/v1/mobile/chat/channels');
        final fetchedAt = DateTime.now();
        final list = (res as List)
            .cast<Map<String, dynamic>>()
            .map(
              (channel) => ConversationSummary.fromOdooChatChannel(
                channel,
                fetchedAt: fetchedAt,
              ),
            )
            .toList();
        if (!controller.isClosed) controller.add(list);
      } catch (e) {
        if (!controller.isClosed) {
          controller.addError(Failure('Không tải được danh sách chat: $e'));
        }
      }
    }

    controller.onListen = refresh;
    return controller.stream;
  }

  Stream<List<Message>> watchMessages(String conversationId) {
    final controller = StreamController<List<Message>>();

    Future<void> refresh() async {
      try {
        final res = await _client.get(
          '/api/v1/mobile/chat/channels/$conversationId/messages',
        );
        final data = Map<String, dynamic>.from(res as Map);
        final msgs =
            (data['messages'] as List? ?? const <dynamic>[])
                .cast<Map<String, dynamic>>()
                .map(
                  (message) => Message.fromOdooMessageInfo(
                    conversationId: conversationId,
                    map: message,
                  ),
                )
                .toList()
              ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
        if (!controller.isClosed) controller.add(msgs);
      } catch (e) {
        if (!controller.isClosed) {
          controller.addError(Failure('Không tải được tin nhắn: $e'));
        }
      }
    }

    controller.onListen = refresh;
    return controller.stream;
  }

  Future<Message> sendMessage(String conversationId, String content) async {
    final res = await _client.post(
      '/api/v1/mobile/chat/messages',
      body: <String, dynamic>{
        'channel_id': int.tryParse(conversationId),
        'body': content,
      },
    );
    final map = _messageMap(res);
    return Message.fromOdooMessageInfo(
      conversationId: conversationId,
      map: map,
    );
  }

  Future<void> markAsRead(String conversationId) async {
    await _client.post(
      '/api/v1/mobile/chat/channels/$conversationId/mark-read',
    );
  }

  Map<String, dynamic> _messageMap(Object? res) {
    if (res is! Map) {
      throw Failure('Phản hồi gửi tin nhắn không hợp lệ.');
    }
    final map = Map<String, dynamic>.from(res);
    final nested = map['message'] ?? map['data'] ?? map['result'];
    if (nested is Map) return Map<String, dynamic>.from(nested);
    return map;
  }

  Future<String> openDirect(String otherUserId) async {
    final res = await _client.post(
      '/api/v1/mobile/chat/direct',
      body: <String, dynamic>{'user_id': int.tryParse(otherUserId)},
    );
    return _channelId(res);
  }

  Future<String> createGroup(String name, List<String> memberIds) async {
    final res = await _client.post(
      '/api/v1/mobile/chat/groups',
      body: <String, dynamic>{
        'name': name,
        'member_ids': memberIds.map(int.tryParse).whereType<int>().toList(),
      },
    );
    return _channelId(res);
  }

  Future<List<Profile>> allUsers() async {
    final res = await _client.get(
      '/api/v1/res.users',
      query: const <String, Object?>{'fields': 'id,login,name,image_128'},
    );
    return (res as List).cast<Map<String, dynamic>>().map((m) {
      final login = (m['login'] ?? '').toString();
      return Profile(
        id: m['id'].toString(),
        email: login,
        displayName: (m['name'] ?? login).toString(),
        avatarUrl:
            _stringOrNull(m['image_128']) ??
            _client.absoluteUrl('/api/v1/mobile/avatar/users/${m['id']}'),
      );
    }).toList();
  }

  Future<Conversation> conversationDetails(String id) async {
    final res = await _client.get(
      '/api/v1/discuss.channel/$id',
      query: const <String, Object?>{
        'fields':
            'id,name,channel_type,create_uid,create_date,channel_member_ids',
      },
    );
    final map = Map<String, dynamic>.from(res as Map);
    final createdAt = _dateTimeOrNow(map['create_date']);
    return Conversation(
      id: map['id'].toString(),
      isGroup: map['channel_type'] != 'chat',
      name: map['name'] as String?,
      createdBy: map['create_uid']?.toString() ?? '',
      createdAt: createdAt,
      members: _conversationMembers(map, createdAt),
    );
  }

  Future<void> archiveConversation(String conversationId) async {
    await _client.post('/api/v1/mobile/chat/channels/$conversationId/archive');
  }

  Future<void> unarchiveConversation(String conversationId) async {
    await _client.post(
      '/api/v1/mobile/chat/channels/$conversationId/unarchive',
    );
  }

  String _channelId(Object? res) {
    if (res is! Map) {
      throw Failure('Phản hồi tạo chat không hợp lệ.');
    }
    final map = Map<String, dynamic>.from(res);
    final nested = map['channel'] ?? map['data'] ?? map['result'];
    if (nested is Map) return _channelId(nested);
    final id = map['id'] ?? map['channel_id'];
    if (id == null) {
      throw Failure('Phản hồi tạo chat thiếu channel id.');
    }
    return id.toString();
  }

  DateTime _dateTimeOrNow(Object? value) {
    if (value == null) return DateTime.now();
    return DateTime.tryParse(value.toString()) ?? DateTime.now();
  }

  List<ConversationMember> _conversationMembers(
    Map<String, dynamic> map,
    DateTime fallbackJoinedAt,
  ) {
    final rawMembers =
        map['members'] ??
        map['channel_member_ids'] ??
        map['member_ids'] ??
        map['partner_ids'];
    if (rawMembers is! List) return const <ConversationMember>[];

    return rawMembers
        .map((member) => _conversationMember(member, fallbackJoinedAt))
        .whereType<ConversationMember>()
        .toList();
  }

  ConversationMember? _conversationMember(
    Object? rawMember,
    DateTime fallbackJoinedAt,
  ) {
    if (rawMember is List) {
      final id = _recordId(rawMember);
      if (id == null) return null;
      final name = _recordName(rawMember) ?? '';
      return ConversationMember(
        profile: Profile(
          id: id,
          email: '',
          displayName: name,
          avatarUrl: _client.absoluteUrl('/api/v1/mobile/avatar/partners/$id'),
        ),
        joinedAt: fallbackJoinedAt,
      );
    }
    if (rawMember is! Map) return null;

    final member = Map<String, dynamic>.from(rawMember);
    final profileSource =
        member['partner_id'] ??
        member['partner'] ??
        member['user_id'] ??
        member['user'] ??
        member['profile'];
    final id =
        _recordId(profileSource) ??
        _stringOrNull(member['partner_id']) ??
        _stringOrNull(member['user_id']) ??
        _stringOrNull(member['id']);
    if (id == null) return null;

    final name =
        _stringOrNull(member['display_name']) ??
        _stringOrNull(member['name']) ??
        _recordName(profileSource) ??
        _stringOrNull(member['email']) ??
        _stringOrNull(member['login']) ??
        '';
    final avatar =
        _stringOrNull(
          member['avatar_url'] ??
              member['avatar_128'] ??
              member['image_128'] ??
              member['image'],
        ) ??
        _client.absoluteUrl('/api/v1/mobile/avatar/partners/$id');

    return ConversationMember(
      profile: Profile(
        id: id,
        email:
            _stringOrNull(member['email']) ??
            _stringOrNull(member['login']) ??
            '',
        displayName: name,
        avatarUrl: avatar,
      ),
      joinedAt: _dateTimeOrNow(member['create_date'] ?? member['joined_at']),
    );
  }

  String? _recordId(Object? value) {
    if (value == null || value == false) return null;
    if (value is List && value.isNotEmpty) return value.first.toString();
    if (value is Map && value['id'] != null) return value['id'].toString();
    final text = value.toString();
    return text.isEmpty ? null : text;
  }

  String? _recordName(Object? value) {
    if (value is List && value.length > 1) return _stringOrNull(value[1]);
    if (value is Map) {
      return _stringOrNull(value['name'] ?? value['display_name']);
    }
    return null;
  }

  String? _stringOrNull(Object? value) {
    if (value == null || value == false) return null;
    final text = value.toString();
    return text.isEmpty ? null : text;
  }
}
