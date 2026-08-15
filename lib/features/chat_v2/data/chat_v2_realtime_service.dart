import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../../core/api/odoo_api_client.dart';
import '../../auth/application/auth_controller.dart';
import 'models/chat_v2_message.dart';

/// Provider quản lý Realtime Service của Chat V2
final chatV2RealtimeServiceProvider = Provider<ChatV2RealtimeService>((ref) {
  final user = ref.watch(authControllerProvider).valueOrNull;

  final meta = user?.userMetadata;
  final partnerId = meta?['partner_id']?.toString() ??
      (meta?['partner'] is Map ? meta!['partner']['id']?.toString() : null);

  final service = ChatV2RealtimeService(
    baseUrl: odooApiClient.absoluteUrl(''),
    partnerId: partnerId,
    sessionToken: odooApiClient.session?.accessToken,
  );

  ref.onDispose(() {
    service.dispose();
  });

  return service;
});

/// Service kết nối WebSocket thời gian thực (Real-time duplex communication)
class ChatV2RealtimeService {
  ChatV2RealtimeService({
    required this.baseUrl,
    this.partnerId,
    this.sessionToken,
  }) {
    _initWebSocket();
  }

  final String baseUrl;
  final String? partnerId;
  final String? sessionToken;

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  bool _isDisposed = false;
  bool _isConnected = false;

  final _messageStreamController = StreamController<ChatV2Message>.broadcast();
  final _channelUpdateController = StreamController<String>.broadcast(); // Channel ID đã update
  final _typingStreamController = StreamController<Map<String, dynamic>>.broadcast();
  final _presenceStreamController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<ChatV2Message> get onMessageReceived => _messageStreamController.stream;
  Stream<String> get onChannelUpdated => _channelUpdateController.stream;
  Stream<Map<String, dynamic>> get onTypingStatusChanged => _typingStreamController.stream;
  Stream<Map<String, dynamic>> get onPresenceChanged => _presenceStreamController.stream;
  bool get isConnected => _isConnected;

  void _initWebSocket() {
    if (_isDisposed) return;

    try {
      final wsUri = _buildWsUri();
      if (wsUri == null) return;

      debugPrint('[ChatRealtime] Connecting to WebSocket: $wsUri');
      _channel = WebSocketChannel.connect(wsUri);

      _sub = _channel?.stream.listen(
        (data) {
          _isConnected = true;
          _handleMessage(data);
        },
        onError: (err) {
          debugPrint('[ChatRealtime] WebSocket error: $err');
          _handleDisconnect();
        },
        onDone: () {
          debugPrint('[ChatRealtime] WebSocket closed');
          _handleDisconnect();
        },
        cancelOnError: false,
      );

      _startHeartbeat();
      _subscribeChannels();
    } catch (e) {
      debugPrint('[ChatRealtime] Failed to connect WebSocket: $e');
      _handleDisconnect();
    }
  }

  Uri? _buildWsUri() {
    try {
      final uri = Uri.parse(baseUrl);
      final wsScheme = uri.scheme == 'https' ? 'wss' : 'ws';
      final host = uri.host;
      final port = uri.hasPort ? ':${uri.port}' : '';
      final token = sessionToken ?? odooApiClient.session?.accessToken ?? '';
      final queryParam = token.isNotEmpty ? '?access_token=$token' : '';
      return Uri.parse('$wsScheme://$host$port/websocket$queryParam');
    } catch (_) {
      return null;
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (_isConnected && _channel != null) {
        try {
          _channel?.sink.add(jsonEncode({'event_name': 'ping'}));
        } catch (_) {}
      }
    });
  }

  void _subscribeChannels() {
    if (_channel == null) return;
    try {
      final channels = <dynamic>[
        'discuss.channel',
        'mail.channel',
        if (partnerId != null && partnerId!.isNotEmpty) ...[
          'res.partner_$partnerId',
          'res.partner',
        ],
      ];
      final payload = {
        'event_name': 'subscribe',
        'data': {
          'channels': channels,
          'last': 0,
        }
      };
      _channel?.sink.add(jsonEncode(payload));
    } catch (e) {
      debugPrint('[ChatRealtime] Subscribe error: $e');
    }
  }

  void _handleMessage(dynamic rawData) {
    try {
      final String text = rawData.toString();
      final decoded = jsonDecode(text);

      if (decoded is List) {
        for (final item in decoded) {
          _processBusPayload(item);
        }
      } else if (decoded is Map<String, dynamic>) {
        _processBusPayload(decoded);
      }
    } catch (e) {
      debugPrint('[ChatRealtime] Parse message error: $e');
    }
  }

  void _processBusPayload(dynamic item) {
    if (item is! Map<String, dynamic>) return;

    // Trong Odoo 17, item có thể là { "id": 1, "message": { "type": ..., "payload": ... } }
    final dynamic msgObj = item.containsKey('message') ? item['message'] : item;
    if (msgObj is! Map<String, dynamic>) return;

    final type = msgObj['type']?.toString();
    final payload = msgObj['payload'];

    // Xử lý sự kiện tin nhắn mới từ Odoo Bus
    if (type == 'mail.record/insert' ||
        type == 'discuss.channel/new_message' ||
        type == 'mail.message/notification' ||
        type == 'discuss.channel/transient_message') {
      if (payload is Map<String, dynamic>) {
        final channelId = payload['channel_id']?.toString() ??
            payload['res_id']?.toString() ??
            payload['id']?.toString();
        if (channelId != null && channelId.isNotEmpty) {
          _channelUpdateController.add(channelId);
        }

        try {
          final msg = ChatV2Message.fromMap(payload);
          if (msg.content.isNotEmpty || msg.attachments.isNotEmpty) {
            _messageStreamController.add(msg);
          }
        } catch (_) {}
      } else if (payload is List) {
        for (final p in payload) {
          if (p is Map<String, dynamic>) {
            final channelId = p['channel_id']?.toString() ??
                p['res_id']?.toString();
            if (channelId != null && channelId.isNotEmpty) {
              _channelUpdateController.add(channelId);
            }
            try {
              final msg = ChatV2Message.fromMap(p);
              if (msg.content.isNotEmpty || msg.attachments.isNotEmpty) {
                _messageStreamController.add(msg);
              }
            } catch (_) {}
          }
        }
      }
    } else if (type == 'discuss.channel.member/seen' ||
        type == 'discuss.channel/member_seen') {
      if (payload is Map<String, dynamic>) {
        final channelId = payload['channel_id']?.toString();
        if (channelId != null && channelId.isNotEmpty) {
          _channelUpdateController.add(channelId);
        }
      }
    } else if (type == 'discuss.channel/typing_status' || type == 'discuss.channel/typing') {
      if (payload is Map<String, dynamic>) {
        _typingStreamController.add(payload);
      }
    } else if (type == 'res.partner/im_status' || type == 'im_status') {
      if (payload is Map<String, dynamic>) {
        _presenceStreamController.add(payload);
      } else if (payload is List) {
        for (final p in payload) {
           if (p is Map<String, dynamic>) _presenceStreamController.add(p);
        }
      }
    }
  }

  int _reconnectAttempts = 0;

  void _handleDisconnect() {
    _isConnected = false;
    _heartbeatTimer?.cancel();
    _sub?.cancel();
    _channel = null;

    if (!_isDisposed) {
      _reconnectTimer?.cancel();
      // Exponential Backoff: 3s -> 6s -> 12s -> 24s (tối đa 30s)
      final delaySeconds = (3 * (1 << _reconnectAttempts.clamp(0, 3))).clamp(3, 30);
      _reconnectAttempts++;

      _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
        if (!_isDisposed) {
          _initWebSocket();
        }
      });
    }
  }

  /// Gửi trạng thái typing (gọi REST API)
  Future<void> sendTypingStatus(String channelId, bool isTyping) async {
    try {
      await odooApiClient.post(
        '/api/v1/mobile/chat/channels/$channelId/typing',
        body: {'is_typing': isTyping},
      );
    } catch (_) {}
  }

  /// Thông báo thủ công khi có tin nhắn gửi thành công
  void notifyMessageSent(String channelId, ChatV2Message msg) {
    _messageStreamController.add(msg);
    _channelUpdateController.add(channelId);
  }

  void dispose() {
    _isDisposed = true;
    _isConnected = false;
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    _sub?.cancel();
    _channel?.sink.close();
    _messageStreamController.close();
    _channelUpdateController.close();
    _typingStreamController.close();
    _presenceStreamController.close();
  }
}
