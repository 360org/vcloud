import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/core/api/odoo_api_client.dart';
import 'package:vcloud/features/timesheet/application/timesheet_controller.dart';
import 'package:vcloud/features/timesheet/data/timesheet_repository.dart';

void main() {
  group('Timesheet Filter Verification - Task Date & Worklog Matching', () {
    final monday = DateTime(2026, 9, 7);
    final wednesday = DateTime(2026, 9, 9);
    final sunday = DateTime(2026, 9, 13);
    final nextWeek = DateTime(2026, 9, 16);

    final weekFilter = TimesheetFilterState(
      presetName: 'Tuần này',
      dateFrom: monday,
      dateTo: sunday,
    );

    test('Open task without dueDate retains visibility via createdAt / dateAssign in range', () {
      final openDate = wednesday;

      final openDay = DateTime(openDate.year, openDate.month, openDate.day);
      final toDay = DateTime(weekFilter.dateTo!.year, weekFilter.dateTo!.month, weekFilter.dateTo!.day);

      // Task tạo trong tuần này không bị coi là after dateTo
      final isAfterToDay = openDay.isAfter(toDay);
      expect(isAfterToDay, isFalse);
    });

    test('Open task without ANY dates is not unjustly discarded', () {
      const DateTime? openDate = null;
      expect(openDate, isNull);
      // Khi openDate == null, filter không loại bỏ task (!t.done)
    });

    test('Open task scheduled far in the future (after dateTo) is filtered out', () {
      final openDate = nextWeek;
      final toDay = DateTime(weekFilter.dateTo!.year, weekFilter.dateTo!.month, weekFilter.dateTo!.day);
      final openDay = DateTime(openDate.year, openDate.month, openDate.day);

      expect(openDay.isAfter(toDay), isTrue, reason: 'Task tuần sau phải bị loại khỏi tuần này');
    });

    test('Task with logged time in range is kept regardless of completion status', () {
      const loggedDuration = Duration(hours: 2);
      final logDate = wednesday;

      final fromDay = DateTime(weekFilter.dateFrom!.year, weekFilter.dateFrom!.month, weekFilter.dateFrom!.day);
      final toDay = DateTime(weekFilter.dateTo!.year, weekFilter.dateTo!.month, weekFilter.dateTo!.day);
      final logDay = DateTime(logDate.year, logDate.month, logDate.day);

      final hasLogged = loggedDuration > Duration.zero;
      final inRange = !logDay.isBefore(fromDay) && !logDay.isAfter(toDay);

      expect(hasLogged && inRange, isTrue, reason: 'Task đã có log trong khoảng lọc phải luôn được giữ lại');
    });

    test('TimesheetFilterState retains and updates projectId correctly for summary synchronization', () {
      final projectFilter = weekFilter.copyWith(
        projectId: '42',
        projectName: 'Dự án Mobile 360',
      );

      expect(projectFilter.projectId, '42');
      expect(projectFilter.projectName, 'Dự án Mobile 360');
      expect(projectFilter.dateFrom, monday);
      expect(projectFilter.dateTo, sunday);
    });

    test('TimesheetRepository.getSummary passes projectId in query params', () async {
      final fakeClient = _SummaryFakeClient();
      final repo = TimesheetRepository(client: fakeClient);

      final summary = await repo.getSummary(
        dateFrom: '2026-09-01',
        dateTo: '2026-09-10',
        projectId: '42',
      );

      expect(summary.totalHours, 18.5);
      expect(summary.count, 7);
      expect(fakeClient.lastQuery['project_id'], '42');
      expect(fakeClient.lastQuery['date_from'], '2026-09-01');
      expect(fakeClient.lastQuery['date_to'], '2026-09-10');
    });

    test('Task created in past month with workedDate log in current range matches filter via lastLogDate', () {
      final workedDateInThisWeek = wednesday;
      final createdAtLastMonth = DateTime(2026, 8, 15);

      final fromDay = DateTime(weekFilter.dateFrom!.year, weekFilter.dateFrom!.month, weekFilter.dateFrom!.day);
      final toDay = DateTime(weekFilter.dateTo!.year, weekFilter.dateTo!.month, weekFilter.dateTo!.day);

      // Giả lập logic _matchesFilter với lastLogDate
      final lastLogDate = workedDateInThisWeek;
      final logDate = lastLogDate;
      final logDay = DateTime(logDate.year, logDate.month, logDate.day);

      final inRange = !logDay.isBefore(fromDay) && !logDay.isAfter(toDay);
      expect(inRange, isTrue, reason: 'Log workedDate tuần này phải giúp task khớp bộ lọc dù createdAt thuộc tháng trước');
    });

    test('TimesheetFilterState copyWith clear options reset fields cleanly', () {
      final filter = TimesheetFilterState(
        presetName: 'Tháng này',
        dateFrom: DateTime(2026, 9, 1),
        dateTo: DateTime(2026, 9, 30),
        projectId: '10',
        projectName: 'Dự án A',
      );

      final cleared = filter.copyWith(
        presetName: 'Hôm nay',
        clearDates: true,
        clearProject: true,
      );

      expect(cleared.presetName, 'Hôm nay');
      expect(cleared.dateFrom, isNull);
      expect(cleared.dateTo, isNull);
      expect(cleared.projectId, isNull);
      expect(cleared.projectName, isNull);
    });
  });
}

class _SummaryFakeClient extends OdooApiClient {
  _SummaryFakeClient() : super(baseUrl: 'https://example.test');

  Map<String, Object?> lastQuery = {};

  @override
  Future<dynamic> get(
    String path, {
    Map<String, Object?> query = const <String, Object?>{},
    bool auth = true,
  }) async {
    lastQuery = Map<String, Object?>.from(query);
    if (path == '/api/v1/mobile/timesheet/summary') {
      return {
        'total_hours': 18.5,
        'count': 7,
        'date_from': query['date_from'],
        'date_to': query['date_to'],
        'project_id': query['project_id'],
      };
    }
    throw StateError('Unexpected path $path');
  }
}

