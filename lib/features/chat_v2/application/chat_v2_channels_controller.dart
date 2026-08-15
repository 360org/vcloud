import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import 'chat_v2_messages_controller.dart';
import 'chat_v2_read_state_controller.dart';
import '../data/chat_v2_realtime_service.dart';
import '../data/chat_v2_repository.dart';
import '../data/models/chat_v2_channel.dart';

final chatV2ChannelsProvider =
    AsyncNotifierProvider.autoDispose<ChatV2ChannelsNotifier, List<ChatV2Channel>>(
  ChatV2ChannelsNotifier.new,
);

class ChatV2ChannelLocalCache {
  static List<ChatV2Channel> _cached = const [];

  static List<ChatV2Channel> get cached => _cached;

  static void set(List<ChatV2Channel> channels) {
    _cached = List.unmodifiable(channels);
  }
}

class ChatV2ChannelsNotifier
    extends AutoDisposeAsyncNotifier<List<ChatV2Channel>> {
  StreamSubscription? _wsSub;
  Timer? _pollingTimer;

  @override
  FutureOr<List<ChatV2Channel>> build() async {
    final repo = ref.watch(chatV2RepositoryProvider);
    final realtime = ref.watch(chatV2RealtimeServiceProvider);
    final user = ref.watch(authControllerProvider).valueOrNull;

    final meta = user?.userMetadata;
    final partnerId = meta?['partner_id']?.toString() ??
        meta?['partner']?['id']?.toString();
    final userId = user?.id;

    _wsSub?.cancel();
    _wsSub = realtime.onChannelUpdated.listen((chId) async {
      try {
        final updated = await repo.getChannels();
        ChatV2ChannelLocalCache.set(updated);

        // Kiểm tra xem kênh vừa cập nhật có phải do chính mình vừa gửi tin không
        if (chId.isNotEmpty) {
          final target = updated.cast<ChatV2Channel?>().firstWhere(
                (c) => c?.id == chId,
                orElse: () => null,
              );
          final lastSentText = ref.read(chatV2LastSentTrackerProvider)[chId];
          final isMineFromTracker = lastSentText != null &&
              target != null &&
              target.lastMessage?.trim() == lastSentText.trim();

          final isMine = isMineFromTracker ||
              (target != null &&
                  target.isLastMessageFromMe(
                    currentUserName: null,
                    currentPartnerId: partnerId,
                    currentUserId: userId,
                  ));

          if (isMine) {
            // Nếu là tin nhắn của chính mình vừa gửi -> Luôn đánh dấu đã xem
            ref.read(chatV2ReadStateProvider.notifier).markChannelAsRead(chId);
          } else {
            // Nếu là tin nhắn từ người khác gửi đến -> Đánh dấu chưa đọc
            ref.read(chatV2LastSentTrackerProvider.notifier).clear(chId);
            ref.read(chatV2ReadStateProvider.notifier).markChannelAsUnread(chId);
          }
        }

        state = AsyncData(updated);
      } catch (_) {}
    });

    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) async {
      if (!state.isLoading && state.hasValue) {
        try {
          final updated = await repo.getChannels();
          if (updated.isNotEmpty) {
            final oldChannels = ChatV2ChannelLocalCache.cached;
            final oldMap = {for (final c in oldChannels) c.id: c};

            for (final ch in updated) {
              final old = oldMap[ch.id];
              if (old != null &&
                  (old.lastMessage != ch.lastMessage ||
                      old.lastMessageDate != ch.lastMessageDate)) {
                // Có tin nhắn mới trong kênh
                final lastSentText = ref.read(chatV2LastSentTrackerProvider)[ch.id];
                final isMineFromTracker = lastSentText != null &&
                    ch.lastMessage?.trim() == lastSentText.trim();

                final isMine = isMineFromTracker ||
                    ch.isLastMessageFromMe(
                      currentUserName: null,
                      currentPartnerId: partnerId,
                      currentUserId: userId,
                    );

                if (!isMine) {
                  // Tin nhắn từ đối phương -> Chuyển thành chưa đọc ngay
                  ref.read(chatV2LastSentTrackerProvider.notifier).clear(ch.id);
                  ref.read(chatV2ReadStateProvider.notifier).markChannelAsUnread(ch.id);
                }
              }
            }

            ChatV2ChannelLocalCache.set(updated);
            state = AsyncData(updated);
          }
        } catch (_) {}
      }
    });

    ref.onDispose(() {
      _wsSub?.cancel();
      _pollingTimer?.cancel();
    });

    final cached = ChatV2ChannelLocalCache.cached;
    if (cached.isNotEmpty) {
      unawaited(() async {
        try {
          final fresh = await repo.getChannels();
          ChatV2ChannelLocalCache.set(fresh);
          state = AsyncData(fresh);
          unawaited(ChatV2MessageLocalCache.preloadChannels(
            fresh.map((c) => c.id).toList(),
            repo,
            partnerId: partnerId,
            userId: userId,
          ));
        } catch (_) {}
      }());

      unawaited(ChatV2MessageLocalCache.preloadChannels(
        cached.map((c) => c.id).toList(),
        repo,
        partnerId: partnerId,
        userId: userId,
      ));

      return cached;
    }

    final fresh = await repo.getChannels();
    ChatV2ChannelLocalCache.set(fresh);

    unawaited(ChatV2MessageLocalCache.preloadChannels(
      fresh.map((c) => c.id).toList(),
      repo,
      partnerId: partnerId,
      userId: userId,
    ));

    return fresh;
  }

  Future<void> refresh() async {
    final repo = ref.read(chatV2RepositoryProvider);
    final fresh = await repo.getChannels();
    ChatV2ChannelLocalCache.set(fresh);
    state = AsyncData(fresh);
  }
}

final chatV2TotalUnreadProvider = Provider.autoDispose<int>((ref) {
  final channelsState = ref.watch(chatV2ChannelsProvider);
  final readNotifier = ref.watch(chatV2ReadStateProvider.notifier);
  ref.watch(chatV2ReadStateProvider); // Watch thay đổi để tự cập nhật badge khi đọc tin

  final currentUser = ref.watch(authControllerProvider).valueOrNull;
  final meta = currentUser?.userMetadata;
  final currentUserName = (meta?['name'] ??
          meta?['display_name'] ??
          meta?['partner_name'] ??
          meta?['partner']?['name']) as String?;
  final currentPartnerId = meta?['partner_id']?.toString() ??
      meta?['partner']?['id']?.toString();
  final currentUserId = currentUser?.id;
  final lastSentMap = ref.watch(chatV2LastSentTrackerProvider);

  return channelsState.maybeWhen(
    data: (channels) {
      return channels.where((c) {
        final lastSentText = lastSentMap[c.id];
        final isMineFromTracker = lastSentText != null &&
            c.lastMessage?.trim() == lastSentText.trim();

        final isMine = isMineFromTracker ||
            c.isLastMessageFromMe(
              currentUserName: currentUserName,
              currentPartnerId: currentPartnerId,
              currentUserId: currentUserId,
            );

        return !isMine &&
            readNotifier.isChannelUnread(
              channelId: c.id,
              serverUnreadCount: c.unreadCount,
              lastMessageDate: c.lastMessageDate,
            );
      }).length;
    },
    orElse: () => 0,
  );
});
