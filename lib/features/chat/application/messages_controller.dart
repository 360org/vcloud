import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/mobile_attachment_repository.dart';
import '../../../shared/models/message.dart';
import 'conversations_controller.dart';

class MessagesState {
  const MessagesState({
    this.messages = const [],
    this.isLoadingMore = false,
    this.hasMore = true,
  });

  final List<Message> messages;
  final bool isLoadingMore;
  final bool hasMore;

  MessagesState copyWith({
    List<Message>? messages,
    bool? isLoadingMore,
    bool? hasMore,
  }) {
    return MessagesState(
      messages: messages ?? this.messages,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

class MessagesNotifier extends AutoDisposeFamilyAsyncNotifier<MessagesState, String> {
  StreamSubscription<List<Message>>? _sub;

  @override
  FutureOr<MessagesState> build(String arg) async {
    final repo = ref.watch(chatRepositoryProvider);
    
    // Subscribe to realtime updates (new messages)
    _sub = repo.watchMessages(arg).listen((newMessages) {
      if (!state.hasValue) return;
      final current = state.value!;
      
      // Merge logic: keep older loaded messages, update/add new ones.
      // Odoo realtime returns latest 35 by default.
      final oldMessagesMap = {for (final m in current.messages) m.id: m};
      for (final nm in newMessages) {
        oldMessagesMap[nm.id] = nm; // overwrite/add new
      }
      
      final merged = oldMessagesMap.values.toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      
      state = AsyncValue.data(current.copyWith(messages: merged));
    });

    ref.onDispose(() {
      _sub?.cancel();
    });

    // Initial load will come from stream shortly, return empty initial state
    return const MessagesState();
  }

  Future<void> loadMore() async {
    if (!state.hasValue) return;
    final current = state.value!;
    if (current.isLoadingMore || !current.hasMore || current.messages.isEmpty) return;

    state = AsyncValue.data(current.copyWith(isLoadingMore: true));

    try {
      final repo = ref.read(chatRepositoryProvider);
      // Older messages are at the beginning of the sorted list
      final oldestMessageId = current.messages.first.id;
      
      final olderMessages = await repo.fetchOlderMessages(
        arg, 
        beforeMessageId: oldestMessageId,
        limit: 35,
      );

      if (olderMessages.isEmpty) {
        state = AsyncValue.data(current.copyWith(
          isLoadingMore: false,
          hasMore: false,
        ));
        return;
      }

      // Merge avoiding duplicates
      final currentMap = {for (final m in current.messages) m.id: m};
      for (final om in olderMessages) {
        currentMap.putIfAbsent(om.id, () => om);
      }
      
      final merged = currentMap.values.toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

      state = AsyncValue.data(current.copyWith(
        messages: merged,
        isLoadingMore: false,
        hasMore: olderMessages.length == 35,
      ));
    } catch (e) {
      state = AsyncValue.data(current.copyWith(isLoadingMore: false));
    }
  }
}

final messagesProvider = AsyncNotifierProvider.autoDispose.family<MessagesNotifier, MessagesState, String>(
  MessagesNotifier.new,
);

class SendMessageAction {
  SendMessageAction(this._repo, this._ref);
  final dynamic _repo;
  final Ref _ref;

  Future<Message> send(String conversationId, String content) async {
    if (content.trim().isEmpty) {
      throw ArgumentError('Empty message.');
    }
    final msg = await _repo.sendMessage(conversationId, content.trim());
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

  Future<Uint8List> bytes(String attachmentId) {
    return _repo.attachmentBytes(attachmentId);
  }
}

final downloadAttachmentActionProvider = Provider<DownloadAttachmentAction>(
  (ref) => DownloadAttachmentAction(ref.read(chatRepositoryProvider)),
);

class ForwardAttachmentAction {
  ForwardAttachmentAction(this._repo, this._ref);
  final dynamic _repo;
  final Ref _ref;

  Future<void> forward(String targetConversationId, String attachmentId) async {
    await _repo.forwardAttachment(targetConversationId, attachmentId);
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
    _ref.invalidate(conversationsProvider);
  }

  Future<void> unpin(String conversationId, String messageId) async {
    await _repo.unpinMessage(conversationId, messageId);
    _ref.invalidate(conversationsProvider);
  }
}

final pinMessageActionProvider = Provider<PinMessageAction>(
  (ref) => PinMessageAction(ref.read(chatRepositoryProvider), ref),
);

class MarkAsReadAction {
  MarkAsReadAction(this._repo, this._ref);
  final dynamic _repo;
  final Ref _ref;

  Future<void> markAsRead(String conversationId) async {
    await _repo.markAsRead(conversationId);
    _ref.invalidate(conversationsProvider);
  }
}

final markAsReadActionProvider = Provider<MarkAsReadAction>(
  (ref) => MarkAsReadAction(ref.read(chatRepositoryProvider), ref),
);
