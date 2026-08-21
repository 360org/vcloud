import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/task.dart';
import '../../../shared/models/task_message.dart';
import '../../../shared/models/timesheet.dart';
import '../data/task_repository.dart';

final taskRepositoryProvider = Provider<TaskRepository>(
  (_) => TaskRepository(),
);

/// HTTP refresh stream of the current user's tasks due *today*.
final todayTasksProvider = StreamProvider<List<Task>>(
  (ref) => ref.read(taskRepositoryProvider).watchToday(),
);


final _completedTaskIdsProvider = StateProvider<Set<String>>(
  (_) => const <String>{},
);

class CompletedTaskLog {
  const CompletedTaskLog({
    required this.summary,
    required this.duration,
    required this.completedAt,
  });

  final String summary;
  final Duration duration;
  final DateTime completedAt;
}

final completedTaskLogsProvider = StateProvider<Map<String, CompletedTaskLog>>(
  (_) => const <String, CompletedTaskLog>{},
);

/// Convenience split used by the screen UI — keeps the sort in one place
/// so the open list renders in `createdAt` order (oldest first, "queue
/// feel") and the completed list newest first.
final todayTasksSplitProvider = Provider<({List<Task> open, List<Task> done})>((
  ref,
) {
  final list = ref.watch(todayTasksProvider).valueOrNull ?? const <Task>[];
  final locallyCompleted = ref.watch(_completedTaskIdsProvider);
  final open = <Task>[];
  final done = <Task>[];
  for (final t in list) {
    (t.isCompleted || locallyCompleted.contains(t.id) ? done : open).add(t);
  }
  open.sort((a, b) => a.createdAt.compareTo(b.createdAt));
  done.sort(
    (a, b) =>
        (b.completedAt ?? b.updatedAt).compareTo(a.completedAt ?? a.updatedAt),
  );
  return (open: open, done: done);
});

class TaskActions {
  TaskActions(this._repo, this._ref);
  final TaskRepository _repo;
  final Ref _ref;

  Future<List<TimesheetProjectOption>> listProjects() {
    return _repo.listProjects();
  }

  Future<List<Task>> listAllTasks() {
    return _repo.listAllTasks();
  }

  Future<List<Task>> listProjectTasks(String projectId) {
    return _repo.listProjectTasks(projectId);
  }

  Future<Task> create({
    required String title,
    String? description,
    TimesheetCategory category = TimesheetCategory.other,
    DateTime? dueDate,
  }) async {
    final t = await _repo.create(
      title: title,
      description: description,
      category: category,
      dueDate: dueDate,
    );
    _ref.invalidate(todayTasksProvider);
    return t;
  }

  /// Log time + mark task complete in a single RPC call.
  ///
  /// Only the tasks stream is invalidated here; callers that also care
  /// about the timesheet entries list (e.g. the entries view + home
  /// summary) should invalidate [timesheetStreamProvider] themselves.
  Future<Task> complete({
    required String taskId,
    required String summary,
    required TimesheetDuration duration,
    Duration? elapsed,
  }) async {
    final t = await _repo.complete(
      taskId: taskId,
      summary: summary,
      duration: duration,
      elapsed: elapsed,
    );
    _ref
        .read(_completedTaskIdsProvider.notifier)
        .update((ids) => <String>{...ids, taskId});
    _ref
        .read(completedTaskLogsProvider.notifier)
        .update(
          (logs) => <String, CompletedTaskLog>{
            ...logs,
            taskId: CompletedTaskLog(
              summary: summary,
              duration: elapsed ?? duration.duration,
              completedAt: DateTime.now(),
            ),
          },
        );
    _ref.invalidate(todayTasksProvider);
    return t;
  }

  Future<void> delete(String id) async {
    await _repo.delete(id);
    _ref.read(_completedTaskIdsProvider.notifier).update((ids) {
      final next = <String>{...ids}..remove(id);
      return next;
    });
    _ref.read(completedTaskLogsProvider.notifier).update((logs) {
      final next = <String, CompletedTaskLog>{...logs}..remove(id);
      return next;
    });
    _ref.invalidate(todayTasksProvider);
  }

  /// Log a work-session against an existing task **without** marking
  /// it complete. Useful when the user wants to record time/note
  /// mid-task (and re-edit later) via the task-detail sheet.
  Future<Task> log({
    required String taskId,
    required String summary,
    required TimesheetDuration duration,
    Duration? elapsed,
  }) async {
    final t = await _repo.log(
      taskId: taskId,
      summary: summary,
      duration: duration,
      elapsed: elapsed,
    );
    _ref.invalidate(todayTasksProvider);
    return t;
  }

  /// Lưu workflow trên Odoo trước khi màn hình phản ánh trạng thái mới.
  Future<Task> updateWorkflow({
    required String taskId,
    required String status,
  }) async {
    final task = await _repo.updateWorkflow(taskId: taskId, status: status);
    _ref.invalidate(todayTasksProvider);
    return task;
  }

  /// Edit a previously-completed task's logged time + note. The screen
  /// is responsible for invalidating [timesheetStreamProvider] itself,
  /// to keep this module free of a circular dependency on
  /// [timesheetController] (which already imports `task_controller`).
  Future<Task> update({
    required String taskId,
    required String timesheetEntryId,
    required String summary,
    required TimesheetDuration duration,
  }) async {
    final t = await _repo.update(
      taskId: taskId,
      timesheetEntryId: timesheetEntryId,
      summary: summary,
      duration: duration,
    );
    // Keep the local "what I did" cache consistent so a screen refresh
    // that races the stream doesn't snap back to the stale summary.
    final durationValue = duration.duration;
    _ref.read(completedTaskLogsProvider.notifier).update((logs) {
      final existing = logs[taskId];
      return <String, CompletedTaskLog>{
        ...logs,
        taskId: CompletedTaskLog(
          summary: summary,
          duration: durationValue,
          completedAt: existing?.completedAt ?? DateTime.now(),
        ),
      };
    });
    _ref.invalidate(todayTasksProvider);
    return t;
  }
  /// Thêm ghi chú/bình luận vào task chatter.
  Future<TaskMessage> addMessage({
    required String taskId,
    required String content,
  }) async {
    final msg = await _repo.addMessage(taskId: taskId, content: content);
    _ref.invalidate(taskDetailProvider(taskId));
    return msg;
  }
}

final taskDetailProvider = FutureProvider.family<Task, String>((ref, taskId) {
  return ref.read(taskRepositoryProvider).getTaskDetail(taskId);
});

final taskActionsProvider = Provider(
  (ref) => TaskActions(ref.read(taskRepositoryProvider), ref),
);
