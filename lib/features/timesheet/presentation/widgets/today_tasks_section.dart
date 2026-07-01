import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/task.dart';
import '../../../../shared/models/timesheet.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/ui_kit.dart';
import '../../application/task_controller.dart';
import '../../application/timesheet_controller.dart';
import 'category_chip.dart';
import 'log_completion_sheet.dart';
import 'task_row.dart';

/// "Công việc của tôi" — Today's tasks split into Chưa hoàn thành /
/// Đã hoàn thành. Mounted inside [TimesheetListScreen] below the
/// "Công việc hôm nay" entries list.
class TodayTasksSection extends ConsumerWidget {
  const TodayTasksSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final split = ref.watch(todayTasksSplitProvider);
    final totalEmpty = split.open.isEmpty && split.done.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitleRow(
          title: 'Công việc của tôi',
          subtitle:
              '${split.open.length} chưa xong • ${split.done.length} hoàn thành',
          onAdd: () => _showCreateTaskDialog(context, ref),
        ),
        const SizedBox(height: 12),
        if (totalEmpty)
          const EmptyState(
            icon: Icons.checklist_rtl,
            title: 'Chưa có task nào hôm nay',
            subtitle: 'Bấm “+ Thêm” phía trên để tạo việc cần làm.',
          )
        else
          _TasksCard(
            open: split.open,
            done: split.done,
            onOpenTap: (t) => _openLogSheet(context, t),
            onDelete: (id) => _confirmDelete(context, ref, id),
          ),
      ],
    );
  }

  Future<void> _openLogSheet(BuildContext context, Task t) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF7F8FC),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: LogCompletionSheet(task: t),
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    String taskId,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa task?'),
        content: const Text('Task sẽ bị xóa. Timesheet đã log vẫn giữ lại.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await ref.read(taskActionsProvider).delete(taskId);
        ref.invalidate(timesheetStreamProvider);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Xóa thất bại: $e')));
        }
      }
    }
  }
}

class _SectionTitleRow extends StatelessWidget {
  const _SectionTitleRow({
    required this.title,
    required this.subtitle,
    required this.onAdd,
  });

  final String title;
  final String subtitle;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.title.copyWith(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onAdd,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                gradient: AppColors.brand,
                borderRadius: BorderRadius.circular(20),
                boxShadow: AppColors.glow(AppColors.primary, opacity: 0.25),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, size: 16, color: Colors.white),
                  SizedBox(width: 4),
                  Text(
                    'Thêm',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TasksCard extends StatelessWidget {
  const _TasksCard({
    required this.open,
    required this.done,
    required this.onOpenTap,
    required this.onDelete,
  });

  final List<Task> open;
  final List<Task> done;
  final ValueChanged<Task> onOpenTap;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Container(
        decoration: glassDecoration(),
        child: Column(
          children: [
            if (open.isEmpty && done.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Text(
                    '🎉 Hết task — đã làm hết rồi!',
                    style: AppTextStyles.body.copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              )
            else
              ..._groupRows(
                heading: 'Chưa hoàn thành',
                tasks: open,
                kind: TaskRowKind.open,
                onTap: onOpenTap,
                onDelete: onDelete,
              ),
            if (open.isNotEmpty && done.isNotEmpty)
              const Divider(indent: 16, endIndent: 16, height: 12),
            if (done.isNotEmpty)
              ..._groupRows(
                heading: 'Hoàn thành',
                tasks: done,
                kind: TaskRowKind.done,
                onTap: null,
                onDelete: onDelete,
              ),
          ],
        ),
      ),
    );
  }

  List<Widget> _groupRows({
    required String heading,
    required List<Task> tasks,
    required TaskRowKind kind,
    required ValueChanged<Task>? onTap,
    required ValueChanged<String> onDelete,
  }) {
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
        child: Row(
          children: [
            Text(
              heading,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.soft(AppColors.primary),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${tasks.length}',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
      for (var i = 0; i < tasks.length; i++) ...[
        if (kind == TaskRowKind.open)
          Dismissible(
            key: ValueKey('open-${tasks[i].id}'),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.delete_outline,
                color: Colors.white,
                size: 20,
              ),
            ),
            confirmDismiss: (_) async {
              HapticFeedback.mediumImpact();
              // Defer to the parent's dialog by signalling.
              onDelete(tasks[i].id);
              return false; // Don't auto-dismiss; the parent handles deletion.
            },
            child: TaskRow(
              task: tasks[i],
              kind: kind,
              onTap: onTap == null ? null : () => onTap(tasks[i]),
            ),
          )
        else
          TaskRow(
            task: tasks[i],
            kind: kind,
            onDelete: () => onDelete(tasks[i].id),
          ),
        if (i != tasks.length - 1) const Divider(indent: 56, height: 1),
      ],
    ];
  }
}

/// Tiny inline "create task" form. Kept here (vs. in `task_row.dart`)
/// because it is the only consumer; promotion to a shared file is
/// only worth it once we have a second screen that creates tasks.
Future<void> showCreateTaskSheet(BuildContext context, WidgetRef ref) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF7F8FC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: const _CreateTaskSheet(),
    ),
  );
}

Future<void> _showCreateTaskDialog(BuildContext context, WidgetRef ref) =>
    showCreateTaskSheet(context, ref);

class _CreateTaskSheet extends ConsumerStatefulWidget {
  const _CreateTaskSheet();
  @override
  ConsumerState<_CreateTaskSheet> createState() => _CreateTaskSheetState();
}

class _CreateTaskSheetState extends ConsumerState<_CreateTaskSheet> {
  final _title = TextEditingController();
  TimesheetCategory _category = TimesheetCategory.other;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final t = _title.text.trim();
    if (t.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nhập tiêu đề task trước đã.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(taskActionsProvider).create(title: t, category: _category);
      if (mounted) Navigator.of(context).pop();
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
    final padding = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom: padding + 16,
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
            Text(
              'Tạo task',
              style: AppTextStyles.title.copyWith(
                fontSize: 20,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              maxLength: 200,
              maxLines: 2,
              minLines: 1,
              style: AppTextStyles.body.copyWith(fontSize: 16),
              decoration: InputDecoration(
                hintText: 'Tên công việc hôm nay',
                hintStyle: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 16,
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
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.6,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Phân loại',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in TimesheetCategory.values)
                  CategoryChip(
                    label: categoryVi(c),
                    icon: categoryIcon(c),
                    color: categoryColor(c),
                    selected: _category == c,
                    onTap: () => setState(() => _category = c),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            GradientButton(
              label: 'Tạo',
              icon: Icons.add_task,
              loading: _saving,
              gradient: AppColors.brand,
              glowColor: AppColors.primary,
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}
