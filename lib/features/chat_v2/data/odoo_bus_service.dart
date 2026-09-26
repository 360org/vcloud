import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/api/odoo_api_client.dart';

final odooBusServiceProvider = Provider<OdooBusService>((ref) {
  final service = OdooBusService();
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});

/// Service kết nối và lắng nghe sự kiện từ Odoo Bus WebSocket (/websocket)
class OdooBusService {
  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  bool _isConnected = false;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;

  final Set<String> _subscribedChannels = {};

  final _peerNotificationController = StreamController<Map<String, dynamic>>.broadcast();
  final _callEndedController = StreamController<Map<String, dynamic>>.broadcast();
  final _incomingCallController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onPeerNotification => _peerNotificationController.stream;
  Stream<Map<String, dynamic>> get onCallEnded => _callEndedController.stream;
  Stream<Map<String, dynamic>> get onIncomingCall => _incomingCallController.stream;
  bool get isConnected => _isConnected;

  /// Khởi tạo kết nối WebSocket Bus với Odoo 19
  Future<void> connect() async {
    if (_isConnected || _channel != null) return;

    final session = odooApiClient.session;
    if (session == null) return;

    try {
      final base = odooApiClient.absoluteUrl('');
      final uri = Uri.parse(base);
      final wsScheme = uri.scheme == 'https' ? 'wss' : 'ws';
      final portSuffix = (uri.hasPort && uri.port != 80 && uri.port != 443) ? ':${uri.port}' : '';
      final wsUrl = '$wsScheme://${uri.host}$portSuffix/websocket?access_token=${session.accessToken}';

      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _isConnected = true;
      _reconnectAttempts = 0;

      // 1. Gửi bản tin subscribe ban đầu
      _sendSubscribe();

      // 2. Lắng nghe luồng dữ liệu
      _sub = _channel!.stream.listen(
        (data) {
          _handleIncomingMessage(data);
        },
        onError: (err) {
          debugPrint('[OdooBus] WebSocket error: $err');
          _handleDisconnect();
        },
        onDone: () {
          debugPrint('[OdooBus] WebSocket closed');
          _handleDisconnect();
        },
      );
    } catch (e) {
      debugPrint('[OdooBus] Failed to connect WebSocket: $e');
      _handleDisconnect();
    }
  }

  /// Thêm phòng chat cần theo dõi realtime
  void subscribeChannel(int channelId) {
    if (channelId <= 0) return;
    final chName = 'discuss.channel_$channelId';
    if (_subscribedChannels.add(chName)) {
      _sendSubscribe();
    }
  }

  /// Gửi bản tin đăng ký nhận notifications từ Odoo Bus
  void _sendSubscribe() {
    if (_channel == null) return;
    try {
      final msg = jsonEncode({
        'event_name': 'subscribe',
        'data': {
          'channels': _subscribedChannels.toList(),
          'last': 0,
        },
      });
      _channel!.sink.add(msg);
    } catch (_) {}
  }

  /// Xử lý bản tin nhận từ WebSocket Odoo Bus
  void _handleIncomingMessage(dynamic raw) {
    try {
      final text = raw is List<int> ? utf8.decode(raw) : raw.toString();
      final decoded = jsonDecode(text);

      if (decoded is List) {
        for (final item in decoded) {
          _processBusNotification(item);
        }
      } else if (decoded is Map) {
        _processBusNotification(decoded);
      }
    } catch (e) {
      debugPrint('[OdooBus] Error parsing message: $e');
    }
  }

  @visibleForTesting
  void processBusNotificationForTesting(dynamic item) {
    _processBusNotification(item);
  }

  void _processBusNotification(dynamic item) {
    if (item is! Map) return;

    final type = item['type']?.toString();
    final payload = item['payload'];

    // Sự kiện Signaling RTC WebRTC P2P
    if (type == 'discuss.channel.rtc.session/peer_notification') {
      if (payload is Map) {
        _peerNotificationController.add(Map<String, dynamic>.from(payload));
      }
    }

    // Sự kiện kênh kết thúc cuộc gọi (hỗ trợ cả VMobile format & Odoo 19 Core sessionId)
    if (type == 'discuss.channel.rtc.session/ended') {
      if (payload is Map) {
        final chId = int.tryParse(payload['channel_id']?.toString() ?? '0') ?? 0;
        final sessionId = int.tryParse(payload['sessionId']?.toString() ?? '0') ?? 0;
        final state = payload['state']?.toString() ?? 'ended';
        final reason = payload['reason']?.toString();
        _callEndedController.add({
          'channel_id': chId,
          'sessionId': sessionId,
          'state': state,
          if (reason != null && reason.isNotEmpty) 'reason': reason,
        });
      }
    }

    // Sự kiện Odoo 17 Cập nhật RTC Sessions (Rời phòng / gác máy)
    if (type == 'discuss.channel/rtc_sessions_update' && payload is Map) {
      final chId = int.tryParse(payload['id']?.toString() ?? '0') ?? 0;
      final rtcSessions = payload['rtcSessions'];
      if (chId > 0 && rtcSessions is List) {
        for (final item in rtcSessions) {
          if (item is List && item.isNotEmpty && item[0] == 'DELETE') {
            debugPrint('📵 [OdooBus] Odoo 17 rtc_sessions_update DELETE kênh $chId -> Cuộc gọi kết thúc');
            _callEndedController.add({
              'channel_id': chId,
              'state': 'ended',
            });
            break;
          }
        }
      }
    }

    // Sự kiện Mail Record Insert: Mời tham gia hoặc hủy/kết thúc cuộc gọi (Odoo 19 & Odoo 17)
    if (type == 'mail.record/insert' && payload is Map) {
      _checkRtcInvitationInsert(payload);
      _checkRtcCallDelete(payload);
    }
  }

  void _checkRtcCallDelete(Map payload) {
    try {
      // 1. Hỗ trợ Odoo 17 Thread format
      final threadData = payload['Thread'];
      if (threadData != null) {
        final threadList = threadData is List ? threadData : [threadData];
        for (final th in threadList) {
          if (th is! Map) continue;
          final chId = int.tryParse(th['id']?.toString() ?? '0') ?? 0;
          if (chId <= 0) continue;

          // Odoo 17: rtcInvitingSession set to false -> Bị hủy / từ chối
          if (th.containsKey('rtcInvitingSession') && th['rtcInvitingSession'] == false) {
            debugPrint('📵 [OdooBus] Odoo 17 rtcInvitingSession false kênh $chId -> Cuộc gọi bị từ chối');
            final reason = th['reason']?.toString() ?? payload['reason']?.toString();
            _callEndedController.add({
              'channel_id': chId,
              'state': 'rejected',
              if (reason != null && reason.isNotEmpty) 'reason': reason,
            });
            continue;
          }

          // Odoo 17: invitedMembers chứa [('DELETE', ...)]
          final invited = th['invitedMembers'];
          if (invited is List) {
            for (final inv in invited) {
              if (inv is List && inv.isNotEmpty && inv[0] == 'DELETE') {
                debugPrint('📵 [OdooBus] Odoo 17 DELETE invitedMembers kênh $chId -> Cuộc gọi bị từ chối');
                final reason = (inv.length > 2 && inv[2] is Map && inv[2]['reason'] != null)
                    ? inv[2]['reason'].toString()
                    : (th['reason']?.toString() ?? payload['reason']?.toString());
                _callEndedController.add({
                  'channel_id': chId,
                  'state': 'rejected',
                  if (reason != null && reason.isNotEmpty) 'reason': reason,
                });
                break;
              }
            }
          }
        }
      }

      // 2. Hỗ trợ Odoo 19 discuss.channel format
      final channels = payload['discuss.channel'];
      if (channels is! List) return;

      for (final ch in channels) {
        if (ch is! Map) continue;
        final chId = int.tryParse(ch['id']?.toString() ?? '0') ?? 0;
        if (chId <= 0) continue;

        // 1. Kiểm tra invited_member_ids bị DELETE -> Đối phương từ chối / hủy lời mời
        final invited = ch['invited_member_ids'];
        if (invited is List) {
          for (final inv in invited) {
            if (inv is List && inv.isNotEmpty && inv[0] == 'DELETE') {
              debugPrint('📵 [OdooBus] Nhận DELETE invited_member_ids kênh $chId -> Cuộc gọi bị từ chối');
              final reason = (inv.length > 2 && inv[2] is Map && inv[2]['reason'] != null)
                  ? inv[2]['reason'].toString()
                  : (ch['reason']?.toString() ?? payload['reason']?.toString());
              _callEndedController.add({
                'channel_id': chId,
                'state': 'rejected',
                if (reason != null && reason.isNotEmpty) 'reason': reason,
              });
              break;
            }
          }
        }

        // 2. Kiểm tra rtc_session_ids bị DELETE -> Thành viên rời cuộc gọi
        final rtcSessions = ch['rtc_session_ids'];
        if (rtcSessions is List) {
          for (final rtc in rtcSessions) {
            if (rtc is List && rtc.isNotEmpty && rtc[0] == 'DELETE') {
              debugPrint('📵 [OdooBus] Nhận DELETE rtc_session_ids kênh $chId -> Cuộc gọi kết thúc');
              _callEndedController.add({
                'channel_id': chId,
                'state': 'ended',
              });
              break;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[OdooBus] Error checking RTC call delete: $e');
    }
  }

  void _checkRtcInvitationInsert(Map payload) {
    try {
      // 1. Hỗ trợ Odoo 17 Thread format
      final threadData = payload['Thread'];
      if (threadData != null) {
        final threadList = threadData is List ? threadData : [threadData];
        for (final th in threadList) {
          if (th is! Map) continue;
          final invSession = th['rtcInvitingSession'];
          if (invSession is Map && invSession['id'] != null) {
            final chId = int.tryParse(th['id']?.toString() ?? '0') ?? 0;
            final invId = int.tryParse(invSession['id'].toString()) ?? 0;
            if (chId > 0 && invId > 0) {
              String callerName = 'Đồng nghiệp';
              String? callerAvatar;
              int callerPartnerId = 0;

              final member = invSession['channelMember'];
              if (member is Map) {
                final persona = member['persona'];
                if (persona is Map && persona['partner'] is Map) {
                  final partner = persona['partner'] as Map;
                  callerPartnerId = int.tryParse(partner['id']?.toString() ?? '0') ?? 0;
                  callerName = partner['name']?.toString() ?? callerName;
                  if (callerPartnerId > 0) {
                    callerAvatar = '/api/v1/mobile/avatar/res.partner/$callerPartnerId?field=avatar_128';
                  }
                }
              }

              final myPartnerId = odooApiClient.session?.partnerId;
              if (myPartnerId == null || callerPartnerId != myPartnerId) {
                _incomingCallController.add({
                  'channel_id': chId,
                  'caller_id': callerPartnerId,
                  'caller_name': callerName,
                  'caller_avatar': callerAvatar,
                  'rtc_inviting_session_id': invId,
                });
                return;
              }
            }
          }
        }
      }

      // 2. Hỗ trợ Odoo 19 discuss.channel.member format
      final members = payload['discuss.channel.member'];
      if (members is! List) return;

      int channelId = 0;
      int rtcInvitingSessionId = 0;
      int callerPartnerId = 0;

      for (final m in members) {
        if (m is! Map) continue;
        if (m['rtc_inviting_session_id'] != null) {
          final invId = int.tryParse(m['rtc_inviting_session_id'].toString()) ?? 0;
          if (invId > 0) {
            rtcInvitingSessionId = invId;
            final ch = m['channel_id'];
            if (ch is Map && ch['id'] != null) {
              channelId = int.tryParse(ch['id'].toString()) ?? 0;
            } else if (ch is num) {
              channelId = ch.toInt();
            }
          }
        }
      }

      if (channelId > 0) {
        // Tìm thông tin caller partner từ danh sách partners
        String callerName = 'Đồng nghiệp';
        String? callerAvatar;
        final partners = payload['res.partner'];
        if (partners is List) {
          for (final p in partners) {
            if (p is Map && p['name'] != null) {
              final pid = int.tryParse(p['id']?.toString() ?? '0') ?? 0;
              // Nếu partner không phải chính user hiện tại
              final myPartnerId = odooApiClient.session?.partnerId;
              if (myPartnerId == null || pid != myPartnerId) {
                callerPartnerId = pid;
                callerName = p['name'].toString();
                callerAvatar = '/api/v1/mobile/avatar/res.partner/$pid?field=avatar_128';
                break;
              }
            }
          }
        }

        _incomingCallController.add({
          'channel_id': channelId,
          'caller_id': callerPartnerId,
          'caller_name': callerName,
          'caller_avatar': callerAvatar,
          'rtc_inviting_session_id': rtcInvitingSessionId,
        });
      }
    } catch (e) {
      debugPrint('[OdooBus] Error checking RTC invitation: $e');
    }
  }

  void _handleDisconnect() {
    _isConnected = false;
    _channel = null;
    _sub?.cancel();
    _sub = null;

    // Tự động kết nối lại với exponential backoff tối đa 5 lần
    _reconnectTimer?.cancel();
    if (_reconnectAttempts < _maxReconnectAttempts) {
      _reconnectAttempts++;
      final delaySeconds = (_reconnectAttempts * 2).clamp(2, 30);
      _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
        if (odooApiClient.session != null) {
          connect();
        }
      });
    }
  }

  void disconnect() {
    _reconnectTimer?.cancel();
    _reconnectAttempts = 0;
    _isConnected = false;
    _sub?.cancel();
    _sub = null;
    _channel?.sink.close();
    _channel = null;
    _subscribedChannels.clear();
  }

  void dispose() {
    disconnect();
    _peerNotificationController.close();
    _callEndedController.close();
    _incomingCallController.close();
  }
}
