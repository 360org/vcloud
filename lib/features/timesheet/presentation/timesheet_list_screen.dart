import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_format.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/ui_kit.dart';

const hardcodedTodayTasks = [
  TodayTaskPreview(
    id: 'erp-sync',
    title: 'Kiểm tra đồng bộ đơn hàng ERP',
    tag: 'ERP',
    accent: AppColors.primary,
    icon: LucideIcons.database,
  ),
  TodayTaskPreview(
    id: 'crm-follow',
    title: 'Cập nhật trạng thái khách hàng CRM',
    tag: 'CRM',
    accent: AppColors.chat,
    icon: LucideIcons.users,
  ),
  TodayTaskPreview(
    id: 'support-ticket',
    title: 'Xử lý ticket tồn từ hôm qua',
    tag: 'Support',
    accent: AppColors.ticket,
    icon: LucideIcons.headphones,
  ),
  TodayTaskPreview(
    id: 'daily-meeting',
    title: 'Chuẩn bị nội dung daily meeting',
    tag: 'Meeting',
    accent: AppColors.timesheet,
    icon: LucideIcons.calendarClock,
  ),
];

final hardcodedTodayTasksProvider = Provider<List<TodayTaskPreview>>(
  (_) => hardcodedTodayTasks,
);

class TodayTaskPreview {
  const TodayTaskPreview({
    required this.id,
    required this.title,
    required this.tag,
    required this.accent,
    required this.icon,
  });

  final String id;
  final String title;
  final String tag;
  final Color accent;
  final IconData icon;
}

class TimesheetListScreen extends StatefulWidget {
  const TimesheetListScreen({super.key});

  @override
  State<TimesheetListScreen> createState() => _TimesheetListScreenState();
}

class _TimesheetListScreenState extends State<TimesheetListScreen> {
  final _tasks = hardcodedTodayTasks
      .map(
        (task) => _TodayTask(
          id: task.id,
          title: task.title,
          tag: task.tag,
          accent: task.accent,
          icon: task.icon,
        ),
      )
      .toList();

  Timer? _ticker;
  DateTime? _startedAt;
  Duration _elapsedBeforePause = Duration.zero;
  bool _running = false;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Duration get _elapsed {
    if (!_running || _startedAt == null) return _elapsedBeforePause;
    return _elapsedBeforePause + DateTime.now().difference(_startedAt!);
  }

  int get _doneMinutes {
    return _tasks
        .where((task) => task.done)
        .fold(0, (sum, task) => sum + task.logged.inMinutes);
  }

  void _startTimer() {
    HapticFeedback.selectionClick();
    setState(() {
      _running = true;
      _startedAt = DateTime.now();
    });
    _ticker ??= Timer.periodic(
      const Duration(seconds: 1),
      (_) => mounted ? setState(() {}) : null,
    );
  }

  void _pauseTimer() {
    HapticFeedback.selectionClick();
    setState(() {
      _elapsedBeforePause = _elapsed;
      _running = false;
      _startedAt = null;
    });
  }

  void _resetTimer() {
    HapticFeedback.lightImpact();
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

    final openTasks = _tasks.where((task) => !task.done).toList();
    if (openTasks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không còn task chưa hoàn thành.')),
      );
      return;
    }

    final result = await _openTimerSaveSheet(
      tasks: openTasks,
      duration: elapsed,
    );
    if (result == null) return;

    _completeTask(
      result.task.id,
      _TaskLogResult(note: result.note, duration: elapsed),
    );
    _resetTimer();
  }

  Future<void> _logTaskDirectly(_TodayTask task) async {
    final result = await _openLogSheet(
      task: task,
      initialDuration: const Duration(minutes: 30),
      allowDurationEdit: true,
    );
    if (result == null) return;
    _completeTask(task.id, result);
  }

  Future<_TaskLogResult?> _openLogSheet({
    required _TodayTask task,
    required Duration initialDuration,
    required bool allowDurationEdit,
  }) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet<_TaskLogResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TaskLogSheet(
        task: task,
        initialDuration: initialDuration,
        allowDurationEdit: allowDurationEdit,
      ),
    );
  }

  Future<_TimerSaveResult?> _openTimerSaveSheet({
    required List<_TodayTask> tasks,
    required Duration duration,
  }) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet<_TimerSaveResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TimerSaveSheet(tasks: tasks, duration: duration),
    );
  }

  void _completeTask(String taskId, _TaskLogResult result) {
    setState(() {
      final index = _tasks.indexWhere((task) => task.id == taskId);
      if (index == -1) return;
      _tasks[index] = _tasks[index].copyWith(
        done: true,
        logged: result.duration,
        note: result.note,
        completedAt: DateTime.now(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final openTasks = _tasks.where((task) => !task.done).toList();
    final doneTasks = _tasks.where((task) => task.done).toList();

    return AppScaffold(
      title: 'Timesheet',
      showAppBar: false,
      wrapSafeArea: false,
      body: ColoredBox(
        color: const Color(0xFFF7F8FC),
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
              const SizedBox(height: 14),
              _TodaySummaryCard(minutes: _doneMinutes, count: doneTasks.length),
              const SizedBox(height: 16),
              _TaskSection(
                title: 'Task cần làm hôm nay',
                count: openTasks.length,
                emptyText: 'Bạn đã hoàn thành hết task hôm nay.',
                tasks: openTasks,
                done: false,
                onTap: _logTaskDirectly,
              ),
              const SizedBox(height: 16),
              _TaskSection(
                title: 'Đã hoàn thành',
                count: doneTasks.length,
                emptyText: 'Chưa có task nào hoàn thành.',
                tasks: doneTasks,
                done: true,
                onTap: (_) {},
              ),
            ],
          ),
        ),
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
              const Expanded(
                child: Text(
                  'Bộ đếm công việc',
                  style: TextStyle(
                    color: AppColors.textPrimary,
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
              style: const TextStyle(
                color: AppColors.textPrimary,
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
  });

  final String title;
  final int count;
  final String emptyText;
  final List<_TodayTask> tasks;
  final bool done;
  final ValueChanged<_TodayTask> onTap;

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
                  style: const TextStyle(
                    color: AppColors.textPrimary,
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
            ],
          ),
          const SizedBox(height: 12),
          if (tasks.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                emptyText,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            )
          else
            for (var i = 0; i < tasks.length; i++) ...[
              _TaskTile(
                task: tasks[i],
                done: done,
                onTap: () => onTap(tasks[i]),
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
  });

  final _TodayTask task;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: done ? null : onTap,
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
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      decoration: done ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      _TagPill(label: task.tag, color: task.accent),
                      if (done) ...[
                        const SizedBox(width: 8),
                        Text(
                          _formatMinutes(task.logged.inMinutes),
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
            Icon(
              done ? LucideIcons.checkCircle2 : LucideIcons.chevronRight,
              color: done ? AppColors.success : AppColors.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _TimerSaveSheet extends StatefulWidget {
  const _TimerSaveSheet({required this.tasks, required this.duration});

  final List<_TodayTask> tasks;
  final Duration duration;

  @override
  State<_TimerSaveSheet> createState() => _TimerSaveSheetState();
}

class _TimerSaveSheetState extends State<_TimerSaveSheet> {
  final _note = TextEditingController();
  _TodayTask? _selectedTask;

  @override
  void initState() {
    super.initState();
    if (widget.tasks.isNotEmpty) _selectedTask = widget.tasks.first;
  }

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
            color: AppColors.surface,
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
                  'Chọn task để lưu vào',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                for (final task in widget.tasks)
                  _TimerTaskChoice(
                    task: task,
                    selected: _selectedTask?.id == task.id,
                    onTap: () => setState(() => _selectedTask = task),
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
                    onPressed: () {
                      final note = _note.text.trim();
                      final task = _selectedTask;
                      if (note.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Nhập nội dung đã làm trước.'),
                          ),
                        );
                        return;
                      }
                      if (task == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Chọn task cần lưu.')),
                        );
                        return;
                      }
                      Navigator.pop(
                        context,
                        _TimerSaveResult(task: task, note: note),
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
}

class _TimerTaskChoice extends StatelessWidget {
  const _TimerTaskChoice({
    required this.task,
    required this.selected,
    required this.onTap,
  });

  final _TodayTask task;
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
              ? AppColors.timesheet.withValues(alpha: 0.12)
              : const Color(0xFFF3F6FC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.timesheet : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(task.icon, color: task.accent, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                task.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Icon(
              selected ? LucideIcons.checkCircle2 : LucideIcons.circle,
              color: selected ? AppColors.timesheet : AppColors.textMuted,
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
            color: AppColors.surface,
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
    required this.tag,
    required this.accent,
    required this.icon,
    this.done = false,
    this.logged = Duration.zero,
    this.note = '',
    this.completedAt,
  });

  final String id;
  final String title;
  final String tag;
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
      tag: tag,
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

  final _TodayTask task;
  final String note;
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
