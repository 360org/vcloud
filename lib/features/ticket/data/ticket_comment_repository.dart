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
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
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
      void scheduleNextPoll() {
        if (ctl.isClosed) return;
        timer?.cancel();
        timer = Timer(const Duration(seconds: 5), () async {
          if (!ctl.isClosed) {
            await refresh();
            scheduleNextPoll();
          }
        });
      }
      scheduleNextPoll();
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
    final rawAuthor = map['author_id'];
    String authorId = '0';
    String? authorName = map['author_name']?.toString();

    if (rawAuthor is List && rawAuthor.isNotEmpty) {
      authorId = rawAuthor.first.toString();
      if (rawAuthor.length > 1 && (authorName == null || authorName.isEmpty)) {
        authorName = rawAuthor[1].toString();
      }
    } else if (rawAuthor != null && rawAuthor != false && rawAuthor != 'false') {
      authorId = rawAuthor.toString();
    } else {
      authorName ??= 'Hệ thống';
    }

    final dateVal = map['date'] ?? map['create_date'];
    final dateStr = (dateVal != null && dateVal != false && dateVal != 'false')
        ? dateVal.toString()
        : DateTime.now().toIso8601String();

    return <String, dynamic>{
      'id': map['id']?.toString() ?? '0',
      'ticket_id': ticketId,
      'author_id': authorId,
      'content': _commentContent(map),
      'created_at': dateStr,
      'author_name': authorName,
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
