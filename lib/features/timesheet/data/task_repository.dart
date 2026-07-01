import 'dart:async';

import '../../../core/api/odoo_api_client.dart';
import '../../../core/error/failure.dart';
import '../../../shared/models/task.dart';
import '../../../shared/models/timesheet.dart';

class TaskRepository {
  TaskRepository({OdooApiClient? client}) : _client = client ?? odooApiClient;

  final OdooApiClient _client;

  Stream<List<Task>> watchToday({DateTime? day}) {
    final ctl = StreamController<List<Task>>();
    final target = day ?? DateTime.now();

    Future<void> refresh() async {
      try {
        final projects = await _client.get('/api/v1/mobile/timesheet/projects');
        final projectList = (projects as List).cast<Map<String, dynamic>>();
        if (projectList.isEmpty) {
          if (!ctl.isClosed) ctl.add(const <Task>[]);
          return;
        }
        final projectId = projectList.first['id'];
        final res = await _client.get(
          '/api/v1/mobile/timesheet/projects/$projectId/tasks',
        );
        final tasks = (res as List)
            .cast<Map<String, dynamic>>()
            .map((m) => _taskFromOdoo(m, target))
            .map(Task.fromMap)
            .toList();
        if (!ctl.isClosed) ctl.add(tasks);
      } catch (e) {
        if (!ctl.isClosed) ctl.addError(Failure('Reload failed: $e'));
      }
    }

    ctl.onListen = refresh;
    return ctl.stream;
  }

  Future<Task> create({
    required String title,
    String? description,
    TimesheetCategory category = TimesheetCategory.other,
    DateTime? dueDate,
  }) async {
    final values = <String, dynamic>{'name': title};
    if (description != null) {
      values['description'] = description;
    }
    if (dueDate != null) {
      values['date_deadline'] = _isoDate(dueDate);
    }
    final res = await _client.post(
      '/api/v1/project.task',
      body: <String, dynamic>{'values': values},
    );
    final id = (res['id'] as num).toInt();
    final task = await _client.get('/api/v1/project.task/$id');
    return Task.fromMap(
      _taskFromOdoo(
        Map<String, dynamic>.from(task as Map),
        dueDate ?? DateTime.now(),
      ),
    );
  }

  Future<void> delete(String id) async {
    await _client.delete('/api/v1/project.task/$id');
  }

  Future<Task> complete({
    required String taskId,
    required String summary,
    required TimesheetDuration duration,
  }) async {
    final res = await _client.post(
      '/api/v1/project.task/$taskId/complete',
      body: <String, dynamic>{
        'summary': summary,
        'unit_amount': duration.duration.inMinutes / 60.0,
        'date': _isoDate(DateTime.now()),
        'name': summary,
      },
    );
    final task = res is Map && (res['task'] is Map || res['id'] != null)
        ? (res['task'] is Map ? res['task'] : res)
        : await _client.get('/api/v1/project.task/$taskId');
    return Task.fromMap(
      _taskFromOdoo(
        Map<String, dynamic>.from(task as Map),
        DateTime.now(),
        completed: true,
      ),
    );
  }

  Map<String, dynamic> _taskFromOdoo(
    Map<String, dynamic> map,
    DateTime fallbackDate, {
    bool completed = false,
  }) {
    final dueDate = map['date_deadline'] as String? ?? _isoDate(fallbackDate);
    final now = DateTime.now().toIso8601String();
    return <String, dynamic>{
      'id': map['id'].toString(),
      'user_id': map['user_id']?.toString() ?? '',
      'title': (map['name'] ?? map['display_name'] ?? 'Task').toString(),
      'description': null,
      'category': TimesheetCategory.other.dbValue,
      'due_date': dueDate,
      'completed_at': completed ? now : null,
      'timesheet_id': null,
      'created_at': now,
      'updated_at': now,
    };
  }

  static String _isoDate(DateTime d) {
    final local = DateTime(d.year, d.month, d.day);
    return local.toIso8601String().split('T').first;
  }
}
