import 'package:flutter/foundation.dart';

import '../../../../core/config/env.dart';
import '../../../../core/utils/date_format.dart';

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
    if (lastMessageAuthorName != null && currentUserName != null) {
      if (lastMessageAuthorName!.trim().toLowerCase() == currentUserName.trim().toLowerCase()) return true;
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
    'members': memberNames,
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

    final trimmedName = name.trim();
    final curName = currentUserName.trim();

    // 1. Kiểm tra nếu name bắt đầu bằng tên user: "Ma Nguyễn Nhật Tân, Chau, Le Ba" -> "Chau, Le Ba"
    final startPattern = RegExp('^${RegExp.escape(curName)}\\s*,\\s*', caseSensitive: false);
    if (startPattern.hasMatch(trimmedName)) {
      final clean = trimmedName.replaceFirst(startPattern, '').trim();
      if (clean.isNotEmpty) return clean;
    }

    // 2. Kiểm tra nếu name kết thúc bằng tên user: "Chau, Le Ba, Ma Nguyễn Nhật Tân" -> "Chau, Le Ba"
    final endPattern = RegExp('\\s*,\\s*${RegExp.escape(curName)}\$', caseSensitive: false);
    if (endPattern.hasMatch(trimmedName)) {
      final clean = trimmedName.replaceFirst(endPattern, '').trim();
      if (clean.isNotEmpty) return clean;
    }

    // 3. Fallback: Nếu tách theo dấu phẩy, tìm và loại bỏ phần trùng với user
    if (name.contains(',')) {
      final parts = name.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      final userIdx = parts.indexWhere((p) => _matchesUser(p, currentUserName));
      if (userIdx != -1 && parts.length > 1) {
        final otherParts = [...parts]..removeAt(userIdx);
        if (otherParts.isNotEmpty) {
          return otherParts.join(', ');
        }
      }
    }

    return name;
  }

  /// Xác định xem có thực sự là nhóm không (loại trừ các kênh 1-1 Odoo đặt tên "A, B")
  bool getActualIsGroup(String? currentUserName) {
    if (channelType == 'chat') return false;
    if (channelType == 'channel') return true;

    if (currentUserName != null && currentUserName.isNotEmpty) {
      final clean = getCleanName(currentUserName);
      if (clean != name && clean.isNotEmpty) {
        // Đã lọc bỏ được tên user hiện tại
        return false;
      }
    }
    return isGroup;
  }

  factory ChatV2Channel.fromMap(Map<String, dynamic> map) {
    final id = _stringOr(map['id'], '');
    final name = _stringOr(map['name'], 'Cuộc trò chuyện');
    final channelType = _stringOr(map['channel_type'], 'chat');
    final isGroup = _boolOr(map['is_group'], channelType == 'group' || channelType == 'channel');
    final rawAvatar = _stringOrNull(map['avatar_url'] ?? map['avatar_128'] ?? map['image_128']);
    String? avatarUrl;
    if (rawAvatar != null && rawAvatar.isNotEmpty) {
      if (rawAvatar.startsWith('http://') || rawAvatar.startsWith('https://')) {
        avatarUrl = rawAvatar;
      } else {
        final base = Env.odooApiBaseUrl.replaceAll(RegExp(r'/+$'), '');
        final path = rawAvatar.startsWith('/') ? rawAvatar : '/$rawAvatar';
        avatarUrl = '$base$path';
      }
    }
    final imStatus = _stringOr(map['im_status'], 'offline');

    // Parse last message
    String? lastMsgText;
    final rawLastMsg = map['last_message'];
    if (rawLastMsg is Map<String, dynamic>) {
      lastMsgText = _stringOrNull(rawLastMsg['body'] ?? rawLastMsg['content']);
    } else if (rawLastMsg is String) {
      lastMsgText = rawLastMsg;
    } else {
      lastMsgText = _stringOrNull(map['last_message_body'] ?? map['description']);
    }

    // Clean HTML in last message preview
    if (lastMsgText != null) {
      lastMsgText = _stripHtml(lastMsgText);
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

    // Parse member names
    final members = <String>[];
    final rawMembers = map['members'];
    if (rawMembers is List) {
      for (final m in rawMembers) {
        if (m is Map<String, dynamic>) {
          final mName = _stringOrNull(m['name']);
          if (mName != null && mName.isNotEmpty) members.add(mName);
        } else if (m is String && m.isNotEmpty) {
          members.add(m);
        }
      }
    }

    // Parse author of last message
    String? authorName;
    String? authorId;
    if (rawLastMsg is Map<String, dynamic>) {
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
      members.isNotEmpty ? members.length : (isGroup ? 2 : 1),
    );

    final rawDirectPartner = map['direct_partner'];
    String? directPartnerId;
    String? directPartnerName;
    String? directPartnerStatus;
    if (rawDirectPartner is Map) {
      directPartnerId = _stringOrNull(rawDirectPartner['id']);
      directPartnerName = _stringOrNull(rawDirectPartner['name']);
      directPartnerStatus = _stringOrNull(rawDirectPartner['im_status']);
    }
    directPartnerId ??= _stringOrNull(map['partner_id'] ?? map['other_partner_id']);
    directPartnerStatus ??= imStatus;

    return ChatV2Channel(
      id: id,
      name: name,
      channelType: channelType,
      isGroup: isGroup,
      avatarUrl: avatarUrl,
      lastMessage: lastMsgText,
      lastMessageDate: date,
      unreadCount: unread,
      memberCount: parsedMemberCount,
      memberNames: members,
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
