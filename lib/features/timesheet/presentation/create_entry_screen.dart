import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/task.dart';
import '../../../shared/models/timesheet.dart';
import '../../../shared/widgets/primary_button.dart';
import '../application/task_controller.dart';
import '../application/timesheet_controller.dart';

class CreateEntryScreen extends ConsumerStatefulWidget {
  const CreateEntryScreen({super.key});

  @override
  ConsumerState<CreateEntryScreen> createState() => _CreateEntryScreenState();
}

class _CreateEntryScreenState extends ConsumerState<CreateEntryScreen> {
  final _form = GlobalKey<FormState>();
  final _task = TextEditingController();
  TimesheetCategory _category = TimesheetCategory.other;
  TimesheetDuration _duration = TimesheetDuration.thirty;
  TimesheetProjectOption? _selectedProject;
  late Future<List<TimesheetProjectOption>> _projectsFuture;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _projectsFuture = ref.read(taskActionsProvider).listProjects();
  }

  @override
  void dispose() {
    _task.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _submitting = true);
    try {
      await ref
          .read(timesheetActionsProvider)
          .add(
            taskName: _task.text.trim(),
            category: _category,
            duration: _duration,
            projectIdOverride: int.tryParse(_selectedProject?.id ?? ''),
          );
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Save failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('New timesheet entry')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FutureBuilder<List<TimesheetProjectOption>>(
                  future: _projectsFuture,
                  builder: (context, snapshot) {
                    final projects = snapshot.data ?? const <TimesheetProjectOption>[];
                    if (projects.isEmpty) return const SizedBox.shrink();
                    final currentId = _selectedProject?.id ?? projects.first.id;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: DropdownButtonFormField<String>(
                        initialValue: currentId,
                        decoration: const InputDecoration(
                          labelText: 'Dự án',
                          prefixIcon: Icon(Icons.folder_outlined),
                        ),
                        items: [
                          for (final p in projects)
                            DropdownMenuItem(
                              value: p.id,
                              child: Text(
                                p.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                        ],
                        onChanged: (val) {
                          if (val == null) return;
                          setState(() {
                            _selectedProject = projects.firstWhere(
                              (p) => p.id == val,
                              orElse: () => projects.first,
                            );
                          });
                        },
                      ),
                    );
                  },
                ),
                TextFormField(
                  controller: _task,
                  maxLength: 120,
                  decoration: const InputDecoration(
                    labelText: 'Task name',
                    prefixIcon: Icon(Icons.task_outlined),
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                Text('Category', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                SegmentedButton<TimesheetCategory>(
                  segments: [
                    for (final c in TimesheetCategory.values)
                      ButtonSegment(value: c, label: Text(c.label)),
                  ],
                  selected: {_category},
                  onSelectionChanged: (s) =>
                      setState(() => _category = s.first),
                  showSelectedIcon: false,
                ),
                const SizedBox(height: 20),
                Text('Duration', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 8),
                DropdownButtonFormField<TimesheetDuration>(
                  initialValue: _duration,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.timer),
                  ),
                  items: [
                    for (final d in TimesheetDuration.values)
                      DropdownMenuItem(value: d, child: Text(d.label)),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _duration = v);
                  },
                ),
                const Spacer(),
                PrimaryButton(
                  label: 'Save entry',
                  icon: Icons.check,
                  loading: _submitting,
                  onPressed: _submitting ? null : _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
