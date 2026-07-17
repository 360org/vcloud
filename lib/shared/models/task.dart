import 'timesheet.dart';

class TimesheetProjectOption {
  const TimesheetProjectOption({required this.id, required this.name});

  final String id;
  final String name;
}

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
    this.projectId,
    this.projectName,
    this.tags = const <String>[],
    this.tagHexColors = const <String, String>{},
    this.allocatedHours,
    this.spentHours,
    this.remainingHours,
    this.stageName,
    this.state,
    this.completedAt,
    this.timesheetId,
  });

  final String id;
  final String userId;
  final String title;
  final String? description;
  final String? projectId;
  final String? projectName;
  final List<String> tags;
  /// Tag name → 6-char hex colour (e.g. `F06050`) sourced from the
  /// `helpdesk.tag.color` field. Empty when the catalog hasn't loaded or
  /// the tag has no colour defined.
  final Map<String, String> tagHexColors;
  final double? allocatedHours;
  final double? spentHours;
  final double? remainingHours;
  final String? stageName;
  final String? state;
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
    projectId: map['project_id'] as String?,
    projectName: map['project_name'] as String?,
    tags: (map['tags'] as List? ?? const <Object?>[])
        .map((tag) => tag.toString())
        .where((tag) => tag.isNotEmpty)
        .toList(),
    tagHexColors: _parseHexColors(map['tag_hex_colors']),
    allocatedHours: (map['allocated_hours'] as num?)?.toDouble(),
    spentHours: (map['spent_hours'] as num?)?.toDouble(),
    remainingHours: (map['remaining_hours'] as num?)?.toDouble(),
    stageName: map['stage_name'] as String?,
    state: map['state'] as String?,
    category: TimesheetCategoryDb.fromDb(map['category'] as String),
    dueDate: DateTime.parse(map['due_date'] as String),
    completedAt: map['completed_at'] == null
        ? null
        : DateTime.parse(map['completed_at'] as String),
    timesheetId: map['timesheet_id'] as String?,
    createdAt: DateTime.parse(map['created_at'] as String),
    updatedAt: DateTime.parse(map['updated_at'] as String),
  );

  static Map<String, String> _parseHexColors(Object? raw) {
    if (raw is! Map) return const <String, String>{};
    return <String, String>{
      for (final entry in raw.entries)
        if (entry.value is String &&
            (entry.value as String).isNotEmpty &&
            entry.key is String)
          entry.key as String: entry.value as String,
    };
  }
}
