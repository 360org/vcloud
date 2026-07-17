/// TicketComment model — represents a comment on a ticket.
class TicketComment {
  const TicketComment({
    required this.id,
    required this.ticketId,
    required this.authorId,
    required this.content,
    required this.createdAt,
    this.authorName,
  });

  final String id;
  final String ticketId;
  final String authorId;
  final String content;
  final DateTime createdAt;
  final String? authorName;

  factory TicketComment.fromMap(Map<String, dynamic> m) {
    return TicketComment(
      id: m['id'] as String,
      ticketId: m['ticket_id'] as String,
      authorId: m['author_id'] as String,
      content: m['content'] as String,
      createdAt: DateTime.parse(m['created_at'] as String),
      authorName: m['author_name'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'ticket_id': ticketId,
      'author_id': authorId,
      'content': content,
      'created_at': createdAt.toIso8601String(),
    };
  }

  TicketComment copyWith({
    String? id,
    String? ticketId,
    String? authorId,
    String? content,
    DateTime? createdAt,
    String? authorName,
  }) {
    return TicketComment(
      id: id ?? this.id,
      ticketId: ticketId ?? this.ticketId,
      authorId: authorId ?? this.authorId,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      authorName: authorName ?? this.authorName,
    );
  }
}
