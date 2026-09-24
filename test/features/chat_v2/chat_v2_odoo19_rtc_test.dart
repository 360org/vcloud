import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vcloud/core/api/odoo_api_client.dart';
import 'package:vcloud/features/chat_v2/data/chat_v2_call_repository.dart';
import 'package:vcloud/features/chat_v2/data/odoo_bus_service.dart';
import 'package:vcloud/features/chat_v2/domain/models/chat_v2_call_session.dart';
import 'package:vcloud/features/chat_v2/application/chat_v2_call_controller.dart';
import 'package:vcloud/features/chat_v2/application/chat_v2_webrtc_engine.dart';

/// Fake API Client mô phỏng JSON-RPC Odoo 19 Discuss RTC Core
class FakeOdoo19RtcApiClient extends OdooApiClient {
  FakeOdoo19RtcApiClient() : super(baseUrl: 'http://localhost:8069');

  final List<Map<String, dynamic>> recordedCalls = [];

  @override
  Future<dynamic> post(
    String path, {
    Object? body,
    Map<String, Object?> query = const <String, Object?>{},
    bool auth = true,
  }) async {
    recordedCalls.add({
      'path': path,
      'body': body,
    });

    if (path == '/mail/rtc/channel/join_call') {
      return {
        'jsonrpc': '2.0',
        'result': {
          'Rtc': {
            'localSession': {'id': 789},
            'iceServers': [
              {
                'urls': ['stun:stun.vuahethong.net:3478']
              }
            ],
            'serverInfo': null,
          },
          'discuss.channel_123': {
            'rtc_session_ids': [
              {'id': 789},
              {'id': 456}
            ],
          }
        }
      };
    }

    if (path == '/mail/rtc/session/notify_call_members') {
      return {'jsonrpc': '2.0', 'result': true};
    }

    if (path == '/mail/rtc/channel/leave_call') {
      return {'jsonrpc': '2.0', 'result': true};
    }

    if (path == '/mail/rtc/channel/cancel_call_invitation') {
      return {'jsonrpc': '2.0', 'result': true};
    }

    if (path == '/mail/rtc/session/update_and_broadcast') {
      return {'jsonrpc': '2.0', 'result': true};
    }

    return {'jsonrpc': '2.0', 'result': null};
  }
}

/// Fake Odoo Bus Service để kiểm soát sự kiện WebSocket phát sinh
class FakeOdooBusService extends OdooBusService {
  final _peerController = StreamController<Map<String, dynamic>>.broadcast();
  final _endedController = StreamController<int>.broadcast();

  @override
  Stream<Map<String, dynamic>> get onPeerNotification => _peerController.stream;

  @override
  Stream<int> get onCallEnded => _endedController.stream;

  void emitPeerNotification(Map<String, dynamic> data) {
    _peerController.add(data);
  }

  void emitCallEnded(int channelId) {
    _endedController.add(channelId);
  }

  @override
  void dispose() {
    _peerController.close();
    _endedController.close();
    super.dispose();
  }
}

/// Fake WebRTC Engine cho Unit Tests (không gọi platform channels FlutterWebRTC.Method)
class FakeChatV2WebRtcEngine extends ChatV2WebRtcEngine {
  FakeChatV2WebRtcEngine({required super.repo});

  bool initialized = false;
  bool offerCreated = false;
  String? lastHandledOffer;
  String? lastHandledAnswer;
  Map<String, dynamic>? lastHandledCandidate;

  @override
  Future<void> initialize({
    required int localSessionId,
    required List<int> targetSessionIds,
    required List<dynamic> iceServersData,
  }) async {
    initialized = true;
  }

  @override
  Future<void> createAndSendOffer() async {
    offerCreated = true;
  }

  @override
  Future<void> handleOfferAndSendAnswer(Map<String, dynamic> sdpMap) async {
    lastHandledOffer = sdpMap['sdp']?.toString();
  }

  @override
  Future<void> handleAnswer(Map<String, dynamic> sdpMap) async {
    lastHandledAnswer = sdpMap['sdp']?.toString();
  }

  @override
  Future<void> handleRemoteCandidate(Map<String, dynamic> candidateMap) async {
    lastHandledCandidate = candidateMap;
  }

  @override
  Future<void> dispose() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global'),
      (methodCall) async => 1,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (methodCall) async => 1,
    );
  });

  group('Odoo 19 RTC Voice Call Test Suite (10 Test Cases)', () {
    late FakeOdoo19RtcApiClient apiClient;
    late ChatV2CallRepository repo;
    late FakeOdooBusService bus;
    late FakeChatV2WebRtcEngine fakeEngine;
    late ChatV2CallController controller;

    setUp(() {
      apiClient = FakeOdoo19RtcApiClient();
      repo = ChatV2CallRepository(client: apiClient);
      bus = FakeOdooBusService();
      fakeEngine = FakeChatV2WebRtcEngine(repo: repo);
      controller = ChatV2CallController(
        repo: repo,
        bus: bus,
        webrtcEngine: fakeEngine,
      );
    });

    tearDown(() {
      controller.dispose();
      bus.dispose();
    });

    test('TC-CALL-01: OdooRtcJoinResult parser trích xuất đúng localSessionId và iceServers', () {
      final store = {
        'Rtc': {
          'localSession': {'id': 789},
          'iceServers': [
            {'urls': 'stun:stun.vuahethong.net:3478'}
          ],
        },
        'discuss.channel_123': {
          'rtc_session_ids': [
            {'id': 789},
            {'id': 456},
          ],
        }
      };

      final result = OdooRtcJoinResult.fromStore(store);
      expect(result.localSessionId, 789);
      expect(result.iceServers.length, 1);
      expect(result.currentRtcSessionIds, contains(456));
      expect(result.currentRtcSessionIds, isNot(contains(789))); // Không chứa chính mình
    });

    test('TC-CALL-02: joinCall gọi đúng endpoint /mail/rtc/channel/join_call qua JSON-RPC', () async {
      final joinRes = await repo.joinCall(channelId: 123);
      expect(joinRes, isNotNull);
      expect(joinRes!.localSessionId, 789);

      final call = apiClient.recordedCalls.firstWhere((c) => c['path'] == '/mail/rtc/channel/join_call');
      expect(call['body']['jsonrpc'], '2.0');
      expect(call['body']['params']['channel_id'], 123);
      expect(call['body']['params']['camera'], false);
    });

    test('TC-CALL-03: notifyCallMembers gửi đúng cấu trúc peer_notifications tuple', () async {
      final success = await repo.notifyCallMembers(
        senderSessionId: 789,
        targetSessionIds: [456],
        content: '{"event":"offer"}',
      );
      expect(success, true);

      final call = apiClient.recordedCalls.firstWhere((c) => c['path'] == '/mail/rtc/session/notify_call_members');
      final notifications = call['body']['params']['peer_notifications'] as List;
      expect(notifications.length, 1);
      expect(notifications[0][0], 789);
      expect(notifications[0][1], [456]);
      expect(notifications[0][2], '{"event":"offer"}');
    });

    test('TC-CALL-04: leaveCall gửi channel_id và session_id đến /mail/rtc/channel/leave_call', () async {
      final success = await repo.leaveCall(channelId: 123, sessionId: 789);
      expect(success, true);

      final call = apiClient.recordedCalls.firstWhere((c) => c['path'] == '/mail/rtc/channel/leave_call');
      expect(call['body']['params']['channel_id'], 123);
      expect(call['body']['params']['session_id'], 789);
    });

    test('TC-CALL-05: cancelCallInvitation hủy lời mời gọi qua /mail/rtc/channel/cancel_call_invitation', () async {
      final success = await repo.cancelCallInvitation(channelId: 123, memberIds: [10, 20]);
      expect(success, true);

      final call = apiClient.recordedCalls.firstWhere((c) => c['path'] == '/mail/rtc/channel/cancel_call_invitation');
      expect(call['body']['params']['channel_id'], 123);
      expect(call['body']['params']['member_ids'], [10, 20]);
    });

    test('TC-CALL-06: updateAndBroadcast cập nhật trạng thái mute/camera lên Odoo', () async {
      final success = await repo.updateAndBroadcast(
        sessionId: 789,
        values: {'is_muted': true},
      );
      expect(success, true);

      final call = apiClient.recordedCalls.firstWhere((c) => c['path'] == '/mail/rtc/session/update_and_broadcast');
      expect(call['body']['params']['session_id'], 789);
      expect(call['body']['params']['values']['is_muted'], true);
    });

    test('TC-CALL-07: startCall tham gia phòng Odoo 19 RTC và chuyển trạng thái outgoingRinging', () async {
      final success = await controller.startCall(
        channelId: 123,
        callerName: 'Tân Nguyễn',
        receiverId: 5,
        receiverName: 'Đồng nghiệp',
      );

      expect(success, true);
      expect(controller.state, isNotNull);
      expect(controller.state!.id, 789);
      expect(controller.state!.channelId, 123);
      expect(controller.state!.state, ChatV2CallState.outgoingRinging);
      expect(controller.state!.isCaller, true);
      expect(fakeEngine.initialized, true);
      expect(fakeEngine.offerCreated, true);
    });

    test('TC-CALL-08: Bus peer_notification nhận và xử lý bản tin signaling an toàn', () async {
      await controller.startCall(
        channelId: 123,
        callerName: 'Tân Nguyễn',
        receiverId: 5,
        receiverName: 'Đồng nghiệp',
      );

      // Bắn bản tin Bus peer_notification mô phỏng SDP Answer từ phía Web
      bus.emitPeerNotification({
        'sender': 456,
        'notifications': [
          '{"event":"answer","channelId":123,"payload":{"sdp":{"type":"answer","sdp":"mock_remote_answer_sdp"}}}'
        ]
      });

      // Cho asynchronous event vòng qua event loop
      await Future.delayed(const Duration(milliseconds: 10));

      expect(fakeEngine.lastHandledAnswer, 'mock_remote_answer_sdp');
      expect(controller.state?.state, ChatV2CallState.outgoingRinging);
    });

    test('TC-CALL-09: Bus onCallEnded kích hoạt khi đối phương gác máy, chuyển state sang ended', () async {
      await controller.startCall(
        channelId: 123,
        callerName: 'Tân Nguyễn',
        receiverId: 5,
        receiverName: 'Đồng nghiệp',
      );

      // Đối phương gác máy trên Odoo Bus
      bus.emitCallEnded(123);
      await Future.delayed(const Duration(milliseconds: 10));

      expect(controller.state?.state, ChatV2CallState.ended);
    });

    test('TC-CALL-10: Callee bấm Từ chối gọi leaveCall giải phóng phiên an toàn', () async {
      const incoming = ChatV2CallSession(
        id: 789,
        channelId: 123,
        callerId: 2,
        callerName: 'Mitchell Admin',
        receiverId: 5,
        receiverName: 'Tân Nguyễn',
        state: ChatV2CallState.incomingRinging,
        isCaller: false,
      );

      controller.setIncomingCall(incoming);
      expect(controller.state?.state, ChatV2CallState.incomingRinging);

      await controller.rejectCall();
      expect(controller.state?.state, ChatV2CallState.rejected);

      final leaveCall = apiClient.recordedCalls.any((c) => c['path'] == '/mail/rtc/channel/leave_call');
      expect(leaveCall, true);
    });
  });
}
