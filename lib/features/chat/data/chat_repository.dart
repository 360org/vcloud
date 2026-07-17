import 'dart:async';
import 'dart:typed_data';

import '../../../core/api/mobile_attachment_repository.dart';
import '../../../core/api/odoo_api_client.dart';
import '../../../core/error/failure.dart';
import '../../../core/notifications/realtime_constants.dart';
import '../../../shared/models/conversation.dart';
import '../../../shared/models/message.dart';
import '../../../shared/models/profile.dart';

class ChatRepository {
  ChatRepository({
    OdooApiClient? client,
    MobileAttachmentRepository? attachmentRepository,
  }) : _client = client ?? odooApiClient,
       _attachmentRepository =
           attachmentRepository ??
           MobileAttachmentRepository(client: client ?? odooApiClient);

  final OdooApiClient _client;
  final MobileAttachmentRepository _attachmentRepository;

  Stream<List<ConversationSummary>> watchConversations({
    Set<String> currentIdentityIds = const <String>{},
  }) {
    final controller = StreamController<List<ConversationSummary>>();
    bool inFlight = false;
    Timer? timer;

    Future<void> refresh() async {
      if (inFlight || controller.isClosed) return;
      inFlight = true;
      try {
        final res = await _client.get('/api/v1/mobile/chat/channels');
        final fetchedAt = DateTime.now();
        final summaries = (res as List)
            .cast<Map<String, dynamic>>()
            .map((channel) => _summaryFromChannel(channel, fetchedAt))
            .toList();
        final list = await Future.wait(
          summaries.map(
            (summary) => _withDirectAvatar(summary, currentIdentityIds),
          ),
        );
        if (!controller.isClosed) controller.add(list);
      } catch (e) {
        if (!controller.isClosed) {
          controller.addError(Failure('Không tải được danh sách chat: $e'));
        }
      } finally {
        inFlight = false;
      }
    }

    controller.onListen = () {
      refresh();
      timer = Timer.periodic(RealtimeIntervals.chatList, (_) => refresh());
    };
    controller.onCancel = () {
      timer?.cancel();
      timer = null;
    };
    return controller.stream;
  }

  Future<ConversationSummary> _withDirectAvatar(
    ConversationSummary summary,
    Set<String> currentIdentityIds,
  ) async {
    if (summary.isGroup) return summary;
    final directAvatar = await _directAvatarFromMessages(
      summary.id,
      currentIdentityIds,
    );
    if (directAvatar == null) return summary;
    return _copySummary(summary, avatarUrl: directAvatar);
  }

  Future<String?> _directAvatarFromMessages(
    String conversationId,
    Set<String> currentIdentityIds,
  ) async {
    try {
      final res = await _client.get(
        '/api/v1/mobile/chat/channels/$conversationId/messages',
      );
      if (res is! Map) return null;
      final messages = res['messages'];
      if (messages is! List) return null;
      final currentLabels = currentIdentityIds
          .map((value) => value.trim().toLowerCase())
          .where((value) => value.isNotEmpty)
          .toSet();
      for (final raw in messages.reversed) {
        if (raw is! Map) continue;
        final message = Map<String, dynamic>.from(raw);
        final authorId = _recordId(
          message['author_id'] ??
              message['author_partner_id'] ??
              message['partner_id'],
        );
        final authorName =
            _stringOrNull(message['author_name']) ??
            _recordName(message['author_id']);
        final authorLabels = <String?>{
          ?authorId,
          ?authorName,
        }.map((value) => value!.trim().toLowerCase()).toSet();
        final isCurrentAuthor =
            authorLabels.isNotEmpty && authorLabels.any(currentLabels.contains);
        if (isCurrentAuthor) continue;
        final avatar = _stringOrNull(message['author_avatar']);
        if (avatar != null) return avatar;
      }
    } catch (_) {
      // Direct avatar enrichment is best-effort; keep the channel avatar.
    }
    return null;
  }

  ConversationSummary _summaryFromChannel(
    Map<String, dynamic> channel,
    DateTime fetchedAt,
  ) {
    final summary = ConversationSummary.fromOdooChatChannel(
      channel,
      fetchedAt: fetchedAt,
    );
    if (summary.avatarUrl != null) return summary;
    return ConversationSummary(
      id: summary.id,
      isGroup: summary.isGroup,
      title: summary.title,
      lastMessage: summary.lastMessage,
      updatedAt: summary.updatedAt,
      unreadCount: summary.unreadCount,
      archivedAt: summary.archivedAt,
      avatarUrl: _client.absoluteUrl(
        '/api/v1/mobile/avatar/channels/${summary.id}',
      ),
      description: summary.description,
      isEditable: summary.isEditable,
      memberCount: summary.memberCount,
      lastSeenMessageId: summary.lastSeenMessageId,
      lastSeenDt: summary.lastSeenDt,
    );
  }

  ConversationSummary _copySummary(
    ConversationSummary summary, {
    String? avatarUrl,
  }) {
    return ConversationSummary(
      id: summary.id,
      isGroup: summary.isGroup,
      title: summary.title,
      lastMessage: summary.lastMessage,
      updatedAt: summary.updatedAt,
      unreadCount: summary.unreadCount,
      archivedAt: summary.archivedAt,
      avatarUrl: avatarUrl ?? summary.avatarUrl,
      description: summary.description,
      isEditable: summary.isEditable,
      memberCount: summary.memberCount,
      lastSeenMessageId: summary.lastSeenMessageId,
      lastSeenDt: summary.lastSeenDt,
    );
  }

  Stream<List<Message>> watchMessages(String conversationId) {
    final controller = StreamController<List<Message>>();
    bool inFlight = false;
    Timer? timer;

    Future<void> refresh() async {
      if (inFlight || controller.isClosed) return;
      inFlight = true;
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
      } finally {
        inFlight = false;
      }
    }

    controller.onListen = () {
      refresh();
      timer = Timer.periodic(RealtimeIntervals.chatDetail, (_) => refresh());
    };
    controller.onCancel = () {
      timer?.cancel();
      timer = null;
    };
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

  Future<MobileAttachment> uploadAttachment(
    String conversationId,
    MobileAttachmentUpload attachment,
  ) async {
    final uploaded = await _attachmentRepository.upload(
      MobileAttachmentUpload(
        filename: attachment.filename,
        bytes: attachment.bytes,
        mimetype: attachment.mimetype,
        resModel: 'discuss.channel',
        resId: int.tryParse(conversationId),
      ),
    );
    await _client.post(
      '/api/v1/mobile/chat/messages',
      body: <String, dynamic>{
        'channel_id': int.tryParse(conversationId),
        'body': attachment.filename,
        'attachment_ids': <int>[uploaded.attachmentId],
      },
    );
    return uploaded;
  }

  Future<String> attachmentDownloadUrl(String attachmentId) async {
    final id = int.tryParse(attachmentId);
    if (id == null) {
      throw Failure('Tệp đính kèm không hợp lệ.');
    }
    final attachment = await _attachmentRepository.one(id);
    final path =
        attachment.downloadUrl ??
        attachment.url ??
        '/web/content/${attachment.attachmentId}?download=1';
    return _client.absoluteUrl(path);
  }

  String attachmentContentUrl(String attachmentId, {String? url}) {
    final path = _previewPath(attachmentId, url);
    return _client.absoluteUrl(path);
  }

  String _previewPath(String attachmentId, String? url) {
    if (url == null || url.trim().isEmpty) {
      return '/web/content/$attachmentId';
    }
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return url;
    final params = Map<String, String>.from(uri.queryParameters)
      ..remove('download');
    if (uri.hasQuery) {
      return uri
          .replace(queryParameters: params.isEmpty ? null : params)
          .toString();
    }
    return url;
  }

  /// Raw bytes of an attachment, for download/forward.
  Future<Uint8List> attachmentBytes(String attachmentId) async {
    final id = int.tryParse(attachmentId);
    if (id == null) {
      throw Failure('Tệp đính kèm không hợp lệ.');
    }
    return _attachmentRepository.fetchBytes(id);
  }

  /// Re-sends an existing attachment into another conversation. Downloads the
  /// bytes once, then re-uploads + sends via [uploadAttachment], which posts
  /// the message with `attachment_ids` — no duplicate send logic.
  Future<void> forwardAttachment(
    String targetConversationId,
    String attachmentId,
  ) async {
    final id = int.tryParse(attachmentId);
    if (id == null) {
      throw Failure('Tệp đính kèm không hợp lệ.');
    }
    final bytes = await _attachmentRepository.fetchBytes(id);
    final meta = await _attachmentRepository.one(id);
    await uploadAttachment(
      targetConversationId,
      MobileAttachmentUpload(
        filename: meta.name,
        bytes: bytes,
        mimetype: meta.mimetype,
      ),
    );
  }

  Future<void> markAsRead(String conversationId) async {
    await _client.post(
      '/api/v1/mobile/chat/channels/$conversationId/mark-read',
    );
  }

  Future<void> pinMessage(String conversationId, String messageId) async {
    await _client.post(
      '/api/v1/mobile/chat/messages/$messageId/pin',
      body: <String, dynamic>{'channel_id': int.tryParse(conversationId)},
    );
  }

  Future<void> unpinMessage(String conversationId, String messageId) async {
    await _client.post(
      '/api/v1/mobile/chat/messages/$messageId/unpin',
      body: <String, dynamic>{'channel_id': int.tryParse(conversationId)},
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

  Future<String> openDirect(String partnerId) async {
    final parsedPartnerId = int.tryParse(partnerId);
    if (parsedPartnerId == null) {
      throw Failure(
        'KhÃ´ng xÃ¡c Ä‘á»‹nh Ä‘Æ°á»£c ngÆ°á»i dÃ¹ng Ä‘á»ƒ táº¡o chat.',
      );
    }
    final res = await _client.post(
      '/api/v1/mobile/chat/direct',
      body: <String, dynamic>{'partner_id': parsedPartnerId},
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

  Future<List<Profile>> searchUsers(String query) async {
    final res = await _client.get(
      '/api/v1/mobile/users/search',
      query: <String, Object?>{'q': query.trim()},
    );
    final records = _userSearchRecords(res);
    return records.map(_profileFromUserSearch).toList();
  }

  /// Retained for group creation, which still uses the user IDs returned by
  /// the internal-user search endpoint.
  Future<List<Profile>> allUsers() => searchUsers('');

  List<Map<String, dynamic>> _userSearchRecords(Object? response) {
    final raw = response is Map
        ? response['users'] ?? response['data'] ?? response['result']
        : response;
    if (raw is! List) {
      throw Failure('Pháº£n há»“i tÃ¬m ngÆ°á»i dÃ¹ng khÃ´ng há»£p lá»‡.');
    }
    return raw.whereType<Map>().map(Map<String, dynamic>.from).toList();
  }

  Profile _profileFromUserSearch(Map<String, dynamic> user) {
    final userId = user['user_id'] ?? user['id'];
    final partnerId = user['partner_id'];
    if (userId == null || partnerId == null) {
      throw Failure('Káº¿t quáº£ tÃ¬m kiáº¿m thiáº¿u user hoáº·c partner id.');
    }
    final email = (user['email'] ?? user['login'] ?? '').toString();
    return Profile(
      id: userId.toString(),
      partnerId: partnerId.toString(),
      email: email,
      displayName: (user['name'] ?? user['display_name'] ?? email).toString(),
      avatarUrl: _client.absoluteUrl(
        '/api/v1/mobile/avatar/partners/$partnerId',
      ),
    );
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

  Future<void> sendContact(String conversationId, int partnerId) async {
    await _client.post(
      '/api/v1/mobile/chat/channels/$conversationId/contact',
      body: <String, dynamic>{'partner_id': partnerId},
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
              member['avatar_128_url'] ??
              member['image_128_url'] ??
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
