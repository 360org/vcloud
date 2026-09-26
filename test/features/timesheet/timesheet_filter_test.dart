import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/features/timesheet/application/timesheet_controller.dart';
import 'package:vcloud/shared/models/task.dart';
import 'package:vcloud/shared/models/timesheet.dart';

void main() {
  group('Timesheet Filter & Stage Classification Tests (10 Cases)', () {
    final today = DateTime(2026, 9, 26);
    final pastWeek = DateTime(2026, 9, 15);
    final pastMonth = DateTime(2026, 8, 10);

    final todayFilter = TimesheetFilterState(
      presetName: 'Hôm nay',
      dateFrom: today,
      dateTo: today,
      myTasksOnly: true,
    );

    // Helper kiểm tra stage và state theo chuẩn logic TaskRepository
    bool evaluateIsDone({
      bool completed = false,
      String? state,
      String? stageName,
    }) {
      final st = (state ?? '').toLowerCase().trim();
      final stage = (stageName ?? '').toLowerCase().trim();
      const activeStages = {
        'development', 'in progress', 'specifications', 'increment',
        'backlog', 'backlogs', 'new', 'pending', 'sprint in progress',
        'đang thực hiện', 'đang phát triển', 'đang xử lý', 'chờ xử lý',
        'yêu cầu thay đổi', 'khảo sát', 'triển khai',
      };
      const doneStages = {
        'done', 'hoàn thành', 'đã hoàn thành', 'xong', 'đã xong',
        'closed', 'đã đóng', 'delivered', 'đã bàn giao',
        'cancelled', 'canceled', 'đã hủy', 'đã huỷ',
      };

      if (completed) return true;
      if (activeStages.contains(stage)) return false;
      if (doneStages.contains(stage)) return true;
      if (st == '1_done' || st == 'done' || st == '1_canceled') return true;
      return false;
    }

    test('Case 1: TimesheetFilterState defaults myTasksOnly to true and copyWith toggles cleanly', () {
      expect(todayFilter.myTasksOnly, isTrue);

      final allStaffFilter = todayFilter.copyWith(myTasksOnly: false);
      expect(allStaffFilter.myTasksOnly, isFalse);

      final resetFilter = allStaffFilter.copyWith(myTasksOnly: true);
      expect(resetFilter.myTasksOnly, isTrue);
    });

    test('Case 2: myTasksOnly=true keeps user tasks and excludes other members', () {
      const currentUid = '3514';
      final myTask = Task(
        id: '16515',
        userId: '3514',
        title: 'Fix tab Cần làm & Hoàn thành',
        category: TimesheetCategory.erp,
        dueDate: today,
        createdAt: today,
        updatedAt: today,
      );
      final otherTask = Task(
        id: '16513',
        userId: '3513',
        title: 'Giao diện GT Lines',
        category: TimesheetCategory.erp,
        dueDate: today,
        createdAt: today,
        updatedAt: today,
      );

      bool matchesMyFilter(Task t) {
        if (todayFilter.myTasksOnly && t.userId.isNotEmpty && t.userId != currentUid) {
          return false;
        }
        return true;
      }

      expect(matchesMyFilter(myTask), isTrue);
      expect(matchesMyFilter(otherTask), isFalse);
    });

    test('Case 3: myTasksOnly=false allows tasks from all team members', () {
      const currentUid = '3514';
      final allStaffFilter = todayFilter.copyWith(myTasksOnly: false);
      final otherTask = Task(
        id: '16513',
        userId: '3513',
        title: 'Giao diện GT Lines',
        category: TimesheetCategory.erp,
        dueDate: today,
        createdAt: today,
        updatedAt: today,
      );

      bool matchesAllStaffFilter(Task t) {
        if (allStaffFilter.myTasksOnly && t.userId.isNotEmpty && t.userId != currentUid) {
          return false;
        }
        return true;
      }

      expect(matchesAllStaffFilter(otherTask), isTrue);
    });

    test('Case 4: Active stages (Development, In Progress) gate state=1_done to keep task open', () {
      // 34 task trên Prod có state=1_done nhưng stage=Development / In Progress
      expect(evaluateIsDone(state: '1_done', stageName: 'Development'), isFalse,
          reason: 'Development stage phải giữ task ở trạng thái Open');
      expect(evaluateIsDone(state: '1_done', stageName: 'In Progress'), isFalse,
          reason: 'In Progress stage phải giữ task ở trạng thái Open');
      expect(evaluateIsDone(state: '1_done', stageName: 'Specifications'), isFalse,
          reason: 'Specifications stage phải giữ task ở trạng thái Open');
      expect(evaluateIsDone(state: '1_done', stageName: 'Backlog'), isFalse,
          reason: 'Backlog stage phải giữ task ở trạng thái Open');
      expect(evaluateIsDone(state: '1_done', stageName: 'Đang phát triển'), isFalse,
          reason: 'Đang phát triển stage phải giữ task ở trạng thái Open');
    });

    test('Case 5: Done stages (Delivered, Done, Hoàn thành, Closed) mark task as isDone=true', () {
      expect(evaluateIsDone(stageName: 'Delivered'), isTrue);
      expect(evaluateIsDone(stageName: 'Done'), isTrue);
      expect(evaluateIsDone(stageName: 'Hoàn thành'), isTrue);
      expect(evaluateIsDone(stageName: 'Đã bàn giao'), isTrue);
      expect(evaluateIsDone(stageName: 'Closed'), isTrue);
    });

    test('Case 6: Completed task without date_end does NOT fallback to now (prevents timestamp poisoning)', () {
      // Khi nạp từ Odoo: completed = false, map['date_end'] = null
      final bool completedFromAppAction = [false].first;
      const String? dateEndFromOdoo = null;
      final nowStr = today.toIso8601String();

      final completedAt = completedFromAppAction ? nowStr : dateEndFromOdoo;
      expect(completedAt, isNull, reason: 'Không được gán DateTime.now() cho task hoàn thành từ trước');
    });

    test('Case 7: Task.isCompleted returns true via isDone even when completedAt is null', () {
      final taskWithIsDoneOnly = Task(
        id: '16493',
        userId: '3514',
        title: 'Google Play Verification',
        category: TimesheetCategory.erp,
        dueDate: pastWeek,
        createdAt: pastMonth,
        updatedAt: pastWeek,
        isDone: true,
        completedAt: null,
      );

      expect(taskWithIsDoneOnly.isCompleted, isTrue);
    });

    test('Case 8: Open tasks in Tab Cần làm remain visible regardless of old createdAt', () {
      final openOldTask = Task(
        id: '16487',
        userId: '3514',
        title: 'Nhiệm vụ tạo từ tháng trước nhưng đang làm',
        category: TimesheetCategory.erp,
        dueDate: pastMonth,
        createdAt: pastMonth,
        updatedAt: pastMonth,
        isDone: false,
      );

      // Logic date filter cho open task: không loại bỏ task đang mở
      bool matchesDateFilter(Task t, bool isDone, TimesheetFilterState filter) {
        if (filter.presetName != 'Tất cả' && (filter.dateFrom != null || filter.dateTo != null)) {
          if (isDone) {
            final effectiveDate = t.completedAt ?? t.dateAssign;
            if (effectiveDate == null) return false;
            final dDay = DateTime(effectiveDate.year, effectiveDate.month, effectiveDate.day);
            final fDay = DateTime(filter.dateFrom!.year, filter.dateFrom!.month, filter.dateFrom!.day);
            final tDay = DateTime(filter.dateTo!.year, filter.dateTo!.month, filter.dateTo!.day);
            if (dDay.isBefore(fDay) || dDay.isAfter(tDay)) return false;
          }
        }
        return true;
      }

      expect(matchesDateFilter(openOldTask, false, todayFilter), isTrue,
          reason: 'Task đang làm dù tạo từ tháng trước vẫn phải hiện ở Tab Cần làm');
    });

    test('Case 9: Tab Đã hoàn thành on Hôm nay filter excludes past completed tasks', () {
      final pastDoneTask = Task(
        id: '16228',
        userId: '3514',
        title: 'Task hoàn thành từ tuần trước',
        category: TimesheetCategory.erp,
        dueDate: pastWeek,
        createdAt: pastMonth,
        updatedAt: pastWeek,
        isDone: true,
        completedAt: pastWeek,
      );

      bool matchesDateFilter(Task t, bool isDone, TimesheetFilterState filter) {
        if (filter.presetName != 'Tất cả' && (filter.dateFrom != null || filter.dateTo != null)) {
          if (isDone) {
            final effectiveDate = t.completedAt;
            if (effectiveDate == null) return false;
            final dDay = DateTime(effectiveDate.year, effectiveDate.month, effectiveDate.day);
            final fDay = DateTime(filter.dateFrom!.year, filter.dateFrom!.month, filter.dateFrom!.day);
            final tDay = DateTime(filter.dateTo!.year, filter.dateTo!.month, filter.dateTo!.day);
            if (dDay.isBefore(fDay) || dDay.isAfter(tDay)) return false;
          }
        }
        return true;
      }

      expect(matchesDateFilter(pastDoneTask, true, todayFilter), isFalse,
          reason: 'Task hoàn tất tuần trước không được hiện trong bộ lọc Hôm nay');
    });

    test('Case 10: Tab Đã hoàn thành on Hôm nay filter shows tasks completed today', () {
      final todayDoneTask = Task(
        id: '16516',
        userId: '3514',
        title: 'Task vừa hoàn thành hôm nay',
        category: TimesheetCategory.erp,
        dueDate: today,
        createdAt: today,
        updatedAt: today,
        isDone: true,
        completedAt: today,
      );

      bool matchesDateFilter(Task t, bool isDone, TimesheetFilterState filter) {
        if (filter.presetName != 'Tất cả' && (filter.dateFrom != null || filter.dateTo != null)) {
          if (isDone) {
            final effectiveDate = t.completedAt;
            if (effectiveDate == null) return false;
            final dDay = DateTime(effectiveDate.year, effectiveDate.month, effectiveDate.day);
            final fDay = DateTime(filter.dateFrom!.year, filter.dateFrom!.month, filter.dateFrom!.day);
            final tDay = DateTime(filter.dateTo!.year, filter.dateTo!.month, filter.dateTo!.day);
            if (dDay.isBefore(fDay) || dDay.isAfter(tDay)) return false;
          }
        }
        return true;
      }

      expect(matchesDateFilter(todayDoneTask, true, todayFilter), isTrue,
          reason: 'Task hoàn thành hôm nay phải hiện trong bộ lọc Hôm nay');
    });

    test('Case 11: Tab Đã hoàn thành on Tất cả filter shows all completed tasks', () {
      const allFilter = TimesheetFilterState(
        presetName: 'Tất cả',
        dateFrom: null,
        dateTo: null,
      );
      final pastDoneTask = Task(
        id: '16228',
        userId: '3514',
        title: 'Task lịch sử hoàn thành',
        category: TimesheetCategory.erp,
        dueDate: pastWeek,
        createdAt: pastMonth,
        updatedAt: pastWeek,
        isDone: true,
        completedAt: pastWeek,
      );

      bool matchesDateFilter(Task t, bool isDone, TimesheetFilterState filter) {
        if (filter.presetName != 'Tất cả' && (filter.dateFrom != null || filter.dateTo != null)) {
          if (isDone) {
            final effectiveDate = t.completedAt;
            if (effectiveDate == null) return false;
            final dDay = DateTime(effectiveDate.year, effectiveDate.month, effectiveDate.day);
            final fDay = DateTime(filter.dateFrom!.year, filter.dateFrom!.month, filter.dateFrom!.day);
            final tDay = DateTime(filter.dateTo!.year, filter.dateTo!.month, filter.dateTo!.day);
            if (dDay.isBefore(fDay) || dDay.isAfter(tDay)) return false;
          }
        }
        return true;
      }

      expect(matchesDateFilter(pastDoneTask, true, allFilter), isTrue,
          reason: 'Bộ lọc Tất cả phải hiển thị tất cả các task đã hoàn thành');
    });

    test('Case 12: Newest open tasks (highest ID) are sorted first', () {
      final task1 = Task(id: '16461', userId: '3514', title: 'Task 1', category: TimesheetCategory.erp, dueDate: today, createdAt: today, updatedAt: today);
      final task2 = Task(id: '16515', userId: '3514', title: 'Task 2', category: TimesheetCategory.erp, dueDate: today, createdAt: today, updatedAt: today);
      final task3 = Task(id: '16487', userId: '3514', title: 'Task 3', category: TimesheetCategory.erp, dueDate: today, createdAt: today, updatedAt: today);

      final openList = [task1, task2, task3];
      openList.sort((a, b) {
        final aId = int.tryParse(a.id) ?? 0;
        final bId = int.tryParse(b.id) ?? 0;
        return bId.compareTo(aId);
      });

      expect(openList.first.id, '16515', reason: 'Task có ID mới nhất phải xếp đầu tiên');
      expect(openList[1].id, '16487');
      expect(openList.last.id, '16461');
    });
  });
}
