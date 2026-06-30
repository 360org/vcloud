/// Row from `public.messages`.
class Message {
  const Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.content,
    required this.createdAt,
    this.status = 'sent',
    this.readAt,
    this.readBy = const [],
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final DateTime createdAt;
  final String status;
  final DateTime? readAt;
  final List<String> readBy;

  factory Message.fromMap(Map<String, dynamic> map) => Message(
        id: map['id'] as String,
        conversationId: map['conversation_id'] as String,
        senderId: map['sender_id'] as String,
        content: map['content'] as String,
        createdAt: DateTime.parse(map['created_at'] as String),
        status: (map['status'] as String?) ?? 'sent',
        readAt: map['read_at'] != null ? DateTime.parse(map['read_at'] as String) : null,
        readBy: (map['read_by'] as List<dynamic>?)?.cast<String>() ?? const [],
      );
}
