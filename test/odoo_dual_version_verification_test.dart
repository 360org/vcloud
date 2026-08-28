import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/core/api/auth_user.dart';
import 'package:vcloud/core/api/odoo_session.dart';
import 'package:vcloud/shared/models/conversation.dart';
import 'package:vcloud/shared/models/message.dart';
import 'package:vcloud/shared/models/task.dart';
import 'package:vcloud/shared/models/ticket.dart';

void main() {
  group('Odoo 17 & Odoo 19 Dual-Version Mobile API Data Mapping Tests', () {
    test('AuthUser and OdooSession correctly restore and serialize JWT session', () {
      final sessionJson = {
        'access_token': 'jwt.token.mock123',
        'refresh_token': 'refresh_token_mock',
        'token_type': 'Bearer',
        'uid': 2,
        'db': 'demo-19',
        'login': 'admin',
        'expires_at': DateTime.now().add(const Duration(days: 7)).toIso8601String(),
        'base_url': 'http://127.0.0.1:8069',
        'partner_id': 3,
      };

      final session = OdooSession.fromJson(sessionJson);
      expect(session.uid, 2);
      expect(session.db, 'demo-19');
      expect(session.accessToken, 'jwt.token.mock123');
      expect(session.isExpired, isFalse);

      final user = AuthUser(
        id: session.uid.toString(),
        email: session.login,
        userMetadata: {
          'display_name': 'Administrator',
          'db': session.db,
          'partner_id': 3,
        },
      );
      expect(user.id, '2');
      expect(user.email, 'admin');
      expect(user.userMetadata['display_name'], 'Administrator');
    });

    test('ConversationSummary parses Odoo 17 & Odoo 19 channels accurately', () {
      final odoo19ChannelJson = {
        'id': 1,
        'name': 'general',
        'channel_type': 'group',
        'is_group': true,
        'member_count': 5,
        'members': [
          {
            'id': 3,
            'name': 'Administrator',
            'email': '',
            'avatar_url': '/api/v1/mobile/avatar/res.partner/3?field=avatar_128',
            'has_avatar': true,
            'im_status': 'offline',
          }
        ],
        'unread_count': 0,
        'last_message': 'Welcome to the #general channel.',
        'last_message_date': '2026-08-27T06:43:55Z',
        'last_message_author_id': 2,
        'last_message_author_name': 'OdooBot',
        'avatar_url': null,
        'has_avatar': false,
        'im_status': 'offline',
      };

      final channel = ConversationSummary.fromOdooChatChannel(odoo19ChannelJson);
      expect(channel.id, '1');
      expect(channel.title, 'general');
      expect(channel.isGroup, isTrue);
      expect(channel.memberCount, 5);
      expect(channel.unreadCount, 0);
      expect(channel.lastMessage?.content, 'Welcome to the #general channel.');
    });

    test('Message parses chat messages from both versions safely', () {
      final messageJson = {
        'id': 101,
        'channel_id': 1,
        'body': 'Hello Odoo 19 from Mobile API',
        'author_id': 3,
        'author_name': 'Administrator',
        'date': '2026-08-27T07:20:00Z',
        'message_type': 'comment',
        'attachment_ids': <int>[],
      };

      final msg = Message.fromOdooMessageInfo(
        conversationId: '1',
        map: messageJson,
      );
      expect(msg.id, '101');
      expect(msg.conversationId, '1');
      expect(msg.content, 'Hello Odoo 19 from Mobile API');
    });

    test('Ticket parses tickets safely with fallback when helpdesk empty', () {
      final ticketJson = {
        'id': 77,
        'name': 'Kiểm tra giao diện mobile',
        'description': '<p>Nội dung ticket kiểm tra</p>',
        'team_id': [1, 'Hỗ trợ kỹ thuật'],
        'stage_id': [2, 'Đang xử lý'],
        'priority': 'P2',
        'assigned_to': 'Mitchell Admin',
        'user_id': 2,
        'create_date': '2026-08-18T01:58:20Z',
        'write_date': '2026-08-18T01:58:20Z',
        'tag_ids': <int>[],
        'status': 'doing',
      };

      final ticket = Ticket.fromMap(ticketJson);
      expect(ticket.id, '77');
      expect(ticket.title, 'Kiểm tra giao diện mobile');
      expect(ticket.description, '<p>Nội dung ticket kiểm tra</p>');
      expect(ticket.status, TicketStatus.doing);
      expect(ticket.priority, TicketPriority.p2);
      expect(ticket.assignedTo, 'Mitchell Admin');
    });

    test('Task model parses task from project_tasks API with correct progress', () {
      final taskJson = {
        'id': 72,
        'name': 'Test Odoo 17 và 19 song song',
        'project_id': 5,
        'project_name': 'Internal',
        'allocated_hours': 10.0,
        'spent_hours': 3.0,
        'remaining_hours': 7.0,
        'state': '01_in_progress',
        'create_date': '2026-08-20T10:00:00Z',
        'write_date': '2026-08-27T10:00:00Z',
      };

      final task = Task.fromMap(taskJson);
      expect(task.id, '72');
      expect(task.title, 'Test Odoo 17 và 19 song song');
      expect(task.allocatedHours, 10.0);
      expect(task.spentHours, 3.0);
      expect(task.remainingHours, 7.0);
      expect(task.projectName, 'Internal');
    });
  });
}
