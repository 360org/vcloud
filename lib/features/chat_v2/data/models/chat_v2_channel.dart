import 'package:flutter/foundation.dart';

@immutable
class ChatV2Channel {
  const ChatV2Channel({
    required this.id,
    required this.name,
    required this.channelType,
    required this.isGroup,
    this.avatarUrl,
    this.lastMessage,
    this.lastMessageDate,
    this.unreadCount = 0,
    this.memberNames = const [],
  });

  final String id;
  final String name;
  final String channelType;
  final bool isGroup;
  final String? avatarUrl;
  final String? lastMessage;
  final DateTime? lastMessageDate;
  final int unreadCount;
  final List<String> memberNames;

  factory ChatV2Channel.fromMap(Map<String, dynamic> map) {
    final id = _stringOr(map['id'], '');
    final name = _stringOr(map['name'], 'Cuộc trò chuyện');
    final channelType = _stringOr(map['channel_type'], 'chat');
    final isGroup = _boolOr(map['is_group'], channelType == 'group');
    final avatarUrl = _stringOrNull(map['avatar_url'] ?? map['avatar_128'] ?? map['image_128']);

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
    DateTime? date;
    final dateStr = _stringOrNull(map['updated_at'] ?? map['last_activity'] ?? map['write_date'] ?? (rawLastMsg is Map ? rawLastMsg['date'] : null));
    if (dateStr != null) {
      date = DateTime.tryParse(dateStr)?.toLocal();
    }

    // Parse unread count
    final unread = _intOr(map['unread_count'] ?? map['message_unread_counter'], 0);

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

    return ChatV2Channel(
      id: id,
      name: name,
      channelType: channelType,
      isGroup: isGroup,
      avatarUrl: avatarUrl,
      lastMessage: lastMsgText,
      lastMessageDate: date,
      unreadCount: unread,
      memberNames: members,
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
