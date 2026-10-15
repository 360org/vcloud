import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/livechat_repository.dart';
import '../data/models/livechat_channel_model.dart';
import '../data/models/livechat_session_model.dart';

/// Provider danh sách kênh hỗ trợ Live Chat động từ Odoo
final livechatChannelsProvider = FutureProvider.autoDispose<List<LivechatChannelModel>>((ref) async {
  final repo = ref.watch(livechatRepositoryProvider);
  return repo.getChannels();
});

/// Controller xử lý mở và chuyển tiếp phiên Live Chat
final livechatControllerProvider = Provider<LivechatController>((ref) {
  return LivechatController(ref.watch(livechatRepositoryProvider));
});

class LivechatController {
  LivechatController(this._repository);

  final LivechatRepository _repository;

  Future<LivechatSessionModel> openSession({
    required int channelId,
    String? webSessionUuid,
  }) {
    return _repository.createOrGetSession(
      channelId: channelId,
      webSessionUuid: webSessionUuid,
    );
  }
}
