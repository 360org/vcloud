import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/features/timesheet/application/timesheet_controller.dart';
import 'package:vcloud/features/timesheet/data/timesheet_repository.dart';
import 'package:vcloud/shared/models/timesheet.dart';

class _FakeTimesheetRepository extends Fake implements TimesheetRepository {
  String? lastTaskName;
  TimesheetCategory? lastCategory;
  TimesheetDuration? lastDuration;
  String? lastTaskId;
  int? lastProjectIdOverride;
  DateTime? lastWorkedDate;

  @override
  Future<TimesheetEntry> add({
    required String taskName,
    required TimesheetCategory category,
    required TimesheetDuration duration,
    String? taskId,
    int? projectIdOverride,
    DateTime? workedDate,
  }) async {
    lastTaskName = taskName;
    lastCategory = category;
    lastDuration = duration;
    lastTaskId = taskId;
    lastProjectIdOverride = projectIdOverride;
    lastWorkedDate = workedDate;

    return TimesheetEntry(
      id: 'ts_999',
      userId: 'emp_1',
      taskName: taskName,
      category: category,
      duration: duration,
      durationMinutes: duration.duration.inMinutes,
      workedDate: workedDate ?? DateTime.now(),
      createdAt: DateTime.now(),
      taskId: taskId,
    );
  }
}

void main() {
  group('Free-form Timesheet Logging Tests', () {
    test('TimesheetRepository supports logging without taskId (free-form task log)', () async {
      final fakeRepo = _FakeTimesheetRepository();
      final workedDate = DateTime(2026, 9, 10);

      final entry = await fakeRepo.add(
        taskName: 'Nghiên cứu kiến trúc Odoo v17 & v19',
        category: TimesheetCategory.erp,
        duration: TimesheetDuration.fortyFive,
        taskId: null,
        projectIdOverride: 45,
        workedDate: workedDate,
      );

      expect(entry.id, 'ts_999');
      expect(entry.taskName, 'Nghiên cứu kiến trúc Odoo v17 & v19');
      expect(entry.durationMinutes, 45);
      expect(entry.taskId, isNull, reason: 'Log tự do không yêu cầu taskId');
      expect(fakeRepo.lastTaskId, isNull);
      expect(fakeRepo.lastProjectIdOverride, 45);
      expect(fakeRepo.lastWorkedDate, workedDate);
    });

    test('Duration bucket calculation converts elapsed times accurately', () {
      expect(durationBucketForElapsed(const Duration(minutes: 10)), TimesheetDuration.fifteen);
      expect(durationBucketForElapsed(const Duration(minutes: 25)), TimesheetDuration.thirty);
      expect(durationBucketForElapsed(const Duration(minutes: 40)), TimesheetDuration.fortyFive);
      expect(durationBucketForElapsed(const Duration(minutes: 65)), TimesheetDuration.sixty);
    });
  });
}
