import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/core/api/mobile_attachment_repository.dart';
import 'package:vcloud/core/api/odoo_api_client.dart';
import 'package:vcloud/features/chat/data/chat_repository.dart';
import 'package:vcloud/features/home/data/dashboard_repository.dart';
import 'package:vcloud/shared/models/conversation.dart';
import 'package:vcloud/shared/models/message.dart';
import 'package:vcloud/shared/models/profile.dart';

void main() {
  test('ChatRepository exposes messages oldest first', () async {
    final repo = ChatRepository(
      client: _FakeOdooApiClient(<String, dynamic>{
        'messages': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 3,
            'body': '<p>Newest</p>',
            'date': '2026-07-01T08:30:00Z',
          },
          <String, dynamic>{
            'id': 1,
            'body': '<p>Oldest</p>',
            'date': '2026-07-01T08:00:00Z',
          },
          <String, dynamic>{
            'id': 2,
            'body': '<p>Middle</p>',
            'date': '2026-07-01T08:15:00Z',
          },
        ],
      }),
    );

    final messages = await repo.watchMessages('42').first;

    expect(messages.map((message) => message.content), <String>[
      'Oldest',
      'Middle',
      'Newest',
    ]);
  });

  test('ChatRepository creates groups through mobile chat endpoint', () async {
    final client = _FakeOdooApiClient(<String, dynamic>{'channel_id': 42});
    final repo = ChatRepository(client: client);

    final channelId = await repo.createGroup('Team VCloud', <String>['7', '9']);

    expect(channelId, '42');
    expect(client.lastPostPath, '/api/v1/mobile/chat/groups');
    expect(client.lastPostBody, <String, dynamic>{
      'name': 'Team VCloud',
      'member_ids': <int>[7, 9],
    });
  });

  test('ChatRepository fetches users with schema-safe fields', () async {
    final client = _FakeOdooApiClient(<Map<String, dynamic>>[
      <String, dynamic>{'id': 7, 'login': 'an@example.com', 'name': 'An'},
    ]);
    final repo = ChatRepository(client: client);

    final users = await repo.allUsers();

    expect(client.lastGetPath, '/api/v1/res.users');
    expect(client.lastGetQuery, <String, Object?>{'fields': 'id,login,name'});
    expect(
      users.single.avatarUrl,
      'https://example.test/api/v1/mobile/avatar/users/7',
    );
  });

  test('ChatRepository sends contact card through mobile endpoint', () async {
    final client = _FakeOdooApiClient(<String, dynamic>{'ok': true});
    final repo = ChatRepository(client: client);

    await repo.sendContact('42', 7);

    expect(client.lastPostPath, '/api/v1/mobile/chat/channels/42/contact');
    expect(client.lastPostBody, <String, dynamic>{'partner_id': 7});
  });

  test('ChatRepository pins and unpins messages through mobile endpoints',
  () async {
    final client = _FakeOdooApiClient(<String, dynamic>{'ok': true});
    final repo = ChatRepository(client: client);

    await repo.pinMessage('42', '99');
    await repo.unpinMessage('42', '99');

    expect(client.postPaths, <String>[
      '/api/v1/mobile/chat/messages/99/pin',
      '/api/v1/mobile/chat/messages/99/unpin',
    ]);
    expect(client.postBodies, <Object?>[
      <String, dynamic>{'channel_id': 42},
      <String, dynamic>{'channel_id': 42},
    ]);
  });

  test('ChatRepository uploads attachments onto discuss channel', () async {
    final client = _FakeOdooApiClient(<String, dynamic>{
      'id': 9,
      'attachment_id': 9,
      'name': 'anh.png',
      'mimetype': 'image/png',
    });
    final repo = ChatRepository(client: client);

    await repo.uploadAttachment(
      '42',
      MobileAttachmentUpload(
        filename: 'anh.png',
        bytes: Uint8List.fromList(<int>[1, 2, 3]),
        mimetype: 'image/png',
      ),
    );

    expect(client.postPaths, <String>[
      '/api/v1/mobile/attachments/upload',
      '/api/v1/mobile/chat/messages',
    ]);
    expect(
      client.postBodies.first,
      containsPair('res_model', 'discuss.channel'),
    );
    expect(client.postBodies.first, containsPair('res_id', 42));
    expect(client.postBodies.first, containsPair('name', 'anh.png'));
    expect(client.postBodies.first, containsPair('datas', 'AQID'));
    expect(client.postBodies.last, containsPair('channel_id', 42));
    expect(client.postBodies.last, containsPair('body', 'anh.png'));
    expect(client.postBodies.last, containsPair('attachment_ids', <int>[9]));
  });

  test('ChatRepository resolves attachment download URL', () async {
    final client = _FakeOdooApiClient(<String, dynamic>{
      'id': 9,
      'attachment_id': 9,
      'name': 'tailieu.txt',
      'download_url': '/web/content/9?download=1',
    });
    final repo = ChatRepository(client: client);

    final url = await repo.attachmentDownloadUrl('9');

    expect(client.lastGetPath, '/api/v1/mobile/attachments/9');
    expect(url, 'https://example.test/web/content/9?download=1');
  });

  test('ChatRepository resolves attachment image preview URL', () {
    final client = _FakeOdooApiClient(<String, dynamic>{});
    final repo = ChatRepository(client: client);

    final url = repo.attachmentContentUrl(
      '9',
      url: '/web/content/9?download=1&access_token=abc',
    );

    expect(url, 'https://example.test/web/content/9?access_token=abc');
  });

  test('ChatRepository.forwardAttachment re-uploads bytes into target channel',
  () async {
    // Flow: fetchBytes → get attachment meta → upload → send message.
    final client = _FakeOdooApiClient(
      // GET /api/v1/mobile/attachments/9 → metadata for the source file.
      <String, dynamic>{
        'id': 9,
        'attachment_id': 9,
        'name': 'anh.png',
        'mimetype': 'image/png',
        'download_url': '/web/content/9?download=1',
      },
      postResponses: <Map<String, dynamic>>[
        // POST /api/v1/mobile/attachments/upload → the re-uploaded attachment.
        <String, dynamic>{
          'id': 20,
          'attachment_id': 20,
          'name': 'anh.png',
          'mimetype': 'image/png',
        },
        // POST /api/v1/mobile/chat/messages → the forwarded message ack.
        <String, dynamic>{'id': 100},
      ],
    );
    final repo = ChatRepository(client: client);

    await repo.forwardAttachment('55', '9');

    // Bytes were fetched from the source attachment's download URL.
    expect(client.lastFetchBytesPath, '/web/content/9?download=1');
    // Upload happened first, then the message send to the *target* channel.
    expect(client.postPaths, <String>[
      '/api/v1/mobile/attachments/upload',
      '/api/v1/mobile/chat/messages',
    ]);
    // Upload payload carries the re-uploaded bytes (base64) + target res_id.
    expect(client.postBodies.first, containsPair('res_model', 'discuss.channel'));
    expect(client.postBodies.first, containsPair('res_id', 55));
    expect(client.postBodies.first, containsPair('name', 'anh.png'));
    // Message send targets the target channel and references the new attachment.
    expect(client.postBodies.last, containsPair('channel_id', 55));
    expect(client.postBodies.last, containsPair('attachment_ids', <int>[20]));
  });

  test('ChatChannel maps into conversation summary metadata', () {
    final fetchedAt = DateTime.utc(2026, 7);
    final summary = ConversationSummary.fromOdooChatChannel(<String, dynamic>{
      'id': 42,
      'name': 'Du an VCloud',
      'channel_type': 'channel',
      'avatar_128': false,
      'description': 'Nhom trien khai',
      'is_editable': true,
      'member_count': 8,
      'last_message_id': 99,
      'last_message': '<p>Hello &amp; team</p>',
      'last_message_date': '2026-07-01T08:30:00Z',
      'unread_count': 3,
      'last_seen_message_id': 98,
      'last_seen_dt': '2026-07-01T08:00:00Z',
    }, fetchedAt: fetchedAt);

    expect(summary.id, '42');
    expect(summary.isGroup, isTrue);
    expect(summary.title, 'Du an VCloud');
    expect(summary.updatedAt, DateTime.parse('2026-07-01T08:30:00Z'));
    expect(summary.avatarUrl, isNull);
    expect(summary.description, 'Nhom trien khai');
    expect(summary.isEditable, isTrue);
    expect(summary.memberCount, 8);
    expect(summary.lastMessage?.id, '99');
    expect(summary.lastMessage?.content, 'Hello & team');
    expect(summary.unreadCount, 3);
    expect(summary.lastSeenMessageId, '98');
    expect(summary.lastSeenDt, DateTime.parse('2026-07-01T08:00:00Z'));
  });

  test('ChatChannel avatar_url is read into avatarUrl field', () {
    final summary = ConversationSummary.fromOdooChatChannel(<String, dynamic>{
      'id': 42,
      'name': 'Direct chat',
      'channel_type': 'chat',
      // OpenAPI ChatChannel.avatar_url — the canonical photo URL
      // returned by `/api/v1/mobile/chat/channels`. Often a relative
      // path against the Odoo base URL.
      'avatar_url': '/web/image/discuss.channel/42/avatar_128/4a3b1f000abc',
      'last_message_date': '2026-07-01T08:30:00Z',
      'last_message': 'Hello',
    }, fetchedAt: DateTime.utc(2026, 7));

    expect(
      summary.avatarUrl,
      '/web/image/discuss.channel/42/avatar_128/4a3b1f000abc',
    );
  });

  test('MessageInfo maps into app message fields', () {
    final message = Message.fromOdooMessageInfo(
      conversationId: '42',
      map: <String, dynamic>{
        'id': 99,
        'body': '<p>Hello&nbsp;&amp; welcome</p>',
        'preview': 'Hello',
        'author_id': <Object>[7, 'Nguyen An'],
        'author_avatar': false,
        'date': '2026-07-01T08:30:00Z',
        'message_type': 'comment',
        'is_internal': false,
        'parent_id': null,
        'attachment_ids': <int>[1, 2],
        'starred': true,
        'pinned_at': '2026-07-01T09:00:00Z',
        'is_read_by_me': true,
        'is_mine': true,
        'read_by_ids': <int>[8, 9],
        'read_by_count': 4,
      },
    );

    expect(message.id, '99');
    expect(message.conversationId, '42');
    expect(message.senderId, '7');
    expect(message.content, 'Hello & welcome');
    expect(message.senderName, 'Nguyen An');
    expect(message.senderAvatarUrl, isNull);
    expect(message.messageType, 'comment');
    expect(message.attachmentIds, <String>['1', '2']);
    expect(message.starred, isTrue);
    expect(message.pinnedAt, DateTime.parse('2026-07-01T09:00:00Z'));
    expect(message.isReadByMe, isTrue);
    expect(message.readBy, <String>['8', '9']);
    expect(message.readByCount, 4);
    expect(message.authoredByMe, isTrue);
  });

  test('MessageInfo maps attachment metadata for previews', () {
    final message = Message.fromOdooMessageInfo(
      conversationId: '42',
      map: <String, dynamic>{
        'id': 100,
        'body': '',
        'preview': '',
        'date': '2026-07-01T08:30:00Z',
        'attachments': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 9,
            'name': 'Demo (1).pdf',
            'mimetype': 'application/pdf',
            'file_size': 131174,
            'url': '/web/content/9?access_token=abc',
            'download_url': '/web/content/9?download=1',
          },
        ],
      },
    );

    expect(message.attachmentIds, <String>['9']);
    expect(message.attachmentName, 'Demo (1).pdf');
    expect(message.attachmentMimeType, 'application/pdf');
    expect(message.attachmentSize, 131174);
    expect(message.attachmentUrl, '/web/content/9?access_token=abc');
  });

  test('Odoo naive datetimes are treated as UTC', () {
    final message = Message.fromOdooMessageInfo(
      conversationId: '42',
      map: <String, dynamic>{
        'id': 100,
        'body': '<p>UTC time</p>',
        'date': '2026-07-01 08:30:00',
      },
    );

    final summary = ConversationSummary.fromOdooChatChannel(<String, dynamic>{
      'id': 42,
      'name': 'Du an VCloud',
      'channel_type': 'channel',
      'last_message': '<p>UTC time</p>',
      'last_message_date': '2026-07-01 08:30:00',
    });

    expect(message.createdAt, DateTime.utc(2026, 7, 1, 8, 30));
    expect(summary.updatedAt, DateTime.utc(2026, 7, 1, 8, 30));
  });

  test('Direct conversation title removes current user labels', () {
    final conversation = Conversation(
      id: '42',
      isGroup: false,
      name: 'You, Nguyen An',
      createdBy: '7',
      createdAt: DateTime.utc(2026, 7),
      members: const [],
    );

    expect(
      conversation.displayTitleFor(const <String>['7', 'you']),
      'Nguyen An',
    );
  });

  test('Direct conversation title uses other member when available', () {
    final conversation = Conversation(
      id: '42',
      isGroup: false,
      name: 'You',
      createdBy: '7',
      createdAt: DateTime.utc(2026, 7),
      members: [
        ConversationMember(
          profile: const Profile(
            id: '3',
            email: 'me@example.com',
            displayName: 'Me',
          ),
          joinedAt: DateTime.utc(2026, 7),
        ),
        ConversationMember(
          profile: const Profile(
            id: '8',
            email: 'an@example.com',
            displayName: 'Nguyen An',
          ),
          joinedAt: DateTime.utc(2026, 7),
        ),
      ],
    );

    expect(
      conversation.displayTitleFor(const <String>['3', 'me@example.com']),
      'Nguyen An',
    );
  });

  test('Mobile dashboard summary maps nested endpoint counters', () {
    final summary = MobileDashboardSummary.fromMap(<String, dynamic>{
      'attendance': <String, dynamic>{'is_checked_in': true},
      'timesheet': <String, dynamic>{'today_hours': 7.5},
      'tickets': <String, dynamic>{'open_count': 4},
      'chat': <String, dynamic>{'unread_count': 12, 'channel_count': 9},
    });

    expect(summary.isCheckedIn, isTrue);
    expect(summary.todayMinutes, 450);
    expect(summary.openTickets, 4);
    expect(summary.unreadMessageCount, 12);
    expect(summary.recentConversationCount, 9);
  });
}

class _FakeOdooApiClient extends OdooApiClient {
  _FakeOdooApiClient(this._response, {List<Map<String, dynamic>>? postResponses})
    : _postResponses = postResponses ?? const <Map<String, dynamic>>[],
      super(baseUrl: 'https://example.test');

  final Object _response;
  final List<Map<String, dynamic>> _postResponses;
  int _postCalls = 0;
  String? lastGetPath;
  Map<String, Object?>? lastGetQuery;
  String? lastPostPath;
  Object? lastPostBody;
  final postPaths = <String>[];
  final postBodies = <Object?>[];
  String? lastFetchBytesPath;
  Uint8List? fetchBytesResult;

  @override
  Future<dynamic> get(
    String path, {
    Map<String, Object?> query = const <String, Object?>{},
    bool auth = true,
  }) async {
    lastGetPath = path;
    lastGetQuery = query;
    return _response;
  }

  @override
  Future<dynamic> post(
    String path, {
    Object? body,
    Map<String, Object?> query = const <String, Object?>{},
    bool auth = true,
  }) async {
    lastPostPath = path;
    lastPostBody = body;
    postPaths.add(path);
    postBodies.add(body);
    // Return successive post responses for orchestrated flows (forward);
    // hold the last one once exhausted.
    if (_postResponses.isEmpty) return _response;
    final index =
        _postCalls < _postResponses.length
            ? _postCalls
            : _postResponses.length - 1;
    _postCalls++;
    return _postResponses[index];
  }

  @override
  Future<Uint8List> fetchBytes(String path) async {
    lastFetchBytesPath = path;
    return fetchBytesResult ?? Uint8List.fromList(const <int>[9, 8, 7]);
  }
}
