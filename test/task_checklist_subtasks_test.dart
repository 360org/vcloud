import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:vcloud/features/timesheet/presentation/widgets/checklist_editor.dart';
import 'package:vcloud/shared/models/task.dart';
import 'package:vcloud/shared/models/timesheet.dart';

void main() {
  group('BUG-010: calculateSubtaskProgress Calculation Tests', () {
    test('returns 0.0% when subtasks list is empty', () {
      expect(calculateSubtaskProgress([]), 0.0);
    });

    test('returns 0.0% when 0 of N subtasks are completed', () {
      final items = [
        const TaskChecklistItem(id: '1', title: 'Task 1', isCompleted: false),
        const TaskChecklistItem(id: '2', title: 'Task 2', isCompleted: false),
        const TaskChecklistItem(id: '3', title: 'Task 3', isCompleted: false),
      ];
      expect(calculateSubtaskProgress(items), 0.0);
    });

    test('returns 25.0% when 1 of 4 subtasks is completed', () {
      final items = [
        const TaskChecklistItem(id: '1', title: 'Task 1', isCompleted: true),
        const TaskChecklistItem(id: '2', title: 'Task 2', isCompleted: false),
        const TaskChecklistItem(id: '3', title: 'Task 3', isCompleted: false),
        const TaskChecklistItem(id: '4', title: 'Task 4', isCompleted: false),
      ];
      expect(calculateSubtaskProgress(items), 25.0);
    });

    test('returns 50.0% when 1 of 2 subtasks is completed', () {
      final items = [
        const TaskChecklistItem(id: '1', title: 'Task 1', isCompleted: true),
        const TaskChecklistItem(id: '2', title: 'Task 2', isCompleted: false),
      ];
      expect(calculateSubtaskProgress(items), 50.0);
    });

    test('returns 75.0% when 3 of 4 subtasks are completed', () {
      final items = [
        const TaskChecklistItem(id: '1', title: 'Task 1', isCompleted: true),
        const TaskChecklistItem(id: '2', title: 'Task 2', isCompleted: true),
        const TaskChecklistItem(id: '3', title: 'Task 3', isCompleted: true),
        const TaskChecklistItem(id: '4', title: 'Task 4', isCompleted: false),
      ];
      expect(calculateSubtaskProgress(items), 75.0);
    });

    test('returns 100.0% when all subtasks are completed', () {
      final items = [
        const TaskChecklistItem(id: '1', title: 'Task 1', isCompleted: true),
        const TaskChecklistItem(id: '2', title: 'Task 2', isCompleted: true),
      ];
      expect(calculateSubtaskProgress(items), 100.0);
    });
  });

  group('BUG-010: TaskChecklistItem Model Tests', () {
    test('serialization toMap and fromMap round-trip', () {
      const item = TaskChecklistItem(
        id: 'st_123',
        title: 'Review pull request',
        isCompleted: true,
      );

      final map = item.toMap();
      expect(map['id'], 'st_123');
      expect(map['title'], 'Review pull request');
      expect(map['is_completed'], true);

      final restored = TaskChecklistItem.fromMap(map);
      expect(restored, item);
      expect(restored.hashCode, item.hashCode);
    });

    test('copyWith updates properties correctly', () {
      const item = TaskChecklistItem(id: 'st_1', title: 'Design API');
      final updated = item.copyWith(isCompleted: true, title: 'Design REST API');

      expect(updated.id, 'st_1');
      expect(updated.title, 'Design REST API');
      expect(updated.isCompleted, true);
    });
  });

  group('BUG-010: Task Integration with Subtasks & Progress', () {
    test('Task calculates subtaskProgressPercent correctly', () {
      final taskWithSubtasks = Task(
        id: 'task_1',
        userId: '1',
        title: 'Complete feature',
        category: TimesheetCategory.erp,
        dueDate: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        subtasks: const [
          TaskChecklistItem(id: 's1', title: 'Subtask 1', isCompleted: true),
          TaskChecklistItem(id: 's2', title: 'Subtask 2', isCompleted: false),
        ],
      );

      expect(taskWithSubtasks.subtasks.length, 2);
      expect(taskWithSubtasks.subtaskProgressPercent, 50.0);
    });

    test('Task.fromMap parses subtasks list correctly', () {
      final rawMap = {
        'id': '99',
        'title': 'Test Subtasks Parsing',
        'category': 'erp',
        'subtasks': [
          {'id': 'sub_1', 'title': 'Draft spec', 'is_completed': true},
          {'id': 'sub_2', 'title': 'Implement', 'is_completed': false},
          {'id': 'sub_3', 'title': 'Verify', 'is_completed': true},
        ],
      };

      final parsed = Task.fromMap(rawMap);
      expect(parsed.subtasks.length, 3);
      expect(parsed.subtasks[0].title, 'Draft spec');
      expect(parsed.subtasks[0].isCompleted, true);
      expect(parsed.subtasks[1].isCompleted, false);
      expect(parsed.subtasks[2].isCompleted, true);
      // 2/3 = 66.666...%
      expect(parsed.subtaskProgressPercent, closeTo(66.66, 0.1));
    });
  });

  group('BUG-010: TaskChecklistEditor Widget Tests', () {
    testWidgets('renders subtasks, progress bar, and percentage label', (tester) async {
      final noteController = TextEditingController();
      final initialSubtasks = [
        const TaskChecklistItem(id: 's1', title: 'Viết test cases', isCompleted: true),
        const TaskChecklistItem(id: 's2', title: 'Chạy phân tích linter', isCompleted: false),
      ];

      double? currentProgress;
      List<TaskChecklistItem>? changedSubtasks;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TaskChecklistEditor(
                noteController: noteController,
                duration: TimesheetDuration.thirty,
                saving: false,
                onDurationChanged: (_) {},
                onSave: () {},
                initialSubtasks: initialSubtasks,
                onProgressChanged: (p) => currentProgress = p,
                onSubtasksChanged: (list) => changedSubtasks = list,
              ),
            ),
          ),
        ),
      );

      // Verify header and 50% (1/2) badge
      expect(find.text('Đầu việc & tiến độ'), findsOneWidget);
      expect(find.text('50% (1/2)'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);

      // Verify subtask titles
      expect(find.text('Viết test cases'), findsOneWidget);
      expect(find.text('Chạy phân tích linter'), findsOneWidget);

      // Toggle second subtask to completed
      await tester.tap(find.text('Chạy phân tích linter'));
      await tester.pumpAndSettle();

      // Badge should update to 100% (2/2)
      expect(find.text('100% (2/2)'), findsOneWidget);
      expect(currentProgress, 100.0);
      expect(changedSubtasks?.every((s) => s.isCompleted), true);
    });

    testWidgets('allows adding a new subtask dynamically', (tester) async {
      final noteController = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TaskChecklistEditor(
                noteController: noteController,
                duration: TimesheetDuration.thirty,
                saving: false,
                onDurationChanged: (_) {},
                onSave: () {},
                initialSubtasks: const [
                  TaskChecklistItem(id: 's1', title: 'Setup database', isCompleted: true),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('100% (1/1)'), findsOneWidget);

      // Enter a new subtask
      final inputFinder = find.byType(TextField).first;
      await tester.enterText(inputFinder, 'Deploy API backend');
      await tester.pumpAndSettle();

      // Tap the plus button
      await tester.tap(find.byIcon(LucideIcons.plus).first);
      await tester.pumpAndSettle();

      // Now should have 2 subtasks, 1 completed -> 50% (1/2)
      expect(find.text('Deploy API backend'), findsOneWidget);
      expect(find.text('50% (1/2)'), findsOneWidget);
    });
  });
}
