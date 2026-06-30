import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/failure.dart';
import '../../../shared/models/ticket_comment.dart';

class TicketCommentRepository {
  TicketCommentRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Watch all comments for a ticket in real-time.
  Stream<List<TicketComment>> watchByTicket(String ticketId) {
    final ctl = StreamController<List<TicketComment>>();
    RealtimeChannel? ch;
    Future<void> refresh() async {
      try {
        final res = await _client
            .from('ticket_comments')
            .select('*, profiles!ticket_comments_author_id_fkey(display_name)')
            .eq('ticket_id', ticketId)
            .order('created_at', ascending: true);
        final list = (res as List).cast<Map<String, dynamic>>().map((m) {
          final profile = m['profiles'] as Map<String, dynamic>?;
          return TicketComment.fromMap({
            ...m,
            'author_name': profile?['display_name'] as String?,
          });
        }).toList();
        if (!ctl.isClosed) ctl.add(list);
      } catch (e) {
        if (!ctl.isClosed) ctl.addError(Failure('Load comments failed: $e'));
      }
    }

    ctl.onListen = () async {
      await refresh();
      ch = _client
          .channel('ticket-comments-$ticketId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'ticket_comments',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'ticket_id',
              value: ticketId,
            ),
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

  /// Add a comment to a ticket.
  Future<TicketComment> add(String ticketId, String content) async {
    final me = _client.auth.currentUser?.id;
    if (me == null) throw Failure('Not signed in');
    final res = await _client.from('ticket_comments').insert({
      'ticket_id': ticketId,
      'author_id': me,
      'content': content,
    }).select().single();
    return TicketComment.fromMap(Map<String, dynamic>.from(res));
  }

  /// Delete a comment (author only).
  Future<void> delete(String commentId) async {
    await _client.from('ticket_comments').delete().eq('id', commentId);
  }
}
