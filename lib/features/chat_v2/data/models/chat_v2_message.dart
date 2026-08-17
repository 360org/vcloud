import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/utils/date_format.dart';

@immutable
class ChatV2Attachment {
  final String id;
  final String name;
  final String? mimetype;
  final int? fileSize;
  final String? url;
  final String? downloadUrl;
  final String? accessToken;
  final Uint8List? bytes;

  const ChatV2Attachment({
    required this.id,
    required this.name,
    this.mimetype,
    this.fileSize,
    this.url,
    this.downloadUrl,
    this.accessToken,
    this.bytes,
  });

  bool get isImage {
    final mime = mimetype?.toLowerCase() ?? '';
    if (mime.startsWith('image/')) return true;
    final lowerName = name.toLowerCase();
    return lowerName.endsWith('.png') ||
        lowerName.endsWith('.jpg') ||
        lowerName.endsWith('.jpeg') ||
        lowerName.endsWith('.webp') ||
        lowerName.endsWith('.gif') ||
        lowerName.endsWith('.svg') ||
        lowerName.endsWith('.bmp') ||
        lowerName.endsWith('.ico') ||
        lowerName.endsWith('.heic') ||
        lowerName.endsWith('.heif') ||
        lowerName.endsWith('.tiff');
  }

  String get extension {
    final idx = name.lastIndexOf('.');
    if (idx != -1 && idx < name.length - 1) {
      return name.substring(idx + 1).toLowerCase();
    }
    return '';
  }

  String resolveFullUrl(String baseUrl) {
    final cleanBase = baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
    if (id.isNotEmpty && isImage) {
      return '$cleanBase/api/v1/mobile/attachments/$id/image';
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

  ChatV2Attachment copyWith({
    String? id,
    String? name,
    String? mimetype,
    int? fileSize,
    String? url,
    String? downloadUrl,
    String? accessToken,
    Uint8List? bytes,
  }) {
    return ChatV2Attachment(
      id: id ?? this.id,
      name: name ?? this.name,
      mimetype: mimetype ?? this.mimetype,
      fileSize: fileSize ?? this.fileSize,
      url: url ?? this.url,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      accessToken: accessToken ?? this.accessToken,
      bytes: bytes ?? this.bytes,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      if (mimetype != null) 'mimetype': mimetype,
      if (fileSize != null) 'file_size': fileSize,
      if (url != null) 'url': url,
      if (downloadUrl != null) 'download_url': downloadUrl,
      if (accessToken != null) 'access_token': accessToken,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChatV2Attachment &&
        other.id == id &&
        other.name == name &&
        other.mimetype == mimetype &&
        other.fileSize == fileSize &&
        other.url == url &&
        other.downloadUrl == downloadUrl &&
        other.accessToken == accessToken;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      name,
      mimetype,
      fileSize,
      url,
      downloadUrl,
      accessToken,
    );
  }
}

/// Model tin nhắn trò chuyện V2
class ChatV2Message {
  const ChatV2Message({
    required this.id,
    required this.channelId,
    required this.content,
    this.authorId,
    this.authorName = 'Người dùng',
    this.authorAvatar,
    this.createdAt,
    this.isMine = false,
    this.status = 'sent',
    this.attachments = const [],
    this.parentId,
    this.parentBody,
    this.parentAuthorName,
  });

  final String id;
  final String channelId;
  final String content;
  final String? authorId;
  final String authorName;
  final String? authorAvatar;
  final DateTime? createdAt;
  final bool isMine;
  final String status;
  final List<ChatV2Attachment> attachments;
  final String? parentId;
  final String? parentBody;
  final String? parentAuthorName;

  bool get hasImageAttachment => attachments.any((a) => a.isImage);

  bool get isImageFilename {
    final clean = content.trim().toLowerCase();
    return clean.endsWith('.png') ||
        clean.endsWith('.jpg') ||
        clean.endsWith('.jpeg') ||
        clean.endsWith('.gif') ||
        clean.endsWith('.webp') ||
        clean.endsWith('.svg') ||
        clean.endsWith('.bmp') ||
        clean.endsWith('.ico') ||
        clean.endsWith('.heic') ||
        clean.endsWith('.heif') ||
        clean.endsWith('.tiff') ||
        clean.startsWith('scaled_') ||
        clean.startsWith('image_picker_');
  }

  bool get isDocumentFilename {
    final clean = content.trim().toLowerCase();
    return clean.endsWith('.pdf') ||
        clean.endsWith('.doc') ||
        clean.endsWith('.docx') ||
        clean.endsWith('.xls') ||
        clean.endsWith('.xlsx') ||
        clean.endsWith('.ppt') ||
        clean.endsWith('.pptx') ||
        clean.endsWith('.txt') ||
        clean.endsWith('.zip') ||
        clean.startsWith('báo giá') ||
        clean.startsWith('baocao_') ||
        clean.startsWith('hopdong_');
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
    List<ChatV2Attachment>? attachments,
    String? parentId,
    String? parentBody,
    String? parentAuthorName,
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
      attachments: attachments ?? this.attachments,
      parentId: parentId ?? this.parentId,
      parentBody: parentBody ?? this.parentBody,
      parentAuthorName: parentAuthorName ?? this.parentAuthorName,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'channel_id': channelId,
    'body': content,
    'author_id': authorId,
    'author_name': authorName,
    'author_avatar': authorAvatar,
    'date': createdAt?.toIso8601String(),
    'is_mine': isMine,
    'status': status,
    'attachments': attachments.map((a) => a.toMap()).toList(),
    'parent_id': parentId,
    'parent_body': parentBody,
    'parent_author_name': parentAuthorName,
  };

  factory ChatV2Message.fromMap(
    Map<String, dynamic> map, {
    String? currentPartnerId,
    String? currentUserId,
  }) {
    final id = _stringOr(map['id'], '');
    final channelId = _stringOr(map['channel_id'] ?? map['record_id'], '');

    // Parse content / body (clean HTML)
    final String rawBody = _stringOr(map['body'] ?? map['content'] ?? map['text'], '');

    // Parse author
    String? authorId;
    String authorName = 'Người dùng';
    final rawAuthor = map['author_id'];
    if (rawAuthor is Map) {
      authorId = _stringOrNull(rawAuthor['id']);
      authorName = _stringOr(rawAuthor['name'], 'Người dùng');
    } else if (rawAuthor != null && rawAuthor != false) {
      authorId = rawAuthor.toString();
      authorName = _stringOr(map['author_name'] ?? map['author'], 'Người dùng');
    } else {
      authorName = _stringOr(map['author_name'] ?? map['author'], 'Người dùng');
    }

    // Parse date
    final createdAt = Dates.parseOdooUtc(map['date'] ?? map['created_at'] ?? map['create_date']);

    // Determine isMine
    bool isMine = false;
    if (map['is_mine'] == true) {
      isMine = true;
    } else if (authorId != null) {
      if (currentPartnerId != null && authorId == currentPartnerId) {
        isMine = true;
      } else if (currentUserId != null && authorId == currentUserId) {
        isMine = true;
      }
    }

    final cleanContent = _cleanHtml(rawBody);

    // Parse attachments
    final parsedAttachments = <ChatV2Attachment>[];
    final rawAtts = map['attachments'];
    if (rawAtts is List) {
      for (final a in rawAtts) {
        if (a is Map) {
          parsedAttachments.add(ChatV2Attachment.fromMap(Map<String, dynamic>.from(a)));
        }
      }
    }

    // Fallback: nếu attachments rỗng nhưng có attachment_ids
    if (parsedAttachments.isEmpty && map['attachment_ids'] is List) {
      final attIds = map['attachment_ids'] as List;
      final clean = cleanContent.toLowerCase();
      final isImgName = clean.endsWith('.png') ||
          clean.endsWith('.jpg') ||
          clean.endsWith('.jpeg') ||
          clean.endsWith('.webp') ||
          clean.endsWith('.gif') ||
          clean.endsWith('.svg') ||
          clean.startsWith('scaled_');

      for (final aid in attIds) {
        if (aid != null) {
          final sId = aid.toString();
          parsedAttachments.add(
            ChatV2Attachment(
              id: sId,
              name: cleanContent.isNotEmpty ? cleanContent : 'Đính kèm $sId',
              url: isImgName ? '/web/image/$sId' : '/web/content/$sId',
              downloadUrl: '/web/content/$sId',
              mimetype: isImgName ? 'image/png' : 'application/octet-stream',
            ),
          );
        }
      }
    }

    // Extract embedded image URLs from HTML body if any
    final imgRegex = RegExp(r'<img[^>]+src=["' "'" r']([^"' "'" r']+)["' "'" r']', caseSensitive: false);
    final imgMatches = imgRegex.allMatches(rawBody);
    for (final match in imgMatches) {
      final src = match.group(1);
      if (src != null && src.isNotEmpty && !parsedAttachments.any((a) => a.url == src)) {
        parsedAttachments.add(
          ChatV2Attachment(
            id: '',
            name: 'Hình ảnh',
            url: src,
            mimetype: 'image/png',
          ),
        );
      }
    }

    final rawParentBody = _stringOrNull(map['parent_body']);
    final cleanParentBody = (rawParentBody != null && rawParentBody.isNotEmpty)
        ? _cleanHtml(rawParentBody)
        : null;

    return ChatV2Message(
      id: id,
      channelId: channelId,
      content: cleanContent,
      authorId: authorId,
      authorName: authorName,
      createdAt: createdAt,
      isMine: isMine,
      status: _stringOr(map['status'], 'sent'),
      attachments: parsedAttachments,
      parentId: _stringOrNull(map['parent_id']),
      parentBody: cleanParentBody,
      parentAuthorName: _stringOrNull(map['parent_author_name']),
    );
  }

  static String _cleanHtml(String html) {
    if (html.isEmpty) return '';
    var text = html;
    for (var i = 0; i < 3; i++) {
      text = text
          .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
          .replaceAll(RegExp(r'</p>', caseSensitive: false), '\n')
          .replaceAll(RegExp(r'<[^>]*>'), '')
          .replaceAll('&nbsp;', ' ')
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>')
          .replaceAll('&amp;', '&')
          .replaceAll('&quot;', '"')
          .replaceAll('&#39;', "'")
          .trim();
    }
    return text;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChatV2Message &&
        other.id == id &&
        other.channelId == channelId &&
        other.content == content &&
        other.authorId == authorId &&
        other.authorName == authorName &&
        other.createdAt == createdAt &&
        other.isMine == isMine &&
        other.status == status &&
        const ListEquality().equals(other.attachments, attachments) &&
        other.parentId == parentId &&
        other.parentBody == parentBody &&
        other.parentAuthorName == parentAuthorName;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      channelId,
      content,
      authorId,
      authorName,
      createdAt,
      isMine,
      status,
      const ListEquality().hash(attachments),
      parentId,
      parentBody,
      parentAuthorName,
    );
  }
}

String _stringOr(dynamic val, String fallback) {
  if (val == null || val == false) return fallback;
  return val.toString();
}

String? _stringOrNull(dynamic val) {
  if (val == null || val == false) return null;
  final str = val.toString().trim();
  return str.isEmpty ? null : str;
}
