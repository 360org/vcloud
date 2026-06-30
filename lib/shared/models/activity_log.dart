class ActivityLog {
  const ActivityLog({
    required this.id,
    this.ticketId,
    this.userId,
    required this.action,
    this.details,
    required this.createdAt,
  });

  final String id;
  final String? ticketId;
  final String? userId;
  final String action;
  final Map<String, dynamic>? details;
  final DateTime createdAt;

  factory ActivityLog.fromMap(Map<String, dynamic> map) => ActivityLog(
        id: map['id'] as String,
        ticketId: map['ticket_id'] as String?,
        userId: map['user_id'] as String?,
        action: map['action'] as String,
        details: map['details'] as Map<String, dynamic>?,
        createdAt: DateTime.parse(map['created_at'] as String),
      );

  String get displayAction {
    switch (action) {
      case 'created':
        return 'Tạo ticket';
      case 'status_changed':
        return 'Thay đổi trạng thái';
      case 'priority_changed':
        return 'Thay đổi mức ưu tiên';
      case 'category_changed':
        return 'Thay đổi danh mục';
      case 'comment_added':
        return 'Thêm bình luận';
      case 'updated':
        return 'Cập nhật';
      default:
        return action;
    }
  }
}
