import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/mobile_attachment_repository.dart';
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

class SendAttachmentAction {
  SendAttachmentAction(this._repo, this._ref);
  final dynamic _repo;
  final Ref _ref;

  Future<MobileAttachment> send(
    String conversationId,
    MobileAttachmentUpload attachment,
  ) async {
    final uploaded = await _repo.uploadAttachment(conversationId, attachment);
    _ref.invalidate(messagesProvider(conversationId));
    _ref.invalidate(conversationsProvider);
    return uploaded;
  }
}

final sendAttachmentActionProvider = Provider<SendAttachmentAction>(
  (ref) => SendAttachmentAction(ref.read(chatRepositoryProvider), ref),
);

class DownloadAttachmentAction {
  DownloadAttachmentAction(this._repo);
  final dynamic _repo;

  Future<String> downloadUrl(String attachmentId) {
    return _repo.attachmentDownloadUrl(attachmentId);
  }

  String contentUrl(String attachmentId, {String? url}) {
    return _repo.attachmentContentUrl(attachmentId, url: url);
  }

  /// Raw bytes for cross-platform save (native save dialog) and forward.
  Future<Uint8List> bytes(String attachmentId) {
    return _repo.attachmentBytes(attachmentId);
  }
}

final downloadAttachmentActionProvider = Provider<DownloadAttachmentAction>(
  (ref) => DownloadAttachmentAction(ref.read(chatRepositoryProvider)),
);

/// Re-sends an existing attachment into another conversation.
class ForwardAttachmentAction {
  ForwardAttachmentAction(this._repo, this._ref);
  final dynamic _repo;
  final Ref _ref;

  Future<void> forward(String targetConversationId, String attachmentId) async {
    await _repo.forwardAttachment(targetConversationId, attachmentId);
    // Refresh the target chat detail and the list preview/unread metadata.
    _ref.invalidate(messagesProvider(targetConversationId));
    _ref.invalidate(conversationsProvider);
  }
}

final forwardAttachmentActionProvider = Provider<ForwardAttachmentAction>(
  (ref) => ForwardAttachmentAction(ref.read(chatRepositoryProvider), ref),
);

class PinMessageAction {
  PinMessageAction(this._repo, this._ref);
  final dynamic _repo;
  final Ref _ref;

  Future<void> pin(String conversationId, String messageId) async {
    await _repo.pinMessage(conversationId, messageId);
    _ref.invalidate(messagesProvider(conversationId));
    _ref.invalidate(conversationsProvider);
  }

  Future<void> unpin(String conversationId, String messageId) async {
    await _repo.unpinMessage(conversationId, messageId);
    _ref.invalidate(messagesProvider(conversationId));
    _ref.invalidate(conversationsProvider);
  }
}

final pinMessageActionProvider = Provider<PinMessageAction>(
  (ref) => PinMessageAction(ref.read(chatRepositoryProvider), ref),
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
