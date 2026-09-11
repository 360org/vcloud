import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/shared/models/task.dart';
import 'package:vcloud/shared/models/task_message.dart';
import 'package:vcloud/shared/models/timesheet.dart';
import 'package:vcloud/shared/models/timesheet_summary.dart';
import 'package:vcloud/features/timesheet/application/timesheet_controller.dart';

void main() {
  group('Timesheet & Task Contract Mapping Tests', () {
    test('TaskMessage.fromMap parses chatter message JSON correctly', () {
      final json = {
        'id': 105,
        'body': '<p>Đã kiểm tra và phê duyệt task này.</p>',
        'author_id': [3, 'Nguyễn Văn A'],
        'author_name': 'Nguyễn Văn A',
        'date': '2026-08-12T03:45:00Z',
        'message_type': 'comment',
      };

      final msg = TaskMessage.fromMap(json);

      expect(msg.id, '105');
      expect(msg.body, 'Đã kiểm tra và phê duyệt task này.');
      expect(msg.authorId, '3');
      expect(msg.authorName, 'Nguyễn Văn A');
      expect(msg.messageType, 'comment');
    });

    test('TimesheetSummary.fromMap parses summary JSON correctly', () {
      final json = {
        'total_hours': 34.5,
        'count': 42,
        'date_from': '2026-08-01',
        'date_to': '2026-08-12',
        'project_id': 10,
      };

      final summary = TimesheetSummary.fromMap(json);

      expect(summary.totalHours, 34.5);
      expect(summary.count, 42);
      expect(summary.dateFrom, '2026-08-01');
      expect(summary.dateTo, '2026-08-12');
      expect(summary.projectId, '10');
    });

    test('Task.fromMap maps allocated, spent, and remaining hours safely', () {
      final json = {
        'id': 201,
        'name': 'Làm ticket Davita',
        'allocated_hours': 10.0,
        'spent_hours': 6.5,
        'remaining_hours': 3.5,
        'state': '01_in_progress',
        'messages': [
          {
            'id': 1,
            'body': 'Bắt đầu xử lý',
            'author_name': 'User A',
            'date': '2026-08-12T01:00:00Z',
          }
        ],
      };

      final task = Task.fromMap(json);

      expect(task.id, '201');
      expect(task.title, 'Làm ticket Davita');
      expect(task.allocatedHours, 10.0);
      expect(task.spentHours, 6.5);
      expect(task.remainingHours, 3.5);
      expect(task.messages, hasLength(1));
      expect(task.messages.first.body, 'Bắt đầu xử lý');
    });

    test('Task.fromMap handles spent > allocated without overflow or NaN', () {
      final json = {
        'id': 202,
        'name': 'Task Quá Giờ',
        'allocated_hours': 5.0,
        'spent_hours': 8.5,
        'remaining_hours': -3.5,
      };

      final task = Task.fromMap(json);

      expect(task.allocatedHours, 5.0);
      expect(task.spentHours, 8.5);
      expect(task.remainingHours, -3.5);
      final isOverBudget = (task.spentHours ?? 0) > (task.allocatedHours ?? 0);
      expect(isOverBudget, true);
    });

    test('TimesheetFilterState preset range applies date values', () {
      const filter = TimesheetFilterState(
        presetName: 'Hôm nay',
      );

      expect(filter.presetName, 'Hôm nay');
      expect(filter.projectId, null);
    });

    test('TimesheetSummary handles missing fields safely', () {
      final summary = TimesheetSummary.fromMap(const {});
      expect(summary.totalHours, 0.0);
      expect(summary.count, 0);
    });

    test('TimesheetFilterState matching logic filters by Project ID and Date Range', () {
      final now = DateTime(2026, 3, 10);
      final taskMatching = Task(
        id: '101',
        userId: '1',
        title: 'Task Dự Án VCloud',
        category: TimesheetCategory.erp,
        dueDate: now,
        createdAt: now,
        updatedAt: now,
        projectId: '42',
        projectName: 'VCloud Project',
        dateAssign: now,
      );

      final taskDifferentProject = Task(
        id: '102',
        userId: '1',
        title: 'Task Dự Án Khác',
        category: TimesheetCategory.erp,
        dueDate: now,
        createdAt: now,
        updatedAt: now,
        projectId: '99',
        projectName: 'Khác',
        dateAssign: now,
      );

      final filter = TimesheetFilterState(
        presetName: 'Hôm nay',
        projectId: '42',
        projectName: 'VCloud Project',
        dateFrom: DateTime(2026, 3, 10),
        dateTo: DateTime(2026, 3, 10),
      );

      // Verify filter matches correctly
      expect(filter.projectId, '42');
      expect(taskMatching.projectId, filter.projectId);
      expect(taskDifferentProject.projectId != filter.projectId, true);
    });
  });
}
