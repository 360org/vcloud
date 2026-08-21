import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/timesheet.dart';

/// Shared selectable-pill used across every timesheet surface
/// (stopwatch category strip, quick-add row, future task-creation
/// sheet). Lifted out of `timesheet_list_screen.dart` so all three
/// call sites render the same chrome.
class CategoryChip extends StatelessWidget {
  const CategoryChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.color,
    this.center = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? color;
  final bool center;

  @override
  Widget build(BuildContext context) {
    final pillColor = color ?? AppColors.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        alignment: center ? Alignment.center : null,
        decoration: BoxDecoration(
          gradient: selected
              ? AppColors.featureGrad(pillColor, pillColor)
              : null,
          color: selected ? null : const Color(0xFFF1F3F6),
          borderRadius: BorderRadius.circular(12),
          boxShadow: selected ? AppColors.glow(pillColor, opacity: 0.2) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null && selected) ...[
              Icon(icon, color: Colors.white, size: 14),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Vietnamese label for [TimesheetCategory]. Identical to the
/// raw enum name today ("ERP", "CRM", "Meeting", "Support") except
/// for [TimesheetCategory.other] which renders as "Khác".
String categoryVi(TimesheetCategory c) => switch (c) {
  TimesheetCategory.erp => 'ERP',
  TimesheetCategory.crm => 'CRM',
  TimesheetCategory.meeting => 'Meeting',
  TimesheetCategory.support => 'Support',
  TimesheetCategory.other => 'Khác',
};

/// Material icon paired with each category. Used by every chip row
/// and the task-list row icons.
IconData categoryIcon(TimesheetCategory c) => switch (c) {
  TimesheetCategory.erp => Icons.storage,
  TimesheetCategory.crm => Icons.groups_2_outlined,
  TimesheetCategory.meeting => Icons.event_outlined,
  TimesheetCategory.support => Icons.support_agent,
  TimesheetCategory.other => Icons.more_horiz,
};

/// Feature colour for each category. Mirrors the convention used by
/// the timer card and quick-add (ERP→primary, CRM→chat,
/// Meeting→timesheet, Support→ticket, Other→textMuted).
Color categoryColor(TimesheetCategory c) => switch (c) {
  TimesheetCategory.erp => AppColors.primary,
  TimesheetCategory.crm => AppColors.chat,
  TimesheetCategory.meeting => AppColors.timesheet,
  TimesheetCategory.support => AppColors.ticket,
  TimesheetCategory.other => AppColors.textMuted,
};
