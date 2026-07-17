import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/timesheet.dart';
import '../../../../shared/widgets/ui_kit.dart';

/// Reusable "what I did + how long" form for a task.
///
/// Renders the note TextField + 4 duration-preset chips + a gradient
/// save button. The save semantics (log-only / complete / update) live
/// in the parent screen via [onSave] + [saveLabel]; this widget just
/// hosts the inputs and forwards the chosen [TimesheetDuration].
///
/// Used both inside the timesheet screen's full task-detail sheet and
/// the home dashboard's quick-edit popup.
class TaskChecklistEditor extends StatelessWidget {
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
  });

  final TextEditingController noteController;
  final TimesheetDuration duration;
  final bool saving;
  final ValueChanged<TimesheetDuration>? onDurationChanged;
  final VoidCallback? onSave;

  /// Text on the trailing save button. The calling screen picks
  /// wording that hints at what tap actually does (log-only vs.
  /// complete vs. update).
  final String saveLabel;

  final String noteLabelText;
  final String noteHintText;

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
          TextField(
            controller: noteController,
            minLines: 3,
            maxLines: 5,
            decoration: InputDecoration(
              labelText: noteLabelText,
              hintText: noteHintText,
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
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final item in TimesheetDuration.values)
                ChoiceChip(
                  label: Text(item.label),
                  selected: duration == item,
                  onSelected: onDurationChanged == null
                      ? null
                      : (_) => onDurationChanged!(item),
                  selectedColor: AppColors.success.withValues(alpha: 0.18),
                  labelStyle: TextStyle(
                    color: duration == item
                        ? AppColors.success
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w800,
                  ),
                  side: BorderSide(
                    color: duration == item
                        ? AppColors.success
                        : AppColors.border,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          GradientButton(
            label: saving ? 'Đang lưu' : saveLabel,
            icon: LucideIcons.check,
            gradient: AppColors.successGrad,
            glowColor: AppColors.success,
            loading: saving,
            onPressed: onSave,
          ),
        ],
      ),
    );
  }
}
