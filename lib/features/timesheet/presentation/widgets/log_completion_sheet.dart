import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/task.dart';
import '../../../../shared/models/timesheet.dart';
import '../../../../shared/widgets/ui_kit.dart';
import '../../application/task_controller.dart';
import '../../application/timesheet_controller.dart';

/// "Ghi những gì đã làm" + quick duration picker → complete the task
/// in one shot. Used from [TodayTasksSection] when the user taps an
/// incomplete row (workflow B in the plan).
class LogCompletionSheet extends ConsumerStatefulWidget {
  const LogCompletionSheet({super.key, required this.task});

  final Task task;

  @override
  ConsumerState<LogCompletionSheet> createState() => _LogCompletionSheetState();
}

class _LogCompletionSheetState extends ConsumerState<LogCompletionSheet> {
  final _summary = TextEditingController();
  TimesheetDuration _duration = TimesheetDuration.thirty;
  bool _saving = false;

  @override
  void dispose() {
    _summary.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_summary.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bạn đã làm gì? Hãy mô tả nhé.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(taskActionsProvider)
          .complete(
            taskId: widget.task.id,
            summary: _summary.text.trim(),
            duration: _duration,
          );
      // Also nudge the timesheet entries stream so the right-hand
      // "Công việc hôm nay" list stays in sync with the new entry.
      ref.invalidate(timesheetStreamProvider);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Failure: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final catColor = categoryColorSync(widget.task.category);
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            // Task header
            GlassCard(
              glowColor: catColor,
              padding: const EdgeInsets.all(14),
              radius: 16,
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: AppColors.featureGrad(catColor, catColor),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      categoryIconSync(widget.task.category),
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.task.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.title.copyWith(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          categoryViSync(widget.task.category),
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            // Description
            Text(
              'Bạn đã làm gì?',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _summary,
              maxLength: 200,
              maxLines: 3,
              minLines: 2,
              style: AppTextStyles.body.copyWith(fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Mô tả ngắn (bắt buộc)',
                hintStyle: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 15,
                ),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: catColor, width: 1.6),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Chọn nhanh thời lượng',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final d in TimesheetDuration.values)
                  DurationQuickChip(
                    label: d.presetLabel,
                    selected: _duration == d,
                    onTap: () => setState(() => _duration = d),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            GradientButton(
              label: 'Lưu & đánh dấu hoàn thành',
              icon: Icons.check_circle_outline,
              loading: _saving,
              gradient: AppColors.featureGrad(
                AppColors.success,
                AppColors.success,
              ),
              glowColor: AppColors.success,
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}

/// Inline helper — equivalent to `categoryColor(category)` but
/// avoids the cross-file import explosion inside this leaf widget.
Color categoryColorSync(TimesheetCategory c) => switch (c) {
  TimesheetCategory.erp => AppColors.primary,
  TimesheetCategory.crm => AppColors.chat,
  TimesheetCategory.meeting => AppColors.timesheet,
  TimesheetCategory.support => AppColors.ticket,
  TimesheetCategory.other => AppColors.textMuted,
};

IconData categoryIconSync(TimesheetCategory c) => switch (c) {
  TimesheetCategory.erp => Icons.storage,
  TimesheetCategory.crm => Icons.groups_2_outlined,
  TimesheetCategory.meeting => Icons.event_outlined,
  TimesheetCategory.support => Icons.support_agent,
  TimesheetCategory.other => Icons.more_horiz,
};

String categoryViSync(TimesheetCategory c) => switch (c) {
  TimesheetCategory.erp => 'ERP',
  TimesheetCategory.crm => 'CRM',
  TimesheetCategory.meeting => 'Meeting',
  TimesheetCategory.support => 'Support',
  TimesheetCategory.other => 'Khác',
};

/// Inline duration quick-select chip — kept tiny here so the sheet
/// stays self-contained.
class DurationQuickChip extends StatelessWidget {
  const DurationQuickChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          gradient: selected ? AppColors.brand : null,
          color: selected ? null : const Color(0xFFF1F3F6),
          borderRadius: BorderRadius.circular(12),
          boxShadow: selected ? AppColors.glow(AppColors.primary) : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
