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
  });

  final String id;
  final bool isGroup;
  final String title;
  final Message? lastMessage;
  final DateTime updatedAt;
  final int unreadCount;
  final DateTime? archivedAt;

  bool get isArchived => archivedAt != null;
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

  String displayTitleFor(String currentUserId) {
    if (isGroup) return name ?? 'Group';
    final other = members.firstWhere(
      (m) => m.profile.id != currentUserId,
      orElse: () => ConversationMember(
        profile: const Profile(id: '', email: '', displayName: 'You'),
        joinedAt: createdAt,
      ),
    );
    return other.profile.displayName.isEmpty
        ? other.profile.email
        : other.profile.displayName;
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
        displayName:
            (row['profiles']?['display_name'] as String?) ?? '',
        avatarUrl: row['profiles']?['avatar_url'] as String?,
      ),
      joinedAt: DateTime.parse(row['joined_at'] as String),
    );
  }
}
