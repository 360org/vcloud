class ChatV2InboxAttachment {
  const ChatV2InboxAttachment({
    required this.id,
    required this.name,
    required this.mimetype,
    required this.fileSize,
    required this.url,
  });

  final int id;
  final String name;
  final String mimetype;
  final int fileSize;
  final String url;

  factory ChatV2InboxAttachment.fromJson(Map<String, dynamic> json) {
    return ChatV2InboxAttachment(
      id: json['id'] is int ? json['id'] as int : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      name: json['name'] as String? ?? '',
      mimetype: json['mimetype'] as String? ?? '',
      fileSize: json['file_size'] is int
          ? json['file_size'] as int
          : int.tryParse(json['file_size']?.toString() ?? '') ?? 0,
      url: json['url'] as String? ?? '',
    );
  }
}

class ChatV2InboxItem {
  const ChatV2InboxItem({
    required this.id,
    required this.subject,
    required this.recordName,
    required this.model,
    required this.resId,
    this.channelId,
    required this.body,
    this.date,
    this.authorId,
    required this.authorName,
    this.authorAvatar,
    this.isStarred = false,
    this.isNeedaction = false,
    this.messageType = 'comment',
    this.attachmentIds = const [],
    this.attachments = const [],
  });

  final int id;
  final String subject;
  final String recordName;
  final String model;
  final int resId;
  final int? channelId;
  final String body;
  final DateTime? date;
  final int? authorId;
  final String authorName;
  final String? authorAvatar;
  final bool isStarred;
  final bool isNeedaction;
  final String messageType;
  final List<int> attachmentIds;
  final List<ChatV2InboxAttachment> attachments;

  ChatV2InboxItem copyWith({
    int? id,
    String? subject,
    String? recordName,
    String? model,
    int? resId,
    int? channelId,
    String? body,
    DateTime? date,
    int? authorId,
    String? authorName,
    String? authorAvatar,
    bool? isStarred,
    bool? isNeedaction,
    String? messageType,
    List<int>? attachmentIds,
    List<ChatV2InboxAttachment>? attachments,
  }) {
    return ChatV2InboxItem(
      id: id ?? this.id,
      subject: subject ?? this.subject,
      recordName: recordName ?? this.recordName,
      model: model ?? this.model,
      resId: resId ?? this.resId,
      channelId: channelId ?? this.channelId,
      body: body ?? this.body,
      date: date ?? this.date,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorAvatar: authorAvatar ?? this.authorAvatar,
      isStarred: isStarred ?? this.isStarred,
      isNeedaction: isNeedaction ?? this.isNeedaction,
      messageType: messageType ?? this.messageType,
      attachmentIds: attachmentIds ?? this.attachmentIds,
      attachments: attachments ?? this.attachments,
    );
  }

  factory ChatV2InboxItem.fromJson(Map<String, dynamic> json) {
    DateTime? parsedDate;
    final rawDate = json['date'];
    if (rawDate is String && rawDate.isNotEmpty) {
      try {
        parsedDate = DateTime.parse(rawDate).toLocal();
      } catch (_) {}
    }

    final rawAtts = json['attachments'] as List<dynamic>? ?? [];
    final parsedAtts = <ChatV2InboxAttachment>[];
    for (final a in rawAtts) {
      if (a is Map) {
        parsedAtts.add(ChatV2InboxAttachment.fromJson(Map<String, dynamic>.from(a)));
      }
    }

    final rawAttIds = json['attachment_ids'] as List<dynamic>? ?? [];
    final parsedAttIds = <int>[];
    for (final id in rawAttIds) {
      if (id is int) {
        parsedAttIds.add(id);
      } else if (id != null) {
        final parsed = int.tryParse(id.toString());
        if (parsed != null) parsedAttIds.add(parsed);
      }
    }

    int? channelId;
    if (json['channel_id'] != null) {
      channelId = json['channel_id'] is int
          ? json['channel_id'] as int
          : int.tryParse(json['channel_id'].toString());
    } else if (json['model'] == 'discuss.channel' && json['res_id'] != null) {
      channelId = json['res_id'] is int
          ? json['res_id'] as int
          : int.tryParse(json['res_id'].toString());
    }

    return ChatV2InboxItem(
      id: json['id'] is int ? json['id'] as int : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      subject: (json['subject'] as String?)?.trim() ?? '',
      recordName: (json['record_name'] as String?)?.trim() ?? '',
      model: json['model'] as String? ?? '',
      resId: json['res_id'] is int
          ? json['res_id'] as int
          : int.tryParse(json['res_id']?.toString() ?? '') ?? 0,
      channelId: channelId,
      body: json['body'] as String? ?? '',
      date: parsedDate,
      authorId: json['author_id'] is int
          ? json['author_id'] as int
          : int.tryParse(json['author_id']?.toString() ?? ''),
      authorName: (json['author_name'] as String?)?.trim() ?? 'System',
      authorAvatar: json['author_avatar'] as String?,
      isStarred: json['is_starred'] == true,
      isNeedaction: json['is_needaction'] == true,
      messageType: json['message_type'] as String? ?? 'comment',
      attachmentIds: parsedAttIds,
      attachments: parsedAtts,
    );
  }

  /// Trích xuất text sạch từ HTML body cho thẻ preview
  String get plainSnippet {
    if (body.isEmpty) return '';
    final text = body
        .replaceAll(RegExp(r'<style[^>]*>.*?</style>', caseSensitive: false, dotAll: true), '')
        .replaceAll(RegExp(r'<script[^>]*>.*?</script>', caseSensitive: false, dotAll: true), '')
        .replaceAll(RegExp(r'<(?:br|p|div|tr|li|h[1-6])[^>]*>', caseSensitive: false), ' ')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll(RegExp(r'\s+([,.:;!?])'), r'$1')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return text;
  }
}
