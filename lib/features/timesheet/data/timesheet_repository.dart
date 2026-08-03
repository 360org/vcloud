import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../../core/api/odoo_api_client.dart';
import '../../../core/error/failure.dart';
import '../../../shared/models/timesheet.dart';

List<TimesheetEntry> _parseTimesheetList(List<dynamic> rawList) {
  final repo = TimesheetRepository();
  return rawList
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .map(repo._entryFromOdoo)
      .map(TimesheetEntry.fromMap)
      .toList();
}

class TimesheetRepository {
  TimesheetRepository({OdooApiClient? client})
    : _client = client ?? odooApiClient;

  final OdooApiClient _client;

  Stream<List<TimesheetEntry>> watchRecent({int limit = 100}) {
    final controller = StreamController<List<TimesheetEntry>>();

    Future<void> refresh() async {
      try {
        final list = await fetchPage(limit: limit, offset: 0);
        if (!controller.isClosed) controller.add(list);
      } catch (e) {
        if (!controller.isClosed) {
          controller.addError(Failure('Reload failed: $e'));
        }
      }
    }

    controller.onListen = refresh;
    return controller.stream;
  }

  Future<List<TimesheetEntry>> fetchPage({int limit = 20, int offset = 0}) async {
    final res = await _client.get(
      '/api/v1/mobile/timesheet/list',
      query: <String, Object?>{'limit': limit, 'offset': offset},
    );
    if (res is! List) return const <TimesheetEntry>[];
    return compute(_parseTimesheetList, res);
  }

  Future<TimesheetEntry> add({
    required String taskName,
    required TimesheetCategory category,
    required TimesheetDuration duration,
    DateTime? workedDate,
    String? taskId,
  }) async {
    final hours = duration.duration.inMinutes / 60.0;
    final projectId = int.tryParse(category.dbValue) ?? 1;
    final res = await _client.post(
      '/api/v1/mobile/timesheet/log',
      body: <String, dynamic>{
        'project_id': projectId,
        if (taskId != null) 'task_id': int.tryParse(taskId),
        'unit_amount': hours,
        'date': _isoDate(workedDate ?? DateTime.now()),
        'name': taskName,
      },
    );
    return TimesheetEntry.fromMap(
      _entryFromOdoo(Map<String, dynamic>.from(res as Map)),
    );
  }

  Future<void> delete(String id) async {
    await _client.delete('/api/v1/account.analytic.line/$id');
  }

  Map<String, dynamic> _entryFromOdoo(Map<String, dynamic> map) {
    final date = map['date'] as String? ?? _isoDate(DateTime.now());
    final hours = (map['unit_amount'] as num?)?.toDouble() ?? 1;
    return <String, dynamic>{
      'id': map['id'].toString(),
      'user_id': _many2OneId(map['employee_id']) ?? '',
      'task_name': _taskNameForEntry(map),
      'category': TimesheetCategory.other.dbValue,
      'duration': _durationFromHours(hours).dbValue,
      'duration_minutes': (hours * 60).round(),
      'worked_date': date,
      'created_at': '${date}T00:00:00.000Z',
      'task_id': _many2OneId(map['task_id']),
    };
  }

  /// Pick the best "what the user did" label from the AAL payload.
  ///
  /// The backend (Odoo Mobile API) returns up to three relevant fields on
  /// `account.analytic.line`:
  ///   • `name`         — the description the client POSTed (user's note)
  ///   • `task_name`    — custom serializer derived from `task_id.name`
  ///                      (always the task's own title, NOT the user's note)
  ///   • `display_name` — computed/joined label, also typically the task
  ///                      title when `task_id` is set
  ///
  /// Reading them in `name → task_name → display_name` order keeps the
  /// user's typed note front-and-centre while still gracefully showing
  /// the linked task title for legacy entries that didn't include a note.
  String _taskNameForEntry(Map<String, dynamic> map) {
    final raw = map['name'];
    if (raw is String && raw.isNotEmpty) return raw;
    return (map['task_name'] ?? map['display_name'] ?? '').toString();
  }

  TimesheetDuration _durationFromHours(double hours) {
    final minutes = (hours * 60).round();
    if (minutes <= 15) return TimesheetDuration.fifteen;
    if (minutes <= 30) return TimesheetDuration.thirty;
    if (minutes <= 45) return TimesheetDuration.fortyFive;
    return TimesheetDuration.sixty;
  }

  String? _many2OneId(Object? value) {
    if (value is List && value.isNotEmpty) return value.first.toString();
    if (value is int) return value.toString();
    return null;
  }

  static String _isoDate(DateTime d) {
    final local = DateTime(d.year, d.month, d.day);
    return local.toIso8601String().split('T').first;
  }
}
