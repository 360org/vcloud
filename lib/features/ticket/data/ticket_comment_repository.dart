import 'dart:async';

import '../../../core/api/odoo_api_client.dart';
import '../../../core/error/failure.dart';
import '../../../shared/models/ticket_comment.dart';

class TicketCommentRepository {
  TicketCommentRepository({OdooApiClient? client})
    : _client = client ?? odooApiClient;

  final OdooApiClient _client;

  Stream<List<TicketComment>> watchByTicket(String ticketId) {
    final ctl = StreamController<List<TicketComment>>();

    Future<void> refresh() async {
      try {
        final res = await _client.get('/api/v1/mobile/ticket/$ticketId');
        final detail = Map<String, dynamic>.from(res as Map);
        final messages = (detail['messages'] as List? ?? const <dynamic>[])
            .cast<Map<String, dynamic>>()
            .map((m) => _commentFromMessage(ticketId, m))
            .map(TicketComment.fromMap)
            .toList();
        if (!ctl.isClosed) ctl.add(messages);
      } catch (e) {
        if (!ctl.isClosed) ctl.addError(Failure('Load comments failed: $e'));
      }
    }

    ctl.onListen = refresh;
    return ctl.stream;
  }

  Future<TicketComment> add(String ticketId, String content) async {
    await _client.post(
      '/api/v1/mobile/ticket/$ticketId/message',
      body: <String, dynamic>{'body': content},
    );
    final comments = await watchByTicket(ticketId).first;
    return comments.isEmpty
        ? TicketComment(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            ticketId: ticketId,
            authorId: '',
            content: content,
            createdAt: DateTime.now(),
          )
        : comments.last;
  }

  Future<void> delete(String commentId) async {
    await _client.delete('/api/v1/mail.message/$commentId');
  }

  Map<String, dynamic> _commentFromMessage(
    String ticketId,
    Map<String, dynamic> map,
  ) {
    return <String, dynamic>{
      'id': map['id'].toString(),
      'ticket_id': ticketId,
      'author_id': map['author_id']?.toString() ?? '',
      'content': (map['body'] ?? map['preview'] ?? '').toString(),
      'created_at': map['date'] ?? DateTime.now().toIso8601String(),
      'author_name': map['author_name'] as String?,
    };
  }
}
