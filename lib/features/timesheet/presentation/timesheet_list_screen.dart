import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../../core/error/failure.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_format.dart';
import '../../../shared/models/task.dart';
import '../../../shared/models/timesheet.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/ui_kit.dart';
import '../application/task_controller.dart';
import '../application/timesheet_controller.dart';
import 'widgets/checklist_editor.dart';

import '../../../shared/widgets/copyable_error_dialog.dart';

class TimesheetListScreen extends ConsumerStatefulWidget {
  const TimesheetListScreen({super.key});

  @override
  ConsumerState<TimesheetListScreen> createState() =>
      _TimesheetListScreenState();
}

class _TimesheetListScreenState extends ConsumerState<TimesheetListScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  Timer? _ticker;
  DateTime? _startedAt;
  Duration _elapsedBeforePause = Duration.zero;
  bool _running = false;
  bool _showCompletedTasks = false;
  final _taskStatusOverrides = <String, _TaskWorkflowStatus>{};


  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Duration get _elapsed {
    if (!_running || _startedAt == null) return _elapsedBeforePause;
    return _elapsedBeforePause + DateTime.now().difference(_startedAt!);
  }

  void _startTimer() {
    HapticFeedback.selectionClick();
    setState(() {
      _running = true;
      _startedAt = DateTime.now();
    });
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _pauseTimer() {
    HapticFeedback.selectionClick();
    _ticker?.cancel();
    setState(() {
      _elapsedBeforePause = _elapsed;
      _running = false;
      _startedAt = null;
    });
  }

  void _resetTimer() {
    HapticFeedback.selectionClick();
    _ticker?.cancel();
    setState(() {
      _running = false;
      _startedAt = null;
      _elapsedBeforePause = Duration.zero;
    });
  }

  Future<void> _saveTimer() async {
    final elapsed = _elapsed;
    if (elapsed.inSeconds == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bấm bắt đầu để đếm giờ trước.')),
      );
      return;
    }

    final result = await _openTimerSaveSheet(duration: elapsed);
    if (result == null) return;

    await _logTimerTime(result.task, result.note, elapsed);
    _resetTimer();
  }

  Future<_TimerSaveResult?> _openTimerSaveSheet({required Duration duration}) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet<_TimerSaveResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TimerSaveSheet(duration: duration),
    );
  }

  Future<void> _completeTask(String taskId, _TaskLogResult result) async {
    try {
      await ref
          .read(taskActionsProvider)
          .complete(
            taskId: taskId,
            summary: result.note,
            duration: durationBucketForElapsed(result.duration),
            elapsed: result.duration,
          );
      ref.invalidate(timesheetStreamProvider);
    } catch (e, stackTrace) {
      if (mounted) {
        await showCopyableErrorDialog(
          context,
          title: 'Lỗi Lưu Timesheet',
          error: e,
          stackTrace: stackTrace,
        );
      }
      rethrow;
    }
  }

  Future<void> _logTimerTime(Task task, String note, Duration elapsed) async {
    try {
      await ref
          .read(taskActionsProvider)
          .log(
            taskId: task.id,
            summary: note,
            duration: durationBucketForElapsed(elapsed),
            elapsed: elapsed,
          );
      setState(() {
        _taskStatusOverrides[task.id] = _TaskWorkflowStatus.inProgress;
      });
      ref.invalidate(timesheetStreamProvider);
    } catch (e, stackTrace) {
      if (mounted) {
        await showCopyableErrorDialog(
          context,
          title: 'Lỗi Lưu Timesheet',
          error: e,
          stackTrace: stackTrace,
        );
      }
      rethrow;
    }
  }

  /// Edit the logged work-time / note of an already-completed task.
  /// Pulls the matching timesheet entry out of the local
  /// [timesheetStreamProvider] cache so we know which
  /// `account.analytic.line` to PUT.
  Future<void> _updateTask(_TodayTask task, _TaskLogResult result) async {
    final entry = _entryByTaskId()[task.id];
    if (entry == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Không tìm thấy entry timesheet để cập nhật.'),
          ),
        );
      }
      return;
    }
    try {
      await ref
          .read(taskActionsProvider)
          .update(
            taskId: task.id,
            timesheetEntryId: entry.id,
            summary: result.note,
            duration: durationBucketForElapsed(result.duration),
          );
      ref.invalidate(timesheetStreamProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cập nhật task thất bại: ${describeError(e)}'),
          ),
        );
      }
      rethrow;
    }
  }

  /// Append a work-log entry against an **open** task without flipping
  /// it to done. The user can come back later and either keep logging
  /// more sessions or complete the task through the status picker.
  Future<void> _logTaskTime(_TodayTask task, _TaskLogResult result) async {
    try {
      await ref
          .read(taskActionsProvider)
          .log(
            taskId: task.id,
            summary: result.note,
            duration: durationBucketForElapsed(result.duration),
          );
      ref.invalidate(timesheetStreamProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lưu log thất bại: ${describeError(e)}')),
        );
      }
      rethrow;
    }
  }

  _TodayTask _taskFromApi(Task task) {
    final entry = _entryByTaskId()[task.id];
    final localLog = ref.watch(completedTaskLogsProvider)[task.id];
    final accent = _categoryColor(task.category);
    final done = task.isCompleted || localLog != null;
    return _TodayTask(
      id: task.id,
      title: task.title,
      description: task.description,
      tag: task.category.label,
      projectName: task.projectName,
      tags: task.tags,
      tagHexColors: task.tagHexColors,
      allocatedHours: task.allocatedHours,
      spentHours: task.spentHours,
      remainingHours: task.remainingHours,
      stageName: task.stageName,
      state: task.state,
      accent: accent,
      icon: _categoryIcon(task.category),
      workflowStatus:
          _taskStatusOverrides[task.id] ??
          _TaskWorkflowStatus.fromRaw(
            isDone: done,
            state: task.state,
            stageName: task.stageName,
          ),
      done: done,
      // Prefer the locally-saved "what I did" summary over the round-tripped
      // entry name so a freshly-saved note doesn't get clobbered by a
      // backend re-fetch that returned the task title (or a stale value)
      // instead of the user's text.
      logged: entry == null
          ? (localLog?.duration ?? Duration.zero)
          : Duration(minutes: entry.durationMinutes),
      note: localLog?.summary ?? entry?.taskName ?? '',
      completedAt: task.completedAt ?? localLog?.completedAt,
    );
  }

  Map<String, TimesheetEntry> _entryByTaskId() {
    final entries =
        ref.read(timesheetStreamProvider).valueOrNull ??
        const <TimesheetEntry>[];
    final byTask = <String, TimesheetEntry>{};
    for (final entry in entries) {
      final taskId = entry.taskId;
      if (taskId == null) continue;
      final current = byTask[taskId];
      if (current == null || entry.createdAt.isAfter(current.createdAt)) {
        byTask[taskId] = entry;
      }
    }
    return byTask;
  }

  Future<void> _showTaskDetail(
    _TodayTask task, {
    _TaskWorkflowStatus? initialStatus,
  }) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TaskDetailSheet(
        task: task,
        initialStatus: initialStatus,
        onComplete: (result) => _completeTask(task.id, result),
        onUpdate: (result) => _updateTask(task, result),
        onLogTime: (result) => _logTaskTime(task, result),
        onStatusChange: (status) => _updateTaskWorkflow(task, status),
        onStatusPicker: () => _pickTaskStatus(task),
      ),
    );
  }

  Future<_TaskWorkflowStatus?> _pickTaskStatus(_TodayTask task) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet<_TaskWorkflowStatus>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _TaskStatusPickerSheet(
        current: _taskStatusOverrides[task.id] ?? task.workflowStatus,
      ),
    );
  }

  Future<void> _openTaskStatusPopup(_TodayTask task) async {
    final status = await _pickTaskStatus(task);
    if (status == null) return;
    if (status == _TaskWorkflowStatus.done) {
      await _showTaskDetail(task, initialStatus: _TaskWorkflowStatus.done);
      return;
    }
    await _updateTaskWorkflow(task, status);
  }

  Future<void> _updateTaskWorkflow(
    _TodayTask task,
    _TaskWorkflowStatus status,
  ) async {
    try {
      await ref
          .read(taskActionsProvider)
          .updateWorkflow(taskId: task.id, status: status.apiValue);
      if (mounted) {
        setState(() => _taskStatusOverrides[task.id] = status);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đổi trạng thái thất bại: ${describeError(e)}'),
          ),
        );
      }
      rethrow;
    }
  }

  IconData _categoryIcon(TimesheetCategory category) {
    return switch (category) {
      TimesheetCategory.erp => LucideIcons.database,
      TimesheetCategory.crm => LucideIcons.users,
      TimesheetCategory.meeting => LucideIcons.calendarClock,
      TimesheetCategory.support => LucideIcons.headphones,
      TimesheetCategory.other => LucideIcons.circleDot,
    };
  }

  Color _categoryColor(TimesheetCategory category) {
    return switch (category) {
      TimesheetCategory.erp => AppColors.primary,
      TimesheetCategory.crm => AppColors.chat,
      TimesheetCategory.meeting => AppColors.timesheet,
      TimesheetCategory.support => AppColors.ticket,
      TimesheetCategory.other => AppColors.textMuted,
    };
  }

  Widget _buildTaskSections() {
    final tasks = ref.watch(todayTasksProvider);
    return tasks.when(
      data: (_) {
        final split = ref.watch(todayTasksSplitProvider);
        final openTasks = split.open.map(_taskFromApi).toList();
        final doneTasks = split.done.map(_taskFromApi).toList();

        return Column(
          children: [
            _TaskSection(
              title: 'Task cần làm hôm nay',
              count: openTasks.length,
              emptyText: 'Bạn đã hoàn thành hết task hôm nay.',
              tasks: openTasks,
              done: false,
              onTap: _showTaskDetail,
              onChecklist: _openTaskStatusPopup,
            ),
            const SizedBox(height: 16),
            _TaskSection(
              title: 'Đã hoàn thành',
              count: doneTasks.length,
              emptyText: 'Chưa có task nào hoàn thành.',
              tasks: doneTasks,
              done: true,
              collapsed: !_showCompletedTasks,
              onToggleCollapsed: () {
                setState(() => _showCompletedTasks = !_showCompletedTasks);
              },
              onTap: _showTaskDetail,
              onChecklist: _openTaskStatusPopup,
            ),
          ],
        );
      },
      loading: () => const _TasksStatusCard(
        icon: LucideIcons.loaderCircle,
        message: 'Đang tải task từ hệ thống...',
      ),

      error: (error, _) => _TasksStatusCard(
        icon: LucideIcons.triangleAlert,
        message: describeError(error),
        isError: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (Theme.of(context).brightness == Brightness.dark) {
      debugPrint('=== [UI LOG] Timesheet Screen đã chuyển sang chế độ Dark Mode ===');
    }

    final timesheetEntries = ref.watch(timesheetStreamProvider).valueOrNull;
    final showTodaySummary = timesheetEntries != null;
    final doneCount = ref.watch(todayTasksSplitProvider).done.length;
    final todayMinutes = showTodaySummary
        ? ref.watch(todayTotalMinutesProvider)
        : 0;

    return AppScaffold(
      title: 'Timesheet',
      showAppBar: false,
      wrapSafeArea: false,
      body: ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: SafeArea(


          child: ListView(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 112),
            children: [
              const _TimesheetHeader(),
              const SizedBox(height: 12),
              _StopwatchCard(
                elapsed: _elapsed,
                running: _running,
                onStart: _startTimer,
                onPause: _pauseTimer,
                onReset: _resetTimer,
                onSave: _saveTimer,
              ),
              if (showTodaySummary) ...[
                const SizedBox(height: 14),
                _TodaySummaryCard(minutes: todayMinutes, count: doneCount),
              ],
              const SizedBox(height: 16),
              _buildTaskSections(),
            ],
          ),
        ),
      ),
    );
  }
}

class _TasksStatusCard extends StatelessWidget {
  const _TasksStatusCard({
    required this.icon,
    required this.message,
    this.isError = false,
  });

  final IconData icon;
  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? AppColors.danger : AppColors.timesheet;
    return GlassCard(
      radius: 20,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          if (icon == LucideIcons.loaderCircle)
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: color,
              ),
            )
          else
            Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),

    );
  }
}

class _TimesheetHeader extends StatelessWidget {
  const _TimesheetHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D0F172A),
                blurRadius: 14,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: const Text(
            'Timesheet',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const Spacer(),
        Container(
          width: 44,
          height: 44,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            LucideIcons.calendarDays,
            color: AppColors.textPrimary,
            size: 21,
          ),
        ),
      ],
    );
  }
}

class _StopwatchCard extends StatelessWidget {
  const _StopwatchCard({
    required this.elapsed,
    required this.running,
    required this.onStart,
    required this.onPause,
    required this.onReset,
    required this.onSave,
  });

  final Duration elapsed;
  final bool running;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onReset;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final canSave = elapsed.inSeconds > 0;
    return GlassCard(
      radius: 22,
      glowColor: running ? AppColors.timesheet : null,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.soft(AppColors.timesheet),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  LucideIcons.timer,
                  color: AppColors.timesheet,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Bộ đếm công việc',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              StatusPill(
                label: running ? 'Đang chạy' : 'Sẵn sàng',
                color: running ? AppColors.success : AppColors.textMuted,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Center(
            child: Text(
              Dates.hms(elapsed),
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 36,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ),

          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: GradientButton(
                  label: running ? 'Tạm dừng' : 'Bắt đầu',
                  icon: running ? LucideIcons.pause : LucideIcons.play,
                  gradient: AppColors.featureGrad(
                    AppColors.timesheet,
                    AppColors.timesheetDeep,
                  ),
                  glowColor: AppColors.timesheet,
                  onPressed: running ? onPause : onStart,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GradientButton(
                  label: 'Lưu',
                  icon: LucideIcons.save,
                  loading: false,
                  gradient: AppColors.featureGrad(
                    AppColors.success,
                    AppColors.successLight,
                  ),
                  glowColor: AppColors.success,
                  onPressed: canSave ? onSave : null,
                ),
              ),
            ],
          ),
          if (canSave) ...[
            const SizedBox(height: 10),
            Center(
              child: TextButton.icon(
                onPressed: onReset,
                icon: const Icon(LucideIcons.rotateCcw, size: 16),
                label: const Text('Đặt lại bộ đếm'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TodaySummaryCard extends StatelessWidget {
  const _TodaySummaryCard({required this.minutes, required this.count});

  final int minutes;
  final int count;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      glowColor: AppColors.timesheet,
      radius: 18,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: AppColors.featureGrad(
                AppColors.timesheet,
                AppColors.timesheetDeep,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(LucideIcons.clock, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Hôm nay',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _formatMinutes(minutes),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          GradientBadge(
            label: '$count việc',
            gradient: AppColors.featureGrad(
              AppColors.timesheet,
              AppColors.timesheetDeep,
            ),
            fontSize: 12,
          ),
        ],
      ),
    );
  }
}

class _TaskSection extends StatelessWidget {
  const _TaskSection({
    required this.title,
    required this.count,
    required this.emptyText,
    required this.tasks,
    required this.done,
    required this.onTap,
    required this.onChecklist,
    this.collapsed = false,
    this.onToggleCollapsed,
  });

  final String title;
  final int count;
  final String emptyText;
  final List<_TodayTask> tasks;
  final bool done;
  final ValueChanged<_TodayTask> onTap;
  final ValueChanged<_TodayTask> onChecklist;
  final bool collapsed;
  final VoidCallback? onToggleCollapsed;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      radius: 20,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              GradientBadge(
                label: '$count',
                gradient: done
                    ? AppColors.featureGrad(
                        AppColors.success,
                        AppColors.successLight,
                      )
                    : AppColors.featureGrad(
                        AppColors.timesheet,
                        AppColors.timesheetDeep,
                      ),
                fontSize: 12,
              ),
              if (onToggleCollapsed != null) ...[
                const SizedBox(width: 6),
                IconButton(
                  onPressed: onToggleCollapsed,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    collapsed ? LucideIcons.chevronDown : LucideIcons.chevronUp,
                    color: AppColors.textMuted,
                    size: 20,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          if (tasks.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                emptyText,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else if (collapsed)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: PressableScale(
                onTap: onToggleCollapsed,
                scale: 0.99,
                child: const Row(
                  children: [
                    Icon(LucideIcons.eye, color: AppColors.textMuted, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Đang thu gọn. Bấm để xem task đã hoàn thành.',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            for (var i = 0; i < tasks.length; i++) ...[
              _TaskTile(
                task: tasks[i],
                done: done,
                onTap: () => onTap(tasks[i]),
                onChecklist: () => onChecklist(tasks[i]),
              ),
              if (i != tasks.length - 1)
                const Divider(height: 1, indent: 58, color: AppColors.border),
            ],
        ],
      ),
    );
  }
}

class _TaskTile extends StatelessWidget {
  const _TaskTile({
    required this.task,
    required this.done,
    required this.onTap,
    required this.onChecklist,
  });

  final _TodayTask task;
  final bool done;
  final VoidCallback onTap;
  final VoidCallback onChecklist;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return PressableScale(
      onTap: onTap,
      scale: 0.99,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.soft(task.accent),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(task.icon, color: task.accent, size: 21),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: done
                          ? (isDark ? AppColors.darkTextMuted : AppColors.textSecondary)
                          : Theme.of(context).colorScheme.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      decoration: done ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  if (task.projectName != null &&
                      task.projectName!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          LucideIcons.folderKanban,
                          color: AppColors.textMuted,
                          size: 13,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            task.projectName!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isDark ? AppColors.darkTextMuted : AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _TagPill(label: task.tag, color: task.accent),
                      for (final tag in task.tags)
                        _TagPill(
                          label: tag,
                          color:
                              AppColors.fromHex(task.tagHexColors[tag]) ??
                              AppColors.textMuted,
                        ),
                      if (done) ...[
                        Text(
                          _formatTaskDuration(task.logged),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (done && task.note.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      task.note,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            PressableScale(
              onTap: onChecklist,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.soft(task.workflowStatus.color),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: task.workflowStatus.color.withValues(alpha: 0.18),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      LucideIcons.listChecks,
                      color: task.workflowStatus.color,
                      size: 16,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Checklist',
                      style: TextStyle(
                        color: task.workflowStatus.color,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskDetailSheet extends StatefulWidget {
  const _TaskDetailSheet({
    required this.task,
    required this.onComplete,
    required this.onUpdate,
    required this.onLogTime,
    required this.onStatusChange,
    required this.onStatusPicker,
    this.initialStatus,
  });

  final _TodayTask task;

  /// Save path used when the user transitions an **open** task to
  /// `Hoàn thành`: writes a fresh timesheet entry AND flips the task
  /// to state `1_done`.
  final Future<void> Function(_TaskLogResult result) onComplete;

  /// Save path used for **already-completed** tasks: PUTs the existing
  /// timesheet entry in place with the new time + note.
  final Future<void> Function(_TaskLogResult result) onUpdate;

  /// Save path used when the user wants to log work on a task that's
  /// still in progress. Writes a fresh timesheet row but leaves the
  /// task workflow status alone.
  final Future<void> Function(_TaskLogResult result) onLogTime;

  final Future<void> Function(_TaskWorkflowStatus status) onStatusChange;
  final Future<_TaskWorkflowStatus?> Function() onStatusPicker;
  final _TaskWorkflowStatus? initialStatus;

  @override
  State<_TaskDetailSheet> createState() => _TaskDetailSheetState();
}

class _TaskDetailSheetState extends State<_TaskDetailSheet> {
  late final TextEditingController _noteController;
  late _TaskWorkflowStatus _status;
  late TimesheetDuration _duration;
  bool _saving = false;

  _TodayTask get task => widget.task;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(text: task.note);
    _status = widget.initialStatus ?? task.workflowStatus;
    _duration = durationBucketForElapsed(
      task.logged == Duration.zero ? const Duration(minutes: 30) : task.logged,
    );
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _saveComplete() async {
    final note = _noteController.text.trim();
    if (note.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập nội dung đã làm.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final result = _TaskLogResult(note: note, duration: _duration.duration);
      if (task.done) {
        // Already completed → update the only timesheet entry we own.
        await widget.onUpdate(result);
      } else if (_status == _TaskWorkflowStatus.done) {
        // User flipped the workflow status to "Hoàn thành" inside this
        // sheet → write a fresh entry and mark the task done atomically.
        await widget.onComplete(result);
      } else {
        if (_status != task.workflowStatus) {
          await widget.onStatusChange(_status);
        }
        // Task đang mở: lưu workflow đã chọn rồi thêm dòng timesheet mới.
        await widget.onLogTime(result);
      }
      if (mounted) Navigator.pop(context);
    } catch (_) {
      // Parent action already shows the backend error.
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openStatusPicker() async {
    final status = await widget.onStatusPicker();
    if (status == null) return;
    setState(() => _status = status);
  }

  /// Outbound label for the editor's save button — communicates the
  /// three-way save semantics so the user always knows what tapping
  /// the button actually does.
  String _editorSaveLabel() {
    if (task.done) return 'Cập nhật task';
    if (_status == _TaskWorkflowStatus.done) {
      return 'Lưu & đánh dấu hoàn thành';
    }
    return 'Lưu log công việc';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 12,
          right: 12,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 10,
        ),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.88,
          ),
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(28),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.soft(task.accent),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(task.icon, color: task.accent, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.title,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _TagPill(label: task.tag, color: task.accent),
                              StatusPill(
                                label: _status.label,
                                color: _status.color,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (task.projectName != null &&
                    task.projectName!.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _TaskInfoBlock(
                    icon: LucideIcons.folderKanban,
                    label: 'Project',
                    value: task.projectName!,
                  ),
                ],
                const SizedBox(height: 14),
                _TaskInfoBlock(
                  icon: LucideIcons.alignLeft,
                  label: 'Mô tả task',
                  value: task.description?.trim().isNotEmpty == true
                      ? task.description!.trim()
                      : 'Chưa có mô tả.',
                  multiline: true,
                ),
                if (task.tags.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final tag in task.tags)
                        _TagPill(
                          label: tag,
                          color:
                              AppColors.fromHex(task.tagHexColors[tag]) ??
                              AppColors.textMuted,
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _TaskDetailMetric(
                        icon: LucideIcons.timer,
                        label: 'Thời gian làm',
                        value: _formatTaskDuration(task.logged),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _TaskDetailMetric(
                        icon: LucideIcons.checkCircle2,
                        label: 'Hoàn thành lúc',
                        value: task.completedAt == null
                            ? 'Chưa có dữ liệu'
                            : Dates.hm(task.completedAt!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _TaskDetailMetric(
                        icon: LucideIcons.hourglass,
                        label: 'Allocated time',
                        value: _formatHours(task.allocatedHours),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _TaskDetailMetric(
                        icon: LucideIcons.activity,
                        label: 'Đã dùng',
                        value: _formatHours(task.spentHours),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _TaskDetailMetric(
                        icon: LucideIcons.gauge,
                        label: 'Còn lại',
                        value: _formatHours(task.remainingHours),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _TaskDetailMetric(
                        icon: LucideIcons.workflow,
                        label: 'Stage',
                        value: task.stageName ?? 'Chưa có dữ liệu',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Text(
                  'Trạng thái task',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                _TaskChecklistButton(
                  status: _status,
                  enabled: !task.done,
                  onTap: task.done ? null : _openStatusPicker,
                ),
                const SizedBox(height: 16),
                // Always-on edit affordance: the user can record time/note
                // on any task — open or done. Save semantics depend on the
                // workflow status (see [_saveComplete]).
                TaskChecklistEditor(
                  noteController: _noteController,
                  duration: _duration,
                  saving: _saving,
                  onDurationChanged: _saving
                      ? null
                      : (duration) {
                          setState(() => _duration = duration);
                        },
                  onSave: _saving ? null : _saveComplete,
                  saveLabel: _editorSaveLabel(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TaskInfoBlock extends StatelessWidget {
  const _TaskInfoBlock({
    required this.icon,
    required this.label,
    required this.value,
    this.multiline = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool multiline;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F6FC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: multiline
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Icon(icon, color: AppColors.timesheet, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: multiline ? 6 : 1,
                  overflow: multiline
                      ? TextOverflow.fade
                      : TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskStatusChip extends StatelessWidget {
  const _TaskStatusChip({
    required this.status,
    required this.selected,
    required this.onTap,
  });

  final _TaskWorkflowStatus status;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.soft(status.color) : AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? status.color : AppColors.border,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(status.icon, size: 15, color: status.color),
            const SizedBox(width: 6),
            Text(
              status.label,
              style: TextStyle(
                color: selected ? status.color : AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskChecklistButton extends StatelessWidget {
  const _TaskChecklistButton({
    required this.status,
    required this.enabled,
    required this.onTap,
  });

  final _TaskWorkflowStatus status;
  final bool enabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.soft(status.color),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: status.color.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: status.color,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(status.icon, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Checklist / Đổi trạng thái',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    status.label,
                    style: TextStyle(
                      color: status.color,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              enabled ? LucideIcons.chevronDown : LucideIcons.lock,
              color: status.color,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskStatusPickerSheet extends StatelessWidget {
  const _TaskStatusPickerSheet({required this.current});

  final _TaskWorkflowStatus current;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(26),
            boxShadow: const [
              BoxShadow(
                color: Color(0x220F172A),
                blurRadius: 22,
                offset: Offset(0, -8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Chọn trạng thái task',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Chỉ trạng thái Hoàn thành mới mở checklist nhập nội dung và thời gian.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final status in _TaskWorkflowStatus.values)
                    _TaskStatusChip(
                      status: status,
                      selected: current == status,
                      onTap: status == _TaskWorkflowStatus.approved
                          ? null // Disabled for Employee (Manager only)
                          : () => Navigator.pop(context, status),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _TaskWorkflowStatus {
  inProgress,
  changeRequest,
  approved,
  canceled,
  done;

  static _TaskWorkflowStatus fromRaw({
    required bool isDone,
    String? state,
    String? stageName,
  }) {
    if (isDone) return _TaskWorkflowStatus.done;
    final raw = '${state ?? ''} ${stageName ?? ''}'.toLowerCase();
    if (raw.contains('cancel') || raw.contains('hủy') || raw.contains('huỷ')) {
      return canceled;
    }
    if (raw.contains('approved') || raw.contains('chấp thuận')) {
      return approved;
    }
    if (raw.contains('change') || raw.contains('thay đổi')) {
      return changeRequest;
    }
    return inProgress;
  }

  String get label => switch (this) {
    inProgress => 'Đang làm',
    changeRequest => 'Thay đổi yêu cầu',
    approved => 'Được chấp thuận',
    canceled => 'Huỷ',
    done => 'Hoàn thành',
  };

  String get apiValue => switch (this) {
    inProgress => 'in_progress',
    changeRequest => 'changes_requested',
    approved => 'approved',
    canceled => 'canceled',
    done => 'done',
  };

  IconData get icon => switch (this) {
    inProgress => LucideIcons.loader,
    changeRequest => LucideIcons.refreshCcw,
    approved => LucideIcons.badgeCheck,
    canceled => LucideIcons.circleX,
    done => LucideIcons.checkCircle2,
  };

  Color get color => switch (this) {
    inProgress => AppColors.timesheet,
    changeRequest => AppColors.warning,
    approved => AppColors.primary,
    canceled => AppColors.danger,
    done => AppColors.success,
  };
}

class _TaskDetailMetric extends StatelessWidget {
  const _TaskDetailMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F6FC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.timesheet, size: 18),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimerSaveSheet extends ConsumerStatefulWidget {
  const _TimerSaveSheet({required this.duration});

  final Duration duration;

  @override
  ConsumerState<_TimerSaveSheet> createState() => _TimerSaveSheetState();
}

class _TimerSaveSheetState extends ConsumerState<_TimerSaveSheet> {
  final _note = TextEditingController();
  late Future<List<_TimerProjectTasks>> _projectTaskGroupsFuture;
  String? _expandedProjectId;
  Task? _selectedTask;

  @override
  void initState() {
    super.initState();
    _projectTaskGroupsFuture = _loadProjectTaskGroups();
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<List<_TimerProjectTasks>> _loadProjectTaskGroups() async {
    final actions = ref.read(taskActionsProvider);
    final projects = await actions.listProjects();
    final groups = await Future.wait(
      projects.map((project) async {
        final tasks = (await actions.listProjectTasks(
          project.id,
        )).where((task) => !task.isCompleted).toList();
        return _TimerProjectTasks(project: project, tasks: tasks);
      }),
    );
    return groups.where((group) => group.tasks.isNotEmpty).toList();
  }

  void _toggleProject(_TimerProjectTasks group) {
    final project = group.project;
    final isExpanded = _expandedProjectId == project.id;
    setState(() {
      _expandedProjectId = isExpanded ? null : project.id;
      if (!group.tasks.any((task) => task.id == _selectedTask?.id)) {
        _selectedTask = null;
      }
    });
  }

  void _submit() {
    final note = _note.text.trim();
    if (note.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nhập nội dung công việc đã làm.')),
      );
      return;
    }
    final task = _selectedTask;
    if (task == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Chọn task cần lưu.')));
      return;
    }
    Navigator.pop(context, _TimerSaveResult(task: task, note: note));
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 12,
          right: 12,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 10,
        ),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.86,
          ),
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(28),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.soft(AppColors.timesheet),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: const Icon(
                        LucideIcons.timer,
                        color: AppColors.timesheet,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Lưu thời gian',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Đã đếm ${_formatDuration(widget.duration)}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _note,
                  maxLines: 4,
                  minLines: 3,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Bạn đã làm những gì?',
                    hintStyle: const TextStyle(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF3F6FC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Chọn project và task được giao',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                FutureBuilder<List<_TimerProjectTasks>>(
                  future: _projectTaskGroupsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const _TimerSheetStatus(
                        icon: LucideIcons.loaderCircle,
                        message: 'Đang tải project và task...',
                      );
                    }
                    if (snapshot.hasError) {
                      return _TimerSheetStatus(
                        icon: LucideIcons.triangleAlert,
                        message: describeError(snapshot.error!),
                        isError: true,
                      );
                    }
                    final groups =
                        snapshot.data ?? const <_TimerProjectTasks>[];
                    if (groups.isEmpty) {
                      return const _TimerSheetStatus(
                        icon: LucideIcons.folderOpen,
                        message:
                            'Bạn không có project nào còn task chưa hoàn thành.',
                      );
                    }
                    return Column(
                      children: [
                        for (final group in groups)
                          _ProjectTaskDropdown(
                            group: group,
                            expanded: _expandedProjectId == group.project.id,
                            selectedTaskId: _selectedTask?.id,
                            onProjectTap: () => _toggleProject(group),
                            onTaskTap: (task) =>
                                setState(() => _selectedTask = task),
                          ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: GradientButton(
                    label: 'Lưu vào task',
                    icon: LucideIcons.check,
                    gradient: AppColors.featureGrad(
                      AppColors.timesheet,
                      AppColors.timesheetDeep,
                    ),
                    glowColor: AppColors.timesheet,
                    onPressed: _submit,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TimerSheetStatus extends StatelessWidget {
  const _TimerSheetStatus({
    required this.icon,
    required this.message,
    this.isError = false,
  });

  final IconData icon;
  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? AppColors.danger : AppColors.textMuted;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F6FC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimerProjectTasks {
  const _TimerProjectTasks({required this.project, required this.tasks});

  final TimesheetProjectOption project;
  final List<Task> tasks;
}

class _ProjectTaskDropdown extends StatelessWidget {
  const _ProjectTaskDropdown({
    required this.group,
    required this.expanded,
    required this.selectedTaskId,
    required this.onProjectTap,
    required this.onTaskTap,
  });

  final _TimerProjectTasks group;
  final bool expanded;
  final String? selectedTaskId;
  final VoidCallback onProjectTap;
  final ValueChanged<Task> onTaskTap;

  @override
  Widget build(BuildContext context) {
    final selectedInProject = group.tasks.any(
      (task) => task.id == selectedTaskId,
    );
    final highlighted = expanded || selectedInProject;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: highlighted
            ? AppColors.timesheet.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: highlighted ? AppColors.timesheet : Colors.transparent,
        ),
      ),
      child: Column(
        children: [
          PressableScale(
            onTap: onProjectTap,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: highlighted
                    ? AppColors.timesheet.withValues(alpha: 0.08)
                    : const Color(0xFFF3F6FC),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(
                    LucideIcons.folderKanban,
                    color: AppColors.timesheet,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      group.project.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${group.tasks.length}',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: const Icon(
                      LucideIcons.chevronDown,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
          ClipRect(
            child: AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              child: expanded
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                      child: Column(
                        children: [
                          for (final task in group.tasks)
                            _ProjectTaskChoice(
                              task: task,
                              selected: selectedTaskId == task.id,
                              onTap: () => onTaskTap(task),
                            ),
                        ],
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectTaskChoice extends StatelessWidget {
  const _ProjectTaskChoice({
    required this.task,
    required this.selected,
    required this.onTap,
  });

  final Task task;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.success.withValues(alpha: 0.12)
              : const Color(0xFFF3F6FC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.success : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            const Icon(
              LucideIcons.listChecks,
              color: AppColors.success,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (task.projectName != null &&
                      task.projectName!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      task.projectName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  if (task.allocatedHours != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Allocated: ${_formatHours(task.allocatedHours)}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  if (task.tags.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        for (final tag in task.tags)
                          _TagPill(
                            label: tag,
                            color:
                                AppColors.fromHex(task.tagHexColors[tag]) ??
                                AppColors.textMuted,
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              selected ? LucideIcons.checkCircle2 : LucideIcons.circle,
              color: selected ? AppColors.success : AppColors.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskLogSheet extends StatefulWidget {
  const _TaskLogSheet({
    required this.task,
    required this.initialDuration,
    required this.allowDurationEdit,
  });

  final _TodayTask task;
  final Duration initialDuration;
  final bool allowDurationEdit;

  @override
  State<_TaskLogSheet> createState() => _TaskLogSheetState();
}

class _TaskLogSheetState extends State<_TaskLogSheet> {
  final _note = TextEditingController();
  late Duration _duration = widget.initialDuration;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 12,
          right: 12,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 10,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(28),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.soft(widget.task.accent),
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Icon(
                        widget.task.icon,
                        color: widget.task.accent,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Hoàn thành task',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.task.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _note,
                  maxLines: 4,
                  minLines: 3,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Bạn đã làm những gì?',
                    hintStyle: const TextStyle(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF3F6FC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(
                      LucideIcons.timer,
                      color: AppColors.textSecondary,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Thời gian: ${_formatDuration(_duration)}',
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                if (widget.allowDurationEdit) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _DurationChip(
                        label: '15 phút',
                        duration: const Duration(minutes: 15),
                        selected: _duration.inMinutes == 15,
                        onTap: _setDuration,
                      ),
                      _DurationChip(
                        label: '30 phút',
                        duration: const Duration(minutes: 30),
                        selected: _duration.inMinutes == 30,
                        onTap: _setDuration,
                      ),
                      _DurationChip(
                        label: '45 phút',
                        duration: const Duration(minutes: 45),
                        selected: _duration.inMinutes == 45,
                        onTap: _setDuration,
                      ),
                      _DurationChip(
                        label: '1 giờ',
                        duration: const Duration(hours: 1),
                        selected: _duration.inMinutes == 60,
                        onTap: _setDuration,
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: GradientButton(
                    label: 'Lưu và hoàn thành',
                    icon: LucideIcons.check,
                    gradient: AppColors.featureGrad(
                      AppColors.timesheet,
                      AppColors.timesheetDeep,
                    ),
                    glowColor: AppColors.timesheet,
                    onPressed: () {
                      final note = _note.text.trim();
                      if (note.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Nhập nội dung đã làm trước.'),
                          ),
                        );
                        return;
                      }
                      Navigator.pop(
                        context,
                        _TaskLogResult(note: note, duration: _duration),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _setDuration(Duration duration) {
    setState(() => _duration = duration);
  }
}

class _DurationChip extends StatelessWidget {
  const _DurationChip({
    required this.label,
    required this.duration,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Duration duration;
  final bool selected;
  final ValueChanged<Duration> onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: () => onTap(duration),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.timesheet : const Color(0xFFF3F6FC),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _TagPill extends StatelessWidget {
  const _TagPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.soft(color),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _TodayTask {
  const _TodayTask({
    required this.id,
    required this.title,
    this.description,
    required this.tag,
    this.projectName,
    this.tags = const <String>[],
    this.tagHexColors = const <String, String>{},
    this.allocatedHours,
    this.spentHours,
    this.remainingHours,
    this.stageName,
    this.state,
    required this.workflowStatus,
    required this.accent,
    required this.icon,
    this.done = false,
    this.logged = Duration.zero,
    this.note = '',
    this.completedAt,
  });

  final String id;
  final String title;
  final String? description;
  final String tag;
  final String? projectName;
  final List<String> tags;

  /// Resolved tag name → 6-char hex colour (from `helpdesk.tag.color`).
  /// Tags with no entry fall back to a neutral pill colour in the UI.
  final Map<String, String> tagHexColors;
  final double? allocatedHours;
  final double? spentHours;
  final double? remainingHours;
  final String? stageName;
  final String? state;
  final _TaskWorkflowStatus workflowStatus;
  final Color accent;
  final IconData icon;
  final bool done;
  final Duration logged;
  final String note;
  final DateTime? completedAt;

  _TodayTask copyWith({
    bool? done,
    Duration? logged,
    String? note,
    DateTime? completedAt,
  }) {
    return _TodayTask(
      id: id,
      title: title,
      description: description,
      tag: tag,
      projectName: projectName,
      tags: tags,
      tagHexColors: tagHexColors,
      allocatedHours: allocatedHours,
      spentHours: spentHours,
      remainingHours: remainingHours,
      stageName: stageName,
      state: state,
      workflowStatus: workflowStatus,
      accent: accent,
      icon: icon,
      done: done ?? this.done,
      logged: logged ?? this.logged,
      note: note ?? this.note,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

class _TaskLogResult {
  const _TaskLogResult({required this.note, required this.duration});

  final String note;
  final Duration duration;
}

class _TimerSaveResult {
  const _TimerSaveResult({required this.task, required this.note});

  final Task task;
  final String note;
}

String _formatTaskDuration(Duration duration) {
  if (duration == Duration.zero) return 'Chưa có dữ liệu';
  return _formatDuration(duration);
}

String _formatHours(double? hours) {
  if (hours == null) return 'Chưa có dữ liệu';
  final minutes = (hours * 60).round();
  if (minutes <= 0) return '0 phút';
  return _formatMinutes(minutes);
}

String _formatMinutes(int minutes) {
  if (minutes < 60) return '$minutes phút';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  if (rest == 0) return '$hours giờ';
  return '$hours giờ $rest phút';
}

String _formatDuration(Duration duration) {
  final totalSeconds = duration.inSeconds;
  if (totalSeconds < 60) return '$totalSeconds giây';
  return _formatMinutes(duration.inMinutes);
}
