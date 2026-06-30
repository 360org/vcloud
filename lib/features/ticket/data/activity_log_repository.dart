import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/failure.dart';
import '../../../shared/models/activity_log.dart';

class ActivityLogRepository {
  ActivityLogRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Stream<List<ActivityLog>> watchByTicket(String ticketId) {
    final ctl = StreamController<List<ActivityLog>>();
    RealtimeChannel? ch;

    Future<void> refresh() async {
      try {
        final res = await _client
            .from('activity_log')
            .select('*')
            .eq('ticket_id', ticketId)
            .order('created_at', ascending: false)
            .limit(50);

        final list = (res as List)
            .cast<Map<String, dynamic>>()
            .map(ActivityLog.fromMap)
            .toList();

        if (!ctl.isClosed) ctl.add(list);
      } catch (e) {
        if (!ctl.isClosed) ctl.addError(Failure('Load activity log failed: $e'));
      }
    }

    ctl.onListen = () async {
      await refresh();
      ch = _client
          .channel('activity-$ticketId')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'activity_log',
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

  Future<void> log({
    required String? ticketId,
    required String action,
    Map<String, dynamic>? details,
  }) async {
    final me = _client.auth.currentUser?.id;
    await _client.from('activity_log').insert({
      'ticket_id': ticketId,
      'user_id': me,
      'action': action,
      'details': details,
    });
  }
}
