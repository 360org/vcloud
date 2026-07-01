import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/conversation.dart';
import '../../auth/application/auth_controller.dart';
import '../data/chat_repository.dart';

final chatRepositoryProvider = Provider<ChatRepository>(
  (_) => ChatRepository(),
);

final conversationsProvider = StreamProvider<List<ConversationSummary>>((ref) {
  final user = ref.watch(authControllerProvider).value;
  if (user == null) return Stream.value(const <ConversationSummary>[]);

  // Non-autoDispose: this stream is the single source of truth for both the
  // chat list and the bottom-nav unread badge. Disposing it on every screen
  // exit would break HTTP refresh updates while the user is on Home / Tickets
  // and silently drop `unread_count` increments.
  //
  // It still watches auth above so login/logout switches rebuild the stream
  // with the correct current Odoo user instead of keeping a stale stream.
  return ref.read(chatRepositoryProvider).watchConversations();
});

class ConversationActions {
  ConversationActions(this._repo);
  final ChatRepository _repo;

  Future<String> openDirect(String otherUserId) =>
      _repo.openDirect(otherUserId);

  Future<String> createGroup(String name, List<String> memberIds) =>
      _repo.createGroup(name, memberIds);

  Future<void> archive(String conversationId) =>
      _repo.archiveConversation(conversationId);

  Future<void> unarchive(String conversationId) =>
      _repo.unarchiveConversation(conversationId);
}

final conversationActionsProvider = Provider<ConversationActions>(
  (ref) => ConversationActions(ref.read(chatRepositoryProvider)),
);

/// Total unread message count across all conversations (for badge display).
final totalUnreadCountProvider = Provider<int>((ref) {
  final conversations = ref.watch(conversationsProvider);
  return conversations.when(
    data: (list) => list.fold(0, (sum, c) => sum + c.unreadCount),
    loading: () => 0,
    error: (e, st) => 0,
  );
});

final conversationDetailsProvider = FutureProvider.autoDispose
    .family<Conversation, String>(
      (ref, conversationId) =>
          ref.read(chatRepositoryProvider).conversationDetails(conversationId),
    );
