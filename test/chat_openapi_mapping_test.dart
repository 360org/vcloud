import 'package:flutter_test/flutter_test.dart';
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
  _FakeOdooApiClient(this._response) : super(baseUrl: 'https://example.test');

  final Object _response;

  @override
  Future<dynamic> get(
    String path, {
    Map<String, Object?> query = const <String, Object?>{},
    bool auth = true,
  }) async {
    return _response;
  }
}
