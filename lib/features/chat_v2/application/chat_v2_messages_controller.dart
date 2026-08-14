import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../data/chat_v2_repository.dart';
import '../data/models/chat_v2_message.dart';
import 'chat_v2_channels_controller.dart';

final chatV2MessagesProvider = AutoDisposeAsyncNotifierProviderFamily<
    ChatV2MessagesNotifier, List<ChatV2Message>, String>(
  ChatV2MessagesNotifier.new,
);

class ChatV2MessagesNotifier
    extends AutoDisposeFamilyAsyncNotifier<List<ChatV2Message>, String> {
  Timer? _pollingTimer;

  @override
  FutureOr<List<ChatV2Message>> build(String arg) async {
    final channelId = arg;
    final repo = ref.watch(chatV2RepositoryProvider);
    final user = ref.watch(authControllerProvider).valueOrNull;

    final meta = user?.userMetadata;
    final partnerId = meta?['partner_id']?.toString() ??
        meta?['partner']?['id']?.toString();
    final userId = user?.id;

    // Tự động đánh dấu đã đọc
    unawaited(repo.markAsRead(channelId));

    // Polling định kỳ mỗi 5s để cập nhật tin nhắn mới
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!state.isLoading && state.hasValue) {
        try {
          final latest = await repo.getMessages(
            channelId,
            currentPartnerId: partnerId,
            currentUserId: userId,
          );
          if (latest.isNotEmpty) {
            state = AsyncData(latest);
          }
        } catch (_) {}
      }
    });

    ref.onDispose(() {
      _pollingTimer?.cancel();
    });

    return repo.getMessages(
      channelId,
      currentPartnerId: partnerId,
      currentUserId: userId,
    );
  }

  Future<void> sendMessage(String text, {List<int>? attachmentIds}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty && (attachmentIds == null || attachmentIds.isEmpty)) {
      return;
    }

    final channelId = arg;
    final repo = ref.read(chatV2RepositoryProvider);
    final user = ref.read(authControllerProvider).valueOrNull;

    final meta = user?.userMetadata;
    final partnerId = meta?['partner_id']?.toString() ??
        meta?['partner']?['id']?.toString();
    final userId = user?.id;
    final userName = meta?['name']?.toString() ?? 'Tôi';

    // Tạo tin nhắn tạm (optimistic update)
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final tempMsg = ChatV2Message(
      id: tempId,
      channelId: channelId,
      content: trimmed,
      authorId: partnerId ?? userId,
      authorName: userName,
      date: DateTime.now(),
      isMine: true,
      status: 'pending',
    );

    final previousState = state.valueOrNull ?? const [];
    state = AsyncData([...previousState, tempMsg]);

    try {
      final sentMsg = await repo.sendMessage(
        channelId,
        trimmed,
        attachmentIds: attachmentIds,
        currentPartnerId: partnerId,
        currentUserId: userId,
        authorName: userName,
      );

      // Cập nhật lại tin nhắn trong danh sách
      final currentList = state.valueOrNull ?? const [];
      final updatedList = currentList.map((m) {
        if (m.id == tempId) {
          return sentMsg.copyWith(isMine: true, status: 'sent');
        }
        return m;
      }).toList();

      // Nếu không tìm thấy tempId để thay thế, thêm vào cuối
      if (!updatedList.any((m) => m.id == sentMsg.id)) {
        updatedList.removeWhere((m) => m.id == tempId);
        updatedList.add(sentMsg.copyWith(isMine: true, status: 'sent'));
      }

      state = AsyncData(updatedList);

      // Invalidate danh sách kênh để cập nhật last message
      ref.invalidate(chatV2ChannelsProvider);
    } catch (e, st) {
      // Đánh dấu tin nhắn lỗi
      final currentList = state.valueOrNull ?? const [];
      state = AsyncData(
        currentList.map((m) {
          if (m.id == tempId) {
            return m.copyWith(status: 'error');
          }
          return m;
        }).toList(),
      );
      state = AsyncError(e, st);
    }
  }
}
