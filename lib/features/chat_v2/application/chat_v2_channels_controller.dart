import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/chat_v2_repository.dart';
import '../data/models/chat_v2_channel.dart';

final chatV2ChannelsProvider =
    FutureProvider.autoDispose<List<ChatV2Channel>>((ref) async {
  final repo = ref.watch(chatV2RepositoryProvider);
  return repo.getChannels();
});

final chatV2TotalUnreadProvider = Provider.autoDispose<int>((ref) {
  final channelsState = ref.watch(chatV2ChannelsProvider);
  return channelsState.maybeWhen(
    data: (channels) =>
        channels.fold<int>(0, (sum, ch) => sum + (ch.unreadCount > 0 ? ch.unreadCount : 0)),
    orElse: () => 0,
  );
});
