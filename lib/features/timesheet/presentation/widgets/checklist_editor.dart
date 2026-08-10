import 'package:flutter/material.dart';
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
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.soft(AppColors.success),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(LucideIcons.listChecks, color: AppColors.success, size: 18),
              SizedBox(width: 8),
              Text(
                'Nội dung & thời gian',
                style: TextStyle(
                  color: AppColors.textPrimary,
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
                color: const Color(0xFFFFF0F2),
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
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: widget.hasError ? AppColors.danger : Colors.transparent,
                width: widget.hasError ? 1.5 : 0,
              ),
            ),
            child: TextField(
              controller: widget.noteController,
              minLines: 3,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: widget.noteLabelText,
                hintText: widget.noteHintText,
                fillColor: widget.hasError ? const Color(0xFFFFF5F5) : null,
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Thời gian',
            style: TextStyle(
              color: AppColors.textSecondary,
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
                    : () => _updateMinutes(_minutes - 15 < 5 ? 5 : _minutes - 15),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Icon(LucideIcons.minus, size: 20, color: AppColors.textPrimary),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.success),
                  ),
                  child: Row(
                    children: [
                      const Icon(LucideIcons.clock, size: 16, color: AppColors.success),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _minutesController,
                          keyboardType: TextInputType.number,
                          enabled: widget.onDurationChanged != null && !widget.saving,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Nhập phút...',
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 10),
                            isDense: true,
                          ),
                          onChanged: _onTyped,
                        ),
                      ),
                      const Text(
                        'phút',
                        style: TextStyle(
                          color: AppColors.textSecondary,
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
                    : () => _updateMinutes(_minutes + 15),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Icon(LucideIcons.plus, size: 20, color: AppColors.textPrimary),
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
              for (final item in TimesheetDuration.values)
                ChoiceChip(
                  label: Text(item.label),
                  selected: _minutes == _durationToMinutes(item),
                  onSelected: widget.onDurationChanged == null || widget.saving
                      ? null
                      : (_) => _updateMinutes(_durationToMinutes(item)),
                  selectedColor: AppColors.success.withValues(alpha: 0.18),
                  labelStyle: TextStyle(
                    color: _minutes == _durationToMinutes(item)
                        ? AppColors.success
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w800,
                  ),
                  side: BorderSide(
                    color: _minutes == _durationToMinutes(item)
                        ? AppColors.success
                        : AppColors.border,
                  ),
                ),
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
