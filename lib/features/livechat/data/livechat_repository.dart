import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/odoo_api_client.dart';
import 'models/livechat_channel_model.dart';
import 'models/livechat_session_model.dart';

final livechatRepositoryProvider = Provider<LivechatRepository>((ref) {
  return LivechatRepository(odooApiClient);
});

class LivechatRepository {
  LivechatRepository(this._client);

  final OdooApiClient _client;

  /// Lấy danh sách các kênh Live Chat (im_livechat.channel) đang hoạt động
  Future<List<LivechatChannelModel>> getChannels() async {
    final response = await _client.get('/api/v1/mobile/livechat/channels');
    if (response is Map<String, dynamic> && response['success'] == true) {
      final list = response['data'];
      if (list is List) {
        return list
            .whereType<Map<String, dynamic>>()
            .map(LivechatChannelModel.fromJson)
            .toList();
      }
    }
    return <LivechatChannelModel>[];
  }

  /// Khởi tạo hoặc tái sử dụng phiên Live Chat chuẩn Odoo
  Future<LivechatSessionModel> createOrGetSession({
    required int channelId,
    String? webSessionUuid,
  }) async {
    final payload = <String, dynamic>{
      'channel_id': channelId,
      if (webSessionUuid != null && webSessionUuid.trim().isNotEmpty)
        'web_session_uuid': webSessionUuid.trim(),
    };

    final response = await _client.post(
      '/api/v1/mobile/livechat/session',
      body: payload,
    );

    if (response is Map<String, dynamic> && response['success'] == true) {
      final data = response['data'];
      if (data is Map<String, dynamic>) {
        return LivechatSessionModel.fromJson(data);
      }
    }

    throw Exception(
      response is Map<String, dynamic> && response['error'] != null
          ? response['error'].toString()
          : 'Không thể khởi tạo phiên hỗ trợ trực tuyến',
    );
  }

  String? resolveAvatarUrl(String? path) => _client.resolveAvatarUrl(path);
}
