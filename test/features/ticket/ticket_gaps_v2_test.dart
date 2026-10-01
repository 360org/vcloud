import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/core/api/odoo_api_client.dart';
import 'package:vcloud/core/error/failure.dart';
import 'package:vcloud/features/ticket/data/activity_log_repository.dart';
import 'package:vcloud/features/ticket/data/ticket_comment_repository.dart';
import 'package:vcloud/features/ticket/data/ticket_repository.dart';
import 'package:vcloud/shared/models/ticket.dart';
import 'package:vcloud/shared/models/ticket_activity.dart';

class _MockOdooClient implements OdooApiClient {
  final List<String> recordedCalls = <String>[];
  final List<dynamic> recordedBodies = <dynamic>[];

  dynamic getResult;
  dynamic postResult;

  _MockOdooClient({this.getResult, this.postResult});

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
    recordedBodies.add(body);
    return postResult;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Ticket Gaps V2 Unit Tests', () {
    test('ActivityLogRepository.log sends correct payload', () async {
      final client = _MockOdooClient(postResult: {'id': 101});
      final repo = ActivityLogRepository(client: client);

      await repo.log(
        ticketId: '99',
        action: 'Gọi điện xác minh sự cố',
        details: {
          'note': 'Khách hàng hẹn chiều nay',
          'activity_type_id': 2,
          'date_deadline': '2026-10-01',
          'user_id': 5,
        },
      );

      expect(client.recordedCalls.single, 'POST /api/v1/mobile/ticket/99/activities');
      final body = client.recordedBodies.single as Map<String, dynamic>;
      expect(body['summary'], 'Gọi điện xác minh sự cố');
      expect(body['note'], 'Khách hàng hẹn chiều nay');
      expect(body['activity_type_id'], 2);
      expect(body['date_deadline'], '2026-10-01');
      expect(body['user_id'], 5);
    });

    test('ActivityLogRepository.markDone calls done route with feedback', () async {
      final client = _MockOdooClient(postResult: {'status': 'done'});
      final repo = ActivityLogRepository(client: client);

      await repo.markDone(101, feedback: 'Đã hoàn tất cuộc gọi thành công');

      expect(client.recordedCalls.single, 'POST /api/v1/mobile/ticket/activities/101/done');
      final body = client.recordedBodies.single as Map<String, dynamic>;
      expect(body['feedback'], 'Đã hoàn tất cuộc gọi thành công');
    });

    test('ActivityLogRepository.activityTypes parses list', () async {
      final client = _MockOdooClient(getResult: [
        {'id': 1, 'name': 'Email'},
        {'id': 2, 'name': 'Call'},
      ]);
      final repo = ActivityLogRepository(client: client);

      final types = await repo.activityTypes();

      expect(client.recordedCalls.single, 'GET /api/v1/mobile/ticket/activity-types');
      expect(types.length, 2);
      expect(types[0]['name'], 'Email');
      expect(types[1]['name'], 'Call');
    });

    test('TicketRepository.update sends update payload and retrieves updated ticket', () async {
      final client = _MockOdooClient(
        postResult: {'status': 'updated'},
        getResult: {
          'id': 99,
          'name': 'Tiêu đề mới',
          'description': 'Mô tả mới',
          'priority': '2',
          'team_name': 'IT Support',
          'user_id': [7, 'Bùi Tuấn Kiệt'],
        },
      );
      final repo = TicketRepository(client: client);

      final ticket = await repo.update(
        '99',
        title: 'Tiêu đề mới',
        description: 'Mô tả mới',
        priority: TicketPriority.p2,
        category: '3',
        assigneeId: 7,
      );

      expect(client.recordedCalls, contains('POST /api/v1/mobile/ticket/99/update'));
      expect(client.recordedCalls, contains('GET /api/v1/mobile/ticket/99'));
      final postBody = client.recordedBodies.single as Map<String, dynamic>;
      expect(postBody['name'], 'Tiêu đề mới');
      expect(postBody['description'], 'Mô tả mới');
      expect(postBody['priority'], '2');
      expect(postBody['team_id'], 3);
      expect(postBody['user_id'], 7);

      expect(ticket.title, 'Tiêu đề mới');
      expect(ticket.assignedTo, '7');
      expect(ticket.assignedUserName, 'Bùi Tuấn Kiệt');
    });

    test('TicketRepository.assignUser delegates to update with assigneeId', () async {
      final client = _MockOdooClient(
        postResult: {'status': 'updated'},
        getResult: {
          'id': 99,
          'name': 'Ticket Test',
          'user_id': [12, 'Kỹ thuật viên 12'],
        },
      );
      final repo = TicketRepository(client: client);

      final ticket = await repo.assignUser('99', 12);

      expect(client.recordedCalls, contains('POST /api/v1/mobile/ticket/99/update'));
      final postBody = client.recordedBodies.single as Map<String, dynamic>;
      expect(postBody['user_id'], 12);
      expect(ticket.assignedTo, '12');
    });

    test('TicketRepository.assignees returns internal users list', () async {
      final client = _MockOdooClient(getResult: [
        {'id': 1, 'name': 'Admin'},
        {'id': 2, 'name': 'Dev 2'},
      ]);
      final repo = TicketRepository(client: client);

      final users = await repo.assignees();

      expect(client.recordedCalls.single, 'GET /api/v1/mobile/ticket/assignees');
      expect(users.length, 2);
      expect(users.first['name'], 'Admin');
    });

    test('TicketCommentRepository.delete throws Failure protecting audit trail', () async {
      final client = _MockOdooClient();
      final repo = TicketCommentRepository(client: client);

      expect(
        () => repo.delete('123'),
        throwsA(isA<Failure>().having(
          (f) => f.message,
          'message',
          contains('toàn vẹn dữ liệu'),
        )),
      );
      expect(client.recordedCalls, isEmpty);
    });

    test('TicketActivity.isDone handles state and dateDone correctly', () {
      const pendingActivity = TicketActivity(
        id: 1,
        summary: 'To-do',
        note: '',
        state: 'planned',
      );
      expect(pendingActivity.isDone, isFalse);

      const doneByState = TicketActivity(
        id: 2,
        summary: 'Done item',
        note: '',
        state: 'done',
      );
      expect(doneByState.isDone, isTrue);

      final doneByDate = TicketActivity(
        id: 3,
        summary: 'Done with date',
        note: '',
        dateDone: DateTime.now(),
      );
      expect(doneByDate.isDone, isTrue);
    });
  });
}
