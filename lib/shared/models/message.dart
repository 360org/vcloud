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
    this.senderName,
    this.senderAvatarUrl,
    this.messageType,
    this.isInternal = false,
    this.parentId,
    this.attachmentIds = const [],
    this.starred = false,
    this.pinnedAt,
    this.isReadByMe = false,
    this.readByCount = 0,
    this.authoredByMe = false,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String content;
  final DateTime createdAt;
  final String status;
  final DateTime? readAt;
  final List<String> readBy;
  final String? senderName;
  final String? senderAvatarUrl;
  final String? messageType;
  final bool isInternal;
  final String? parentId;
  final List<String> attachmentIds;
  final bool starred;
  final DateTime? pinnedAt;
  final bool isReadByMe;
  final int readByCount;
  final bool authoredByMe;

  factory Message.fromMap(Map<String, dynamic> map) => Message(
    id: map['id'] as String,
    conversationId: map['conversation_id'] as String,
    senderId: map['sender_id'] as String,
    content: map['content'] as String,
    createdAt: _dateTimeOrNull(map['created_at']) ?? DateTime.now(),
    status: (map['status'] as String?) ?? 'sent',
    readAt: _dateTimeOrNull(map['read_at']),
    readBy: _stringList(map['read_by']),
    senderName: _stringOrNull(map['sender_name']),
    senderAvatarUrl: _stringOrNull(map['sender_avatar_url']),
    messageType: _stringOrNull(map['message_type']),
    isInternal: map['is_internal'] as bool? ?? false,
    parentId: _stringOrNull(map['parent_id']),
    attachmentIds: (map['attachment_ids'] as List<dynamic>? ?? const [])
        .map((id) => id.toString())
        .toList(),
    starred: map['starred'] as bool? ?? false,
    pinnedAt: _dateTimeOrNull(map['pinned_at']),
    isReadByMe: map['is_read_by_me'] as bool? ?? false,
    readByCount: (map['read_by_count'] as num?)?.toInt() ?? 0,
    authoredByMe: map['authored_by_me'] as bool? ?? false,
  );

  factory Message.fromOdooMessageInfo({
    required String conversationId,
    required Map<String, dynamic> map,
  }) {
    final body = cleanHtmlText(map['body']);
    final preview = cleanHtmlText(map['preview']);
    return Message(
      id: map['id'].toString(),
      conversationId: conversationId,
      senderId:
          _recordId(
            map['author_id'] ?? map['author_partner_id'] ?? map['partner_id'],
          ) ??
          '',
      content: body.isNotEmpty ? body : preview,
      createdAt: _dateTimeOrNull(map['date']) ?? DateTime.now(),
      senderName:
          _stringOrNull(map['author_name']) ?? _recordName(map['author_id']),
      senderAvatarUrl: _stringOrNull(map['author_avatar']),
      messageType: _stringOrNull(map['message_type']),
      isInternal: map['is_internal'] as bool? ?? false,
      parentId: _stringOrNull(map['parent_id']),
      attachmentIds: (map['attachment_ids'] as List<dynamic>? ?? const [])
          .map((id) => id.toString())
          .toList(),
      starred: map['starred'] as bool? ?? false,
      pinnedAt: _dateTimeOrNull(map['pinned_at']),
      isReadByMe: map['is_read_by_me'] as bool? ?? false,
      readBy: _stringList(
        map['read_by'] ??
            map['read_by_ids'] ??
            map['read_partner_ids'] ??
            map['seen_by'],
      ),
      readByCount: (map['read_by_count'] as num?)?.toInt() ?? 0,
      authoredByMe:
          map['authored_by_me'] as bool? ??
          map['is_mine'] as bool? ??
          map['is_author'] as bool? ??
          false,
    );
  }

  static String cleanHtmlText(Object? value) {
    if (value == null || value == false) return '';
    final text = value.toString();
    if (text.isEmpty) return '';

    final withBreaks = text
        .replaceAll(RegExp(r'<\s*br\s*/?\s*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</\s*p\s*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</\s*div\s*>', caseSensitive: false), '\n')
        .replaceAll(RegExp(r'</\s*li\s*>', caseSensitive: false), '\n');
    final withoutTags = withBreaks.replaceAll(RegExp(r'<[^>]*>'), '');
    final decoded = _decodeHtmlEntities(withoutTags);
    return decoded
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .join('\n')
        .trim();
  }

  static DateTime? _dateTimeOrNull(Object? value) {
    if (value == null || value == false) return null;
    final text = value.toString();
    final parsed = DateTime.tryParse(text);
    if (parsed == null || parsed.isUtc || _hasTimezone(text)) return parsed;
    return DateTime.utc(
      parsed.year,
      parsed.month,
      parsed.day,
      parsed.hour,
      parsed.minute,
      parsed.second,
      parsed.millisecond,
      parsed.microsecond,
    );
  }

  static String? _stringOrNull(Object? value) {
    if (value == null || value == false) return null;
    final text = value.toString();
    return text.isEmpty ? null : text;
  }

  static String? _recordId(Object? value) {
    if (value == null || value == false) return null;
    if (value is List && value.isNotEmpty) return value.first.toString();
    if (value is Map && value['id'] != null) return value['id'].toString();
    final text = value.toString();
    return text.isEmpty ? null : text;
  }

  static String? _recordName(Object? value) {
    if (value is List && value.length > 1) return _stringOrNull(value[1]);
    if (value is Map) return _stringOrNull(value['name']);
    return null;
  }

  static bool _hasTimezone(String value) {
    return RegExp(
      r'(z|[+-]\d\d:?\d\d)$',
      caseSensitive: false,
    ).hasMatch(value.trim());
  }

  static List<String> _stringList(Object? value) {
    if (value == null || value == false) return const [];
    if (value is! List) return const [];
    return value
        .map((item) {
          if (item is Map && item['id'] != null) return item['id'].toString();
          if (item is List && item.isNotEmpty) return item.first.toString();
          return item.toString();
        })
        .where((id) => id.isNotEmpty && id != 'false')
        .toList();
  }

  static String _decodeHtmlEntities(String text) {
    const entities = <String, String>{
      '&amp;': '&',
      '&lt;': '<',
      '&gt;': '>',
      '&quot;': '"',
      '&#39;': "'",
      '&apos;': "'",
      '&nbsp;': ' ',
    };
    var decoded = text;
    for (final entry in entities.entries) {
      decoded = decoded.replaceAll(entry.key, entry.value);
    }
    return decoded
        .replaceAllMapped(RegExp(r'&#(\d+);'), (match) {
          final codePoint = int.tryParse(match.group(1) ?? '');
          return codePoint == null
              ? match.group(0)!
              : String.fromCharCode(codePoint);
        })
        .replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (match) {
          final codePoint = int.tryParse(match.group(1) ?? '', radix: 16);
          return codePoint == null
              ? match.group(0)!
              : String.fromCharCode(codePoint);
        });
  }
}
