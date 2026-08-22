import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/api/odoo_api_client.dart';
import '../../../../core/utils/date_format.dart';
import '../../domain/models/chat_v2_poll_model.dart';
import 'chat_v2_reaction.dart';

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

  bool get isAudio {
    final mime = mimetype?.toLowerCase() ?? '';
    if (mime.startsWith('audio/')) return true;
    final lowerName = name.toLowerCase();
    return lowerName.endsWith('.m4a') ||
        lowerName.endsWith('.aac') ||
        lowerName.endsWith('.mp3') ||
        lowerName.endsWith('.wav') ||
        lowerName.endsWith('.ogg') ||
        lowerName.endsWith('.webm') ||
        lowerName.endsWith('.opus');
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
    this.rawBody,
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
    this.reactions = const [],
  });

  final String id;
  final String channelId;
  final String content;
  final String? rawBody;
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
  final List<ChatV2Reaction> reactions;

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

  bool get isPollMessage => poll != null;

  ChatV2Poll? get poll => ChatV2Poll.tryParseFromBody(rawBody ?? content);

  static final _locationRegex = RegExp(
    r'(?:https?:\/\/)?(?:www\.)?(?:maps\.google\.com\/(?:\?q=|maps\?q=)|maps\.apple\.com\/(?:\?q=|maps\?q=)|google\.com\/maps\?q=|openstreetmap\.org\/\?mlat=)(-?\d+\.?\d*)[,\/](-?\d+\.?\d*)',
    caseSensitive: false,
  );

  bool get isLocationMessage {
    final text = (rawBody ?? content).trim();
    if (text.isEmpty) return false;
    return text.contains('maps.google.com') ||
        text.contains('maps.apple.com') ||
        text.contains('google.com/maps') ||
        text.contains('openstreetmap.org') ||
        (text.contains('📍') && _locationRegex.hasMatch(text));
  }

  ({double lat, double lng, String mapUrl})? get locationCoordinates {
    final text = (rawBody ?? content).trim();
    final match = _locationRegex.firstMatch(text);
    if (match != null && match.groupCount >= 2) {
      final latStr = match.group(1);
      final lngStr = match.group(2);
      if (latStr != null && lngStr != null) {
        final lat = double.tryParse(latStr);
        final lng = double.tryParse(lngStr);
        if (lat != null && lng != null) {
          return (
            lat: lat,
            lng: lng,
            mapUrl: 'https://maps.google.com/?q=$lat,$lng',
          );
        }
      }
    }
    return null;
  }

  ChatV2Message copyWith({
    String? id,
    String? channelId,
    String? content,
    String? rawBody,
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
    List<ChatV2Reaction>? reactions,
  }) {
    return ChatV2Message(
      id: id ?? this.id,
      channelId: channelId ?? this.channelId,
      content: content ?? this.content,
      rawBody: rawBody ?? this.rawBody,
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
      reactions: reactions ?? this.reactions,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'channel_id': channelId,
    'body': rawBody ?? content,
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
    'reactions': reactions.map((r) => r.toJson()).toList(),
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

    // Parse Reply Quote từ rawBody nếu có (format <blockquote... hoặc &lt;blockquote...)
    String? extractedParentId = _stringOrNull(map['parent_id']);
    String? extractedParentAuthor = _stringOrNull(map['parent_author_name']);
    String? extractedParentBody = _stringOrNull(map['parent_body']);

    // Tự động unescape rawBody để nhận diện blockquote dù bị Odoo backend escape HTML
    final unescapedBody = rawBody
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&amp;', '&');

    String bodyWithoutQuote = unescapedBody;
    if (bodyWithoutQuote.contains('class="o_poll_json"') || bodyWithoutQuote.contains("class='o_poll_json'")) {
      bodyWithoutQuote = bodyWithoutQuote.replaceAll(
        RegExp(r'<div[^>]*class=[\x27"]o_poll_json[\x27"][^>]*>.*?<\/div>', caseSensitive: false, dotAll: true),
        '',
      );
    }
    if (unescapedBody.contains('data-reply-') || unescapedBody.contains('<blockquote') || unescapedBody.contains('o_quote')) {
      // 1. Nhận diện <div data-reply-...>...</div>
      final divRegex = RegExp(r'<div([^>]*data-reply-[^>]*)>(.*?)<\/div>', caseSensitive: false, dotAll: true);
      final divMatch = divRegex.firstMatch(unescapedBody);
      if (divMatch != null) {
        final attrs = divMatch.group(1) ?? '';
        final idMatch = RegExp('data-reply-id="([^"]+)"').firstMatch(attrs) ??
            RegExp("data-reply-id='([^']+)'").firstMatch(attrs);
        final authorMatch = RegExp('data-reply-author="([^"]+)"').firstMatch(attrs) ??
            RegExp("data-reply-author='([^']+)'").firstMatch(attrs);
        final bodyMatch = RegExp('data-reply-body="([^"]+)"').firstMatch(attrs) ??
            RegExp("data-reply-body='([^']+)'").firstMatch(attrs);

        extractedParentId ??= idMatch?.group(1);
        extractedParentAuthor ??= authorMatch?.group(1);
        extractedParentBody ??= bodyMatch?.group(1);

        bodyWithoutQuote = unescapedBody.replaceFirst(divMatch.group(0)!, '').trim();
      }

      // 2. Nhận diện <blockquote...>...</blockquote>
      final bqRegex = RegExp(r'<blockquote([^>]*)>(.*?)<\/blockquote>', caseSensitive: false, dotAll: true);
      final bqMatch = bqRegex.firstMatch(bodyWithoutQuote);
      if (bqMatch != null) {
        final bqAttrs = bqMatch.group(1) ?? '';
        final bqInner = bqMatch.group(2) ?? '';

        final idMatch = RegExp('data-reply-id="([^"]+)"').firstMatch(bqAttrs) ??
            RegExp("data-reply-id='([^']+)'").firstMatch(bqAttrs);
        final authorMatch = RegExp('data-reply-author="([^"]+)"').firstMatch(bqAttrs) ??
            RegExp("data-reply-author='([^']+)'").firstMatch(bqAttrs);
        final bodyMatch = RegExp('data-reply-body="([^"]+)"').firstMatch(bqAttrs) ??
            RegExp("data-reply-body='([^']+)'").firstMatch(bqAttrs);

        extractedParentId ??= idMatch?.group(1);
        extractedParentAuthor ??= authorMatch?.group(1);
        extractedParentBody ??= bodyMatch?.group(1);

        if (extractedParentBody == null || extractedParentBody.isEmpty) {
          final cleanInner = _cleanHtml(bqInner);
          if (cleanInner.isNotEmpty) {
            extractedParentBody = cleanInner;
            extractedParentId ??= 'quote';
          }
        }

        bodyWithoutQuote = bodyWithoutQuote.replaceFirst(bqMatch.group(0)!, '').trim();
      }
    }

    final cleanContent = _cleanHtml(bodyWithoutQuote);

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
          clean.endsWith('.heic') ||
          clean.endsWith('.heif') ||
          clean.endsWith('.bmp') ||
          clean.startsWith('scaled_') ||
          clean.startsWith('image_picker_');

      for (final aid in attIds) {
        if (aid != null) {
          final sId = aid.toString();
          parsedAttachments.add(
            ChatV2Attachment(
              id: sId,
              name: cleanContent.isNotEmpty ? cleanContent : (isImgName ? 'image_$sId.jpg' : 'attachment_$sId'),
              url: '/api/v1/mobile/attachments/$sId/download',
              downloadUrl: '/api/v1/mobile/attachments/$sId/download',
              mimetype: isImgName ? 'image/jpeg' : 'application/octet-stream',
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

    final cleanParentBody = (extractedParentBody != null && extractedParentBody.isNotEmpty)
        ? _cleanHtml(extractedParentBody)
        : null;

    final parsedReactions = <ChatV2Reaction>[];
    final rawReacts = map['reactions'];
    if (rawReacts is List) {
      for (final r in rawReacts) {
        if (r is Map) {
          parsedReactions.add(ChatV2Reaction.fromJson(Map<String, dynamic>.from(r)));
        }
      }
    }

    final rawAuthorAvatar = _stringOrNull(
      map['author_avatar'] ??
          map['avatar_url'] ??
          map['avatar_128_url'] ??
          map['avatar_128'] ??
          map['image_128'],
    );
    final authorAvatar = odooApiClient.resolveAvatarUrl(rawAuthorAvatar) ??
        (authorId != null && authorId.isNotEmpty
            ? odooApiClient.resolveAvatarUrl('/api/v1/mobile/avatar/res.partner/$authorId')
            : null);

    return ChatV2Message(
      id: id,
      channelId: channelId,
      content: cleanContent,
      rawBody: rawBody,
      authorId: authorId,
      authorName: authorName,
      authorAvatar: authorAvatar,
      createdAt: createdAt,
      isMine: isMine,
      status: _stringOr(map['status'], 'sent'),
      attachments: parsedAttachments,
      parentId: extractedParentId,
      parentBody: cleanParentBody,
      parentAuthorName: extractedParentAuthor,
      reactions: parsedReactions,
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
        other.parentAuthorName == parentAuthorName &&
        const ListEquality().equals(other.reactions, reactions);
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
      const ListEquality().hash(reactions),
    );
  }
}

String _stringOr(dynamic val, String fallback) {
  if (val == null || val == false) return fallback;
  return val.toString();
}

String? _stringOrNull(dynamic val) {
  if (val == null || val == false) return null;
  if (val is List && val.isNotEmpty) {
    return val[0]?.toString();
  }
  final str = val.toString().trim();
  return str.isEmpty ? null : str;
}

/// Bộ đệm bộ nhớ lưu trữ thông tin Reply (Trích dẫn tin nhắn)
/// Đảm bảo không bao giờ bị mất thẻ trích dẫn khi backend Odoo polling/SWR ghi đè
class ChatV2ReplyCache {
  static final Map<String, Map<String, String?>> _memoryCache = {};

  static void set(
    String messageId, {
    String? parentId,
    String? parentBody,
    String? parentAuthorName,
  }) {
    if (messageId.isEmpty) return;
    if (parentId == null && parentBody == null && parentAuthorName == null) return;
    _memoryCache[messageId] = {
      'parent_id': parentId,
      'parent_body': parentBody,
      'parent_author_name': parentAuthorName,
    };
  }

  static Map<String, String?>? get(String messageId) {
    return _memoryCache[messageId];
  }

  static void clear() {
    _memoryCache.clear();
  }
}

