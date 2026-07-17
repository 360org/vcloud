import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/task.dart';
import 'category_chip.dart';

/// Row renderer for one [Task]. Used inside [TodayTasksSection]; the
/// only behavioural difference between `open` and `done` is the
/// trailing chip and the chevron.
class TaskRow extends StatelessWidget {
  const TaskRow({
    super.key,
    required this.task,
    required this.kind,
    this.onTap,
    this.onDelete,
  });

  final Task task;
  final TaskRowKind kind;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final catColor = categoryColor(task.category);
    final catIcon = categoryIcon(task.category);

    final leading = Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        gradient: AppColors.featureGrad(catColor, catColor),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(catIcon, color: Colors.white, size: 18),
    );

    final title = Text(
      task.title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
    );

    Widget trailing;
    if (kind == TaskRowKind.done) {
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, color: AppColors.success, size: 18),
          const SizedBox(width: 6),
          Text(
            _fmtTime(task.completedAt!),
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    } else {
      trailing = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            categoryVi(task.category),
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
        ],
      );
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 12),
            Expanded(child: title),
            trailing,
          ],
        ),
      ),
    );
  }

  static String _fmtTime(DateTime t) {
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}

enum TaskRowKind { open, done }
