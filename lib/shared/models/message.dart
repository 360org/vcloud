import '../../core/utils/html_text.dart';

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
    this.attachmentName,
    this.attachmentMimeType,
    this.attachmentUrl,
    this.attachmentSize,
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
  final String? attachmentName;
  final String? attachmentMimeType;
  final String? attachmentUrl;
  final int? attachmentSize;
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
    attachmentIds: _attachmentIds(map),
    attachmentName: _attachmentName(map),
    attachmentMimeType: _attachmentMimeType(map),
    attachmentUrl: _attachmentUrl(map),
    attachmentSize: _attachmentSize(map),
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
      status: (map['status'] as String?) ??
          ((map['is_read'] == true) ? 'read' : 'sent'),
      senderName:
          _stringOrNull(map['author_name']) ?? _recordName(map['author_id']),
      senderAvatarUrl:
          _stringOrNull(map['author_avatar']) ??
          _stringOrNull(map['avatar_url']),
      messageType: _stringOrNull(map['message_type']),
      isInternal: map['is_internal'] as bool? ?? false,
      parentId: _stringOrNull(map['parent_id']),
      attachmentIds: _attachmentIds(map),
      attachmentName: _attachmentName(map),
      attachmentMimeType: _attachmentMimeType(map),
      attachmentUrl: _attachmentUrl(map),
      attachmentSize: _attachmentSize(map),
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

  static DateTime? _dateTimeOrNull(Object? value) {
    if (value == null || value == false) return null;
    final text = value.toString();
    final parsed = DateTime.tryParse(text);
    if (parsed == null) return null;
    final utcDt = (parsed.isUtc || _hasTimezone(text))
        ? parsed.toUtc()
        : DateTime.utc(
            parsed.year,
            parsed.month,
            parsed.day,
            parsed.hour,
            parsed.minute,
            parsed.second,
            parsed.millisecond,
            parsed.microsecond,
          );
    return utcDt.toLocal();
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

  static List<String> _attachmentIds(Map<String, dynamic> map) {
    final values = _attachmentValues(map);
    return values
        .map(_attachmentId)
        .whereType<String>()
        .where((id) => id.isNotEmpty && id != 'false')
        .toList();
  }

  static String? _attachmentName(Map<String, dynamic> map) {
    final direct = _stringOrNull(
      map['attachment_name'] ?? map['filename'] ?? map['file_name'],
    );
    if (direct != null) return direct;
    for (final value in _attachmentValues(map)) {
      final name = _attachmentField(value, const [
        'name',
        'filename',
        'display_name',
      ]);
      if (name != null) return name;
      if (value is List && value.length > 1) return _stringOrNull(value[1]);
    }
    return null;
  }

  static String? _attachmentMimeType(Map<String, dynamic> map) {
    final direct = _stringOrNull(
      map['attachment_mimetype'] ?? map['mimetype'] ?? map['mime_type'],
    );
    if (direct != null) return direct;
    for (final value in _attachmentValues(map)) {
      final mimetype = _attachmentField(value, const ['mimetype', 'mime_type']);
      if (mimetype != null) return mimetype;
    }
    return null;
  }

  static String? _attachmentUrl(Map<String, dynamic> map) {
    final direct = _stringOrNull(
      map['attachment_url'] ??
          map['url'] ??
          map['thumbnail_url'] ??
          map['attachment_download_url'] ??
          map['download_url'],
    );
    if (direct != null) return direct;
    for (final value in _attachmentValues(map)) {
      final url = _attachmentField(value, const [
        'url',
        'thumbnail_url',
        'download_url',
      ]);
      final accessToken = _attachmentField(value, const ['access_token']);
      if (url != null) {
        if (accessToken != null && accessToken.isNotEmpty && !url.contains('access_token=')) {
          return '$url${url.contains('?') ? '&' : '?'}access_token=$accessToken';
        }
        return url;
      }
    }
    return null;
  }

  static int? _attachmentSize(Map<String, dynamic> map) {
    final direct = _intOrNull(
      map['attachment_size'] ?? map['file_size'] ?? map['size'],
    );
    if (direct != null) return direct;
    for (final value in _attachmentValues(map)) {
      final size = _intOrNull(
        value is Map ? value['file_size'] ?? value['size'] : null,
      );
      if (size != null) return size;
    }
    return null;
  }

  static List<dynamic> _attachmentValues(Map<String, dynamic> map) {
    final raw = map['attachments'] ?? map['attachment_ids'];
    if (raw is List) return raw;
    return const [];
  }

  static String? _attachmentId(Object? value) {
    if (value is Map) {
      return _stringOrNull(value['id'] ?? value['attachment_id']);
    }
    if (value is List && value.isNotEmpty) return value.first.toString();
    return _stringOrNull(value);
  }

  static String? _attachmentField(Object? value, List<String> keys) {
    if (value is! Map) return null;
    for (final key in keys) {
      final text = _stringOrNull(value[key]);
      if (text != null) return text;
    }
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

  static int? _intOrNull(Object? value) {
    if (value == null || value == false) return null;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}
