import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/core/api/odoo_api_client.dart';
import 'package:vcloud/features/timesheet/data/timesheet_repository.dart';

void main() {
  test('timesheet list user note wins over task name in entry mapping',
      () async {
    final client = _FakeOdooApiClient();
    final repo = TimesheetRepository(client: client);

    final entries = await repo.watchRecent().first;

    expect(entries, hasLength(1));
    final entry = entries.single;
    // `name` (user-typed note) must beat `task_name` (auto from task_id.name)
    // so "Hoàn thành việc X" is displayed instead of "Việc X".
    expect(entry.taskName, 'Hoàn thành migration Odoo 19 doanh nghiệp');
    expect(entry.taskId, '42');
    expect(entry.durationMinutes, 60);
  });
}

class _FakeOdooApiClient extends OdooApiClient {
  _FakeOdooApiClient() : super(baseUrl: 'https://example.test');

  @override
  Future<dynamic> get(
    String path, {
    Map<String, Object?> query = const <String, Object?>{},
    bool auth = true,
  }) async {
    if (path == '/api/v1/mobile/timesheet/list') {
      return <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 7,
          'name': 'Hoàn thành migration Odoo 19 doanh nghiệp',
          'task_name': 'Fix timer save', // computed from task_id.name
          'display_name': 'Fix timer save', // also from task_id
          'unit_amount': 1.0,
          'date': '2026-07-02',
          'task_id': [42, 'Fix timer save'],
        },
      ];
    }
    throw StateError('Unexpected GET $path');
  }
}
