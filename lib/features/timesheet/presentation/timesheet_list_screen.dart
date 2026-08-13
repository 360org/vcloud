import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../../core/error/failure.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/utils/html_text.dart';
import '../../../shared/models/task.dart';
import '../../../shared/models/task_message.dart';
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
  final _scrollController = ScrollController();
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _offset = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() {
      _isLoadingMore = true;
    });
    try {
      final repo = ref.read(timesheetRepositoryProvider);
      final newEntries = await repo.fetchPage(limit: 20, offset: _offset + 20);
      if (newEntries.isEmpty) {
        _hasMore = false;
      } else {
        _offset += newEntries.length;
      }
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
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
      showTopNotification(
        context,
        message: 'Bấm bắt đầu để đếm giờ trước.',
        isError: true,
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
      enableDrag: true,
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
  Future<void> _updateTask(_TodayTask task, _TaskLogResult result) async {
    final entry = _entryByTaskId()[task.id];
    if (entry == null) {
      if (mounted) {
        showTopNotification(
          context,
          message: 'Không tìm thấy entry timesheet để cập nhật.',
          isError: true,
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
        showTopNotification(
          context,
          message: 'Cập nhật task thất bại: ${describeError(e)}',
          isError: true,
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
        showTopNotification(
          context,
          message: 'Lưu log thất bại: ${describeError(e)}',
          isError: true,
        );
      }
      rethrow;
    }
  }

  _TodayTask _taskFromApi(
    Task task, {
    Map<String, TimesheetEntry>? entryByTaskMap,
    Map<String, CompletedTaskLog>? completedLogsMap,
  }) {
    final entryMap = entryByTaskMap ?? _entryByTaskId();
    final logsMap = completedLogsMap ?? ref.read(completedTaskLogsProvider) ?? const <String, CompletedTaskLog>{};
    final entry = entryMap[task.id];
    final localLog = logsMap[task.id];
    final accent = _categoryColor(task.category);
    final done = task.isCompleted || localLog != null;
    return _TodayTask(
      id: task.id,
      title: task.title,
      description: task.description,
      tag: task.category.label,
      projectName: task.projectName,
      userName: task.userName,
      partnerName: task.partnerName,
      dateAssign: task.dateAssign,
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
      enableDrag: true,
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
      isScrollControlled: true,
      enableDrag: true,
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
        final entryByTask = _entryByTaskId();
        final completedLogs = ref.watch(completedTaskLogsProvider);
        final openTasks = split.open
            .map((t) => _taskFromApi(t, entryByTaskMap: entryByTask, completedLogsMap: completedLogs))
            .toList();
        final doneTasks = split.done
            .map((t) => _taskFromApi(t, entryByTaskMap: entryByTask, completedLogsMap: completedLogs))
            .toList();

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

    return AppScaffold(
      title: 'Timesheet',
      showAppBar: false,
      wrapSafeArea: false,
      body: ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: SafeArea(


          child: ListView(
            controller: _scrollController,
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
              const SizedBox(height: 14),
              const _TimesheetSummaryCard(),
              const SizedBox(height: 16),
              _buildTaskSections(),
              if (_isLoadingMore) ...[
                const SizedBox(height: 16),
                const Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppColors.timesheet,
                    ),
                  ),
                ),
              ],
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

class _TimesheetHeader extends ConsumerWidget {
  const _TimesheetHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(timesheetFilterProvider);

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
          child: Text(
            'Timesheet',
            style: TextStyle(
              color: context.textColor,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => _TimesheetFilterSheet(initialFilter: filter),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: context.cardColor,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0D0F172A),
                  blurRadius: 14,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(
                  LucideIcons.calendarDays,
                  color: AppColors.primary,
                  size: 19,
                ),
                const SizedBox(width: 6),
                Text(
                  filter.presetName,
                  style: TextStyle(
                    color: context.textColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
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

class _TimesheetSummaryCard extends ConsumerWidget {
  const _TimesheetSummaryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(timesheetFilterProvider);
    final summaryAsync = ref.watch(timesheetSummaryProvider);

    return summaryAsync.when(
      data: (summary) {
        final hoursInt = summary.totalHours.floor();
        final minutesInt = ((summary.totalHours - hoursInt) * 60).round();
        final hoursText = hoursInt > 0 ? '${hoursInt}h ${minutesInt}m' : '${minutesInt}m';

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
                    Text(
                      'Tổng giờ làm · ${filter.presetName}',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      hoursText,
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
                label: '${summary.count} việc',
                gradient: AppColors.featureGrad(
                  AppColors.timesheet,
                  AppColors.timesheetDeep,
                ),
                fontSize: 12,
              ),
            ],
          ),
        );
      },
      loading: () => const _TasksStatusCard(
        icon: LucideIcons.loaderCircle,
        message: 'Đang tải thống kê giờ làm...',
      ),
      error: (e, _) => GlassCard(
        radius: 18,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(LucideIcons.info, color: AppColors.textMuted, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Tổng giờ làm: ${_formatMinutes(ref.watch(todayTotalMinutesProvider))}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskSection extends StatefulWidget {
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
  State<_TaskSection> createState() => _TaskSectionState();
}

class _TaskSectionState extends State<_TaskSection> {
  int _limit = 20;

  @override
  Widget build(BuildContext context) {
    final tasks = widget.tasks;
    final visibleCount = _limit.clamp(0, tasks.length);
    final hasMore = tasks.length > visibleCount;

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
                  widget.title,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              GradientBadge(
                label: '${widget.count}',
                gradient: widget.done
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
              if (widget.onToggleCollapsed != null) ...[
                const SizedBox(width: 6),
                IconButton(
                  onPressed: widget.onToggleCollapsed,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    widget.collapsed ? LucideIcons.chevronDown : LucideIcons.chevronUp,
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
                widget.emptyText,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else if (widget.collapsed)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: PressableScale(
                onTap: widget.onToggleCollapsed,
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
          else ...[
            for (var i = 0; i < visibleCount; i++) ...[
              _TaskTile(
                task: tasks[i],
                done: widget.done,
                onTap: () => widget.onTap(tasks[i]),
                onChecklist: () => widget.onChecklist(tasks[i]),
              ),
              if (i != visibleCount - 1)
                const Divider(height: 1, indent: 58, color: AppColors.border),
            ],
            if (hasMore) ...[
              const SizedBox(height: 10),
              Center(
                child: TextButton.icon(
                  onPressed: () => setState(() => _limit += 30),
                  icon: const Icon(LucideIcons.chevronDown, size: 16, color: AppColors.primary),
                  label: Text(
                    'Xem thêm (${tasks.length - visibleCount} task khác)',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
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
                  horizontal: 11,
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
                      task.workflowStatus.icon,
                      color: task.workflowStatus.color,
                      size: 17,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      task.workflowStatus.label,
                      style: TextStyle(
                        color: task.workflowStatus.color,
                        fontSize: 13.5,
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

class _TaskDetailSheet extends ConsumerStatefulWidget {
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

  final Future<void> Function(_TaskLogResult result) onComplete;
  final Future<void> Function(_TaskLogResult result) onUpdate;
  final Future<void> Function(_TaskLogResult result) onLogTime;
  final Future<void> Function(_TaskWorkflowStatus status) onStatusChange;
  final Future<_TaskWorkflowStatus?> Function() onStatusPicker;
  final _TaskWorkflowStatus? initialStatus;

  @override
  ConsumerState<_TaskDetailSheet> createState() => _TaskDetailSheetState();
}

class _TaskDetailSheetState extends ConsumerState<_TaskDetailSheet> {
  late final TextEditingController _noteController;
  late _TaskWorkflowStatus _status;
  late TimesheetDuration _duration;
  bool _saving = false;
  bool _noteError = false;
  String? _validationError;
  _TodayTask? _detailedTask;

  _TodayTask get task => _detailedTask ?? widget.task;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(text: task.note);
    _status = widget.initialStatus ?? task.workflowStatus;
    _duration = durationBucketForElapsed(
      task.logged == Duration.zero ? const Duration(minutes: 30) : task.logged,
    );
    _loadTaskDetail();
  }

  Future<void> _loadTaskDetail() async {
    try {
      final repo = ref.read(taskRepositoryProvider);
      final fullTask = await repo.getTaskDetail(widget.task.id);
      if (mounted) {
        setState(() {
          _detailedTask = _TodayTask(
            id: fullTask.id,
            title: fullTask.title,
            description: (fullTask.description != null &&
                    fullTask.description!.trim().isNotEmpty)
                ? fullTask.description
                : widget.task.description,
            tag: fullTask.category.label,
            projectName: fullTask.projectName ?? widget.task.projectName,
            userName: fullTask.userName ?? widget.task.userName,
            partnerName: fullTask.partnerName ?? widget.task.partnerName,
            dateAssign: fullTask.dateAssign ?? widget.task.dateAssign,
            tags: fullTask.tags.isNotEmpty ? fullTask.tags : widget.task.tags,
            tagHexColors: fullTask.tagHexColors.isNotEmpty ? fullTask.tagHexColors : widget.task.tagHexColors,
            allocatedHours: fullTask.allocatedHours ?? widget.task.allocatedHours,
            spentHours: fullTask.spentHours ?? widget.task.spentHours,
            remainingHours: fullTask.remainingHours ?? widget.task.remainingHours,
            stageName: fullTask.stageName ?? widget.task.stageName,
            state: fullTask.state ?? widget.task.state,
            workflowStatus: widget.task.workflowStatus,
            accent: widget.task.accent,
            icon: widget.task.icon,
            done: widget.task.done,
            logged: widget.task.logged,
            note: widget.task.note,
            completedAt: fullTask.completedAt ?? widget.task.completedAt,
          );
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _saveComplete() async {
    final note = _noteController.text.trim();
    if (note.isEmpty) {
      HapticFeedback.mediumImpact();
      setState(() {
        _noteError = true;
        _validationError =
            'Vui lòng nhập nội dung công việc đã làm trước khi lưu.';
      });
      showTopNotification(
        context,
        message: 'Vui lòng nhập nội dung công việc đã làm.',
        isError: true,
      );
      return;
    }
    setState(() {
      _noteError = false;
      _validationError = null;
      _saving = true;
    });
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
            physics: const ClampingScrollPhysics(),
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
                const SizedBox(height: 6),
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(LucideIcons.x, color: AppColors.textSecondary),
                      tooltip: 'Hủy',
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Chi tiết task',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
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
                                icon: _status.icon,
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
                if (task.userName != null && task.userName!.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _TaskInfoBlock(
                    icon: LucideIcons.user,
                    label: 'Người thực hiện',
                    value: task.userName!,
                  ),
                ],
                if (task.dateAssign != null) ...[
                  const SizedBox(height: 14),
                  _TaskInfoBlock(
                    icon: LucideIcons.calendar,
                    label: 'Ngày phân công',
                    value: Dates.isoDate(task.dateAssign!),
                  ),
                ],
                if (task.partnerName != null &&
                    task.partnerName!.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _TaskInfoBlock(
                    icon: LucideIcons.building2,
                    label: 'Khách hàng',
                    value: task.partnerName!,
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
                        label: 'Lần log gần nhất',
                        value: _formatTaskDuration(task.logged),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _TaskDetailMetric(
                        icon: LucideIcons.checkCircle2,
                        label: 'Hoàn thành lúc',
                        value: task.completedAt == null
                            ? 'Đang thực hiện'
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
                        label: 'Thời gian dự kiến',
                        value: _formatHours(task.allocatedHours),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _TaskDetailMetric(
                        icon: LucideIcons.activity,
                        label: 'Tổng thời gian đã làm',
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
                  hasError: _noteError,
                  errorMessage: _validationError,
                  onDurationChanged: _saving
                      ? null
                      : (duration) {
                          setState(() => _duration = duration);
                        },
                  onSave: _saving ? null : _saveComplete,
                  saveLabel: _editorSaveLabel(),
                ),
                const SizedBox(height: 20),
                _TaskChatterSection(taskId: widget.task.id),
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

  Widget _buildValueWidget(String cleanValue) {
    if (!multiline) {
      return Text(
        cleanValue,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w800,
          height: 1.35,
        ),
      );
    }

    const defaultStyle = TextStyle(
      color: AppColors.textPrimary,
      fontSize: 14,
      fontWeight: FontWeight.w700,
      height: 1.45,
    );

    final linkStyle = defaultStyle.copyWith(
      color: const Color(0xFF2563EB),
      fontWeight: FontWeight.w800,
      decoration: TextDecoration.underline,
    );

    final regex = RegExp(
      r'((https?://[^\s<]+)|(www\.[^\s<]+)|([a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}))',
      caseSensitive: false,
    );

    final spans = <InlineSpan>[];
    int start = 0;

    for (final match in regex.allMatches(cleanValue)) {
      if (match.start > start) {
        spans.add(TextSpan(text: cleanValue.substring(start, match.start)));
      }
      final matchedText = match.group(0)!;
      spans.add(
        TextSpan(
          text: matchedText,
          style: linkStyle,
        ),
      );
      start = match.end;
    }

    if (start < cleanValue.length) {
      spans.add(TextSpan(text: cleanValue.substring(start)));
    }

    return SelectableText.rich(
      TextSpan(children: spans, style: defaultStyle),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cleanValue = cleanHtmlText(value);
    final displayValue = cleanValue.isEmpty ? value : cleanValue;

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
                _buildValueWidget(displayValue),
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
                fontSize: 14,
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
              child: Text(
                status.label,
                style: TextStyle(
                  color: status.color,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
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
  String? _validationError;
  bool _noteError = false;
  bool _taskError = false;

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
    final allTasks = await actions.listAllTasks();

    final groupsMap = <String, ({TimesheetProjectOption project, List<Task> tasks})>{};
    for (final task in allTasks) {
      if (task.isCompleted) continue;
      final projId = task.projectId ?? '0';
      final projName = (task.projectName != null && task.projectName != 'Project' && task.projectName!.isNotEmpty)
          ? task.projectName!
          : 'Dự án khác';
      final existing = groupsMap[projId];
      if (existing == null) {
        groupsMap[projId] = (
          project: TimesheetProjectOption(id: projId, name: projName),
          tasks: [task],
        );
      } else {
        existing.tasks.add(task);
      }
    }

    return groupsMap.values
        .map((g) => _TimerProjectTasks(project: g.project, tasks: g.tasks))
        .toList();
  }

  void _toggleProject(_TimerProjectTasks group) {
    final project = group.project;
    final isExpanded = _expandedProjectId == project.id;
    setState(() {
      _expandedProjectId = isExpanded ? null : project.id;
      if (!group.tasks.any((task) => task.id == _selectedTask?.id)) {
        _selectedTask = null;
      }
      _taskError = false;
      if (_validationError != null && _selectedTask != null) {
        _validationError = null;
      }
    });
  }

  void _submit() {
    final note = _note.text.trim();
    if (note.isEmpty) {
      HapticFeedback.mediumImpact();
      setState(() {
        _noteError = true;
        _taskError = false;
        _validationError = 'Vui lòng nhập nội dung công việc đã làm trước khi lưu.';
      });
      showTopNotification(
        context,
        message: 'Vui lòng nhập nội dung công việc đã làm.',
        isError: true,
      );
      return;
    }
    final task = _selectedTask;
    if (task == null) {
      HapticFeedback.mediumImpact();
      setState(() {
        _noteError = false;
        _taskError = true;
        _validationError = 'Vui lòng chọn project và task cần lưu.';
      });
      showTopNotification(
        context,
        message: 'Vui lòng chọn project và task cần lưu.',
        isError: true,
      );
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
            physics: const ClampingScrollPhysics(),
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
                const SizedBox(height: 6),
                Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(LucideIcons.x, color: AppColors.textSecondary),
                      tooltip: 'Hủy',
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'Hủy',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
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
                if (_validationError != null) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF0F2),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(LucideIcons.triangleAlert, color: AppColors.danger, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _validationError!,
                            style: const TextStyle(
                              color: AppColors.danger,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                TextField(
                  controller: _note,
                  maxLines: 4,
                  minLines: 3,
                  onChanged: (_) {
                    if (_noteError || _validationError != null) {
                      setState(() {
                        _noteError = false;
                        _validationError = null;
                      });
                    }
                  },
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
                    fillColor: _noteError ? const Color(0xFFFFF0F2) : const Color(0xFFF3F6FC),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: _noteError
                          ? const BorderSide(color: AppColors.danger, width: 1.5)
                          : BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: _noteError
                          ? const BorderSide(color: AppColors.danger, width: 2.0)
                          : const BorderSide(color: AppColors.timesheet, width: 1.5),
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
                            hasError: _taskError,
                            onProjectTap: () => _toggleProject(group),
                            onTaskTap: (task) => setState(() {
                              _selectedTask = task;
                              _taskError = false;
                              if (_validationError != null) {
                                _validationError = null;
                              }
                            }),
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
    this.hasError = false,
  });

  final _TimerProjectTasks group;
  final bool expanded;
  final String? selectedTaskId;
  final VoidCallback onProjectTap;
  final ValueChanged<Task> onTaskTap;
  final bool hasError;

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
        color: hasError
            ? const Color(0xFFFFF0F2)
            : (highlighted
                ? AppColors.timesheet.withValues(alpha: 0.08)
                : Colors.transparent),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasError
              ? AppColors.danger
              : (highlighted ? AppColors.timesheet : Colors.transparent),
          width: hasError ? 1.5 : 1.0,
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
  String? _validationError;
  bool _noteError = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  void _submit() {
    final note = _note.text.trim();
    if (note.isEmpty) {
      HapticFeedback.mediumImpact();
      setState(() {
        _noteError = true;
        _validationError = 'Vui lòng nhập nội dung công việc đã làm trước khi lưu.';
      });
      showTopNotification(
        context,
        message: 'Vui lòng nhập nội dung công việc đã làm.',
        isError: true,
      );
      return;
    }
    Navigator.pop(
      context,
      _TaskLogResult(note: note, duration: _duration),
    );
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
                if (_validationError != null) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF0F2),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      children: [
                        const Icon(LucideIcons.triangleAlert, color: AppColors.danger, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _validationError!,
                            style: const TextStyle(
                              color: AppColors.danger,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                TextField(
                  controller: _note,
                  maxLines: 4,
                  minLines: 3,
                  onChanged: (_) {
                    if (_noteError || _validationError != null) {
                      setState(() {
                        _noteError = false;
                        _validationError = null;
                      });
                    }
                  },
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
                    fillColor: _noteError ? const Color(0xFFFFF0F2) : const Color(0xFFF3F6FC),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: _noteError
                          ? const BorderSide(color: AppColors.danger, width: 1.5)
                          : BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: _noteError
                          ? const BorderSide(color: AppColors.danger, width: 2.0)
                          : const BorderSide(color: AppColors.timesheet, width: 1.5),
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
    this.userName,
    this.partnerName,
    this.dateAssign,
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
  final String? userName;
  final String? partnerName;
  final DateTime? dateAssign;
  final List<String> tags;

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
  if (duration == Duration.zero) return 'Chưa log (0h)';
  return _formatDuration(duration);
}

String _formatHours(double? hours) {
  if (hours == null || hours <= 0) return '0 giờ';
  final minutes = (hours * 60).round();
  if (minutes <= 0) return '0 giờ';
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

class _TaskChatterSection extends ConsumerStatefulWidget {
  const _TaskChatterSection({
    required this.taskId,
  });

  final String taskId;

  @override
  ConsumerState<_TaskChatterSection> createState() => _TaskChatterSectionState();
}

class _TaskChatterSectionState extends ConsumerState<_TaskChatterSection> {
  final _commentController = TextEditingController();
  bool _sending = false;
  List<TaskMessage>? _localMessages;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _sendComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      final newMsg = await ref.read(taskActionsProvider).addMessage(
        taskId: widget.taskId,
        content: text,
      );
      if (mounted) {
        _commentController.clear();
        setState(() {
          _localMessages = [newMsg, ...(_localMessages ?? const [])];
        });
        showTopNotification(context, message: 'Đã gửi bình luận thành công!');
      }
    } catch (e) {
      if (mounted) {
        showTopNotification(context, message: 'Lỗi gửi bình luận: $e', isError: true);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final taskAsync = ref.watch(taskDetailProvider(widget.taskId));
    final messages = _localMessages ?? taskAsync.valueOrNull?.messages ?? const [];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFE),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.messageSquare, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Trao đổi & Ghi chú (${messages.length})',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (messages.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: Text(
                  'Chưa có ghi chú nào.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: messages.length,
              separatorBuilder: (_, _) => const Divider(height: 16, color: AppColors.border),
              itemBuilder: (ctx, index) {
                final msg = messages[index];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          msg.authorName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          Dates.hm(msg.date),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      msg.body,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ],
                );
              },
            ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  enabled: !_sending,
                  decoration: InputDecoration(
                    hintText: 'Nhập bình luận...',
                    hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                  onSubmitted: (_) => _sendComment(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _sending ? null : _sendComment,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: _sending
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(LucideIcons.send, size: 18, color: Colors.white),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimesheetFilterSheet extends ConsumerStatefulWidget {
  const _TimesheetFilterSheet({required this.initialFilter});

  final TimesheetFilterState initialFilter;

  @override
  ConsumerState<_TimesheetFilterSheet> createState() => _TimesheetFilterSheetState();
}

class _TimesheetFilterSheetState extends ConsumerState<_TimesheetFilterSheet> {
  late String _preset;
  late DateTime? _dateFrom;
  late DateTime? _dateTo;
  late String? _projectId;
  late String? _projectName;
  List<TimesheetProjectOption> _projects = const [];
  bool _loadingProjects = true;

  @override
  void initState() {
    super.initState();
    _preset = widget.initialFilter.presetName;
    _dateFrom = widget.initialFilter.dateFrom;
    _dateTo = widget.initialFilter.dateTo;
    _projectId = widget.initialFilter.projectId;
    _projectName = widget.initialFilter.projectName;
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    try {
      final list = await ref.read(taskActionsProvider).listProjects();
      if (mounted) {
        setState(() {
          _projects = list;
          _loadingProjects = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingProjects = false);
    }
  }

  void _applyPreset(String preset) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    setState(() {
      _preset = preset;
      switch (preset) {
        case 'Hôm nay':
          _dateFrom = today;
          _dateTo = today;
          break;
        case 'Hôm qua':
          final yest = today.subtract(const Duration(days: 1));
          _dateFrom = yest;
          _dateTo = yest;
          break;
        case 'Tuần này':
          _dateFrom = today.subtract(Duration(days: today.weekday - 1));
          _dateTo = _dateFrom!.add(const Duration(days: 6));
          break;
        case 'Tuần trước':
          final startThis = today.subtract(Duration(days: today.weekday - 1));
          _dateFrom = startThis.subtract(const Duration(days: 7));
          _dateTo = startThis.subtract(const Duration(days: 1));
          break;
        case 'Tháng này':
          _dateFrom = DateTime(now.year, now.month, 1);
          _dateTo = DateTime(now.year, now.month + 1, 0);
          break;
        case 'Tháng trước':
          _dateFrom = DateTime(now.year, now.month - 1, 1);
          _dateTo = DateTime(now.year, now.month, 0);
          break;
        case 'Tùy chọn':
          break;
      }
    });
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: _dateFrom != null && _dateTo != null
          ? DateTimeRange(start: _dateFrom!, end: _dateTo!)
          : DateTimeRange(start: DateTime.now(), end: DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _preset = 'Tùy chọn';
        _dateFrom = picked.start;
        _dateTo = picked.end;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final presets = ['Hôm nay', 'Hôm qua', 'Tuần này', 'Tuần trước', 'Tháng này', 'Tháng trước', 'Tùy chọn'];

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 24,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
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
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.soft(AppColors.primary),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      LucideIcons.slidersHorizontal,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Bộ lọc Timesheet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      final now = DateTime.now();
                      setState(() {
                        _preset = 'Hôm nay';
                        _dateFrom = now;
                        _dateTo = now;
                        _projectId = null;
                        _projectName = null;
                      });
                    },
                    icon: const Icon(LucideIcons.rotateCcw, size: 15, color: AppColors.primary),
                    label: const Text(
                      'Đặt lại',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                'Khoảng thời gian',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final p in presets)
                    FilterChip(
                      label: Text(
                        p,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: _preset == p ? FontWeight.w800 : FontWeight.w600,
                          color: _preset == p ? AppColors.primary : AppColors.textPrimary,
                        ),
                      ),
                      selected: _preset == p,
                      selectedColor: AppColors.soft(AppColors.primary),
                      checkmarkColor: AppColors.primary,
                      backgroundColor: Theme.of(context).cardColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: _preset == p ? AppColors.primary : AppColors.border,
                          width: _preset == p ? 1.5 : 1.0,
                        ),
                      ),
                      onSelected: (_) {
                        HapticFeedback.selectionClick();
                        _applyPreset(p);
                      },
                    ),
                ],
              ),
              if (_preset == 'Tùy chọn') ...[
                const SizedBox(height: 14),
                InkWell(
                  onTap: _pickDateRange,
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.soft(AppColors.primary),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(LucideIcons.calendar, size: 18, color: AppColors.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _dateFrom != null && _dateTo != null
                                ? '${Dates.dateVi(_dateFrom!)} — ${Dates.dateVi(_dateTo!)}'
                                : 'Chọn khoảng ngày tùy chỉnh...',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const Icon(LucideIcons.chevronRight, size: 16, color: AppColors.textMuted),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              const Text(
                'Dự án',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              if (_loadingProjects)
                const SizedBox(
                  height: 48,
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                  ),
                )
              else
                DropdownButtonFormField<String?>(
                  initialValue: _projectId,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(LucideIcons.folderKanban, size: 18, color: AppColors.primary),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                    ),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text(
                        'Tất cả dự án',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                    ),
                    for (final proj in _projects)
                      DropdownMenuItem<String?>(
                        value: proj.id,
                        child: Text(
                          proj.name,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                      ),
                  ],
                  onChanged: (val) {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _projectId = val;
                      _projectName = _projects
                          .firstWhere((p) => p.id == val, orElse: () => const TimesheetProjectOption(id: '', name: ''))
                          .name;
                    });
                  },
                ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    final newFilter = TimesheetFilterState(
                      presetName: _preset,
                      dateFrom: _dateFrom,
                      dateTo: _dateTo,
                      projectId: _projectId,
                      projectName: _projectName,
                    );
                    ref.read(timesheetFilterProvider.notifier).state = newFilter;
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shadowColor: AppColors.primary.withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.check, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Áp dụng bộ lọc',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
