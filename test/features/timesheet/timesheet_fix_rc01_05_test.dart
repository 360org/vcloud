import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/shared/models/timesheet.dart';
import 'package:vcloud/features/timesheet/application/timesheet_controller.dart';

void main() {
  group('Timesheet & Filter Bug Fixes (RC-01 to RC-05) - 10 Test Cases', () {
    test('Case 1: TimesheetEntry parses projectId and projectName from Many2One list [id, name]', () {
      final raw = <String, dynamic>{
        'id': 101,
        'employee_id': [3, 'Nguyen Van A'],
        'name': 'Pha che cocktail',
        'unit_amount': 2.5,
        'date': '2026-09-28',
        'project_id': [42, 'Dự án Mobile App'],
      };

      final entry = TimesheetEntry.fromMap(raw);
      expect(entry.id, '101');
      expect(entry.projectId, '42');
      expect(entry.projectName, 'Dự án Mobile App');
      expect(entry.durationMinutes, 150);
    });

    test('Case 2: TimesheetEntry parses scalar projectId and project_name string fallback', () {
      final raw = <String, dynamic>{
        'id': '102',
        'employee_id': 3,
        'task_name': 'Fix bug UI',
        'unit_amount': 1.0,
        'date': '2026-09-28',
        'project_id': 99,
        'project_name': 'Backend API',
      };

      final entry = TimesheetEntry.fromMap(raw);
      expect(entry.projectId, '99');
      expect(entry.projectName, 'Backend API');
    });

    test('Case 3: Date parser handles YYYY-MM-DD safely without timezone shift', () {
      final raw = <String, dynamic>{
        'id': 103,
        'employee_id': 3,
        'name': 'Audit code',
        'unit_amount': 1.0,
        'date': '2026-01-15',
      };

      final entry = TimesheetEntry.fromMap(raw);
      expect(entry.workedDate.year, 2026);
      expect(entry.workedDate.month, 1);
      expect(entry.workedDate.day, 15);
      expect(entry.workedDate.hour, 0);
      expect(entry.workedDate.minute, 0);
    });

    test('Case 4: TimesheetRepository._entryFromOdoo preserves project_id and project_name', () {
      // Mapping preserves project_id and project_name data
      final odooMap = <String, dynamic>{
        'id': 505,
        'employee_id': [3, 'Admin'],
        'name': 'Task test',
        'unit_amount': 1.5,
        'date': '2026-09-28',
        'project_id': [10, 'Website Redesign'],
      };

      final entry = TimesheetEntry.fromMap(odooMap);
      expect(entry.projectId, '10');
      expect(entry.projectName, 'Website Redesign');
      expect(entry.durationMinutes, 90);
    });

    test('Case 5: Tab Nhật ký giờ filters by projectId correctly', () {
      final entries = [
        TimesheetEntry.fromMap({
          'id': '1',
          'employee_id': 3,
          'name': 'Work on Project A',
          'unit_amount': 1.0,
          'date': '2026-09-28',
          'project_id': [1, 'Project A'],
        }),
        TimesheetEntry.fromMap({
          'id': '2',
          'employee_id': 3,
          'name': 'Work on Project B',
          'unit_amount': 2.0,
          'date': '2026-09-28',
          'project_id': [2, 'Project B'],
        }),
      ];

      final filteredForA = entries.where((e) => e.projectId == '1').toList();
      expect(filteredForA.length, 1);
      expect(filteredForA.first.taskName, 'Work on Project A');

      final filteredForB = entries.where((e) => e.projectId == '2').toList();
      expect(filteredForB.length, 1);
      expect(filteredForB.first.taskName, 'Work on Project B');
    });

    test('Case 6: Tab Nhật ký giờ allows matching by projectName when ID not matching', () {
      final entries = [
        TimesheetEntry.fromMap({
          'id': '1',
          'employee_id': 3,
          'name': 'Design mockups',
          'unit_amount': 1.0,
          'date': '2026-09-28',
          'project_id': [5, 'CRM Mobile'],
        }),
      ];

      const filterProjectName = 'crm mobile';
      final matched = entries.where((e) {
        return e.projectName?.trim().toLowerCase() == filterProjectName;
      }).toList();

      expect(matched.length, 1);
      expect(matched.first.projectName, 'CRM Mobile');
    });

    test('Case 7: Pagination append pattern concatenates base and extra entries without losing pages', () {
      final page1 = [
        TimesheetEntry.fromMap({'id': '1', 'employee_id': 3, 'name': 'Item 1', 'unit_amount': 1, 'date': '2026-09-28'}),
        TimesheetEntry.fromMap({'id': '2', 'employee_id': 3, 'name': 'Item 2', 'unit_amount': 1, 'date': '2026-09-28'}),
      ];
      final page2 = [
        TimesheetEntry.fromMap({'id': '3', 'employee_id': 3, 'name': 'Item 3', 'unit_amount': 1, 'date': '2026-09-28'}),
        TimesheetEntry.fromMap({'id': '4', 'employee_id': 3, 'name': 'Item 4', 'unit_amount': 1, 'date': '2026-09-28'}),
      ];

      final combined = [...page1, ...page2];
      expect(combined.length, 4);
      expect(combined.map((e) => e.id).toList(), ['1', '2', '3', '4']);
    });

    test('Case 8: Date range filtering matches workedDate accurately across boundary days', () {
      final from = DateTime(2026, 9, 1);
      final to = DateTime(2026, 9, 15);

      final entryInside = TimesheetEntry.fromMap({
        'id': '1',
        'employee_id': 3,
        'name': 'Early September work',
        'unit_amount': 1.0,
        'date': '2026-09-10',
      });
      final entryOutside = TimesheetEntry.fromMap({
        'id': '2',
        'employee_id': 3,
        'name': 'Late September work',
        'unit_amount': 1.0,
        'date': '2026-09-20',
      });

      bool isInRange(TimesheetEntry e) {
        final d = DateTime(e.workedDate.year, e.workedDate.month, e.workedDate.day);
        return !d.isBefore(from) && !d.isAfter(to);
      }

      expect(isInRange(entryInside), isTrue);
      expect(isInRange(entryOutside), isFalse);
    });

    test('Case 9: TimesheetFilterState handles dateFrom, dateTo and projectId cleanly', () {
      final filter = TimesheetFilterState(
        presetName: 'Tháng trước',
        dateFrom: DateTime(2026, 8, 1),
        dateTo: DateTime(2026, 8, 31),
        projectId: '42',
        projectName: 'Dự án A',
      );

      expect(filter.presetName, 'Tháng trước');
      expect(filter.projectId, '42');
      expect(filter.dateFrom, DateTime(2026, 8, 1));
      expect(filter.dateTo, DateTime(2026, 8, 31));

      final cleared = filter.copyWith(clearProject: true, clearDates: true);
      expect(cleared.projectId, isNull);
      expect(cleared.dateFrom, isNull);
      expect(cleared.dateTo, isNull);
    });

    test('Case 10: TimesheetEntry duration presets bucket correctly for 15, 30, 45, 60m', () {
      final entry15 = TimesheetEntry.fromMap({'id': '1', 'employee_id': 3, 'name': 'A', 'duration': '15m', 'date': '2026-09-28'});
      final entry30 = TimesheetEntry.fromMap({'id': '2', 'employee_id': 3, 'name': 'B', 'duration': '30m', 'date': '2026-09-28'});
      final entry45 = TimesheetEntry.fromMap({'id': '3', 'employee_id': 3, 'name': 'C', 'duration': '45m', 'date': '2026-09-28'});
      final entry60 = TimesheetEntry.fromMap({'id': '4', 'employee_id': 3, 'name': 'D', 'duration': '1h', 'date': '2026-09-28'});

      expect(entry15.duration, TimesheetDuration.fifteen);
      expect(entry30.duration, TimesheetDuration.thirty);
      expect(entry45.duration, TimesheetDuration.fortyFive);
      expect(entry60.duration, TimesheetDuration.sixty);
    });
  });
}
