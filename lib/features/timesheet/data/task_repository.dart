import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/failure.dart';
import '../../../shared/models/task.dart';
import '../../../shared/models/timesheet.dart';

/// Data layer for the daily task workflow. Mirrors the realtime +
/// RLS pattern used by [TicketRepository], but scoped to a single
/// `due_date` (typically "today").
class TaskRepository {
  TaskRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Watch tasks for [day] (defaults to today). Ordered with
  /// incomplete-first so the UI can render without re-sorting.
  Stream<List<Task>> watchToday({DateTime? day}) {
    final ctl = StreamController<List<Task>>();
    RealtimeChannel? ch;
    final target = day ?? DateTime.now();

    Future<void> refresh() async {
      try {
        final me = _client.auth.currentUser?.id;
        if (me == null) {
          if (!ctl.isClosed) ctl.add(const <Task>[]);
          return;
        }
        final iso = _isoDate(target);
        final res = await _client
            .from('tasks')
            .select('*')
            .eq('user_id', me)
            .eq('due_date', iso)
            .order('completed_at', ascending: true, nullsFirst: true)
            .order('created_at', ascending: true);
        final list = (res as List)
            .cast<Map<String, dynamic>>()
            .map(Task.fromMap)
            .toList();
        if (!ctl.isClosed) ctl.add(list);
      } catch (e) {
        if (!ctl.isClosed) ctl.addError(Failure('Reload failed: $e'));
      }
    }

    ctl.onListen = () async {
      await refresh();
      final me = _client.auth.currentUser?.id;
      ch = _client
          .channel('tasks-$me')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'tasks',
            callback: (_) => refresh(),
          )
          .subscribe();
    };
    ctl.onCancel = () async {
      final c = ch;
      if (c != null) await _client.removeChannel(c);
    };
    return ctl.stream;
  }

  Future<Task> create({
    required String title,
    String? description,
    TimesheetCategory category = TimesheetCategory.other,
    DateTime? dueDate,
  }) async {
    final me = _client.auth.currentUser?.id;
    if (me == null) throw Failure('Not signed in');
    final res = await _client.from('tasks').insert({
      'user_id': me,
      'title': title,
      'description': description,
      'category': category.dbValue,
      if (dueDate != null)
        'due_date': _isoDate(dueDate),
    }).select().single();
    return Task.fromMap(Map<String, dynamic>.from(res));
  }

  Future<void> delete(String id) async {
    final me = _client.auth.currentUser?.id;
    if (me == null) throw Failure('Not signed in');
    await _client.from('tasks').delete().eq('id', id).eq('user_id', me);
  }

  /// Atomic "log time and mark task complete" — wraps the
  /// `public.complete_task` RPC from migration 0012. Returns the
  /// updated task with `completed_at` and `timesheet_id` populated.
  Future<Task> complete({
    required String taskId,
    required String summary,
    required TimesheetDuration duration,
  }) async {
    final me = _client.auth.currentUser?.id;
    if (me == null) throw Failure('Not signed in');
    final res = await _client.rpc('complete_task', params: {
      'p_task': taskId,
      'p_duration': duration.dbValue,
      'p_summary': summary,
      'p_user': me,
    });
    return Task.fromMap(Map<String, dynamic>.from(res as Map));
  }

  static String _isoDate(DateTime d) {
    final local = DateTime(d.year, d.month, d.day);
    return local.toIso8601String().split('T').first;
  }
}
