import '../../core/utils/html_text.dart';

class TaskMessage {
  const TaskMessage({
    required this.id,
    required this.body,
    required this.authorId,
    required this.authorName,
    required this.date,
    this.messageType,
  });

  final String id;
  final String body;
  final String authorId;
  final String authorName;
  final DateTime date;
  final String? messageType;

  factory TaskMessage.fromMap(Map<String, dynamic> m) {
    final rawDate = m['date'] ?? m['created_at'] ?? m['create_date'];
    final parsedDate = _parseDate(rawDate);

    final rawAuthorId = m['author_id'];
    String authorIdStr = '0';
    if (rawAuthorId != null && rawAuthorId != false && rawAuthorId != 'false') {
      if (rawAuthorId is List && rawAuthorId.isNotEmpty) {
        authorIdStr = rawAuthorId.first.toString();
      } else {
        authorIdStr = rawAuthorId.toString();
      }
    }

    final rawAuthorName = m['author_name'];
    String authorNameStr = 'Người dùng';
    if (rawAuthorName != null && rawAuthorName != false && rawAuthorName != 'false') {
      authorNameStr = rawAuthorName.toString();
    } else if (rawAuthorId is List && rawAuthorId.length > 1) {
      authorNameStr = rawAuthorId[1].toString();
    }

    return TaskMessage(
      id: m['id']?.toString() ?? '0',
      body: cleanHtmlText(m['body']?.toString() ?? ''),
      authorId: authorIdStr,
      authorName: authorNameStr,
      date: parsedDate,
      messageType: m['message_type']?.toString(),
    );
  }

  static DateTime _parseDate(Object? value) {
    if (value == null || value == false) return DateTime.now();
    if (value is DateTime) return value.isUtc ? value.toLocal() : value;
    final text = value.toString();
    final parsed = DateTime.tryParse(text);
    if (parsed == null) return DateTime.now();
    return parsed.isUtc ? parsed.toLocal() : parsed;
  }
}
