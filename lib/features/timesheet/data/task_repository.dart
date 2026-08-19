import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;

import '../../../core/api/odoo_api_client.dart';
import '../../../core/error/failure.dart';
import '../../../shared/models/task.dart';
import '../../../shared/models/task_message.dart';
import '../../../shared/models/timesheet.dart';

class TaskRepository {
  TaskRepository({OdooApiClient? client}) : _client = client ?? odooApiClient;

  final OdooApiClient _client;

  final Map<String, String> _projectNameMap = <String, String>{};

  Future<List<TimesheetProjectOption>> listProjects() async {
    try {
      final res = await _client.get('/api/v1/mobile/project/list');
      final list = (res as List).cast<Map<String, dynamic>>().map((map) {
        final name = (map['name'] ?? map['display_name'] ?? 'Project').toString();
        final id = map['id'].toString();
        _projectNameMap[id] = name;
        return TimesheetProjectOption(id: id, name: name);
      }).toList();
      return list;
    } catch (_) {
      try {
        final res = await _client.get('/api/v1/mobile/timesheet/projects');
        final list = (res as List).cast<Map<String, dynamic>>().map((map) {
          final name = (map['name'] ?? map['display_name'] ?? 'Project').toString();
          final id = map['id'].toString();
          _projectNameMap[id] = name;
          return TimesheetProjectOption(id: id, name: name);
        }).toList();
        return list;
      } catch (_) {
        return const <TimesheetProjectOption>[];
      }
    }
  }

  Future<List<Task>> listAllTasks() async {
    try {
      final res = await _client.get('/api/v1/mobile/project/all_tasks');
      if (res is List) {
        return res
            .cast<Map<String, dynamic>>()
            .map((m) => Task.fromMap(_taskFromOdoo(m, DateTime.now())))
            .toList();
      }
      return const <Task>[];
    } catch (_) {
      // Fallback: Khi endpoint /all_tasks chưa có trên Odoo, nạp an toàn qua danh sách từng dự án
      try {
        final projectListOptions = await listProjects();
        if (projectListOptions.isEmpty) return const <Task>[];
        // Giới hạn tối đa 3 projects đầu tiên để tuyệt đối không gây bão request lên Odoo
        final topProjects = projectListOptions.take(3).toList();
        final tasksById = <String, Task>{};
        for (final project in topProjects) {
          final list = await listProjectTasks(project.id, projectName: project.name);
          for (final task in list) {
            tasksById[task.id] = task;
          }
        }
        return tasksById.values.toList();
      } catch (_) {
        return const <Task>[];
      }
    }
  }

  Stream<List<Task>> watchToday({DateTime? day}) {
    final ctl = StreamController<List<Task>>.broadcast();

    Future<void> refresh() async {
      try {
        final tasks = await listAllTasks().timeout(
          const Duration(seconds: 15),
          onTimeout: () => const <Task>[],
        );
        if (!ctl.isClosed) ctl.add(tasks);
      } catch (e) {
        debugPrint('watchToday error: $e');
        if (!ctl.isClosed) ctl.add(const <Task>[]);
      }
    }

    ctl.onListen = refresh;
    return ctl.stream;
  }

  Future<List<Task>> listProjectTasks(String projectId, {String? projectName}) async {
    final projName = projectName ?? _projectNameMap[projectId];
    try {
      final res = await _client.get(
        '/api/v1/mobile/project/$projectId/tasks',
      );
      if (res is List) {
        return res
            .cast<Map<String, dynamic>>()
            .map(
              (m) => Task.fromMap(
                _taskFromOdoo(
                  m,
                  DateTime.now(),
                  projectId: projectId,
                  projectName: projName,
                ),
              ),
            )
            .toList();
      }
      return const <Task>[];
    } catch (_) {
      return const <Task>[];
    }
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

  Future<Task> getTaskDetail(String taskId) async {
    try {
      final res = await _client.get('/api/v1/mobile/project/task/$taskId');
      if (res is Map) {
        return Task.fromMap(
          _taskFromOdoo(Map<String, dynamic>.from(res), DateTime.now()),
        );
      }
    } catch (_) {
      try {
        final res = await _client.get('/api/v1/project.task/$taskId');
        if (res is Map) {
          return Task.fromMap(
            _taskFromOdoo(Map<String, dynamic>.from(res), DateTime.now()),
          );
        }
      } catch (_) {}
    }
    throw Failure('Không thể nạp chi tiết task $taskId');
  }

  Future<void> delete(String id) async {
    await _client.delete('/api/v1/project.task/$id');
  }

  /// Log a fresh timesheet entry against an existing task **without**
  /// flipping the task to `state=1_done`. Used by the task-detail flow
  /// to let the user record work-in-progress time/note before (or
  /// separate from) marking the task complete.
  Future<Task> log({
    required String taskId,
    required String summary,
    required TimesheetDuration duration,
    Duration? elapsed,
  }) async {
    final projectId = await _projectIdForTask(taskId);
    final loggedDuration = elapsed ?? duration.duration;
    await _client.post(
      '/api/v1/mobile/timesheet/log',
      body: <String, dynamic>{
        'project_id': projectId,
        'task_id': int.tryParse(taskId),
        'unit_amount': loggedDuration.inSeconds / 3600.0,
        'date': _isoDate(DateTime.now()),
        'name': summary,
      },
    );
    final res = await _client.get('/api/v1/project.task/$taskId');
    return Task.fromMap(
      _taskFromOdoo(
        Map<String, dynamic>.from(res as Map),
        DateTime.now(),
        projectId: projectId,
      ),
    );
  }

  /// Edit an existing timesheet entry in-place. Used by the task-detail
  /// flow to let the user tweak the work-time / note they already logged
  /// without creating a brand-new entry.
  ///
  /// We need both the Odoo task id (so the task payload stays in sync)
  /// and the `account.analytic.line` id we wrote in [complete]. The
  /// caller is responsible for resolving that line id (the screen has
  /// it from `timesheetStreamProvider`).
  Future<Task> update({
    required String taskId,
    required String timesheetEntryId,
    required String summary,
    required TimesheetDuration duration,
  }) async {
    final hours = duration.duration.inMinutes / 60.0;
    await _client.put(
      '/api/v1/account.analytic.line/$timesheetEntryId',
      body: <String, dynamic>{
        'values': <String, dynamic>{'unit_amount': hours, 'name': summary},
      },
    );
    final res = await _client.get('/api/v1/project.task/$taskId');
    return Task.fromMap(
      _taskFromOdoo(Map<String, dynamic>.from(res as Map), DateTime.now()),
    );
  }

  Future<Task> complete({
    required String taskId,
    required String summary,
    required TimesheetDuration duration,
    Duration? elapsed,
  }) async {
    final projectId = await _projectIdForTask(taskId);
    final loggedDuration = elapsed ?? duration.duration;
    final res = await _client.post(
      '/api/v1/mobile/timesheet/log',
      body: <String, dynamic>{
        'project_id': projectId,
        'task_id': int.tryParse(taskId),
        'unit_amount': loggedDuration.inSeconds / 3600.0,
        'date': _isoDate(DateTime.now()),
        'name': summary,
      },
    );
    try {
      await _client.post(
        '/api/v1/project.task/$taskId/complete',
        body: <String, dynamic>{'note': summary},
      );
    } catch (_) {
      try {
        await _client.put(
          '/api/v1/mobile/project/task/$taskId/workflow',
          body: <String, dynamic>{'status': 'done'},
        );
      } catch (_) {}
    }
    try {
      return await getTaskDetail(taskId);
    } catch (_) {
      final task = await _client.get('/api/v1/project.task/$taskId');
      return Task.fromMap(
        _taskFromOdoo(
          Map<String, dynamic>.from(task as Map),
          DateTime.now(),
          projectId: projectId,
          completed: true,
          timesheetId: res is Map ? res['id']?.toString() : null,
        ),
      );
    }
  }

  /// Lưu trạng thái workflow qua endpoint nghiệp vụ để app không phải tự
  /// suy diễn mã `state` hoặc `stage_id` của Odoo.
  Future<Task> updateWorkflow({
    required String taskId,
    required String status,
  }) async {
    await _client.put(
      '/api/v1/mobile/project/task/$taskId/workflow',
      body: <String, dynamic>{'status': status},
    );
    return getTaskDetail(taskId);
  }

  /// Thêm ghi chú/bình luận vào task chatter.
  Future<TaskMessage> addMessage({
    required String taskId,
    required String content,
  }) async {
    final res = await _client.post(
      '/api/v1/mobile/project/task/$taskId/message',
      body: <String, dynamic>{'body': content},
    );
    if (res is Map) {
      return TaskMessage.fromMap(Map<String, dynamic>.from(res));
    }
    throw Failure('Không thể gửi bình luận');
  }

  Map<String, dynamic> _taskFromOdoo(
    Map<String, dynamic> map,
    DateTime fallbackDate, {
    Object? projectId,
    String? projectName,
    bool completed = false,
    String? timesheetId,
  }) {
    final dueDate = map['date_deadline'] as String? ?? _isoDate(fallbackDate);
    final now = DateTime.now().toIso8601String();
    final state = (map['state'] ?? '').toString();
    final isDone = completed || state == '1_done' || state == 'done';
    return <String, dynamic>{
      'id': map['id'].toString(),
      'user_id': map['user_id']?.toString() ?? '',
      'title': (map['name'] ?? map['display_name'] ?? 'Task').toString(),
      'description': _stringOrNull(map['description']),
      'project_id': _idOrNull(map['project_id']) ?? _idOrNull(projectId),
      'project_name': () {
        final raw = _stringOrNull(map['project_name']) ?? _many2OneName(map['project_id']);
        if (raw != null && raw != 'Project' && raw.isNotEmpty) return raw;
        if (projectName != null && projectName != 'Project' && projectName.isNotEmpty) return projectName;
        final pId = _idOrNull(map['project_id']) ?? _idOrNull(projectId);
        if (pId != null && _projectNameMap.containsKey(pId)) return _projectNameMap[pId];
        return raw ?? projectName ?? 'Dự án khác';
      }(),
      'tags': _tagsFromOdoo(map),
      'tag_hex_colors': _parseHexColorMap(map['tag_hex_colors']),
      'allocated_hours': ((map['allocated_hours'] ?? map['planned_hours'] ?? map['subtask_planned_hours']) as num?)?.toDouble(),
      'spent_hours':
          ((map['spent_hours'] ?? map['effective_hours'] ?? map['total_hours_spent'] ?? map['subtask_effective_hours']) as num?)
              ?.toDouble(),
      'remaining_hours': (map['remaining_hours'] as num?)?.toDouble() ??
          (((map['allocated_hours'] ?? map['planned_hours']) is num && (map['effective_hours'] ?? map['total_hours_spent']) is num)
              ? (((map['allocated_hours'] ?? map['planned_hours']) as num).toDouble() - ((map['effective_hours'] ?? map['total_hours_spent']) as num).toDouble())
              : null),
      'stage_name':
          _many2OneName(map['stage_id']) ?? _stringOrNull(map['stage_name']) ?? _stringOrNull(map['stage']),
      'state': _stringOrNull(map['state']),
      'category': TimesheetCategory.other.dbValue,
      'due_date': dueDate,
      'completed_at': isDone ? (map['date_end']?.toString() ?? now) : null,

      'timesheet_id': timesheetId,
      'created_at': now,
      'updated_at': now,
    };
  }



  /// Walk `tag_ids` from a (hydrated) Odoo payload and replace integer IDs
  /// with their human-readable names (+ colour) from the catalog cache.
  /// The mobile list endpoint doesn't expose tags at all, and
  /// `project.task` detail only carries `tag_ids: [int, ...]` — without this
  /// lookup the UI would fall back to `Tag #N`.


  static Map<String, String> _parseHexColorMap(Object? raw) {
    if (raw is! Map) return <String, String>{};
    return <String, String>{
      for (final entry in raw.entries)
        if (entry.key is String &&
            entry.value is String &&
            (entry.value as String).isNotEmpty)
          entry.key as String: entry.value as String,
    };
  }



  Future<int> _projectIdForTask(String taskId) async {
    final task = await _client.get('/api/v1/project.task/$taskId');
    final projectId = _idOrNull((task as Map)['project_id']);
    if (projectId != null) return int.parse(projectId);

    final projects = await _client.get('/api/v1/mobile/timesheet/projects');
    for (final project in (projects as List).cast<Map<String, dynamic>>()) {
      final id = project['id'];
      if (id == null) continue;
      final tasks = await _client.get(
        '/api/v1/mobile/timesheet/projects/$id/tasks',
      );
      final found = (tasks as List).cast<Map<String, dynamic>>().any(
        (task) => task['id'].toString() == taskId,
      );
      if (found) return (id as num).toInt();
    }
    throw Failure('Không tìm thấy project của task.');
  }

  String? _idOrNull(Object? value) {
    if (value == null || value == false) return null;
    if (value is num) return value.toInt().toString();
    if (value is List && value.isNotEmpty) return _idOrNull(value.first);
    if (value is Map && value['id'] != null) return _idOrNull(value['id']);
    final text = value.toString();
    return text.isEmpty ? null : text;
  }

  String? _stringOrNull(Object? value) {
    if (value == null || value == false) return null;
    final text = value.toString();
    return text.isEmpty ? null : text;
  }

  String? _many2OneName(Object? value) {
    if (value is List && value.length > 1) return _stringOrNull(value[1]);
    if (value is Map && value['name'] != null) {
      return _stringOrNull(value['name']);
    }
    return null;
  }

  List<String> _tagsFromOdoo(Map<String, dynamic> map) {
    final raw = map['tags'] ?? map['tag_names'] ?? map['tag_ids'];
    if (raw is List) {
      return raw
          .map((tag) {
            if (tag is List && tag.length > 1) return tag[1].toString();
            if (tag is Map) {
              return (tag['name'] ?? tag['display_name'] ?? tag['id'])
                  ?.toString();
            }
            if (tag is num) return 'Tag #${tag.toInt()}';
            return tag.toString();
          })
          .whereType<String>()
          .where((tag) => tag.isNotEmpty)
          .toList();
    }
    if (raw is String && raw.isNotEmpty) return <String>[raw];
    return const <String>[];
  }

  static String _isoDate(DateTime d) {
    final local = DateTime(d.year, d.month, d.day);
    return local.toIso8601String().split('T').first;
  }
}
