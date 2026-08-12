import '../../core/utils/html_text.dart';
import 'task_message.dart';
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
    this.userName,
    this.partnerName,
    this.dateAssign,
    this.tags = const <String>[],
    this.tagHexColors = const <String, String>{},
    this.allocatedHours,
    this.spentHours,
    this.remainingHours,
    this.stageName,
    this.state,
    this.messages = const <TaskMessage>[],
    this.completedAt,
    this.timesheetId,
  });

  final String id;
  final String userId;
  final String title;
  final String? description;
  final String? projectId;
  final String? projectName;
  final String? userName;
  final String? partnerName;
  final DateTime? dateAssign;
  final List<String> tags;
  final Map<String, String> tagHexColors;
  final double? allocatedHours;
  final double? spentHours;
  final double? remainingHours;
  final String? stageName;
  final String? state;
  final List<TaskMessage> messages;
  final TimesheetCategory category;
  final DateTime dueDate;
  final DateTime? completedAt;
  final String? timesheetId;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// True once the user has logged time against this task.
  bool get isCompleted => completedAt != null;

  factory Task.fromMap(Map<String, dynamic> map) => Task(
    id: map['id'].toString(),
    userId: (map['user_id'] ?? '').toString(),
    title: (map['title'] ?? map['name'] ?? 'Task').toString(),
    description: cleanHtmlText(map['description']),
    projectId: map['project_id']?.toString(),
    projectName: map['project_name']?.toString(),
    userName: map['user_name']?.toString(),
    partnerName: map['partner_name']?.toString() ??
        (map['partner_id'] is List && (map['partner_id'] as List).length > 1
            ? (map['partner_id'] as List)[1].toString()
            : null),
    dateAssign: map['date_assign'] == null || map['date_assign'] == false
        ? null
        : DateTime.tryParse(map['date_assign'].toString()),
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
    messages: (map['messages'] as List? ?? const <Object?>[])
        .whereType<Map>()
        .map((m) => TaskMessage.fromMap(Map<String, dynamic>.from(m)))
        .toList(),
    category: TimesheetCategoryDb.fromDb(map['category'] as String? ?? 'other'),
    dueDate: map['due_date'] == null
        ? DateTime.now()
        : DateTime.tryParse(map['due_date'].toString()) ?? DateTime.now(),
    completedAt: map['completed_at'] == null || map['completed_at'] == false
        ? null
        : DateTime.tryParse(map['completed_at'].toString()),
    timesheetId: map['timesheet_id']?.toString(),
    createdAt: map['created_at'] == null
        ? DateTime.now()
        : DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now(),
    updatedAt: map['updated_at'] == null
        ? DateTime.now()
        : DateTime.tryParse(map['updated_at'].toString()) ?? DateTime.now(),
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
