import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/odoo_api_client.dart';
import '../domain/models/chat_v2_call_session.dart';

final chatV2CallRepositoryProvider = Provider<ChatV2CallRepository>((ref) {
  return ChatV2CallRepository(client: odooApiClient);
});

class ChatV2CallRepository {
  final OdooApiClient client;

  ChatV2CallRepository({required this.client});

  /// Khởi tạo cuộc gọi mới trong kênh
  Future<ChatV2CallSession?> initiateCall({
    required int channelId,
    String? sdpOffer,
    int? receiverId,
  }) async {
    try {
      final body = <String, dynamic>{'channel_id': channelId};
      if (sdpOffer != null) body['sdp_offer'] = sdpOffer;
      if (receiverId != null) body['receiver_id'] = receiverId;

      final res = await client.post(
        '/api/v1/mobile/chat/call/initiate',
        body: body,
      );

      if (res is Map && res['call'] != null) {
        return ChatV2CallSession.fromJson(Map<String, dynamic>.from(res['call'] as Map));
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Lấy thông tin phiên gọi đang hoạt động của người dùng
  Future<ChatV2CallSession?> getActiveCall() async {
    try {
      final res = await client.get('/api/v1/mobile/chat/call/active');
      if (res is Map && res['active_call'] != null) {
        return ChatV2CallSession.fromJson(Map<String, dynamic>.from(res['active_call'] as Map));
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Lấy chi tiết phiên gọi và dữ liệu signaling theo ID
  Future<ChatV2CallSession?> getCallSession(int callId) async {
    try {
      final res = await client.get('/api/v1/mobile/chat/call/$callId');
      if (res is Map && res['call'] != null) {
        return ChatV2CallSession.fromJson(Map<String, dynamic>.from(res['call'] as Map));
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Người nhận bấm Trả lời
  Future<ChatV2CallSession?> acceptCall(int callId, {String? sdpAnswer}) async {
    try {
      final body = <String, dynamic>{};
      if (sdpAnswer != null) body['sdp_answer'] = sdpAnswer;

      final res = await client.post(
        '/api/v1/mobile/chat/call/$callId/accept',
        body: body,
      );
      if (res is Map && res['call'] != null) {
        return ChatV2CallSession.fromJson(Map<String, dynamic>.from(res['call'] as Map));
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Người nhận bấm Từ chối
  Future<bool> rejectCall(int callId) async {
    try {
      final res = await client.post('/api/v1/mobile/chat/call/$callId/reject');
      return res is Map && res['status'] == 'success';
    } catch (_) {
      return false;
    }
  }

  /// Người gọi chủ động Hủy
  Future<bool> cancelCall(int callId) async {
    try {
      final res = await client.post('/api/v1/mobile/chat/call/$callId/cancel');
      return res is Map && res['status'] == 'success';
    } catch (_) {
      return false;
    }
  }

  /// Gác máy và lưu thời lượng
  Future<bool> endCall(int callId, {int duration = 0}) async {
    try {
      final res = await client.post(
        '/api/v1/mobile/chat/call/$callId/end',
        body: {'duration': duration},
      );
      return res is Map && res['status'] == 'success';
    } catch (_) {
      return false;
    }
  }

  /// Gửi ICE Candidate lên server
  Future<bool> sendIceCandidate(int callId, Map<String, dynamic> candidate) async {
    try {
      final res = await client.post(
        '/api/v1/mobile/chat/call/$callId/ice',
        body: {'candidate': candidate},
      );
      return res is Map && res['status'] == 'success';
    } catch (_) {
      return false;
    }
  }
}
