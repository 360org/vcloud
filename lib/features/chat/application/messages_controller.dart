import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/message.dart';
import 'conversations_controller.dart';

final messagesProvider = StreamProvider.autoDispose
    .family<List<Message>, String>((ref, conversationId) {
      final repo = ref.read(chatRepositoryProvider);
      return repo.watchMessages(conversationId);
    });

class SendMessageAction {
  SendMessageAction(this._repo, this._ref);
  final dynamic _repo;
  final Ref _ref;

  Future<Message> send(String conversationId, String content) async {
    if (content.trim().isEmpty) {
      throw ArgumentError('Empty message.');
    }
    final msg = await _repo.sendMessage(conversationId, content.trim());
    // Refresh chat detail and the list preview/unread metadata together.
    _ref.invalidate(messagesProvider(conversationId));
    _ref.invalidate(conversationsProvider);
    return msg;
  }
}

final sendMessageActionProvider = Provider<SendMessageAction>(
  (ref) => SendMessageAction(ref.read(chatRepositoryProvider), ref),
);

/// Action to mark messages as read when opening a conversation.
class MarkAsReadAction {
  MarkAsReadAction(this._repo, this._ref);
  final dynamic _repo;
  final Ref _ref;

  Future<void> markAsRead(String conversationId) async {
    await _repo.markAsRead(conversationId);
    _ref.invalidate(messagesProvider(conversationId));
    _ref.invalidate(conversationsProvider);
  }
}

final markAsReadActionProvider = Provider<MarkAsReadAction>(
  (ref) => MarkAsReadAction(ref.read(chatRepositoryProvider), ref),
);
