import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/core/api/odoo_api_client.dart';
import 'package:vcloud/features/timesheet/data/task_repository.dart';
import 'package:vcloud/shared/models/timesheet.dart';

void main() {
  test('complete logs time through the mobile timesheet endpoint', () async {
    final client = _FakeOdooApiClient();
    final repo = TaskRepository(client: client);

    final task = await repo.complete(
      taskId: '42',
      summary: 'Fix timer save',
      duration: TimesheetDuration.thirty,
    );

    final body = client.posts.single.body as Map<String, dynamic>;
    expect(task.isCompleted, isTrue);
    expect(task.timesheetId, '99');
    expect(client.posts.single.path, '/api/v1/mobile/timesheet/log');
    expect(body, <String, dynamic>{
      'project_id': 7,
      'task_id': 42,
      'unit_amount': 0.5,
      'date': body['date'],
      'name': 'Fix timer save',
    });
    expect(client.puts.single.path, '/api/v1/project.task/42');
    expect(client.puts.single.body, <String, dynamic>{
      'values': <String, dynamic>{'state': '1_done'},
    });
  });

  test('complete can log the exact stopwatch duration', () async {
    final client = _FakeOdooApiClient();
    final repo = TaskRepository(client: client);

    await repo.complete(
      taskId: '42',
      summary: 'Five minute timer',
      duration: TimesheetDuration.fifteen,
      elapsed: const Duration(minutes: 5),
    );

    final body = client.posts.single.body as Map<String, dynamic>;
    expect(body['unit_amount'], closeTo(5 / 60, 0.000001));
  });

  test('update rewrites an existing timesheet entry in place', () async {
    final client = _FakeOdooApiClient();
    final repo = TaskRepository(client: client);

    await repo.update(
      taskId: '42',
      timesheetEntryId: '99',
      summary: 'Refined copy',
      duration: TimesheetDuration.fortyFive,
    );

    expect(client.puts.single.path, '/api/v1/account.analytic.line/99');
    final body = client.puts.single.body as Map<String, dynamic>;
    final values = body['values'] as Map<String, dynamic>;
    expect(values['name'], 'Refined copy');
    expect(values['unit_amount'], closeTo(45 / 60, 0.000001));
  });

  test(
    'log writes a fresh timesheet entry without flipping task state',
    () async {
      final client = _FakeOdooApiClient();
      final repo = TaskRepository(client: client);

      await repo.log(
        taskId: '42',
        summary: 'Mid-task work log',
        duration: TimesheetDuration.thirty,
        elapsed: const Duration(minutes: 5),
      );

      // Only one POST (the timesheet log) — no PUT to flip project.task
      // state, since this path is for in-progress logging.
      expect(client.posts, hasLength(1));
      expect(client.posts.single.path, '/api/v1/mobile/timesheet/log');
      final body = client.posts.single.body as Map<String, dynamic>;
      expect(body['task_id'], 42);
      expect(body['unit_amount'], closeTo(5 / 60, 0.000001));
      expect(body['name'], 'Mid-task work log');
      expect(client.puts, isEmpty);
    },
  );

  test('logged time does not make an in-progress task completed', () async {
    final client = _FakeOdooApiClient();
    final repo = TaskRepository(client: client);

    final task = await repo.log(
      taskId: '42',
      summary: 'Still working',
      duration: TimesheetDuration.thirty,
    );

    expect(task.isCompleted, isFalse);
    expect(client.puts, isEmpty);
  });

  test('watchToday emits tasks from every assigned project', () async {
    final client = _FakeOdooApiClient();
    final repo = TaskRepository(client: client);

    final tasks = await repo.watchToday().first;

    expect(tasks.map((task) => task.id), containsAll(<String>['11', '22']));
    expect(tasks.length, 2);
    expect(
      tasks.firstWhere((task) => task.id == '11').projectName,
      'Project A',
    );
    expect(tasks.firstWhere((task) => task.id == '11').tags, <String>[
      'Design',
      'Mobile',
    ]);
    expect(tasks.firstWhere((task) => task.id == '11').allocatedHours, 2);
  });

  test(
    'resolves tag_ids to names and colours via the helpdesk.tag catalog',
    () async {
      final client = _FakeOdooApiClient();
      final repo = TaskRepository(client: client);

      final tasks = await repo.watchToday().first;
      final task22 = tasks.firstWhere((task) => task.id == '22');

      expect(task22.tags, <String>['Urgent']);
      expect(task22.tagHexColors, <String, String>{'Urgent': 'F06050'});
      expect(client.tagRequests, 1);
    },
  );
}

class _FakeOdooApiClient extends OdooApiClient {
  _FakeOdooApiClient() : super(baseUrl: 'https://example.test');

  final posts = <({String path, Object? body})>[];
  final puts = <({String path, Object? body})>[];
  int tagRequests = 0;

  @override
  Future<dynamic> get(
    String path, {
    Map<String, Object?> query = const <String, Object?>{},
    bool auth = true,
  }) async {
    if (path == '/api/v1/mobile/timesheet/projects') {
      return <Map<String, dynamic>>[
        <String, dynamic>{'id': 1, 'name': 'Project A'},
        <String, dynamic>{'id': 2, 'name': 'Project B'},
      ];
    }
    if (path == '/api/v1/mobile/timesheet/projects/1/tasks') {
      return <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 11,
          'name': 'Task A',
          'project_id': 1,
          'user_id': 3,
          'state': '01_in_progress',
          'tags': <String>['Design', 'Mobile'],
        },
      ];
    }
    if (path == '/api/v1/mobile/timesheet/projects/2/tasks') {
      return <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 22,
          'name': 'Task B',
          'project_id': 2,
          'user_id': 3,
          'state': '01_in_progress',
        },
      ];
    }
    if (path == '/api/v1/helpdesk.tag') {
      tagRequests++;
      return <Map<String, dynamic>>[
        <String, dynamic>{'id': 9, 'name': 'Urgent', 'color': 1},
        <String, dynamic>{'id': 12, 'name': 'Backend', 'color': 4},
      ];
    }
    if (path == '/api/v1/project.task/42') {
      return <String, dynamic>{
        'id': 42,
        'name': 'Timer task',
        'project_id': 7,
        'user_id': 3,
        'state': '01_in_progress',
        'timesheet_ids': <int>[99],
      };
    }
    if (path == '/api/v1/project.task/11') {
      return <String, dynamic>{
        'id': 11,
        'name': 'Task A',
        'project_id': 1,
        'user_id': 3,
        'state': '01_in_progress',
        'allocated_hours': 2,
        'effective_hours': 0.5,
        'remaining_hours': 1.5,
        'tags': <String>['Design', 'Mobile'],
      };
    }
    if (path == '/api/v1/project.task/22') {
      return <String, dynamic>{
        'id': 22,
        'name': 'Task B',
        'project_id': 2,
        'user_id': 3,
        'state': '01_in_progress',
        'tag_ids': <int>[9],
      };
    }
    throw StateError('Unexpected GET $path');
  }

  @override
  Future<dynamic> post(
    String path, {
    Object? body,
    Map<String, Object?> query = const <String, Object?>{},
    bool auth = true,
  }) async {
    posts.add((path: path, body: body));
    return <String, dynamic>{
      'id': 99,
      'display_name': 'Fix timer save',
      'unit_amount': 0.5,
      'date': '2026-07-02',
    };
  }

  @override
  Future<dynamic> put(String path, {Object? body}) async {
    puts.add((path: path, body: body));
    return <String, dynamic>{'status': 'ok'};
  }
}
