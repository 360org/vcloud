import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/conversation.dart';
import '../../auth/application/auth_controller.dart';
import '../data/chat_repository.dart';

export 'unread_chat_controller.dart' show totalUnreadCountProvider;

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
  final currentIdentityIds = <String>{
    user.id,
    user.email ?? '',
    user.email?.split('@').first ?? '',
    user.userMetadata['display_name']?.toString() ?? '',
    user.userMetadata['partner_id']?.toString() ?? '',
  }.where((value) => value.trim().isNotEmpty).toSet();
  return ref
      .read(chatRepositoryProvider)
      .watchConversations(currentIdentityIds: currentIdentityIds);
});

class ConversationActions {
  ConversationActions(this._repo);
  final ChatRepository _repo;

  Future<String> openDirect(String partnerId) => _repo.openDirect(partnerId);

  Future<String> createGroup(String name, List<String> memberIds) =>
      _repo.createGroup(name, memberIds);

  Future<void> sendContact(String conversationId, int partnerId) =>
      _repo.sendContact(conversationId, partnerId);

  Future<void> archive(String conversationId) =>
      _repo.archiveConversation(conversationId);

  Future<void> unarchive(String conversationId) =>
      _repo.unarchiveConversation(conversationId);
}

final conversationActionsProvider = Provider<ConversationActions>(
  (ref) => ConversationActions(ref.read(chatRepositoryProvider)),
);

final conversationDetailsProvider = FutureProvider.autoDispose
    .family<Conversation, String>(
      (ref, conversationId) =>
          ref.read(chatRepositoryProvider).conversationDetails(conversationId),
    );
