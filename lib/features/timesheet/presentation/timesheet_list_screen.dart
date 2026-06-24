import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/timesheet.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../application/timesheet_controller.dart';

/// Mockup 04 — "Timesheet": today's entries + quick-add (category chips,
/// duration chips, save).
class TimesheetListScreen extends ConsumerStatefulWidget {
  const TimesheetListScreen({super.key});

  @override
  ConsumerState<TimesheetListScreen> createState() =>
      _TimesheetListScreenState();
}

class _TimesheetListScreenState extends ConsumerState<TimesheetListScreen> {
  final _task = TextEditingController();
  TimesheetCategory _category = TimesheetCategory.erp;
  TimesheetDuration _duration = TimesheetDuration.thirty;
  bool _saving = false;

  @override
  void dispose() {
    _task.dispose();
    super.dispose();
  }

  static String _catVi(TimesheetCategory c) => switch (c) {
        TimesheetCategory.erp => 'ERP',
        TimesheetCategory.crm => 'CRM',
        TimesheetCategory.meeting => 'Meeting',
        TimesheetCategory.support => 'Support',
        TimesheetCategory.other => 'Khác',
      };

  static IconData _catIcon(TimesheetCategory c) => switch (c) {
        TimesheetCategory.erp => Icons.storage,
        TimesheetCategory.crm => Icons.groups_2_outlined,
        TimesheetCategory.meeting => Icons.event_outlined,
        TimesheetCategory.support => Icons.support_agent,
        TimesheetCategory.other => Icons.more_horiz,
      };

  static String _durVi(TimesheetDuration d) {
    final m = d.duration.inMinutes;
    if (m < 60) return '$m phút';
    final h = m / 60;
    final s = h.toStringAsFixed(h % 1 == 0 ? 0 : 1);
    return '$s giờ';
  }

  static String _durChip(TimesheetDuration d) => switch (d) {
        TimesheetDuration.fifteen => '+15 phút',
        TimesheetDuration.thirty => '+30 phút',
        TimesheetDuration.sixty => '+1 giờ',
        TimesheetDuration.oneTwenty => '+2 giờ',
      };

  Future<void> _save() async {
    if (_task.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nhập tên công việc trước đã.')));
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(timesheetActionsProvider).add(
            taskName: _task.text.trim(),
            category: _category,
            duration: _duration,
          );
      _task.clear();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.toString().replaceFirst('Failure: ', ''))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = ref.watch(timesheetStreamProvider).value ?? const [];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayEntries = rows
        .where((e) =>
            DateTime(e.workedDate.year, e.workedDate.month,
                e.workedDate.day) ==
            today)
        .toList();

    return AppScaffold(
      title: 'Timesheet',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('Hôm nay bạn làm gì?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Container(
            decoration: cardDecoration(),
            child: Column(
              children: [
                if (todayEntries.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('Chưa có công việc nào hôm nay',
                        style: TextStyle(color: AppColors.textMuted)),
                  )
                else
                  for (var i = 0; i < todayEntries.length; i++) ...[
                    _entryRow(todayEntries[i]),
                    if (i != todayEntries.length - 1)
                      const Divider(indent: 56, height: 1),
                  ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: const [
                    Icon(Icons.add, color: AppColors.primary, size: 20),
                    SizedBox(width: 6),
                    Text('Thêm công việc',
                        style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _task,
                  maxLength: 120,
                  decoration: const InputDecoration(
                    hintText: 'Bạn đã làm gì?',
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 14),
                const Text('Chọn nhanh',
                    style: TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final c in TimesheetCategory.values)
                      _ChoicePill(
                        label: _catVi(c),
                        selected: _category == c,
                        onTap: () => setState(() => _category = c),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Thời lượng',
                    style: TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (final d in TimesheetDuration.values) ...[
                      Expanded(
                        child: _ChoicePill(
                          label: _durChip(d),
                          selected: _duration == d,
                          center: true,
                          onTap: () => setState(() => _duration = d),
                        ),
                      ),
                      if (d != TimesheetDuration.values.last)
                        const SizedBox(width: 8),
                    ],
                  ],
                ),
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Lưu thời gian'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _entryRow(TimesheetEntry e) {
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppColors.soft(AppColors.timesheet),
          borderRadius: BorderRadius.circular(9),
        ),
        child:
            Icon(_catIcon(e.category), color: AppColors.timesheet, size: 20),
      ),
      title:
          Text(e.taskName, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_durVi(e.duration),
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 13)),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

class _ChoicePill extends StatelessWidget {
  const _ChoicePill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.center = false,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool center;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        alignment: center ? Alignment.center : null,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : const Color(0xFFF1F3F6),
          borderRadius: BorderRadius.circular(10),
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
