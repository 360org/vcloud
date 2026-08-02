import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;

import '../../../core/api/odoo_api_client.dart';
import '../../../core/error/failure.dart';
import '../../../shared/models/task.dart';
import '../../../shared/models/timesheet.dart';

/// Lightweight DTO used internally while resolving `tag_ids`. Keeps the name
/// (always present) and the colour hex (optional — index 0 returns null so
/// the UI can fall back to a neutral pill colour).
class _TagInfo {
  const _TagInfo({required this.name, this.colorHex});
  final String name;
  final String? colorHex;
}

class TaskRepository {
  TaskRepository({OdooApiClient? client}) : _client = client ?? odooApiClient;

  final OdooApiClient _client;

  /// Cached `id → TagInfo` map for the `project.tags` endpoint, populated
  /// lazily the first time a task response carries raw `tag_ids`. Resolve-once
  /// is enough for the lifetime of the repo instance: tags rarely change
  /// inside a session, and the next list refresh will pick up new entries
  /// via [refreshTagNames].
  Map<int, _TagInfo>? _tagNamesCache;
  Future<Map<int, _TagInfo>>? _tagNamesFuture;

  Future<List<TimesheetProjectOption>> listProjects() async {
    try {
      final res = await _client.get('/api/v1/mobile/project/list');
      return (res as List).cast<Map<String, dynamic>>().map((map) {
        final name = (map['name'] ?? map['display_name'] ?? 'Project').toString();
        return TimesheetProjectOption(id: map['id'].toString(), name: name);
      }).toList();
    } catch (_) {
      try {
        final res = await _client.get('/api/v1/mobile/timesheet/projects');
        return (res as List).cast<Map<String, dynamic>>().map((map) {
          final name = (map['name'] ?? map['display_name'] ?? 'Project').toString();
          return TimesheetProjectOption(id: map['id'].toString(), name: name);
        }).toList();
      } catch (_) {
        return const <TimesheetProjectOption>[];
      }
    }
  }

  Future<List<Task>> listProjectTasks(String projectId) async {
    final project = (await listProjects()).where((p) => p.id == projectId);
    final projectName = project.isEmpty ? null : project.first.name;
    try {
      final res = await _client.get(
        '/api/v1/mobile/project/$projectId/tasks',
      );
      return Future.wait(
        (res as List).cast<Map<String, dynamic>>().map(
          (m) async => Task.fromMap(
            await _taskFromOdooHydrated(
              m,
              DateTime.now(),
              projectId: projectId,
              projectName: projectName,
            ),
          ),
        ),
      );
    } catch (_) {
      return const <Task>[];
    }
  }

  Stream<List<Task>> watchToday({DateTime? day}) {
    final ctl = StreamController<List<Task>>();

    Future<void> refresh() async {
      try {
        final projectListOptions = await listProjects().timeout(
          const Duration(seconds: 10),
          onTimeout: () => const <TimesheetProjectOption>[],
        );
        if (projectListOptions.isEmpty) {
          if (!ctl.isClosed) ctl.add(const <Task>[]);
          return;
        }
        final tasksById = <String, Task>{};
        for (final project in projectListOptions) {
          final projectTasks = await listProjectTasks(project.id).timeout(
            const Duration(seconds: 8),
            onTimeout: () => const <Task>[],
          );
          for (final task in projectTasks) {
            tasksById[task.id] = task;
          }
        }
        final tasks = tasksById.values.toList();
        if (!ctl.isClosed) ctl.add(tasks);
      } catch (e) {
        debugPrint('watchToday error: $e');
        if (!ctl.isClosed) ctl.add(const <Task>[]);
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
    await _client.put(
      '/api/v1/project.task/$taskId',
      body: <String, dynamic>{
        'values': <String, dynamic>{'state': '1_done'},
      },
    );
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
    final task = await _client.get('/api/v1/project.task/$taskId');
    return Task.fromMap(
      _taskFromOdoo(Map<String, dynamic>.from(task as Map), DateTime.now()),
    );
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
      'project_name':
          _stringOrNull(map['project_name']) ??
          _many2OneName(map['project_id']) ??
          projectName,
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

  Future<Map<String, dynamic>> _taskFromOdooHydrated(
    Map<String, dynamic> map,
    DateTime fallbackDate, {
    Object? projectId,
    String? projectName,
    bool completed = false,
    String? timesheetId,
  }) async {
    final id = map['id'];
    var merged = map;
    if (id != null) {
      try {
        final detail = await _client.get('/api/v1/project.task/$id').timeout(
          const Duration(seconds: 3),
          onTimeout: () => <String, dynamic>{},
        );
        if (detail is Map) {
          merged = <String, dynamic>{
            ...map,
            ...Map<String, dynamic>.from(detail),
          };
        }
      } catch (_) {
        // The mobile list still has enough data to render a task row.
      }
    }
    try {
      merged = await _resolveTagIds(merged).timeout(
        const Duration(seconds: 3),
        onTimeout: () => merged,
      );
    } catch (_) {}

    return _taskFromOdoo(
      merged,
      fallbackDate,
      projectId: projectId,
      projectName: projectName,
      completed: completed,
      timesheetId: timesheetId,
    );
  }

  /// Walk `tag_ids` from a (hydrated) Odoo payload and replace integer IDs
  /// with their human-readable names (+ colour) from the catalog cache.
  /// The mobile list endpoint doesn't expose tags at all, and
  /// `project.task` detail only carries `tag_ids: [int, ...]` — without this
  /// lookup the UI would fall back to `Tag #N`.
  Future<Map<String, dynamic>> _resolveTagIds(Map<String, dynamic> map) async {
    final raw = map['tag_ids'];
    if (raw is! List || raw.isEmpty) return map;
    // The detail response may already include a resolved `tags` array; skip
    // resolution to avoid duplicating entries.
    final existing = map['tags'];
    final hasNames =
        existing is List &&
        existing.isNotEmpty &&
        existing.every((e) => e is String);
    final ids = <int>[];
    for (final entry in raw) {
      if (entry is num) {
        ids.add(entry.toInt());
      } else if (entry is String) {
        final parsed = int.tryParse(entry);
        if (parsed != null) ids.add(parsed);
      }
    }
    if (ids.isEmpty) return map;
    final lookup = await _ensureTagNames();
    final resolvedNames = <String>[];
    final resolvedColors = <String, String>{};
    for (final id in ids) {
      final info = lookup[id];
      if (info != null) {
        resolvedNames.add(info.name);
        if (info.colorHex != null) {
          resolvedColors[info.name] = info.colorHex!;
        }
      } else {
        resolvedNames.add('Tag #$id');
      }
    }
    final next = <String, dynamic>{...map, 'tags': resolvedNames};
    if (resolvedColors.isNotEmpty) {
      // Merge with whatever the project.task detail already supplied so we
      // don't overwrite colour information that came in-line.
      final merged = <String, String>{
        ..._parseHexColorMap(map['tag_hex_colors']),
        ...resolvedColors,
      };
      next['tag_hex_colors'] = merged;
    } else if (hasNames) {
      // Already had pre-resolved names — preserve whatever colours the
      // detail payload came with.
      next['tag_hex_colors'] = _parseHexColorMap(map['tag_hex_colors']);
    }
    return next;
  }

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

  /// Memoised load of the project.tags catalog. Returns an empty map on
  /// failure so the rendering layer keeps working (still shows raw IDs as
  /// `Tag #N`); a network blip should never block the timesheet list.
  Future<Map<int, _TagInfo>> _ensureTagNames() {
    final cached = _tagNamesCache;
    if (cached != null) return Future.value(cached);
    return _tagNamesFuture ??= _loadTagNames();
  }

  Future<Map<int, _TagInfo>> _loadTagNames() async {
    try {
      final raw = await _client.get('/api/v1/mobile/project/tags');
      final list = _unwrapTagList(raw);
      final lookup = <int, _TagInfo>{};
      for (final entry in list.whereType<Map>()) {
        final id = entry['id'];
        if (id is! num) continue;
        final name = entry['name']?.toString();
        if (name == null || name.isEmpty) continue;
        lookup[id.toInt()] = _TagInfo(
          name: name,
          colorHex: _tagColorToHex(entry['color']),
        );
      }
      _tagNamesCache = lookup;
      return lookup;
    } catch (e) {
      debugPrint('TaskRepository: project.tags catalog failed: $e');
      return const <int, _TagInfo>{};
    }
  }

  /// Force a re-fetch on the next list refresh — pass-through for screens
  /// that suspect stale tag colours after a sync.
  void refreshTagNames() {
    _tagNamesCache = null;
    _tagNamesFuture = null;
  }

  /// Accept both the bare-array and `{data|tags|records: [...]}` envelopes
  /// the Odoo Mobile API has historically shipped under different versions.
  Iterable _unwrapTagList(Object? raw) {
    if (raw is List) return raw;
    if (raw is Map) {
      for (final key in const ['data', 'tags', 'records', 'items']) {
        final candidate = raw[key];
        if (candidate is List) return candidate;
      }
    }
    return const [];
  }

  String? _tagColorToHex(Object? value) {
    if (value is num) {
      const palette = <int, String>{
        0: '',
        1: 'F06050',
        2: 'FAAA38',
        3: 'F7E928',
        4: 'A8D245',
        5: '51BBE5',
        6: '7D7D7D',
        7: '7C7BAD',
        8: '825F5F',
        9: 'C24668',
        10: '1F8E76',
        11: '0F8FA9',
      };
      return palette[value.toInt()];
    }
    if (value is String) {
      var hex = value.trim();
      if (hex.startsWith('#')) hex = hex.substring(1);
      if (hex.length == 6) return hex.toUpperCase();
      if (hex.length == 8) return hex.substring(2).toUpperCase();
    }
    return null;
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
