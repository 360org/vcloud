import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/failure.dart';
import '../../../shared/models/ticket.dart';

class TicketRepository {
  TicketRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Stream<List<Ticket>> watchAssigned() {
    final ctl = StreamController<List<Ticket>>();
    RealtimeChannel? ch;
    Future<void> refresh() async {
      try {
        final me = _client.auth.currentUser?.id;
        if (me == null) {
          ctl.add(const <Ticket>[]);
          return;
        }
        final res = await _client
            .from('tickets')
            .select('*')
            .or('assigned_to.eq.$me,created_by.eq.$me')
            .order('updated_at', ascending: false);
        final list = (res as List)
            .cast<Map<String, dynamic>>()
            .map(Ticket.fromMap)
            .toList();
        if (!ctl.isClosed) ctl.add(list);
      } catch (e) {
        if (!ctl.isClosed) ctl.addError(Failure('Reload failed: $e'));
      }
    }

    ctl.onListen = () async {
      await refresh();
      ch = _client
          .channel('tickets-${_client.auth.currentUser?.id}')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'tickets',
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

  Future<Ticket> create({
    required String title,
    required String? description,
    TicketPriority priority = TicketPriority.p3,
    String? category,
  }) async {
    final me = _client.auth.currentUser?.id;
    if (me == null) throw Failure('Not signed in');
    final res = await _client.from('tickets').insert({
      'title': title,
      'description': description,
      'created_by': me,
      'assigned_to': me,
      'status': TicketStatus.doing.dbValue,
      'priority': priority.dbValue,
      'category': category,
    }).select().single();
    return Ticket.fromMap(Map<String, dynamic>.from(res));
  }

  Future<Ticket> updateStatus(String id, TicketStatus status) async {
    final res = await _client
        .from('tickets')
        .update({'status': status.dbValue})
        .eq('id', id)
        .select()
        .single();
    return Ticket.fromMap(Map<String, dynamic>.from(res));
  }

  Future<Ticket> updatePriority(String id, TicketPriority priority) async {
    final res = await _client
        .from('tickets')
        .update({'priority': priority.dbValue})
        .eq('id', id)
        .select()
        .single();
    return Ticket.fromMap(Map<String, dynamic>.from(res));
  }

  Future<Ticket> updateCategory(String id, String? category) async {
    final res = await _client
        .from('tickets')
        .update({'category': category})
        .eq('id', id)
        .select()
        .single();
    return Ticket.fromMap(Map<String, dynamic>.from(res));
  }

  Future<Ticket> one(String id) async {
    final res =
        await _client.from('tickets').select('*').eq('id', id).single();
    return Ticket.fromMap(Map<String, dynamic>.from(res));
  }

  Future<void> delete(String id) async {
    await _client.from('tickets').delete().eq('id', id);
  }
}
