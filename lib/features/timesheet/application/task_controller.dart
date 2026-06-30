import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/task.dart';
import '../../../shared/models/timesheet.dart';
import '../data/task_repository.dart';

final taskRepositoryProvider = Provider<TaskRepository>(
  (_) => TaskRepository(),
);

/// Realtime stream of the current user's tasks due *today*.
final todayTasksProvider = StreamProvider.autoDispose<List<Task>>(
  (ref) => ref.read(taskRepositoryProvider).watchToday(),
);

/// Convenience split used by the screen UI — keeps the sort in one place
/// so the open list renders in `createdAt` order (oldest first, "queue
/// feel") and the completed list newest first.
final todayTasksSplitProvider =
    Provider<({List<Task> open, List<Task> done})>((ref) {
      final list = ref.watch(todayTasksProvider).value ?? const <Task>[];
      final open = <Task>[];
      final done = <Task>[];
      for (final t in list) {
        (t.isCompleted ? done : open).add(t);
      }
      open.sort((a, b) => a.createdAt.compareTo(b.createdAt));
      done.sort((a, b) => b.completedAt!.compareTo(a.completedAt!));
      return (open: open, done: done);
    });

class TaskActions {
  TaskActions(this._repo, this._ref);
  final TaskRepository _repo;
  final Ref _ref;

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
  }) async {
    final t = await _repo.complete(
      taskId: taskId,
      summary: summary,
      duration: duration,
    );
    _ref.invalidate(todayTasksProvider);
    return t;
  }

  Future<void> delete(String id) async {
    await _repo.delete(id);
    _ref.invalidate(todayTasksProvider);
  }
}

final taskActionsProvider = Provider(
  (ref) => TaskActions(ref.read(taskRepositoryProvider), ref),
);
