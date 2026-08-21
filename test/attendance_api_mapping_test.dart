import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/core/api/odoo_api_client.dart';
import 'package:vcloud/features/attendance/data/attendance_repository.dart';
import 'package:vcloud/features/home/data/dashboard_repository.dart';

void main() {
  test('Ánh xạ trạng thái attendance theo hợp đồng API hiện tại', () async {
    final repository = AttendanceRepository(
      client: _FakeAttendanceClient(<String, dynamic>{
        'is_checked_in': true,
        'current_attendance_id': 15,
        'employee_id': 3,
        'check_in': '2026-07-15T01:15:47',
      }),
    );

    final attendance = await repository.currentOpenAttendance();

    expect(attendance, isNotNull);
    expect(attendance!.id, '15');
  });

  test('Vẫn chấp nhận tên trường tương thích từ API cũ', () async {
    final repository = AttendanceRepository(
      client: _FakeAttendanceClient(<String, dynamic>{
        'checked_in': true,
        'attendance_id': 16,
        'employee_id': 3,
        'check_in': '2026-07-15T02:00:00',
      }),
    );

    final attendance = await repository.currentOpenAttendance();

    expect(attendance, isNotNull);
    expect(attendance!.id, '16');
  });

  test('Dashboard chấp nhận today_attendance của Odoo 17', () {
    final summary = MobileDashboardSummary.fromMap(<String, dynamic>{
      'today_attendance': <String, dynamic>{'checked_in': true},
    });

    expect(summary.isCheckedIn, isTrue);
  });
  test(
    'Maps Odoo v17 attendance_state aliases when a mobile id is present',
    () async {
      final repository = AttendanceRepository(
        client: _FakeAttendanceClient(<String, dynamic>{
          'attendance_state': 'checked_in',
          'current_attendance_id': 17,
          'employee_id': 3,
          'last_check_in': '2026-07-15T03:00:00',
        }),
      );

      final attendance = await repository.currentOpenAttendance();

      expect(attendance, isNotNull);
      expect(attendance!.id, '17');
    },
  );
}

class _FakeAttendanceClient extends OdooApiClient {
  _FakeAttendanceClient(this.response) : super(baseUrl: 'https://example.test');

  final Object response;

  @override
  Future<dynamic> get(
    String path, {
    Map<String, Object?> query = const <String, Object?>{},
    bool auth = true,
  }) async {
    expect(path, '/api/v1/mobile/attendance/today');
    return response;
  }
}
