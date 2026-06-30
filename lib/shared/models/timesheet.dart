import 'task.dart';

/// Whitelisted values for the `timesheet_category` postgres enum.
enum TimesheetCategory { erp, crm, meeting, support, other }

extension TimesheetCategoryDb on TimesheetCategory {
  String get dbValue => switch (this) {
        TimesheetCategory.erp => 'ERP',
        TimesheetCategory.crm => 'CRM',
        TimesheetCategory.meeting => 'Meeting',
        TimesheetCategory.support => 'Support',
        TimesheetCategory.other => 'Other',
      };

  String get label => switch (this) {
        TimesheetCategory.erp => 'ERP',
        TimesheetCategory.crm => 'CRM',
        TimesheetCategory.meeting => 'Meeting',
        TimesheetCategory.support => 'Support',
        TimesheetCategory.other => 'Other',
      };

  static TimesheetCategory fromDb(String v) {
    return TimesheetCategory.values.firstWhere(
      (c) => c.dbValue == v,
      orElse: () => TimesheetCategory.other,
    );
  }
}

/// Whitelisted values for the `timesheet_duration` postgres enum.
///
/// Presets are 15 / 30 / 45 / 60 minute buckets — see the [Task] workflow.
/// `'2h'` still exists in the DB for backwards compatibility; the
/// `fromDb` fallback renders it as `sixty` (1 hour).
enum TimesheetDuration { fifteen, thirty, fortyFive, sixty }

extension TimesheetDurationDb on TimesheetDuration {
  String get dbValue => switch (this) {
        TimesheetDuration.fifteen => '15m',
        TimesheetDuration.thirty => '30m',
        TimesheetDuration.fortyFive => '45m',
        TimesheetDuration.sixty => '1h',
      };

  Duration get duration => switch (this) {
        TimesheetDuration.fifteen => const Duration(minutes: 15),
        TimesheetDuration.thirty => const Duration(minutes: 30),
        TimesheetDuration.fortyFive => const Duration(minutes: 45),
        TimesheetDuration.sixty => const Duration(hours: 1),
      };

  String get label => switch (this) {
        TimesheetDuration.fifteen => '15 phút',
        TimesheetDuration.thirty => '30 phút',
        TimesheetDuration.fortyFive => '45 phút',
        TimesheetDuration.sixty => '1 giờ',
      };

  /// Localised quick-preset chip label for the "+N phút" affordance.
  String get presetLabel => switch (this) {
        TimesheetDuration.fifteen => '+15 phút',
        TimesheetDuration.thirty => '+30 phút',
        TimesheetDuration.fortyFive => '+45 phút',
        TimesheetDuration.sixty => '+1 giờ',
      };

  static TimesheetDuration fromDb(String v) {
    return TimesheetDuration.values.firstWhere(
      (d) => d.dbValue == v,
      orElse: () => TimesheetDuration.sixty,
    );
  }
}

/// Row from `public.timesheets`.
class TimesheetEntry {
  const TimesheetEntry({
    required this.id,
    required this.userId,
    required this.taskName,
    required this.category,
    required this.duration,
    required this.workedDate,
    required this.createdAt,
    this.taskId,
    this.task,
  });

  final String id;
  final String userId;
  final String taskName;
  final TimesheetCategory category;
  final TimesheetDuration duration;
  final DateTime workedDate;
  final DateTime createdAt;

  /// FK to `public.tasks.id`. Null when the entry was logged without a
  /// task (legacy free-text flow).
  final String? taskId;

  /// Hydrated [Task], populated by clients that joined against
  /// the `tasks` table. Null on the base stream.
  final Task? task;

  factory TimesheetEntry.fromMap(Map<String, dynamic> map) => TimesheetEntry(
        id: map['id'] as String,
        userId: map['user_id'] as String,
        taskName: map['task_name'] as String,
        category: TimesheetCategoryDb.fromDb(map['category'] as String),
        duration: TimesheetDurationDb.fromDb(map['duration'] as String),
        workedDate: DateTime.parse(map['worked_date'] as String),
        createdAt: DateTime.parse(map['created_at'] as String),
        taskId: map['task_id'] as String?,
      );
}
