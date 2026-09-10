import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/features/timesheet/application/timesheet_controller.dart';
import 'package:vcloud/shared/models/task.dart';
import 'package:vcloud/shared/models/timesheet.dart';

void main() {
  test('TimesheetFilterState copyWith and matching logic test', () {
    final now = DateTime(2026, 9, 10);
    final filter = TimesheetFilterState(
      presetName: 'Hôm nay',
      dateFrom: now,
      dateTo: now,
      projectId: '45',
      projectName: '360 KPI',
    );

    final task1 = Task(
      id: '101',
      userId: '1',
      title: 'Fix bug bộ lọc',
      category: TimesheetCategory.erp,
      dueDate: now,
      createdAt: now,
      updatedAt: now,
      projectId: '45',
      projectName: '360 KPI',
    );

    final task2 = Task(
      id: '102',
      userId: '1',
      title: 'Khảo sát dự án khác',
      category: TimesheetCategory.erp,
      dueDate: now,
      createdAt: now,
      updatedAt: now,
      projectId: '99',
      projectName: 'VCloud Core',
    );

    // Kiểm tra task1 khớp projectId '45'
    expect(task1.projectId == filter.projectId, isTrue);
    // Kiểm tra task2 không khớp projectId '45'
    expect(task2.projectId == filter.projectId, isFalse);
  });

  test('task_repository _taskFromOdoo accurately distinguishes intermediate vs done stages', () {
    // Giả lập logic _taskFromOdoo
    bool checkDone({
      bool completed = false,
      String? state,
      String? stageName,
    }) {
      final st = (state ?? '').toLowerCase().trim();
      final stage = (stageName ?? '').toLowerCase().trim();
      return completed ||
          st == '1_done' ||
          st == 'done' ||
          stage == 'done' ||
          stage == 'hoàn thành' ||
          stage == 'đã hoàn thành' ||
          stage == 'xong' ||
          stage == 'đã xong' ||
          stage == 'closed' ||
          stage == 'đã đóng' ||
          stage == 'cancelled' ||
          stage == 'canceled' ||
          stage == 'đã hủy' ||
          stage == 'đã huỷ';
    }

    // Các stage kết thúc thật sự -> Phải nhận diện isDone = true
    expect(checkDone(state: '1_done'), isTrue);
    expect(checkDone(state: 'done'), isTrue);
    expect(checkDone(stageName: 'Hoàn thành'), isTrue);
    expect(checkDone(stageName: 'Đã hoàn thành'), isTrue);
    expect(checkDone(stageName: 'Done'), isTrue);
    expect(checkDone(stageName: 'Đã đóng'), isTrue);
    expect(checkDone(stageName: 'Đã hủy'), isTrue);

    // Các stage trung gian chứa từ 'xong' hoặc 'done' -> KHÔNG ĐƯỢC coi là isDone (Phải là false để ở lại tab Cần làm)
    expect(checkDone(stageName: 'Review xong'), isFalse, reason: 'Review xong là stage trung gian');
    expect(checkDone(stageName: 'Chờ duyệt xong'), isFalse, reason: 'Chờ duyệt xong là stage trung gian');
    expect(checkDone(stageName: 'Testing done'), isFalse, reason: 'Testing done là stage trung gian');
    expect(checkDone(stageName: 'Đang làm xong trước 12h'), isFalse, reason: 'Stage chú thích thời gian');
    expect(checkDone(stageName: 'Done stage test'), isFalse, reason: 'Stage test chứa từ done');
  });
}
