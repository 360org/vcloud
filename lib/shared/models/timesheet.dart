import 'task.dart';

/// Whitelisted values for the app's timesheet categories.
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
    TimesheetCategory.meeting => 'Họp',
    TimesheetCategory.support => 'Hỗ trợ',
    TimesheetCategory.other => 'Công việc',
  };

  static TimesheetCategory fromDb(String v) {
    return TimesheetCategory.values.firstWhere(
      (c) => c.dbValue == v,
      orElse: () => TimesheetCategory.other,
    );
  }
}

/// Whitelisted values for the app's timesheet duration presets.
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
    required this.durationMinutes,
    required this.workedDate,
    required this.createdAt,
    this.taskId,
    this.task,
    this.projectId,
    this.projectName,
  });

  final String id;
  final String userId;
  final String taskName;
  final TimesheetCategory category;
  final TimesheetDuration duration;
  final int durationMinutes;
  final DateTime workedDate;
  final DateTime createdAt;

  /// FK to `public.tasks.id`. Null when the entry was logged without a
  /// task (legacy free-text flow).
  final String? taskId;

  /// Hydrated [Task], populated by clients that joined against
  /// the `tasks` table. Null on the base stream.
  final Task? task;

  /// Project ID and Name from Odoo account.analytic.line
  final String? projectId;
  final String? projectName;

  factory TimesheetEntry.fromMap(Map<String, dynamic> map) => TimesheetEntry(
    id: (map['id'] ?? '').toString(),
    userId: (map['user_id'] ?? map['employee_id'] ?? '').toString(),
    taskName: (map['task_name'] ?? map['name'] ?? 'Công việc').toString(),
    category: TimesheetCategoryDb.fromDb((map['category'] ?? 'Other').toString()),
    duration: TimesheetDurationDb.fromDb((map['duration'] ?? '1h').toString()),
    durationMinutes: _parseDurationMinutes(map),
    workedDate: _parseTimesheetDate(map['worked_date'] ?? map['date']),
    createdAt: _parseTimesheetDate(map['created_at'] ?? map['create_date']),
    taskId: map['task_id'] != null && map['task_id'] != false ? map['task_id'].toString() : null,
    projectId: _parseMany2OneId(map['project_id']),
    projectName: _parseMany2OneName(map['project_id']) ?? (map['project_name'] is String ? map['project_name'].toString() : null),
  );
}

String? _parseMany2OneId(Object? value) {
  if (value == null || value == false) return null;
  if (value is List && value.isNotEmpty) return value.first.toString();
  if (value is num || value is String) {
    final s = value.toString().trim();
    return s.isNotEmpty ? s : null;
  }
  return null;
}

String? _parseMany2OneName(Object? value) {
  if (value is List && value.length > 1) return value[1].toString();
  return null;
}

int _parseDurationMinutes(Map<String, dynamic> map) {
  final raw = map['duration_minutes'] ?? map['unit_amount'];
  if (raw is int) return raw;
  if (raw is num) return (raw * 60).round();
  if (raw is String) {
    final parsed = int.tryParse(raw);
    if (parsed != null) return parsed;
  }
  return TimesheetDurationDb.fromDb((map['duration'] ?? '1h').toString()).duration.inMinutes;
}

DateTime _parseTimesheetDate(Object? v) {
  if (v == null || v == false) return DateTime.now();
  final str = v.toString().trim();
  if (str.isEmpty) return DateTime.now();
  try {
    // Nếu là định dạng thuần ngày YYYY-MM-DD (từ Odoo fields.Date)
    // Parse các thành phần để tạo local DateTime tại 00:00:00, tránh DateTime.parse().toLocal() làm trôi sang ngày hôm trước ở múi giờ âm
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(str)) {
      final parts = str.split('-').map(int.parse).toList();
      return DateTime(parts[0], parts[1], parts[2]);
    }
    return DateTime.parse(str).toLocal();
  } catch (_) {
    return DateTime.now();
  }
}
