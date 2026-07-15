import 'dart:async';

import '../../../core/api/odoo_api_client.dart';
import '../../../core/error/failure.dart';
import '../../../core/utils/html_text.dart';
import '../../../shared/models/ticket_comment.dart';

class TicketCommentRepository {
  TicketCommentRepository({OdooApiClient? client})
    : _client = client ?? odooApiClient;

  final OdooApiClient _client;

  Stream<List<TicketComment>> watchByTicket(String ticketId) {
    final ctl = StreamController<List<TicketComment>>();
    Timer? timer;
    var refreshing = false;

    Future<void> refresh() async {
      if (refreshing) return;
      refreshing = true;
      try {
        final res = await _client.get('/api/v1/mobile/ticket/$ticketId');
        final detail = Map<String, dynamic>.from(res as Map);
        final initialDescription = _normalizedContent(detail['description']);
        final messages = (detail['messages'] as List? ?? const <dynamic>[])
            .cast<Map<String, dynamic>>()
            // The ticket-create endpoint can add the supplied description to
            // Odoo's chatter as its first mail.message. It is ticket content,
            // not a user-authored reply, and is already rendered above the
            // comment composer.
            .where(
              (message) =>
                  initialDescription.isEmpty ||
                  _normalizedContent(message['body'] ?? message['preview']) !=
                      initialDescription,
            )
            .map((m) => _commentFromMessage(ticketId, m))
            .map(TicketComment.fromMap)
            .toList();
        if (!ctl.isClosed) ctl.add(messages);
      } catch (e) {
        if (!ctl.isClosed) ctl.addError(Failure('Load comments failed: $e'));
      } finally {
        refreshing = false;
      }
    }

    ctl.onListen = () {
      refresh();
      timer = Timer.periodic(const Duration(seconds: 5), (_) => refresh());
    };
    ctl.onCancel = () {
      timer?.cancel();
      timer = null;
    };
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
      'content': _commentContent(map),
      'created_at': map['date'] ?? DateTime.now().toIso8601String(),
      'author_name': map['author_name'] as String?,
    };
  }

  String _commentContent(Map<String, dynamic> map) {
    final body = cleanHtmlText(map['body']);
    if (body.isNotEmpty) return body;
    return cleanHtmlText(map['preview']);
  }

  String _normalizedContent(Object? value) {
    return cleanHtmlText(
      value,
    ).replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();
  }
}
