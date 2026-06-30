import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/failure.dart';
import '../../../shared/models/conversation.dart';
import '../../../shared/models/message.dart';
import '../../../shared/models/profile.dart';

/// Streaming APIs for chat. Internally we fetch a snapshot, then
/// subscribe to postgres_changes; whenever an insert/update/delete
/// fires we re-fetch and re-emit.
class ChatRepository {
  ChatRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Stream<List<ConversationSummary>> watchConversations() {
    final controller = StreamController<List<ConversationSummary>>();
    final myId = _client.auth.currentUser?.id;
    if (myId == null) {
      controller.add(const <ConversationSummary>[]);
      controller.close();
      return controller.stream;
    }

    RealtimeChannel? channel;

    Future<void> refresh() async {
      try {
        final ids = await _myConversationIds(myId);
        final list = ids.isEmpty
            ? const <ConversationSummary>[]
            : await _fetchSummaries(myId, ids);
        if (!controller.isClosed) controller.add(list);
      } catch (e) {
        if (!controller.isClosed) {
          controller.addError(Failure('Refresh failed: $e'));
        }
      }
    }

    Future<void> sub() async {
      try {
        final ids = await _myConversationIds(myId);
        if (ids.isEmpty) {
          controller.add(const <ConversationSummary>[]);
        } else {
          controller.add(await _fetchSummaries(myId, ids));
        }
      } catch (e) {
        controller.addError(Failure('Chat refresh failed: $e'));
      }

      channel = _client
          .channel('conv-list-$myId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'conversations',
            callback: (_) => refresh(),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'conversation_members',
            callback: (_) => refresh(),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'messages',
            callback: (_) => refresh(),
          )
          .subscribe();
    }

    controller.onListen = sub;
    controller.onCancel = () async {
      final c = channel;
      if (c != null) await _client.removeChannel(c);
    };
    return controller.stream;
  }

  Stream<List<Message>> watchMessages(String conversationId) {
    final controller = StreamController<List<Message>>();
    RealtimeChannel? channel;
    String? lastSeen;

    Future<void> refresh() async {
      try {
        final res = await _client
            .from('messages')
            .select('*')
            .eq('conversation_id', conversationId)
            .order('created_at', ascending: true);
        final msgs = (res as List)
            .cast<Map<String, dynamic>>()
            .map(Message.fromMap)
            .toList();
        if (!controller.isClosed) controller.add(msgs);
      } catch (e) {
        if (!controller.isClosed) {
          controller.addError(Failure('Refresh failed: $e'));
        }
      }
    }

    controller.onListen = () async {
      await refresh();
      channel = _client
          .channel('msg-$conversationId-$lastSeen')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'messages',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'conversation_id',
              value: conversationId,
            ),
            callback: (_) => refresh(),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'messages',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'conversation_id',
              value: conversationId,
            ),
            callback: (_) => refresh(),
          )
          .subscribe();
    };
    controller.onCancel = () async {
      final c = channel;
      if (c != null) await _client.removeChannel(c);
    };
    return controller.stream;
  }

  Future<Message> sendMessage(String conversationId, String content) async {
    final myId = _client.auth.currentUser?.id;
    if (myId == null) throw Failure('Not signed in');
    final res = await _client
        .from('messages')
        .insert({
          'conversation_id': conversationId,
          'sender_id': myId,
          'content': content,
        })
        .select()
        .single();
    return Message.fromMap(res);
  }

  /// Mark all messages in a conversation as read by the current user
  /// and reset the unread count for this user's membership.
  Future<void> markAsRead(String conversationId) async {
    final myId = _client.auth.currentUser?.id;
    if (myId == null) return;

    // Use the database function to mark messages as read and reset unread count
    await _client.rpc(
      'mark_messages_as_read',
      params: {'p_conversation_id': conversationId, 'p_user_id': myId},
    );
  }

  /// Looks for an existing 1:1 conversation between the current user and
  /// [otherUserId] (idempotent via the create_direct_conversation RPC).
  Future<String> openDirect(String otherUserId) async {
    final res = await _client.rpc(
      'create_direct_conversation',
      params: {'other_id': otherUserId},
    );
    return res.toString();
  }

  Future<String> createGroup(String name, List<String> memberIds) async {
    final me = _client.auth.currentUser?.id;
    if (me == null) throw Failure('Not signed in');

    final conv = await _client
        .from('conversations')
        .insert({'created_by': me, 'is_group': true, 'name': name})
        .select('id')
        .single();
    final id = conv['id'] as String;

    final rows = <Map<String, dynamic>>[
      {'conversation_id': id, 'user_id': me},
      for (final m in memberIds.where((m) => m != me))
        {'conversation_id': id, 'user_id': m},
    ];
    await _client.from('conversation_members').insert(rows);
    return id;
  }

  Future<List<Profile>> allUsers() async {
    final me = _client.auth.currentUser?.id;
    final res = await _client
        .from('profiles')
        .select('*')
        .order('display_name');
    return (res as List)
        .cast<Map<String, dynamic>>()
        .map(
          (m) => Profile(
            id: m['id'] as String,
            email: m['email'] as String,
            displayName: m['display_name'] as String,
            avatarUrl: m['avatar_url'] as String?,
          ),
        )
        .where((p) => p.id != me)
        .toList();
  }

  Future<Conversation> conversationDetails(String id) async {
    final conv = await _client
        .from('conversations')
        .select('*')
        .eq('id', id)
        .single();
    final members = await _client
        .from('conversation_members')
        .select('user_id, joined_at, profiles(*)')
        .eq('conversation_id', id);
    final rows = (members as List).cast<Map<String, dynamic>>();
    final convMap = Map<String, dynamic>.from(conv);
    final merged = [
      for (final row in rows) <String, dynamic>{...convMap, ...row},
    ];
    return Conversation.fromMaps(merged);
  }

  /// Archive a conversation for the current user.
  Future<void> archiveConversation(String conversationId) async {
    final myId = _client.auth.currentUser?.id;
    if (myId == null) throw Failure('Not signed in');

    await _client
        .from('conversation_members')
        .update({'archived_at': DateTime.now().toIso8601String()})
        .eq('conversation_id', conversationId)
        .eq('user_id', myId);
  }

  /// Unarchive a conversation for the current user.
  Future<void> unarchiveConversation(String conversationId) async {
    final myId = _client.auth.currentUser?.id;
    if (myId == null) throw Failure('Not signed in');

    await _client
        .from('conversation_members')
        .update({'archived_at': null})
        .eq('conversation_id', conversationId)
        .eq('user_id', myId);
  }

  // ---------------------------------------------------------------------------

  Future<List<String>> _myConversationIds(String userId) async {
    final res = await _client
        .from('conversation_members')
        .select('conversation_id')
        .eq('user_id', userId);
    return (res as List)
        .cast<Map<String, dynamic>>()
        .map((r) => r['conversation_id'] as String)
        .toList();
  }

  Future<List<ConversationSummary>> _fetchSummaries(
    String myId,
    List<String> ids,
  ) async {
    final convsRes = await _client
        .from('conversations')
        .select('*')
        .inFilter('id', ids)
        .order('created_at', ascending: false);
    final convList = (convsRes as List).cast<Map<String, dynamic>>();

    final membersRes = await _client
        .from('conversation_members')
        .select('conversation_id, user_id, profiles(*)')
        .inFilter('conversation_id', ids);
    final memberRows = (membersRes as List).cast<Map<String, dynamic>>();

    // Fetch my membership rows to get unread counts and archived status
    final myMemberships = await _client
        .from('conversation_members')
        .select('conversation_id, unread_count, archived_at')
        .eq('user_id', myId)
        .inFilter('conversation_id', ids);
    final membershipMap = <String, Map<String, dynamic>>{};
    for (final m in (myMemberships as List).cast<Map<String, dynamic>>()) {
      membershipMap[m['conversation_id'] as String] = m;
    }

    final summaries = <ConversationSummary>[];
    for (final c in convList) {
      final ci = c['id'] as String;
      final itsMembers = memberRows
          .where((m) => m['conversation_id'] == ci)
          .toList();
      final lastMsgs = await _client
          .from('messages')
          .select('*')
          .eq('conversation_id', ci)
          .order('created_at', ascending: false)
          .limit(1);
      final Message? last = lastMsgs.isEmpty
          ? null
          : Message.fromMap((lastMsgs.first as Map).cast<String, dynamic>());

      final isGroup = c['is_group'] as bool;
      String title;
      if (isGroup) {
        title = (c['name'] as String?) ?? 'Group';
      } else {
        final other = itsMembers.firstWhere(
          (m) => (m['profiles']?['id'] as String?) != myId,
          orElse: () => <String, dynamic>{
            'profiles': {'id': myId, 'email': '', 'display_name': 'You'},
          },
        );
        title =
            (other['profiles']?['display_name'] as String?)?.isNotEmpty == true
            ? other['profiles']['display_name'] as String
            : (other['profiles']?['email'] as String? ?? 'You');
      }

      final membershipData = membershipMap[ci];
      final unreadCount = (membershipData?['unread_count'] as int?) ?? 0;
      final archivedAtStr = membershipData?['archived_at'] as String?;
      final archivedAt = archivedAtStr != null
          ? DateTime.parse(archivedAtStr)
          : null;

      summaries.add(
        ConversationSummary(
          id: ci,
          isGroup: isGroup,
          title: title,
          lastMessage: last,
          updatedAt:
              last?.createdAt ?? DateTime.parse(c['created_at'] as String),
          unreadCount: unreadCount,
          archivedAt: archivedAt,
        ),
      );
    }
    summaries.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return summaries;
  }
}
