import 'timesheet.dart';

/// Row from `public.tasks` — a user-scoped unit of work that can be
/// completed (and linked to a [TimesheetEntry]) via the new task
/// workflows.
///
/// The model is intentionally lean: no status enum, no priority — the
/// only on/off state is whether [completedAt] is set.
class Task {
  const Task({
    required this.id,
    required this.userId,
    required this.title,
    required this.category,
    required this.dueDate,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.completedAt,
    this.timesheetId,
  });

  final String id;
  final String userId;
  final String title;
  final String? description;
  final TimesheetCategory category;
  final DateTime dueDate;
  final DateTime? completedAt;
  final String? timesheetId;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// True once the user has logged time against this task.
  bool get isCompleted => completedAt != null;

  factory Task.fromMap(Map<String, dynamic> map) => Task(
    id: map['id'] as String,
    userId: map['user_id'] as String,
    title: map['title'] as String,
    description: map['description'] as String?,
    category: TimesheetCategoryDb.fromDb(map['category'] as String),
    dueDate: DateTime.parse(map['due_date'] as String),
    completedAt: map['completed_at'] == null
        ? null
        : DateTime.parse(map['completed_at'] as String),
    timesheetId: map['timesheet_id'] as String?,
    createdAt: DateTime.parse(map['created_at'] as String),
    updatedAt: DateTime.parse(map['updated_at'] as String),
  );
}
