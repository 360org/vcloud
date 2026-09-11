import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/ticket.dart';
import '../../../../shared/widgets/ui_kit.dart';
import '../../../ticket/application/ticket_controller.dart';
import '../../../timesheet/application/task_controller.dart';

/// Data returned from checkout dialog
class CheckoutData {
  final String workDescription;
  final String? selectedTaskId;

  const CheckoutData({required this.workDescription, this.selectedTaskId});
}

class _SelectableItem {
  final String id;
  final String title;
  final String? subtitle;
  final bool isTask;

  const _SelectableItem({
    required this.id,
    required this.title,
    this.subtitle,
    required this.isTask,
  });
}

/// Checkout confirmation dialog with work description and task selection
class CheckoutDialog extends ConsumerStatefulWidget {
  const CheckoutDialog({super.key});

  @override
  ConsumerState<CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends ConsumerState<CheckoutDialog> {
  final _descriptionController = TextEditingController();
  String? _selectedTaskId;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  void _save() {
    final text = _descriptionController.text.trim();
    Navigator.pop(
      context,
      CheckoutData(
        workDescription: text.isEmpty ? 'Hoàn thành ca làm việc' : text,
        selectedTaskId: _selectedTaskId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ticketsAsync = ref.watch(ticketsProvider);
    final tickets = ticketsAsync.valueOrNull ?? [];
    final doingTickets = tickets
        .where((t) => t.status == TicketStatus.doing)
        .toList();

    final tasksSplit = ref.watch(todayTasksSplitProvider);
    final openTasks = tasksSplit.open;

    final items = <_SelectableItem>[
      ...openTasks.map(
        (t) => _SelectableItem(
          id: t.id,
          title: t.title,
          subtitle: t.projectName ?? (t.description?.isNotEmpty == true ? t.description : 'Task dự án'),
          isTask: true,
        ),
      ),
      ...doingTickets.map(
        (ticket) => _SelectableItem(
          id: ticket.id,
          title: ticket.title,
          subtitle: ticket.description ?? 'Ticket hỗ trợ',
          isTask: false,
        ),
      ),
    ];

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.border, width: 0.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.midnight, AppColors.midnightLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        LucideIcons.logOut,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Check Out',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Mô tả công việc đã hoàn thành',
                            style: TextStyle(color: Colors.white70, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Content (Scrollable to prevent any keyboard / screen overflow)
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Work description field
                      const Text(
                        'Mô tả công việc (tùy chọn)',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _descriptionController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Nhập mô tả công việc (mặc định: Hoàn thành ca làm việc)...',
                          hintStyle: const TextStyle(color: AppColors.textMuted),
                          filled: true,
                          fillColor: AppColors.bg,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: AppColors.primary,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Task selection
                      if (items.isNotEmpty) ...[
                        const Text(
                          'Liên kết với task / công việc (tùy chọn)',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          constraints: const BoxConstraints(maxHeight: 180),
                          decoration: BoxDecoration(
                            color: AppColors.bg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Material(
                            type: MaterialType.transparency,
                            child: RadioGroup<String>(
                              groupValue: _selectedTaskId,
                              onChanged: (value) {
                                setState(() {
                                  _selectedTaskId = value;
                                });
                              },
                              child: ListView.builder(
                                shrinkWrap: true,
                                padding: const EdgeInsets.all(8),
                                itemCount: items.length,
                                itemBuilder: (context, index) {
                                  final item = items[index];
                                  final isSelected = _selectedTaskId == item.id;
                                  return ListTile(
                                    leading: Radio<String>(value: item.id),
                                    title: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          margin: const EdgeInsets.only(right: 6),
                                          decoration: BoxDecoration(
                                            color: item.isTask ? AppColors.primary.withValues(alpha: 0.12) : AppColors.ticket.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            item.isTask ? 'Task' : 'Ticket',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w700,
                                              color: item.isTask ? AppColors.primary : AppColors.ticket,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: Text(
                                            item.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13,
                                              color: isSelected
                                                  ? AppColors.primary
                                                  : AppColors.textPrimary,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    subtitle: Text(
                                      item.subtitle ?? 'Không có mô tả',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTextStyles.caption.copyWith(
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                    contentPadding: EdgeInsets.zero,
                                    onTap: () {
                                      setState(() {
                                        _selectedTaskId = item.id;
                                      });
                                    },
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Actions
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.all(Radius.circular(12)),
                          ),
                          side: const BorderSide(color: AppColors.border),
                        ),
                        child: const Text(
                          'Huỷ',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GradientButton(
                        label: 'CHECK-OUT',
                        icon: LucideIcons.logOut,
                        gradient: AppColors.featureGrad(
                          AppColors.danger,
                          AppColors.dangerDeep,
                        ),
                        glowColor: AppColors.danger,
                        onPressed: _save,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
