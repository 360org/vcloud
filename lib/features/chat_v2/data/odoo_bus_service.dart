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
  final _callEndedController = StreamController<int>.broadcast();

  Stream<Map<String, dynamic>> get onPeerNotification => _peerNotificationController.stream;
  Stream<int> get onCallEnded => _callEndedController.stream;
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

    // Sự kiện kênh kết thúc cuộc gọi
    if (type == 'discuss.channel.rtc.session/ended') {
      if (payload is Map && payload['channel_id'] != null) {
        final chId = int.tryParse(payload['channel_id'].toString()) ?? 0;
        _callEndedController.add(chId);
      }
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
  }
}
