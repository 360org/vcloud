import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/api/odoo_api_client.dart';
import '../../../../core/utils/date_format.dart';
import '../../domain/models/chat_v2_poll_model.dart';

@immutable
class ChatV2Member {
  final String id;
  final String name;
  final String? email;
  final String? avatarUrl;
  final String imStatus;
  final bool isMe;

  const ChatV2Member({
    required this.id,
    required this.name,
    this.email,
    this.avatarUrl,
    this.imStatus = 'offline',
    this.isMe = false,
  });

  factory ChatV2Member.fromJson(dynamic json) {
    if (json is Map) {
      final id = json['id']?.toString() ?? '';
      final rawAvatar = json['avatar_url']?.toString() ??
          json['avatar_128_url']?.toString() ??
          json['avatar_128']?.toString() ??
          json['image_128']?.toString();
      final avatarUrl = odooApiClient.resolveAvatarUrl(rawAvatar);
      return ChatV2Member(
        id: id,
        name: json['name']?.toString() ?? '',
        email: json['email']?.toString(),
        avatarUrl: avatarUrl,
        imStatus: json['im_status']?.toString() ?? 'offline',
        isMe: json['is_me'] == true,
      );
    }
    return ChatV2Member(
      id: '',
      name: json?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'avatar_url': avatarUrl,
    'im_status': imStatus,
    'is_me': isMe,
  };
}

@immutable
class ChatV2Channel {
  final String id;
  final String name;
  final String channelType;
  final bool isGroup;
  final String? avatarUrl;
  final String? lastMessage;
  final DateTime? lastMessageDate;
  final int unreadCount;
  final int memberCount;
  final List<ChatV2Member> members;
  final List<String> memberNames;
  final String imStatus;
  final String? lastMessageAuthorName;
  final String? lastMessageAuthorId;
  final String? partnerId;
  final String? directPartnerId;
  final String? directPartnerName;
  final String? directPartnerStatus;

  const ChatV2Channel({
    required this.id,
    required this.name,
    this.channelType = 'chat',
    this.isGroup = false,
    this.avatarUrl,
    this.lastMessage,
    this.lastMessageDate,
    this.unreadCount = 0,
    this.memberCount = 0,
    this.members = const [],
    this.memberNames = const [],
    this.imStatus = 'offline',
    this.lastMessageAuthorName,
    this.lastMessageAuthorId,
    this.partnerId,
    this.directPartnerId,
    this.directPartnerName,
    this.directPartnerStatus,
  });

  ChatV2Channel copyWith({
    String? id,
    String? name,
    String? channelType,
    bool? isGroup,
    String? avatarUrl,
    String? lastMessage,
    DateTime? lastMessageDate,
    int? unreadCount,
    int? memberCount,
    List<ChatV2Member>? members,
    List<String>? memberNames,
    String? imStatus,
    String? lastMessageAuthorName,
    String? lastMessageAuthorId,
    String? partnerId,
    String? directPartnerId,
    String? directPartnerName,
    String? directPartnerStatus,
  }) {
    return ChatV2Channel(
      id: id ?? this.id,
      name: name ?? this.name,
      channelType: channelType ?? this.channelType,
      isGroup: isGroup ?? this.isGroup,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageDate: lastMessageDate ?? this.lastMessageDate,
      unreadCount: unreadCount ?? this.unreadCount,
      memberCount: memberCount ?? this.memberCount,
      members: members ?? this.members,
      memberNames: memberNames ?? this.memberNames,
      imStatus: imStatus ?? this.imStatus,
      lastMessageAuthorName: lastMessageAuthorName ?? this.lastMessageAuthorName,
      lastMessageAuthorId: lastMessageAuthorId ?? this.lastMessageAuthorId,
      partnerId: partnerId ?? this.partnerId,
      directPartnerId: directPartnerId ?? this.directPartnerId,
      directPartnerName: directPartnerName ?? this.directPartnerName,
      directPartnerStatus: directPartnerStatus ?? this.directPartnerStatus,
    );
  }

  bool isLastMessageFromMe({
    String? currentUserId,
    String? currentPartnerId,
    String? currentUserName,
  }) {
    if (lastMessageAuthorId != null) {
      if (currentPartnerId != null && lastMessageAuthorId == currentPartnerId) return true;
      if (currentUserId != null && lastMessageAuthorId == currentUserId) return true;
    }
    if (lastMessageAuthorName != null) {
      final aLower = lastMessageAuthorName!.trim().toLowerCase();
      if (aLower == 'tôi' || aLower == 'bạn' || aLower == 'me') return true;
      if (currentUserName != null && currentUserName.trim().isNotEmpty) {
        final uLower = currentUserName.trim().toLowerCase();
        if (aLower == uLower || aLower.contains(uLower) || uLower.contains(aLower)) return true;
      }
    }
    return false;
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'channel_type': channelType,
    'is_group': isGroup,
    'avatar_url': avatarUrl,
    'last_message': lastMessage,
    'last_message_date': lastMessageDate?.toIso8601String(),
    'unread_count': unreadCount,
    'member_count': memberCount,
    'members': members.map((m) => m.toJson()).toList(),
    'member_names': memberNames,
    'im_status': imStatus,
    'last_message_author_name': lastMessageAuthorName,
    'last_message_author_id': lastMessageAuthorId,
    'partner_id': partnerId,
  };

  static bool _matchesUser(String part, String? currentUserName) {
    if (currentUserName == null || currentUserName.isEmpty) return false;
    final pLower = part.trim().toLowerCase();
    final uLower = currentUserName.trim().toLowerCase();
    if (pLower.isEmpty || uLower.isEmpty) return false;
    return pLower == uLower || uLower.contains(pLower) || pLower.contains(uLower);
  }

  /// Lấy tên hiển thị sạch: Nếu là chat 1-1 chứa tên người dùng thì chỉ lấy tên của người đối diện
  String getCleanName(String? currentUserName) {
    if (name.isEmpty) return 'Cuộc trò chuyện';
    if (currentUserName == null || currentUserName.trim().isEmpty) return name;

    if (!isGroup) {
      if (directPartnerName != null && directPartnerName!.isNotEmpty) {
        return directPartnerName!;
      }
      final uTrim = currentUserName.trim();
      final uLower = uTrim.toLowerCase();
      final nLower = name.toLowerCase();

      if (nLower.contains(uLower)) {
        var clean = name;
        final patterns = [
          RegExp('^\\s*${RegExp.escape(uTrim)}\\s*[,/|-]\\s*', caseSensitive: false),
          RegExp('\\s*[,/|-]\\s*${RegExp.escape(uTrim)}\\s*\$', caseSensitive: false),
          RegExp('^\\s*${RegExp.escape(uTrim)}\\s+(\\bvà\\b|&)\\s*', caseSensitive: false),
          RegExp('\\s+(\\bvà\\b|&)\\s*${RegExp.escape(uTrim)}\\s*\$', caseSensitive: false),
        ];
        for (final p in patterns) {
          if (p.hasMatch(clean)) {
            clean = clean.replaceFirst(p, '').trim();
            break;
          }
        }
        if (clean.isNotEmpty && clean.toLowerCase() != uLower) {
          return clean;
        }
      }

      final parts = name.split(RegExp(r'\s*[,/|-]\s*|\s+và\s+|\s+&\s+'));
      if (parts.length >= 2) {
        final otherParts = parts.where((p) => !_matchesUser(p, currentUserName)).toList();
        if (otherParts.isNotEmpty) {
          return otherParts.join(', ').trim();
        }
      }
    }
    return name;
  }

  bool getActualIsGroup(String? currentUserName) {
    // 0. Ưu tiên cao nhất: channelType == 'chat' hoặc 'direct' là cá nhân
    if (channelType == 'chat' || channelType == 'direct') return false;

    // 1. Nếu có trên 2 thành viên -> Chắc chắn là Nhóm
    if (memberCount > 2) return true;
    if (members.length > 2) return true;

    // 2. Nếu là loại nhóm tường minh (channel_type == 'group')
    if (channelType == 'group') return true;

    // 3. Nếu tên chứa danh sách >= 3 người (VD: "A, B, C")
    final clean = getCleanName(currentUserName);
    final count = clean.split(RegExp(r'\s*[,/|-]\s*|\s+và\s+|\s+&\s+')).length;
    if (count > 2) return true;

    // 4. Nếu có partnerId / directPartner / chat type -> 1-1 Cá nhân
    if (directPartnerId != null && directPartnerId!.isNotEmpty) return false;
    if (directPartnerName != null && directPartnerName!.isNotEmpty) return false;
    if (partnerId != null && partnerId!.isNotEmpty) return false;

    // 5. Nếu memberCount là 1 hoặc 2 -> 1-1 Cá nhân
    if (memberCount == 1 || memberCount == 2) return false;
    if (members.length == 1 || members.length == 2) return false;

    // 6. Nếu được đánh dấu isGroup = true
    if (isGroup) return true;

    // 7. Mặc định là cá nhân 1-1
    return false;
  }

  /// Kiểm tra có phải kênh thảo luận Odoo (channel) hay không
  bool get isChannel => channelType == 'channel';

  /// Kiểm tra có phải hội thoại 1-1 nội bộ giữa 2 người hay không (loại trừ nhóm và kênh)
  bool isInternalDirect(String? currentUserName) {
    if (channelType == 'channel') return false;
    return !getActualIsGroup(currentUserName);
  }

  /// Kiểm tra có phải nhóm trò chuyện nhiều người hay không (loại trừ kênh chung)
  bool isGroupChat(String? currentUserName) {
    if (channelType == 'channel') return false;
    return getActualIsGroup(currentUserName);
  }

  factory ChatV2Channel.fromMap(Map<String, dynamic> map) => ChatV2Channel.fromJson(map);

  factory ChatV2Channel.fromJson(dynamic raw) {
    if (raw is! Map) {
      return ChatV2Channel(id: raw?.toString() ?? '', name: 'Cuộc trò chuyện');
    }
    final map = raw;

    final id = _stringOr(map['id'] ?? map['channel_id'], '');
    final name = _stringOr(map['name'] ?? map['display_name'], 'Cuộc trò chuyện');
    final channelType = _stringOr(map['channel_type'] ?? map['type'], 'chat');
    final rawIsGroup = map['is_group'];
    final bool isGroup;
    if (rawIsGroup is bool) {
      isGroup = rawIsGroup;
    } else {
      isGroup = channelType == 'group';
    }

    final rawAvatar = _stringOrNull(
      map['avatar_url'] ??
          map['channel_avatar_url'] ??
          map['avatar_128_url'] ??
          map['avatar_128'] ??
          map['image_128'] ??
          map['avatar'],
    );
    final avatarUrl = odooApiClient.resolveAvatarUrl(rawAvatar);
    final imStatus = _stringOr(map['im_status'] ?? map['user_status'], 'offline');

    // Parse last message
    final rawLastMsg = map['last_message'];
    String? lastMsgText;
    if (rawLastMsg is Map) {
      lastMsgText = _stringOrNull(rawLastMsg['body'] ?? rawLastMsg['content']);
    } else if (rawLastMsg is String) {
      lastMsgText = rawLastMsg;
    } else {
      lastMsgText = _stringOrNull(map['last_message_body'] ?? map['description']);
    }

    // Clean HTML & filenames in last message preview
    if (lastMsgText != null) {
      lastMsgText = _cleanLastMessageText(lastMsgText);
    }

    // Parse date
    final date = Dates.parseOdooUtc(map['last_message_date'] ??
        map['updated_at'] ??
        map['last_activity'] ??
        map['write_date'] ??
        (rawLastMsg is Map ? rawLastMsg['date'] : null));

    // Parse unread count
    final unread = _intOr(
        map['unread_count'] ??
            map['message_unread_counter'] ??
            map['message_needaction_counter'] ??
            map['unread_messages'],
        0);

    // Parse members
    final memberObjs = <ChatV2Member>[];
    final memberNamesList = <String>[];
    final rawMembers = map['members'] ?? map['channel_members'];
    if (rawMembers is List) {
      for (final m in rawMembers) {
        if (m is Map) {
          final mem = ChatV2Member.fromJson(m);
          if (mem.name.isNotEmpty) {
            memberObjs.add(mem);
            memberNamesList.add(mem.name);
          }
        } else if (m is String && m.isNotEmpty) {
          memberObjs.add(ChatV2Member(id: '', name: m));
          memberNamesList.add(m);
        }
      }
    }

    // Parse author of last message
    String? authorName;
    String? authorId;
    if (rawLastMsg is Map) {
      authorName = _stringOrNull(rawLastMsg['author_name'] ?? rawLastMsg['author']);
      authorId = _stringOrNull(rawLastMsg['author_id']);
    } else {
      authorName = _stringOrNull(map['last_message_author_name'] ?? map['last_message_author']);
      authorId = _stringOrNull(map['last_message_author_id'] ?? map['author_id']);
    }

    // Parse member count
    final rawMemberCount = map['member_count'] ?? map['members_count'];
    final parsedMemberCount = _intOr(
      rawMemberCount,
      memberObjs.isNotEmpty ? memberObjs.length : (isGroup ? 2 : 1),
    );

    final rawDirectPartner = map['direct_partner'];
    String? directPartnerId;
    String? directPartnerName;
    String? directPartnerStatus;
    String? directPartnerAvatar;
    if (rawDirectPartner is Map) {
      directPartnerId = _stringOrNull(rawDirectPartner['id']);
      directPartnerName = _stringOrNull(rawDirectPartner['name']);
      directPartnerStatus = _stringOrNull(rawDirectPartner['im_status']);
      directPartnerAvatar = odooApiClient.resolveAvatarUrl(
        _stringOrNull(rawDirectPartner['avatar_url'] ?? rawDirectPartner['image_128']),
      );
    }
    directPartnerId ??= _stringOrNull(map['partner_id'] ?? map['other_partner_id']);
    directPartnerStatus ??= imStatus;

    String? finalAvatarUrl = avatarUrl;
    if (finalAvatarUrl == null && !isGroup) {
      if (directPartnerAvatar != null && directPartnerAvatar.isNotEmpty) {
        finalAvatarUrl = directPartnerAvatar;
      } else if (memberObjs.isNotEmpty) {
        final otherMember = memberObjs.firstWhereOrNull(
          (m) => !m.isMe && m.avatarUrl != null && m.avatarUrl!.isNotEmpty,
        );
        if (otherMember != null) {
          finalAvatarUrl = otherMember.avatarUrl;
        }
      }
    }

    return ChatV2Channel(
      id: id,
      name: name,
      channelType: channelType,
      isGroup: isGroup,
      avatarUrl: finalAvatarUrl,
      lastMessage: lastMsgText,
      lastMessageDate: date,
      unreadCount: unread,
      memberCount: parsedMemberCount,
      members: memberObjs,
      memberNames: memberNamesList,
      imStatus: imStatus,
      lastMessageAuthorName: authorName,
      lastMessageAuthorId: authorId,
      partnerId: directPartnerId,
      directPartnerId: directPartnerId,
      directPartnerName: directPartnerName,
      directPartnerStatus: directPartnerStatus,
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

  static int _intOr(dynamic val, int fallback) {
    if (val == null || val == false) return fallback;
    if (val is int) return val;
    if (val is num) return val.toInt();
    return int.tryParse(val.toString()) ?? fallback;
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

  static String? _cleanLastMessageText(String? raw) {
    if (raw == null) return null;
    final poll = ChatV2Poll.tryParseFromBody(raw);
    if (poll != null) {
      return '📊 [Bình chọn] ${poll.question}';
    }
    final cleaned = _stripHtml(raw).trim();
    if (cleaned.isEmpty) return null;
    final lower = cleaned.toLowerCase();
    if (lower.contains('"id":"poll_') || lower.contains('"id": "poll_')) {
      final qMatch = RegExp(r'"question":\s*"([^"]+)"').firstMatch(cleaned);
      final qTitle = qMatch?.group(1) ?? 'Bình chọn';
      return '📊 [Bình chọn] $qTitle';
    }
    final isImg = lower.endsWith('.png') ||
        lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.svg') ||
        lower.endsWith('.bmp') ||
        lower.endsWith('.ico') ||
        lower.endsWith('.heic') ||
        lower.endsWith('.heif') ||
        lower.startsWith('scaled_') ||
        lower.startsWith('image_picker_');
    if (isImg) {
      return '[Hình ảnh]';
    }
    final isDoc = lower.endsWith('.docx') ||
        lower.endsWith('.pdf') ||
        lower.endsWith('.xlsx') ||
        lower.endsWith('.xls') ||
        lower.endsWith('.doc') ||
        lower.endsWith('.zip') ||
        lower.endsWith('.txt');
    if (isDoc && !cleaned.startsWith('[Tập tin]') && !cleaned.startsWith('[Tài liệu]')) {
      return '[Tập tin]';
    }
    return cleaned;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChatV2Channel &&
        other.id == id &&
        other.name == name &&
        other.channelType == channelType &&
        other.isGroup == isGroup &&
        other.avatarUrl == avatarUrl &&
        other.lastMessage == lastMessage &&
        other.lastMessageDate == lastMessageDate &&
        other.unreadCount == unreadCount &&
        other.memberCount == memberCount &&
        const ListEquality().equals(other.memberNames, memberNames) &&
        other.imStatus == imStatus &&
        other.lastMessageAuthorName == lastMessageAuthorName &&
        other.lastMessageAuthorId == lastMessageAuthorId &&
        other.partnerId == partnerId &&
        other.directPartnerId == directPartnerId &&
        other.directPartnerName == directPartnerName &&
        other.directPartnerStatus == directPartnerStatus;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      name,
      channelType,
      isGroup,
      avatarUrl,
      lastMessage,
      lastMessageDate,
      unreadCount,
      memberCount,
      const ListEquality().hash(memberNames),
      imStatus,
      lastMessageAuthorName,
      lastMessageAuthorId,
      partnerId,
      directPartnerId,
      directPartnerName,
      directPartnerStatus,
    );
  }
}
