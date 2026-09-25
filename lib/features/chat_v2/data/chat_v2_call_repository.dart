import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/odoo_api_client.dart';
import '../domain/models/chat_v2_call_session.dart';

final chatV2CallRepositoryProvider = Provider<ChatV2CallRepository>((ref) {
  return ChatV2CallRepository(client: odooApiClient);
});

/// Kết quả trả về từ endpoint /mail/rtc/channel/join_call của Odoo 19
class OdooRtcJoinResult {
  final int localSessionId;
  final List<dynamic> iceServers;
  final List<int> currentRtcSessionIds;
  final Map<String, dynamic> rawStore;

  const OdooRtcJoinResult({
    required this.localSessionId,
    required this.iceServers,
    required this.currentRtcSessionIds,
    required this.rawStore,
  });

  factory OdooRtcJoinResult.fromStore(Map<String, dynamic> store) {
    int localSid = 0;
    final rtcData = store['Rtc'];
    if (rtcData is Map) {
      final localSession = rtcData['localSession'];
      if (localSession is Map && localSession['id'] != null) {
        localSid = int.tryParse(localSession['id'].toString()) ?? 0;
      } else if (localSession is num) {
        localSid = localSession.toInt();
      } else if (localSession != null) {
        localSid = int.tryParse(localSession.toString()) ?? 0;
      }
    }
    // Fallback cho Odoo 17: 'sessionId' nằm trực tiếp ở root của response
    if (localSid == 0 && store['sessionId'] != null) {
      localSid = int.tryParse(store['sessionId'].toString()) ?? 0;
    }

    List<dynamic> ice = [];
    if (rtcData is Map && rtcData['iceServers'] is List) {
      ice = List<dynamic>.from(rtcData['iceServers'] as List);
    } else if (store['iceServers'] is List) {
      // Odoo 17 root-level iceServers
      ice = List<dynamic>.from(store['iceServers'] as List);
    }

    // Trích xuất các session khác đang trong phòng
    final sessionIds = <int>{};

    // 0. Trích xuất từ Odoo 17 rtcSessions: [['ADD', [{id: ...}]]]
    final rawRtcSessions = store['rtcSessions'];
    if (rawRtcSessions is List) {
      for (final item in rawRtcSessions) {
        if (item is List && item.length >= 2 && item[0] == 'ADD') {
          final added = item[1];
          if (added is List) {
            for (final s in added) {
              if (s is Map && s['id'] != null) {
                final sid = int.tryParse(s['id'].toString());
                if (sid != null && sid != localSid) sessionIds.add(sid);
              } else if (s is num && s.toInt() != localSid) {
                sessionIds.add(s.toInt());
              }
            }
          }
        }
      }
    }

    // 1. Trích xuất trực tiếp từ discuss.channel.rtc.session nếu có
    final rtcSessions = store['discuss.channel.rtc.session'];
    if (rtcSessions is List) {
      for (final s in rtcSessions) {
        if (s is Map && s['id'] != null) {
          final sid = int.tryParse(s['id'].toString());
          if (sid != null && sid != localSid) sessionIds.add(sid);
        } else if (s is num && s.toInt() != localSid) {
          sessionIds.add(s.toInt());
        }
      }
    }

    // 2. Quét qua các danh sách/map discuss.channel hoặc command tuple [ADD, [id]]
    for (final entry in store.entries) {
      final valList = entry.value is List ? (entry.value as List) : [entry.value];
      for (final val in valList) {
        if (val is! Map) continue;
        final rawRtc = val['rtc_session_ids'];
        if (rawRtc is List) {
          for (final s in rawRtc) {
            if (s is Map && s['id'] != null) {
              final sid = int.tryParse(s['id'].toString());
              if (sid != null && sid != localSid) sessionIds.add(sid);
            } else if (s is num && s.toInt() != localSid) {
              sessionIds.add(s.toInt());
            } else if (s is List && s.length >= 2 && s[0] == 'ADD') {
              final added = s[1];
              if (added is List) {
                for (final a in added) {
                  final sid = int.tryParse(a.toString());
                  if (sid != null && sid != localSid) sessionIds.add(sid);
                }
              }
            }
          }
        }
      }
    }

    return OdooRtcJoinResult(
      localSessionId: localSid,
      iceServers: ice,
      currentRtcSessionIds: sessionIds.toList(),
      rawStore: store,
    );
  }
}

/// Repository giao tiếp trực tiếp với native Odoo 19 Discuss RTC Core (/mail/rtc/*)
class ChatV2CallRepository {
  final OdooApiClient client;

  ChatV2CallRepository({required this.client});

  /// Helper gọi JSON-RPC chuẩn Odoo
  Future<dynamic> _callJsonRpc(String path, Map<String, dynamic> params) async {
    final response = await client.post(
      path,
      body: {
        'jsonrpc': '2.0',
        'method': 'call',
        'params': params,
      },
      auth: true,
    );
    if (response is Map && response.containsKey('result')) {
      return response['result'];
    }
    return response;
  }

  /// 1. Tham gia phòng RTC Call (Odoo 19 Core: /mail/rtc/channel/join_call)
  Future<OdooRtcJoinResult?> joinCall({
    required int channelId,
    List<int> checkRtcSessionIds = const [],
    bool camera = false,
  }) async {
    try {
      final params = <String, dynamic>{
        'channel_id': channelId,
        'check_rtc_session_ids': checkRtcSessionIds,
      };
      // ponytail: Odoo 17 không có param camera, chỉ truyền khi camera thực sự bật
      if (camera) {
        params['camera'] = true;
      }
      final res = await _callJsonRpc('/mail/rtc/channel/join_call', params);

      if (res is Map) {
        return OdooRtcJoinResult.fromStore(Map<String, dynamic>.from(res));
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// 2. Gửi Signaling WebRTC P2P (SDP Offer/Answer, ICE Candidate)
  /// Odoo 19 Core: /mail/rtc/session/notify_call_members
  Future<bool> notifyCallMembers({
    required int senderSessionId,
    required List<int> targetSessionIds,
    required String content,
  }) async {
    try {
      await _callJsonRpc('/mail/rtc/session/notify_call_members', {
        'peer_notifications': [
          [senderSessionId, targetSessionIds, content],
        ],
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 3. Rời cuộc gọi / Gác máy (Odoo 19 Core: /mail/rtc/channel/leave_call)
  Future<bool> leaveCall({
    required int channelId,
    int? sessionId,
  }) async {
    try {
      final params = <String, dynamic>{'channel_id': channelId};
      // ponytail: Odoo 19 hỗ trợ session_id, Odoo 17 chỉ nhận channel_id
      if (sessionId != null && sessionId > 0) {
        params['session_id'] = sessionId;
      }
      try {
        await _callJsonRpc('/mail/rtc/channel/leave_call', params);
      } catch (_) {
        if (params.containsKey('session_id')) {
          await _callJsonRpc('/mail/rtc/channel/leave_call', {'channel_id': channelId});
        } else {
          rethrow;
        }
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 4. Hủy lời mời gọi thoại nếu bên kia chưa bắt máy
  /// Odoo 19 Core: /mail/rtc/channel/cancel_call_invitation
  Future<bool> cancelCallInvitation({
    required int channelId,
    List<int>? memberIds,
  }) async {
    try {
      final params = <String, dynamic>{'channel_id': channelId};
      if (memberIds != null && memberIds.isNotEmpty) {
        params['member_ids'] = memberIds;
      }
      await _callJsonRpc('/mail/rtc/channel/cancel_call_invitation', params);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 5. Cập nhật trạng thái Mute / Deaf / Camera
  /// Odoo 19 Core: /mail/rtc/session/update_and_broadcast
  Future<bool> updateAndBroadcast({
    required int sessionId,
    required Map<String, dynamic> values,
  }) async {
    try {
      await _callJsonRpc('/mail/rtc/session/update_and_broadcast', {
        'session_id': sessionId,
        'values': values,
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 6. Legacy / Backward-compatible methods cho Odoo 17 & Unit Tests
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

  Future<bool> rejectCall(int callId) async {
    try {
      final res = await client.post('/api/v1/mobile/chat/call/$callId/reject');
      return res is Map && res['status'] == 'success';
    } catch (_) {
      return false;
    }
  }

  Future<bool> cancelCall(int callId) async {
    try {
      final res = await client.post('/api/v1/mobile/chat/call/$callId/cancel');
      return res is Map && res['status'] == 'success';
    } catch (_) {
      return false;
    }
  }

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
