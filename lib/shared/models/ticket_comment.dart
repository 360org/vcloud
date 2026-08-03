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
    final rawDate = m['created_at'];
    DateTime parsedDate;
    if (rawDate is DateTime) {
      parsedDate = rawDate;
    } else if (rawDate is String) {
      parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    final rawAuthorId = m['author_id'];
    String authorIdStr;
    if (rawAuthorId == null || rawAuthorId == false || rawAuthorId == 'false') {
      authorIdStr = '0';
    } else if (rawAuthorId is List && rawAuthorId.isNotEmpty) {
      authorIdStr = rawAuthorId.first.toString();
    } else {
      authorIdStr = rawAuthorId.toString();
    }

    final rawAuthorName = m['author_name'];
    String? authorNameStr;
    if (rawAuthorName != null && rawAuthorName != false && rawAuthorName != 'false') {
      authorNameStr = rawAuthorName.toString();
    } else if (rawAuthorId is List && rawAuthorId.length > 1) {
      authorNameStr = rawAuthorId[1].toString();
    } else if (authorIdStr == '0') {
      authorNameStr = 'Hệ thống';
    }

    return TicketComment(
      id: m['id']?.toString() ?? '0',
      ticketId: m['ticket_id']?.toString() ?? '',
      authorId: authorIdStr,
      content: m['content']?.toString() ?? '',
      createdAt: parsedDate,
      authorName: authorNameStr,
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
