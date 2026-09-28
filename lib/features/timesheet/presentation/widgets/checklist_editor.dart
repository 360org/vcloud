import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/task_checklist_item.dart';
import '../../../../shared/models/timesheet.dart';
import '../../../../shared/widgets/ui_kit.dart';

export '../../../../shared/models/task_checklist_item.dart';

/// Reusable "what I did + how long" form for a task.
///
/// Renders subtask checklist + % progress bar + note TextField + interactive Stepper/Textbox + duration-preset chips + gradient save button.
class TaskChecklistEditor extends StatefulWidget {
  const TaskChecklistEditor({
    super.key,
    required this.noteController,
    required this.duration,
    required this.saving,
    required this.onDurationChanged,
    required this.onSave,
    this.initialSubtasks = const <TaskChecklistItem>[],
    this.onSubtasksChanged,
    this.onProgressChanged,
    this.saveLabel = 'Lưu & đánh dấu hoàn thành',
    this.noteLabelText = 'Nội dung công việc đã làm',
    this.noteHintText = 'Ghi ngắn gọn kết quả, phần đã xử lý...',
    this.hasError = false,
    this.errorMessage,
  });

  final TextEditingController noteController;
  final TimesheetDuration duration;
  final bool saving;
  final ValueChanged<TimesheetDuration>? onDurationChanged;
  final VoidCallback? onSave;

  final List<TaskChecklistItem> initialSubtasks;
  final ValueChanged<List<TaskChecklistItem>>? onSubtasksChanged;
  final ValueChanged<double>? onProgressChanged;

  final String saveLabel;
  final String noteLabelText;
  final String noteHintText;
  final bool hasError;
  final String? errorMessage;

  @override
  State<TaskChecklistEditor> createState() => _TaskChecklistEditorState();
}

class _TaskChecklistEditorState extends State<TaskChecklistEditor> {
  late TextEditingController _minutesController;
  late TextEditingController _newSubtaskController;
  late int _minutes;
  late List<TaskChecklistItem> _subtasks;

  @override
  void initState() {
    super.initState();
    _minutes = _durationToMinutes(widget.duration);
    _minutesController = TextEditingController(text: '$_minutes');
    _newSubtaskController = TextEditingController();
    _subtasks = List<TaskChecklistItem>.from(widget.initialSubtasks);
  }

  @override
  void didUpdateWidget(covariant TaskChecklistEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      if (_minutesToDuration(_minutes) != widget.duration) {
        _minutes = _durationToMinutes(widget.duration);
        _minutesController.text = '$_minutes';
      }
    }
    if (oldWidget.initialSubtasks != widget.initialSubtasks) {
      _subtasks = List<TaskChecklistItem>.from(widget.initialSubtasks);
    }
  }

  @override
  void dispose() {
    _minutesController.dispose();
    _newSubtaskController.dispose();
    super.dispose();
  }

  double get _progressPercent => calculateSubtaskProgress(_subtasks);
  int get _completedCount => _subtasks.where((s) => s.isCompleted).length;

  void _addSubtask() {
    final text = _newSubtaskController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _subtasks.add(
        TaskChecklistItem(
          id: 'subtask_${DateTime.now().microsecondsSinceEpoch}',
          title: text,
          isCompleted: false,
        ),
      );
      _newSubtaskController.clear();
    });
    _notifySubtasks();
  }

  void _toggleSubtask(int index) {
    if (index < 0 || index >= _subtasks.length) return;
    setState(() {
      final current = _subtasks[index];
      _subtasks[index] = current.copyWith(isCompleted: !current.isCompleted);
    });
    _notifySubtasks();
  }

  void _removeSubtask(int index) {
    if (index < 0 || index >= _subtasks.length) return;
    setState(() {
      _subtasks.removeAt(index);
    });
    _notifySubtasks();
  }

  void _notifySubtasks() {
    widget.onSubtasksChanged?.call(List.unmodifiable(_subtasks));
    widget.onProgressChanged?.call(_progressPercent);
  }

  int _durationToMinutes(TimesheetDuration d) {
    return switch (d) {
      TimesheetDuration.fifteen => 15,
      TimesheetDuration.thirty => 30,
      TimesheetDuration.fortyFive => 45,
      TimesheetDuration.sixty => 60,
    };
  }

  TimesheetDuration _minutesToDuration(int mins) {
    if (mins <= 22) return TimesheetDuration.fifteen;
    if (mins <= 37) return TimesheetDuration.thirty;
    if (mins <= 52) return TimesheetDuration.fortyFive;
    return TimesheetDuration.sixty;
  }

  void _updateMinutes(int newMins) {
    final clamped = newMins.clamp(5, 1440);
    setState(() {
      _minutes = clamped;
      _minutesController.text = '$_minutes';
    });
    final matchedDur = _minutesToDuration(clamped);
    widget.onDurationChanged?.call(matchedDur);
  }

  void _onTyped(String text) {
    final cleanText = text.replaceAll(RegExp(r'[^0-9]'), '');
    final val = int.tryParse(cleanText);
    if (val != null && val > 0) {
      final clamped = val.clamp(1, 1440);
      _minutes = clamped;
      final matchedDur = _minutesToDuration(clamped);
      widget.onDurationChanged?.call(matchedDur);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : AppColors.soft(AppColors.success),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF00C83A).withValues(alpha: isDark ? 0.35 : 0.16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(LucideIcons.listChecks, color: Color(0xFF00C83A), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Đầu việc & tiến độ',
                    style: TextStyle(
                      color: isDark ? Colors.white : AppColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              if (_subtasks.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00C83A).withValues(alpha: isDark ? 0.25 : 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF00C83A).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    '${_progressPercent.toStringAsFixed(0)}% ($_completedCount/${_subtasks.length})',
                    style: const TextStyle(
                      color: Color(0xFF00C83A),
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),
          if (_subtasks.isNotEmpty) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: _subtasks.isEmpty ? 0.0 : (_completedCount / _subtasks.length),
                minHeight: 6,
                backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.black.withValues(alpha: 0.06),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00C83A)),
              ),
            ),
          ],
          const SizedBox(height: 10),

          // ── Subtask List ──────────────────────────────────────────────
          if (_subtasks.isNotEmpty) ...[
            for (int i = 0; i < _subtasks.length; i++) ...[
              () {
                final item = _subtasks[i];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.saving ? null : () => _toggleSubtask(i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                      child: Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: item.isCompleted ? const Color(0xFF00C83A) : Colors.transparent,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: item.isCompleted
                                    ? const Color(0xFF00C83A)
                                    : (isDark ? Colors.white38 : AppColors.border),
                                width: 1.5,
                              ),
                            ),
                            child: item.isCompleted
                                ? const Icon(LucideIcons.check, size: 14, color: Colors.white)
                                : null,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              item.title,
                              style: TextStyle(
                                color: item.isCompleted
                                    ? (isDark ? Colors.white38 : AppColors.textSecondary)
                                    : (isDark ? Colors.white : AppColors.textPrimary),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                decoration: item.isCompleted ? TextDecoration.lineThrough : null,
                              ),
                            ),
                          ),
                          if (!widget.saving)
                            IconButton(
                              icon: const Icon(LucideIcons.trash2, size: 16),
                              color: isDark ? Colors.white38 : AppColors.textSecondary,
                              splashRadius: 16,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                              onPressed: () => _removeSubtask(i),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }(),
            ],
            const SizedBox(height: 6),
          ],

          // ── Add Subtask Field ─────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newSubtaskController,
                  enabled: !widget.saving,
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    fontSize: 13,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Thêm đầu việc con (subtask)...',
                    hintStyle: TextStyle(
                      color: isDark ? Colors.white38 : AppColors.textSecondary,
                      fontSize: 13,
                    ),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    filled: true,
                    fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white12 : AppColors.border,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white12 : AppColors.border,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: Color(0xFF00C83A),
                      ),
                    ),
                  ),
                  onSubmitted: (_) => _addSubtask(),
                ),
              ),
              const SizedBox(width: 8),
              PressableScale(
                onTap: widget.saving ? null : _addSubtask,
                child: Container(
                  height: 38,
                  width: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00C83A),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(LucideIcons.plus, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (widget.errorMessage != null &&
              widget.errorMessage!.isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF450A0A) : const Color(0xFFFFF0F2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.danger.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    LucideIcons.triangleAlert,
                    color: AppColors.danger,
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.errorMessage!,
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
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : null,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: widget.hasError
                    ? AppColors.danger
                    : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.transparent),
                width: widget.hasError ? 1.5 : (isDark ? 1.0 : 0),
              ),
            ),
            child: TextField(
              controller: widget.noteController,
              minLines: 3,
              maxLines: 5,
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF0F172A),
                fontSize: 14,
              ),
              decoration: InputDecoration(
                labelText: widget.noteLabelText,
                labelStyle: TextStyle(
                  color: isDark ? Colors.white60 : null,
                ),
                hintText: widget.noteHintText,
                hintStyle: TextStyle(
                  color: isDark ? Colors.white38 : null,
                ),
                fillColor: widget.hasError
                    ? (isDark ? const Color(0xFF450A0A) : const Color(0xFFFFF5F5))
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Thời gian',
            style: TextStyle(
              color: isDark ? Colors.white70 : AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),

          // ── Stepper [-] Textbox [~] [+] ──────────────────────────────────
          Row(
            children: [
              PressableScale(
                onTap: (widget.onDurationChanged == null || widget.saving)
                    ? null
                    : () {
                        HapticFeedback.lightImpact();
                        _updateMinutes(_minutes - 15 < 5 ? 5 : _minutes - 15);
                      },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? Colors.white.withValues(alpha: 0.08) : AppColors.border,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    LucideIcons.minus,
                    size: 20,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF00C83A),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00C83A).withValues(alpha: 0.15),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        LucideIcons.clock,
                        size: 16,
                        color: Color(0xFF00C83A),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 48,
                        child: TextField(
                          controller: _minutesController,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          enabled: widget.onDurationChanged != null &&
                              !widget.saving,
                          style: TextStyle(
                            color: isDark ? Colors.white : AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            errorBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            filled: false,
                            fillColor: Colors.transparent,
                            contentPadding: EdgeInsets.zero,
                            isDense: true,
                          ),
                          onChanged: _onTyped,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'phút',
                        style: TextStyle(
                          color: isDark ? Colors.white70 : AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              PressableScale(
                onTap: (widget.onDurationChanged == null || widget.saving)
                    ? null
                    : () {
                        HapticFeedback.lightImpact();
                        _updateMinutes(_minutes + 15);
                      },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? Colors.white.withValues(alpha: 0.08) : AppColors.border,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    LucideIcons.plus,
                    size: 20,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // ── Presets Chips (15 phút, 30 phút, 45 phút, 1 giờ) ──────────────
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in TimesheetDuration.values) ...[
                () {
                  final isSelected = _minutes == _durationToMinutes(item);
                  return PressableScale(
                    onTap: (widget.onDurationChanged == null || widget.saving)
                        ? null
                        : () {
                            HapticFeedback.selectionClick();
                            _updateMinutes(_durationToMinutes(item));
                          },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(0xFF00C83A)
                            : (isDark ? const Color(0xFF1E293B) : Colors.white),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? const Color(0xFF00C83A)
                              : (isDark ? Colors.white.withValues(alpha: 0.08) : AppColors.border),
                          width: isSelected ? 1.5 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF00C83A).withValues(
                                    alpha: 0.25,
                                  ),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : const [],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isSelected) ...[
                            const Icon(
                              LucideIcons.check,
                              size: 14,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 5),
                          ],
                          Text(
                            item.label,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : (isDark ? Colors.white70 : AppColors.textSecondary),
                              fontSize: 13,
                              fontWeight: isSelected
                                  ? FontWeight.w900
                                  : FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }(),
              ],
            ],
          ),
          const SizedBox(height: 14),
          GradientButton(
            label: widget.saving ? 'Đang lưu' : widget.saveLabel,
            icon: LucideIcons.check,
            gradient: AppColors.successGrad,
            glowColor: AppColors.success,
            loading: widget.saving,
            onPressed: widget.onSave,
          ),
        ],
      ),
    );
  }
}
