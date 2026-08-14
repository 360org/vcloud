import 'package:flutter/foundation.dart';

@immutable
class ChatV2Message {
  const ChatV2Message({
    required this.id,
    required this.channelId,
    required this.content,
    this.bodyHtml,
    this.authorId,
    required this.authorName,
    this.authorAvatar,
    this.date,
    this.isMine = false,
    this.status = 'sent',
    this.attachmentIds = const [],
    this.attachmentUrls = const [],
  });

  final String id;
  final String channelId;
  final String content;
  final String? bodyHtml;
  final String? authorId;
  final String authorName;
  final String? authorAvatar;
  final DateTime? date;
  final bool isMine;
  final String status;
  final List<String> attachmentIds;
  final List<String> attachmentUrls;

  factory ChatV2Message.fromMap(
    Map<String, dynamic> map, {
    String? currentPartnerId,
    String? currentUserId,
  }) {
    final id = _stringOr(map['id'], '');
    final channelId = _stringOr(map['channel_id'], '');
    final rawBody = _stringOr(map['body'] ?? map['content'], '');
    final cleanContent = _stripHtml(rawBody);
    final authorId = _stringOrNull(map['author_id'] ?? (map['author'] is Map ? map['author']['id'] : null));
    final authorName = _stringOr(
      map['author_name'] ?? (map['author'] is Map ? map['author']['name'] : null),
      'Thành viên',
    );
    final authorAvatar = _stringOrNull(
      map['author_avatar'] ?? (map['author'] is Map ? map['author']['avatar_url'] : null),
    );

    DateTime? date;
    final dateStr = _stringOrNull(map['date'] ?? map['create_date']);
    if (dateStr != null) {
      date = DateTime.tryParse(dateStr)?.toLocal();
    }

    final isRead = _boolOr(map['is_read'], false);
    final status = _stringOr(map['status'], isRead ? 'read' : 'sent');

    // Kiểm tra isMine
    bool isMine = false;
    if (currentPartnerId != null && authorId == currentPartnerId) {
      isMine = true;
    } else if (currentUserId != null && authorId == currentUserId) {
      isMine = true;
    } else if (map['is_mine'] == true) {
      isMine = true;
    }

    // Parse attachments
    final attIds = <String>[];
    final rawAttIds = map['attachment_ids'];
    if (rawAttIds is List) {
      for (final item in rawAttIds) {
        final idStr = _stringOrNull(item);
        if (idStr != null) attIds.add(idStr);
      }
    }
    final rawAtts = map['attachments'];
    if (rawAtts is List) {
      for (final item in rawAtts) {
        if (item is Map<String, dynamic>) {
          final idStr = _stringOrNull(item['id'] ?? item['attachment_id']);
          if (idStr != null && !attIds.contains(idStr)) attIds.add(idStr);
        }
      }
    }

    final attUrls = <String>[];
    if (rawAtts is List) {
      for (final item in rawAtts) {
        if (item is Map<String, dynamic>) {
          final urlStr = _stringOrNull(item['download_url'] ?? item['url']);
          if (urlStr != null) attUrls.add(urlStr);
        }
      }
    }

    return ChatV2Message(
      id: id,
      channelId: channelId,
      content: cleanContent.isEmpty ? (attIds.isNotEmpty ? '[Tệp đính kèm]' : '') : cleanContent,
      bodyHtml: rawBody,
      authorId: authorId,
      authorName: authorName,
      authorAvatar: authorAvatar,
      date: date,
      isMine: isMine,
      status: status,
      attachmentIds: attIds,
      attachmentUrls: attUrls,
    );
  }

  ChatV2Message copyWith({
    String? id,
    String? channelId,
    String? content,
    String? bodyHtml,
    String? authorId,
    String? authorName,
    String? authorAvatar,
    DateTime? date,
    bool? isMine,
    String? status,
    List<String>? attachmentIds,
    List<String>? attachmentUrls,
  }) {
    return ChatV2Message(
      id: id ?? this.id,
      channelId: channelId ?? this.channelId,
      content: content ?? this.content,
      bodyHtml: bodyHtml ?? this.bodyHtml,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorAvatar: authorAvatar ?? this.authorAvatar,
      date: date ?? this.date,
      isMine: isMine ?? this.isMine,
      status: status ?? this.status,
      attachmentIds: attachmentIds ?? this.attachmentIds,
      attachmentUrls: attachmentUrls ?? this.attachmentUrls,
    );
  }

  static String _stringOr(dynamic val, String fallback) {
    if (val == null || val == false) return fallback;
    return val.toString();
  }

  static String? _stringOrNull(dynamic val) {
    if (val == null || val == false) return null;
    final str = val.toString().trim();
    return str.isEmpty ? null : str;
  }

  static bool _boolOr(dynamic val, bool fallback) {
    if (val == null) return fallback;
    if (val is bool) return val;
    final s = val.toString().toLowerCase();
    if (s == 'true' || s == '1') return true;
    if (s == 'false' || s == '0') return false;
    return fallback;
  }

  static String _stripHtml(String html) {
    final text = html
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&#39;', "'")
        .replaceAll('&amp;', '&');
    final exp = RegExp(r'<[^>]*>', multiLine: true);
    return text.replaceAll(exp, '').replaceAll('&nbsp;', ' ').trim();
  }
}
