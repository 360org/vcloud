import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/timesheet.dart';
import '../../../shared/models/timesheet_summary.dart';
import '../data/timesheet_repository.dart';
import 'task_controller.dart';

final timesheetRepositoryProvider = Provider<TimesheetRepository>(
  (_) => TimesheetRepository(),
);

final timesheetStreamProvider = StreamProvider<List<TimesheetEntry>>(
  (ref) => ref.read(timesheetRepositoryProvider).watchRecent(),
);


/// Sum of today's durations. Used by the home dashboard.
final todayTotalMinutesProvider = Provider<int>((ref) {
  final list =
      ref.watch(timesheetStreamProvider).valueOrNull ??
      const <TimesheetEntry>[];
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  var total = 0;
  for (final e in list) {
    final wd = DateTime(
      e.workedDate.year,
      e.workedDate.month,
      e.workedDate.day,
    );
    if (wd == today) total += e.durationMinutes;
  }
  return total;
});

enum TimesheetTimerStatus { idle, running, paused }

/// New buckets are 15 / 30 / 45 / 60 minutes. Thresholds sit at the
/// midpoint between adjacent buckets so a stopwatch reading rounds
/// "down" to the bucket below its midpoint and "up" to the bucket
/// above:
///   ≤22 → 15m    (midpoint 15 / 30)
///   ≤37 → 30m    (midpoint 30 / 45)
///   ≤52 → 45m    (midpoint 45 / 60)
///   larger → 60m
TimesheetDuration durationBucketForElapsed(Duration elapsed) {
  final minutes = elapsed.inMinutes;
  if (minutes <= 22) return TimesheetDuration.fifteen;
  if (minutes <= 37) return TimesheetDuration.thirty;
  if (minutes <= 52) return TimesheetDuration.fortyFive;
  return TimesheetDuration.sixty;
}

class TimesheetTimerState {
  const TimesheetTimerState({
    this.taskName = '',
    this.category = TimesheetCategory.erp,
    this.status = TimesheetTimerStatus.idle,
    this.startedAt,
    this.accumulated = Duration.zero,
    this.taskId,
    this.taskTitle,
  });

  final String taskName;
  final TimesheetCategory category;
  final TimesheetTimerStatus status;
  final DateTime? startedAt;
  final Duration accumulated;

  /// Optional task the timer is logging against. When set, [stopAndSave]
  /// delegates to [TaskActions.complete] instead of writing a free-text
  /// timesheet row, so the task is atomically flipped to "completed".
  final String? taskId;

  /// Display-only mirror of the chosen task, so the timer card can
  /// show "Gắn vào: {title}" without re-fetching the full list.
  final String? taskTitle;

  bool get isRunning => status == TimesheetTimerStatus.running;
  bool get isPaused => status == TimesheetTimerStatus.paused;
  bool get isIdle => status == TimesheetTimerStatus.idle;

  Duration elapsed({DateTime? now}) {
    if (!isRunning || startedAt == null) return accumulated;
    return accumulated + (now ?? DateTime.now()).difference(startedAt!);
  }

  TimesheetTimerState copyWith({
    String? taskName,
    TimesheetCategory? category,
    TimesheetTimerStatus? status,
    DateTime? startedAt,
    Duration? accumulated,
    String? taskId,
    String? taskTitle,
    bool clearStartedAt = false,
    bool clearTask = false,
  }) => TimesheetTimerState(
    taskName: taskName ?? this.taskName,
    category: category ?? this.category,
    status: status ?? this.status,
    startedAt: clearStartedAt ? null : (startedAt ?? this.startedAt),
    accumulated: accumulated ?? this.accumulated,
    taskId: clearTask ? null : (taskId ?? this.taskId),
    taskTitle: clearTask ? null : (taskTitle ?? this.taskTitle),
  );
}

class TimesheetTimerController extends Notifier<TimesheetTimerState> {
  @override
  TimesheetTimerState build() => const TimesheetTimerState();

  void updateTask(String value) {
    state = state.copyWith(taskName: value);
  }

  void updateCategory(TimesheetCategory category) {
    state = state.copyWith(category: category);
  }

  /// Pins the timer to a specific task. Pass `null` or use [clearTask]
  /// to detach.
  void setTask({required String id, required String title}) {
    state = state.copyWith(taskId: id, taskTitle: title);
  }

  void clearTask() {
    state = state.copyWith(clearTask: true);
  }

  void start() {
    if (state.isRunning) return;
    state = state.copyWith(
      status: TimesheetTimerStatus.running,
      startedAt: DateTime.now(),
    );
  }

  void pause() {
    if (!state.isRunning) return;
    state = state.copyWith(
      status: TimesheetTimerStatus.paused,
      accumulated: state.elapsed(),
      clearStartedAt: true,
    );
  }

  void resume() {
    if (!state.isPaused) return;
    state = state.copyWith(
      status: TimesheetTimerStatus.running,
      startedAt: DateTime.now(),
    );
  }

  void reset() {
    state = const TimesheetTimerState();
  }

  /// Persist the running timer. When [TimesheetTimerState.taskId] is
  /// set, this routes through [TaskActions.complete] (atomic RPC) so
  /// the linked task is marked complete in the same call. Otherwise we
  /// fall back to the legacy free-text [TimesheetActions.add].
  Future<TimesheetDuration> stopAndSave({
    required TimesheetActions timesheetActions,
    required TaskActions taskActions,
  }) async {
    final taskName = state.taskName.trim();
    if (taskName.isEmpty) {
      throw ArgumentError('Nhập tên công việc trước đã.');
    }
    final elapsed = state.elapsed();
    final duration = durationBucketForElapsed(elapsed);
    final taskId = state.taskId;
    if (taskId != null) {
      await taskActions.complete(
        taskId: taskId,
        summary: taskName,
        duration: duration,
        elapsed: elapsed,
      );
      // refresh both streams so the entries list and task list update.
      timesheetActions.invalidateTimesheetStream();
    } else {
      await timesheetActions.add(
        taskName: taskName,
        category: state.category,
        duration: duration,
      );
    }
    reset();
    return duration;
  }
}

final timesheetTimerControllerProvider =
    NotifierProvider<TimesheetTimerController, TimesheetTimerState>(
      TimesheetTimerController.new,
    );

class TimesheetActions {
  TimesheetActions(this._repo, this._ref);
  final TimesheetRepository _repo;
  final Ref _ref;

  /// Allow other collaborators (e.g. the timer stopAndSave flow when
  /// it completes a task via the RPC) to nudge [timesheetStreamProvider]
  /// without exposing the provider symbol publicly.
  void invalidateTimesheetStream() {
    _ref.invalidate(timesheetStreamProvider);
  }

  Future<void> add({
    required String taskName,
    required TimesheetCategory category,
    required TimesheetDuration duration,
    String? taskId,
  }) async {
    await _repo.add(
      taskName: taskName,
      category: category,
      duration: duration,
      taskId: taskId,
    );
    _ref.invalidate(timesheetStreamProvider);
  }

  Future<void> delete(String id) async {
    await _repo.delete(id);
    _ref.invalidate(timesheetStreamProvider);
  }
}

final timesheetActionsProvider = Provider(
  (ref) => TimesheetActions(ref.read(timesheetRepositoryProvider), ref),
);

class TimesheetFilterState {
  const TimesheetFilterState({
    this.presetName = 'Hôm nay',
    this.dateFrom,
    this.dateTo,
    this.projectId,
    this.projectName,
  });

  final String presetName;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? projectId;
  final String? projectName;

  TimesheetFilterState copyWith({
    String? presetName,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? projectId,
    String? projectName,
    bool clearDates = false,
    bool clearProject = false,
  }) {
    return TimesheetFilterState(
      presetName: presetName ?? this.presetName,
      dateFrom: clearDates ? null : (dateFrom ?? this.dateFrom),
      dateTo: clearDates ? null : (dateTo ?? this.dateTo),
      projectId: clearProject ? null : (projectId ?? this.projectId),
      projectName: clearProject ? null : (projectName ?? this.projectName),
    );
  }
}

final timesheetFilterProvider = StateProvider<TimesheetFilterState>((ref) {
  final now = DateTime.now();
  return TimesheetFilterState(
    presetName: 'Hôm nay',
    dateFrom: now,
    dateTo: now,
  );
});

final timesheetSummaryProvider = FutureProvider<TimesheetSummary>((ref) async {
  final repo = ref.watch(timesheetRepositoryProvider);
  final filter = ref.watch(timesheetFilterProvider);

  String? dateFromStr;
  if (filter.dateFrom != null) {
    final d = filter.dateFrom!;
    dateFromStr = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }
  String? dateToStr;
  if (filter.dateTo != null) {
    final d = filter.dateTo!;
    dateToStr = '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  return repo.getSummary(
    dateFrom: dateFromStr,
    dateTo: dateToStr,
  );
});

/// Làm mới toàn bộ dữ liệu timesheet (tasks, logs, summary)
void refreshTimesheetData(WidgetRef ref) {
  ref.invalidate(todayTasksProvider);
  ref.invalidate(timesheetStreamProvider);
  ref.invalidate(timesheetSummaryProvider);
}
