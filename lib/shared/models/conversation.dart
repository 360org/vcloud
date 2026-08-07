import '../../core/utils/html_text.dart';
import 'message.dart';
import 'profile.dart';

/// Row from `public.conversations`, joined with the latest message
/// and a denormalised display title for the conversation list.
class ConversationSummary {
  ConversationSummary({
    required this.id,
    required this.isGroup,
    required this.title,
    required this.lastMessage,
    required this.updatedAt,
    this.unreadCount = 0,
    this.archivedAt,
    this.avatarUrl,
    this.description,
    this.isEditable = false,
    this.memberCount = 0,
    this.lastSeenMessageId,
    this.lastSeenDt,
    this.imStatus,
  });

  final String id;
  final bool isGroup;
  final String title;
  final Message? lastMessage;
  final DateTime updatedAt;
  final int unreadCount;
  final DateTime? archivedAt;
  final String? avatarUrl;
  final String? description;
  final bool isEditable;
  final int memberCount;
  final String? lastSeenMessageId;
  final DateTime? lastSeenDt;
  final String? imStatus;

  bool get isArchived => archivedAt != null;

  factory ConversationSummary.fromOdooChatChannel(
    Map<String, dynamic> map, {
    DateTime? fetchedAt,
  }) {
    final id = map['id'].toString();
    final lastMessageDate = _dateTimeOrNull(map['last_message_date']);
    final lastMessageId = _stringOrNull(map['last_message_id']);
    final rawCleanText = _stringOrNull(cleanHtmlText(map['last_message']));
    final lastMessageText = rawCleanText?.replaceAll('\n', ' ');

    return ConversationSummary(
      id: id,
      isGroup: map['channel_type'] != 'chat',
      title: (map['name'] ?? 'Chat').toString(),
      lastMessage: lastMessageText == null
          ? null
          : Message(
              id: lastMessageId ?? 'last-$id',
              conversationId: id,
              senderId: '',
              content: lastMessageText,
              createdAt: lastMessageDate ?? fetchedAt ?? DateTime.now(),
            ),
      updatedAt: lastMessageDate ?? fetchedAt ?? DateTime.now(),
      unreadCount: (map['unread_count'] as num?)?.toInt() ??
          int.tryParse(map['unread_count']?.toString() ?? '') ??
          (map['message_unread_counter'] as num?)?.toInt() ??
          0,
      avatarUrl: _stringOrNull(
        map['avatar_url'] ??
            map['channel_avatar_url'] ??
            map['avatar_128_url'] ??
            map['image_128_url'] ??
            map['avatar_128'] ??
            map['image_128'],
      ),
      description: _stringOrNull(map['description']),
      isEditable: map['is_editable'] as bool? ?? false,
      memberCount: (map['member_count'] as num?)?.toInt() ?? 0,
      lastSeenMessageId: _stringOrNull(map['last_seen_message_id']),
      lastSeenDt: _dateTimeOrNull(map['last_seen_dt']),
      imStatus: _stringOrNull(map['im_status'] ?? map['imStatus']),
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

  static bool _hasTimezone(String value) {
    return RegExp(
      r'(z|[+-]\d\d:?\d\d)$',
      caseSensitive: false,
    ).hasMatch(value.trim());
  }

  static String? _stringOrNull(Object? value) {
    if (value == null || value == false) return null;
    final text = value.toString();
    return text.isEmpty ? null : text;
  }
}

/// Full conversation metadata, used by chat-detail for header/title.
class Conversation {
  const Conversation({
    required this.id,
    required this.isGroup,
    required this.name,
    required this.createdBy,
    required this.createdAt,
    required this.members,
  });

  final String id;
  final bool isGroup;
  final String? name;
  final String createdBy;
  final DateTime createdAt;
  final List<ConversationMember> members;

  String displayTitleFor(Iterable<String> currentIdentityIds) {
    final title = name?.trim();
    if (isGroup) return title?.isNotEmpty == true ? title! : 'Group';

    final currentLabels = currentIdentityIds
        .map((label) => label.trim().toLowerCase())
        .where((label) => label.isNotEmpty)
        .toSet();
    ConversationMember? other;
    for (final member in members) {
      if (!member.profile.matchesAny(currentLabels)) {
        other = member;
        break;
      }
    }
    if (other != null) return other.profile.bestLabel;

    final titleFromChannelName = _directTitleFromName(title, currentLabels);
    if (titleFromChannelName != null) return titleFromChannelName;

    return title?.isNotEmpty == true ? title! : 'Chat';
  }

  factory Conversation.fromMaps(List<Map<String, dynamic>> memberRows) {
    if (memberRows.isEmpty) {
      throw StateError('Cannot build a conversation from no rows');
    }
    final c = memberRows.first;
    return Conversation(
      id: c['id'] as String,
      isGroup: c['is_group'] as bool,
      name: c['name'] as String?,
      createdBy: c['created_by'] as String,
      createdAt: DateTime.parse(c['created_at'] as String),
      members: memberRows.map(ConversationMember.fromMap).toList(),
    );
  }

  static String? _directTitleFromName(String? name, Set<String> currentLabels) {
    if (name == null || name.isEmpty || !name.contains(',')) return null;
    final others = name
        .split(',')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .where((part) {
          final label = part.toLowerCase();
          return label != 'you' &&
              label != 'ban' &&
              label != 'bạn' &&
              !currentLabels.contains(label);
        })
        .toList();
    return others.isEmpty ? null : others.join(', ');
  }
}

class ConversationMember {
  const ConversationMember({required this.profile, required this.joinedAt});

  final Profile profile;
  final DateTime joinedAt;

  factory ConversationMember.fromMap(Map<String, dynamic> row) {
    return ConversationMember(
      profile: Profile(
        id: row['user_id'] as String,
        email: (row['profiles']?['email'] as String?) ?? '',
        displayName: (row['profiles']?['display_name'] as String?) ?? '',
        avatarUrl: row['profiles']?['avatar_url'] as String?,
      ),
      joinedAt: DateTime.parse(row['joined_at'] as String),
    );
  }
}

extension on Profile {
  String get bestLabel {
    final name = displayName.trim();
    if (name.isNotEmpty) return name;
    final mail = email.trim();
    return mail.isNotEmpty ? mail : 'Chat';
  }

  bool matchesAny(Set<String> labels) {
    return labels.contains(id.trim().toLowerCase()) ||
        labels.contains(email.trim().toLowerCase()) ||
        labels.contains(displayName.trim().toLowerCase());
  }
}
