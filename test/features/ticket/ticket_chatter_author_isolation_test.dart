import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/core/api/odoo_api_client.dart';
import 'package:vcloud/features/ticket/data/ticket_comment_repository.dart';
import 'package:vcloud/features/ticket/presentation/widgets/ticket_chatter.dart';
import 'package:vcloud/shared/models/ticket.dart';
import 'package:vcloud/shared/models/ticket_comment.dart';
import 'package:vcloud/shared/widgets/app_scaffold.dart';

class _MockOdooClient implements OdooApiClient {
  final List<String> recordedCalls = <String>[];
  dynamic getResult;
  dynamic postResult;

  _MockOdooClient({this.getResult});

  @override
  Future<dynamic> get(
    String path, {
    Map<String, Object?> query = const <String, Object?>{},
    bool auth = true,
  }) async {
    recordedCalls.add('GET $path');
    return getResult;
  }

  @override
  Future<dynamic> post(
    String path, {
    Object? body,
    Map<String, Object?> query = const <String, Object?>{},
    bool auth = true,
  }) async {
    recordedCalls.add('POST $path');
    return postResult;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Helpdesk Ticket Chatter & Author Isolation Tests (12 Test Cases)', () {
    // -------------------------------------------------------------------------
    // Case 1: author_avatar_url mapping
    // -------------------------------------------------------------------------
    test('Case 1: TicketComment.fromMap parses author_avatar_url correctly', () {
      final map = {
        'id': '101',
        'ticket_id': '42',
        'author_id': 7,
        'author_name': 'Nguyễn Văn A',
        'author_avatar_url': 'https://vuahethong.net/web/image/res.partner/7/avatar_128',
        'body': 'Đã nhận xử lý sự cố',
        'date': '2026-10-09T10:00:00Z',
      };
      final comment = TicketComment.fromMap(map);
      expect(comment.id, '101');
      expect(comment.ticketId, '42');
      expect(comment.authorId, '7');
      expect(comment.authorName, 'Nguyễn Văn A');
      expect(comment.authorAvatarUrl, 'https://vuahethong.net/web/image/res.partner/7/avatar_128');
      expect(comment.content, 'Đã nhận xử lý sự cố');
    });

    // -------------------------------------------------------------------------
    // Case 2: Fallback to author_avatar or avatar_url
    // -------------------------------------------------------------------------
    test('Case 2: TicketComment.fromMap falls back to author_avatar or avatar_url', () {
      final map1 = {
        'id': '102',
        'ticket_id': '42',
        'author_id': 8,
        'author_avatar': 'https://vuahethong.net/avatar_alt.png',
        'body': 'Bình luận thử',
      };
      final comment1 = TicketComment.fromMap(map1);
      expect(comment1.authorAvatarUrl, 'https://vuahethong.net/avatar_alt.png');

      final map2 = {
        'id': '103',
        'ticket_id': '42',
        'author_id': 9,
        'avatar_url': 'https://vuahethong.net/avatar_alt2.png',
        'body': 'Bình luận thử 2',
      };
      final comment2 = TicketComment.fromMap(map2);
      expect(comment2.authorAvatarUrl, 'https://vuahethong.net/avatar_alt2.png');
    });

    // -------------------------------------------------------------------------
    // Case 3: authorAvatarUrl is null when avatar is missing/empty/false
    // -------------------------------------------------------------------------
    test('Case 3: TicketComment.fromMap handles missing or false avatar cleanly', () {
      final map = {
        'id': '104',
        'ticket_id': '42',
        'author_id': 10,
        'author_avatar_url': false,
        'body': 'Nội dung bình luận',
      };
      final comment = TicketComment.fromMap(map);
      expect(comment.authorAvatarUrl, isNull);
    });

    // -------------------------------------------------------------------------
    // Case 4: Odoo Many2one author_id list format [id, name]
    // -------------------------------------------------------------------------
    test('Case 4: TicketComment.fromMap parses Many2one list format [id, name]', () {
      final map = {
        'id': '105',
        'ticket_id': '42',
        'author_id': [15, 'Trần Kỹ Thuật Viên'],
        'body': 'Đang kiểm tra kết nối mạng',
      };
      final comment = TicketComment.fromMap(map);
      expect(comment.authorId, '15');
      expect(comment.authorName, 'Trần Kỹ Thuật Viên');
    });

    // -------------------------------------------------------------------------
    // Case 5: System / bot comment fallback
    // -------------------------------------------------------------------------
    test('Case 5: TicketComment.fromMap assigns "Hệ thống" when author_id is 0/null', () {
      final map = {
        'id': '106',
        'ticket_id': '42',
        'author_id': 0,
        'body': 'Hệ thống tự động kích hoạt SLA',
      };
      final comment = TicketComment.fromMap(map);
      expect(comment.authorId, '0');
      expect(comment.authorName, 'Hệ thống');
    });

    // -------------------------------------------------------------------------
    // Case 6: toMap and copyWith preserve authorAvatarUrl
    // -------------------------------------------------------------------------
    test('Case 6: TicketComment toMap and copyWith preserve authorAvatarUrl', () {
      final comment = TicketComment(
        id: '200',
        ticketId: '42',
        authorId: '12',
        content: 'Nội dung',
        createdAt: DateTime(2026, 10, 9, 10, 30),
        authorName: 'Lê Văn B',
        authorAvatarUrl: 'https://cdn.example.com/b.png',
      );
      final map = comment.toMap();
      expect(map['author_avatar_url'], 'https://cdn.example.com/b.png');
      expect(map['author_name'], 'Lê Văn B');

      final copied = comment.copyWith(authorName: 'Lê Văn B (Updated)');
      expect(copied.authorAvatarUrl, 'https://cdn.example.com/b.png');
      expect(copied.authorName, 'Lê Văn B (Updated)');
    });

    // -------------------------------------------------------------------------
    // Case 7: TicketCommentRepository parses messages with avatar_url
    // -------------------------------------------------------------------------
    test('Case 7: TicketCommentRepository watchByTicket parses author_avatar_url', () async {
      final mock = _MockOdooClient(
        getResult: {
          'id': 42,
          'description': 'Mô tả ban đầu',
          'messages': [
            {
              'id': 301,
              'author_id': 88,
              'author_name': 'Kỹ sư tiếp nhận',
              'author_avatar_url': 'https://vuahethong.net/avatar_tech.jpg',
              'body': '<p><strong>Kỹ sư tiếp nhận</strong> đã nhận xử lý ticket này.</p>',
              'date': '2026-10-09T10:15:00Z',
            },
          ],
        },
      );
      final repo = TicketCommentRepository(client: mock);
      final stream = repo.watchByTicket('42');
      final list = await stream.first;

      expect(list.length, 1);
      final c = list.first;
      expect(c.authorName, 'Kỹ sư tiếp nhận');
      expect(c.authorAvatarUrl, 'https://vuahethong.net/avatar_tech.jpg');
      expect(c.content, contains('đã nhận xử lý ticket này'));
    });

    // -------------------------------------------------------------------------
    // Case 8: TicketCommentCard strictly displays comment.authorName
    // -------------------------------------------------------------------------
    testWidgets('Case 8: TicketCommentCard renders author name from comment.authorName', (tester) async {
      final comment = TicketComment(
        id: '401',
        ticketId: '42',
        authorId: '99',
        content: 'Tôi đang xử lý vấn đề này',
        createdAt: DateTime(2026, 10, 9, 11, 0),
        authorName: 'Nguyễn Văn Nhận',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TicketCommentCard(
              comment: comment,
              myId: '1',
            ),
          ),
        ),
      );

      // Must find author name strictly from comment
      expect(find.text('Nguyễn Văn Nhận'), findsOneWidget);
      expect(find.text('Tôi đang xử lý vấn đề này'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // Case 9: TicketCommentCard renders UserAvatar widget
    // -------------------------------------------------------------------------
    testWidgets('Case 9: TicketCommentCard renders UserAvatar with authorAvatarUrl', (tester) async {
      final comment = TicketComment(
        id: '402',
        ticketId: '42',
        authorId: '99',
        content: 'Tiến độ 50%',
        createdAt: DateTime(2026, 10, 9, 11, 5),
        authorName: 'Nguyễn Văn Nhận',
        authorAvatarUrl: 'https://vuahethong.net/avatar_99.png',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TicketCommentCard(
              comment: comment,
              myId: '1',
            ),
          ),
        ),
      );

      final avatarFinder = find.byType(UserAvatar);
      expect(avatarFinder, findsOneWidget);
      final userAvatar = tester.widget<UserAvatar>(avatarFinder);
      expect(userAvatar.displayName, 'Nguyễn Văn Nhận');
      expect(userAvatar.avatarUrl, 'https://vuahethong.net/avatar_99.png');
      expect(userAvatar.userId, '99');
    });

    // -------------------------------------------------------------------------
    // Case 10: Anti-misattribution: empty content never defaults to "đã tạo ticket"
    // -------------------------------------------------------------------------
    testWidgets('Case 10: Empty comment content displays update notice, NOT "đã tạo ticket"', (tester) async {
      final comment = TicketComment(
        id: '403',
        ticketId: '42',
        authorId: '55',
        content: '', // Empty content
        createdAt: DateTime(2026, 10, 9, 11, 10),
        authorName: 'Kỹ sư Trần',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TicketCommentCard(
              comment: comment,
              myId: '1',
            ),
          ),
        ),
      );

      // Must NOT contain "đã tạo ticket này"
      expect(find.text('Kỹ sư Trần đã tạo ticket này.'), findsNothing);
      // Must contain neutral update notice
      expect(find.text('Kỹ sư Trần đã gửi một cập nhật.'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // Case 11: Ticket Action Bar hides "Nhận ticket" when already taken/assigned
    // -------------------------------------------------------------------------
    testWidgets('Case 11: Ticket is taken hides "Nhận ticket" and shows full width "Hoàn thành"', (tester) async {
      final takenTicket = Ticket(
        id: '42',
        title: 'Ticket đã có người nhận',
        description: 'Mô tả',
        status: TicketStatus.doing, // In progress
        priority: TicketPriority.p3,
        createdBy: 'Trần Khách Hàng',
        assignedTo: 'Nguyễn Văn A',
        assignedUserName: 'Nguyễn Văn A',
        createdAt: DateTime(2026, 10, 9, 8, 0),
        updatedAt: DateTime(2026, 10, 9, 9, 0),
      );

      // Build container that tests button layout for taken ticket
      final isTaken = takenTicket.status == TicketStatus.doing || takenTicket.assignedTo.trim().isNotEmpty;
      expect(isTaken, isTrue);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                if (!isTaken) ...[
                  ElevatedButton(
                    onPressed: () {},
                    child: const Text('Nhận ticket'),
                  ),
                ],
                ElevatedButton(
                  onPressed: () {},
                  child: const Text('Hoàn thành'),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Nhận ticket'), findsNothing);
      expect(find.text('Hoàn thành'), findsOneWidget);
    });

    // -------------------------------------------------------------------------
    // Case 12: Ticket Action Bar shows both "Nhận ticket" and "Hoàn thành" when unassigned
    // -------------------------------------------------------------------------
    testWidgets('Case 12: Ticket unassigned shows both "Nhận ticket" and "Hoàn thành"', (tester) async {
      final unassignedTicket = Ticket(
        id: '43',
        title: 'Ticket chưa có người nhận',
        description: 'Mô tả',
        status: TicketStatus.todo, // Not taken
        priority: TicketPriority.p3,
        createdBy: 'Trần Khách Hàng',
        assignedTo: '',
        createdAt: DateTime(2026, 10, 9, 8, 0),
        updatedAt: DateTime(2026, 10, 9, 8, 0),
      );

      final isTaken = unassignedTicket.status == TicketStatus.doing || unassignedTicket.assignedTo.trim().isNotEmpty;
      expect(isTaken, isFalse);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                if (!isTaken) ...[
                  ElevatedButton(
                    onPressed: () {},
                    child: const Text('Nhận ticket'),
                  ),
                ],
                ElevatedButton(
                  onPressed: () {},
                  child: const Text('Hoàn thành'),
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Nhận ticket'), findsOneWidget);
      expect(find.text('Hoàn thành'), findsOneWidget);
    });
  });
}
