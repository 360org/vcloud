import 'package:flutter/foundation.dart';

@immutable
class ChatV2Attachment {
  final String id;
  final String name;
  final String? mimetype;
  final int? fileSize;
  final String? url;
  final String? downloadUrl;
  final String? accessToken;

  const ChatV2Attachment({
    required this.id,
    required this.name,
    this.mimetype,
    this.fileSize,
    this.url,
    this.downloadUrl,
    this.accessToken,
  });

  bool get isImage {
    final mime = mimetype?.toLowerCase() ?? '';
    if (mime.startsWith('image/')) return true;
    final lowerName = name.toLowerCase();
    return lowerName.endsWith('.png') ||
        lowerName.endsWith('.jpg') ||
        lowerName.endsWith('.jpeg') ||
        lowerName.endsWith('.gif') ||
        lowerName.endsWith('.webp');
  }

  String resolveFullUrl(String baseUrl) {
    final cleanBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    if (id.isNotEmpty && isImage) {
      return '$cleanBase/web/image/$id';
    }
    final target = (url != null && url!.isNotEmpty) ? url! : (downloadUrl ?? '');
    if (target.startsWith('http://') || target.startsWith('https://')) {
      return target;
    }
    final cleanTarget = target.startsWith('/') ? target : '/$target';
    return '$cleanBase$cleanTarget';
  }

  factory ChatV2Attachment.fromMap(Map<String, dynamic> map) {
    final id = _stringOr(map['id'] ?? map['attachment_id'], '');
    final rawName = _stringOr(map['name'] ?? map['filename'], 'attachment');
    final mimetype = _stringOrNull(map['mimetype']);
    final fileSize = map['file_size'] is int ? map['file_size'] as int : null;
    final url = _stringOrNull(map['url']);
    final downloadUrl = _stringOrNull(map['download_url']);
    final accessToken = _stringOrNull(map['access_token']);

    return ChatV2Attachment(
      id: id,
      name: rawName,
      mimetype: mimetype,
      fileSize: fileSize,
      url: url,
      downloadUrl: downloadUrl,
      accessToken: accessToken,
    );
  }
}

@immutable
class ChatV2Message {
  final String id;
  final String channelId;
  final String content;
  final String? authorId;
  final String authorName;
  final String? authorAvatar;
  final DateTime? createdAt;
  final bool isMine;
  final String status;
  final bool isRead;
  final List<String> attachmentIds;
  final List<String> attachmentUrls;
  final List<ChatV2Attachment> attachments;

  const ChatV2Message({
    required this.id,
    required this.channelId,
    required this.content,
    this.authorId,
    required this.authorName,
    this.authorAvatar,
    this.createdAt,
    required this.isMine,
    this.status = 'sent',
    this.isRead = false,
    this.attachmentIds = const [],
    this.attachmentUrls = const [],
    this.attachments = const [],
  });

  bool get hasImageAttachment => attachments.any((att) => att.isImage);

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
    final attList = <ChatV2Attachment>[];
    final attIds = <String>[];
    final attUrls = <String>[];

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
          final att = ChatV2Attachment.fromMap(item);
          attList.add(att);
          if (att.id.isNotEmpty && !attIds.contains(att.id)) {
            attIds.add(att.id);
          }
          final urlStr = att.downloadUrl ?? att.url;
          if (urlStr != null && urlStr.isNotEmpty) {
            attUrls.add(urlStr);
          }
        }
      }
    }

    return ChatV2Message(
      id: id,
      channelId: channelId,
      content: cleanContent,
      authorId: authorId,
      authorName: authorName,
      authorAvatar: authorAvatar,
      createdAt: date,
      isMine: isMine,
      status: status,
      isRead: isRead,
      attachmentIds: attIds,
      attachmentUrls: attUrls,
      attachments: attList,
    );
  }

  ChatV2Message copyWith({
    String? id,
    String? channelId,
    String? content,
    String? authorId,
    String? authorName,
    String? authorAvatar,
    DateTime? createdAt,
    bool? isMine,
    String? status,
    bool? isRead,
    List<String>? attachmentIds,
    List<String>? attachmentUrls,
    List<ChatV2Attachment>? attachments,
  }) {
    return ChatV2Message(
      id: id ?? this.id,
      channelId: channelId ?? this.channelId,
      content: content ?? this.content,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorAvatar: authorAvatar ?? this.authorAvatar,
      createdAt: createdAt ?? this.createdAt,
      isMine: isMine ?? this.isMine,
      status: status ?? this.status,
      isRead: isRead ?? this.isRead,
      attachmentIds: attachmentIds ?? this.attachmentIds,
      attachmentUrls: attachmentUrls ?? this.attachmentUrls,
      attachments: attachments ?? this.attachments,
    );
  }
}

String _stringOr(dynamic value, String fallback) {
  if (value == null) return fallback;
  if (value is String) {
    final trimmed = value.trim();
    return trimmed.isNotEmpty ? trimmed : fallback;
  }
  return value.toString().trim();
}

String? _stringOrNull(dynamic value) {
  if (value == null) return null;
  if (value is String) {
    final trimmed = value.trim();
    return trimmed.isNotEmpty ? trimmed : null;
  }
  final str = value.toString().trim();
  return str.isNotEmpty ? str : null;
}

bool _boolOr(dynamic value, bool fallback) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final lower = value.toLowerCase().trim();
    if (lower == 'true' || lower == '1') return true;
    if (lower == 'false' || lower == '0') return false;
  }
  return fallback;
}

String _stripHtml(String html) {
  if (html.isEmpty) return '';
  final noTags = html.replaceAll(RegExp(r'<[^>]*>', multiLine: true), '');
  return _unescapeHtml(noTags).trim();
}

String _unescapeHtml(String text) {
  return text
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&#39;', "'")
      .replaceAll('&amp;', '&');
}
