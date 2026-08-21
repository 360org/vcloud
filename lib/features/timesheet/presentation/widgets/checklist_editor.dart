import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/timesheet.dart';
import '../../../../shared/widgets/ui_kit.dart';

/// Reusable "what I did + how long" form for a task.
///
/// Renders the note TextField + interactive Stepper/Textbox + 4 duration-preset chips + gradient save button.
class TaskChecklistEditor extends StatefulWidget {
  const TaskChecklistEditor({
    super.key,
    required this.noteController,
    required this.duration,
    required this.saving,
    required this.onDurationChanged,
    required this.onSave,
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
  late int _minutes;

  @override
  void initState() {
    super.initState();
    _minutes = _durationToMinutes(widget.duration);
    _minutesController = TextEditingController(text: '$_minutes');
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
  }

  @override
  void dispose() {
    _minutesController.dispose();
    super.dispose();
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
            children: [
              const Icon(LucideIcons.listChecks, color: Color(0xFF00C83A), size: 18),
              const SizedBox(width: 8),
              Text(
                'Nội dung & thời gian',
                style: TextStyle(
                  color: isDark ? Colors.white : AppColors.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
