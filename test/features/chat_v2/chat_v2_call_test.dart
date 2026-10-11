import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:vcloud/features/chat_v2/domain/models/chat_v2_call_session.dart';
import 'package:vcloud/features/chat_v2/data/chat_v2_call_repository.dart';
import 'package:vcloud/features/chat_v2/data/odoo_bus_service.dart';
import 'package:vcloud/features/chat_v2/application/chat_v2_call_controller.dart';
import 'package:vcloud/features/chat_v2/application/chat_v2_webrtc_engine.dart';
import 'package:vcloud/core/api/odoo_api_client.dart';

class FakeCallApiClient extends OdooApiClient {
  FakeCallApiClient() : super(baseUrl: 'http://localhost:8069');

  Map<String, dynamic>? mockResponse;
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
    if (path.contains('/leave_call')) {
      return {'jsonrpc': '2.0', 'result': true};
    }
    if (path.contains('/join_call')) {
      return {
        'jsonrpc': '2.0',
        'result': {
          'Rtc': {
            'localSession': {'id': 101},
            'iceServers': [],
          },
          'rtcSessions': [],
        }
      };
    }
    if (path.contains('/initiate')) {
      return {
        'status': 'success',
        'call': {
          'id': 101,
          'channel_id': 4255,
          'caller_id': 2,
          'caller_name': 'Marc Demo',
          'receiver_id': 5,
          'receiver_name': 'Bùi Tuấn Kiệt',
          'state': 'ringing',
          'duration': 0,
          'is_caller': true,
        }
      };
    }
    if (path.contains('/accept')) {
      return {
        'status': 'success',
        'call': {
          'id': 101,
          'channel_id': 4255,
          'caller_id': 2,
          'caller_name': 'Marc Demo',
          'receiver_id': 5,
          'receiver_name': 'Bùi Tuấn Kiệt',
          'state': 'connected',
          'duration': 0,
          'is_caller': false,
        }
      };
    }
    if (path.contains('/reject') || path.contains('/cancel') || path.contains('/end')) {
      return {'status': 'success'};
    }
    return mockResponse ?? {'status': 'success'};
  }

  @override
  Future<dynamic> get(
    String path, {
    Map<String, Object?> query = const <String, Object?>{},
    bool auth = true,
  }) async {
    if (path.contains('/config')) {
      return {
        'ice_servers': [
          {'urls': ['stun:stun.l.google.com:19302']},
          {
            'urls': ['turn:turn.vuahethong.net:3478?transport=udp'],
            'username': '1760000000:vcloud_2',
            'credential': 'dyn_hmac_sha1_sample_credential_token',
          }
        ]
      };
    }
    if (path.contains('/active')) {
      return {
        'active_call': {
          'id': 101,
          'channel_id': 4255,
          'caller_id': 2,
          'caller_name': 'Marc Demo',
          'receiver_id': 5,
          'receiver_name': 'Bùi Tuấn Kiệt',
          'state': 'ringing',
          'duration': 0,
          'is_caller': false,
        }
      };
    }
    if (path.contains('/101')) {
      return {
        'call': {
          'id': 101,
          'channel_id': 4255,
          'caller_id': 2,
          'caller_name': 'Marc Demo',
          'receiver_id': 5,
          'receiver_name': 'Bùi Tuấn Kiệt',
          'state': 'connected',
          'duration': 15,
          'is_caller': true,
        }
      };
    }
    return mockResponse ?? {};
  }
}

class FakeOdooBusService extends OdooBusService {
  final _peerController = StreamController<Map<String, dynamic>>.broadcast();
  final _endedController = StreamController<Map<String, dynamic>>.broadcast();
  final _incomingController = StreamController<Map<String, dynamic>>.broadcast();
  final _acceptedController = StreamController<Map<String, dynamic>>.broadcast();
  final _peerJoinedController = StreamController<Map<String, dynamic>>.broadcast();

  @override
  Stream<Map<String, dynamic>> get onPeerNotification => _peerController.stream;

  @override
  Stream<Map<String, dynamic>> get onCallEnded => _endedController.stream;

  @override
  Stream<Map<String, dynamic>> get onIncomingCall => _incomingController.stream;

  @override
  Stream<Map<String, dynamic>> get onCallAccepted => _acceptedController.stream;

  @override
  Stream<Map<String, dynamic>> get onPeerJoined => _peerJoinedController.stream;

  void emitPeerNotification(Map<String, dynamic> data) {
    _peerController.add(data);
  }

  void emitCallEnded({int channelId = 0, int sessionId = 0, String? state, String? reason}) {
    _endedController.add({
      'channel_id': channelId,
      'sessionId': sessionId,
      'state': state,
      'reason': ?reason,
    });
  }

  void emitIncomingCall(Map<String, dynamic> data) {
    _incomingController.add(data);
  }

  void emitCallAccepted(Map<String, dynamic> data) {
    _acceptedController.add(data);
  }

  void emitPeerJoined(Map<String, dynamic> data) {
    _peerJoinedController.add(data);
  }

  @override
  void dispose() {
    _peerController.close();
    _endedController.close();
    _incomingController.close();
    _acceptedController.close();
    _peerJoinedController.close();
    super.dispose();
  }
}

class FakeWebRtcEngine extends ChatV2WebRtcEngine {
  FakeWebRtcEngine({required super.repo});

  List<int>? lastUpdatedTargetSessionIds;
  bool createAndSendOfferCalled = false;
  Map<String, dynamic>? lastHandledAnswer;

  @override
  Future<void> initialize({
    required int localSessionId,
    required List<int> targetSessionIds,
    required List<dynamic> iceServersData,
  }) async {}

  @override
  void updateTargetSessionIds(List<int> targetIds) {
    lastUpdatedTargetSessionIds = List<int>.from(targetIds);
  }

  @override
  Future<void> createAndSendOffer() async {
    createAndSendOfferCalled = true;
  }

  @override
  Future<void> handleOfferAndSendAnswer(Map<String, dynamic> sdpMap) async {}

  @override
  Future<void> handleAnswer(Map<String, dynamic> sdpMap) async {
    lastHandledAnswer = sdpMap;
  }

  @override
  Future<void> handleRemoteCandidate(Map<String, dynamic> candidateMap) async {}

  @override
  Future<void> dispose() async {}

  void triggerConnectionState(RTCPeerConnectionState state) {
    onConnectionState?.call(state);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('xyz.luan/audioplayers.global'),
    (MethodCall methodCall) async => 1,
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('xyz.luan/audioplayers'),
    (MethodCall methodCall) async => 1,
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('flutter_callkit_incoming'),
    (MethodCall methodCall) async => null,
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
    const MethodChannel('FlutterWebRTC.Method'),
    (MethodCall methodCall) async {
      if (methodCall.method == 'createPeerConnection') {
        return {'peerConnectionId': 'pc-test-101'};
      }
      if (methodCall.method == 'getUserMedia') {
        return {
          'streamId': 'stream-test-101',
          'audioTracks': [
            {'id': 'track-audio-1', 'label': 'mic', 'kind': 'audio', 'enabled': true}
          ],
          'videoTracks': [],
        };
      }
      if (methodCall.method == 'addTrack') {
        return {
          'senderId': 'sender-1',
          'track': <String, dynamic>{},
          'rtpParameters': {
            'transactionId': '',
            'encodings': [],
            'headerExtensions': [],
            'codecs': [],
            'rtcp': {'cname': '', 'reducedSize': false},
          },
          'ownsTrack': false,
        };
      }
      return {};
    },
  );

  group('ChatV2CallSession Model Tests', () {
    test('TC-01: Parse from JSON correctly', () {
      final json = {
        'id': 101,
        'channel_id': 4255,
        'caller_id': 2,
        'caller_name': 'Marc Demo',
        'caller_avatar': '/web/image/res.partner/3/avatar_128',
        'receiver_id': 5,
        'receiver_name': 'Bùi Tuấn Kiệt',
        'receiver_avatar': null,
        'state': 'ringing',
        'duration': 0,
        'is_caller': true,
      };

      final session = ChatV2CallSession.fromJson(json);

      expect(session.id, 101);
      expect(session.channelId, 4255);
      expect(session.callerName, 'Marc Demo');
      expect(session.receiverName, 'Bùi Tuấn Kiệt');
      expect(session.state, ChatV2CallState.outgoingRinging);
      expect(session.isCaller, true);
    });

    test('TC-02: Formatted duration mm:ss', () {
      const session0 = ChatV2CallSession(
        id: 1,
        channelId: 1,
        callerId: 1,
        callerName: 'A',
        receiverId: 2,
        receiverName: 'B',
        state: ChatV2CallState.connected,
        duration: 0,
      );
      expect(session0.formattedDuration, '00:00');

      const session65 = ChatV2CallSession(
        id: 1,
        channelId: 1,
        callerId: 1,
        callerName: 'A',
        receiverId: 2,
        receiverName: 'B',
        state: ChatV2CallState.connected,
        duration: 65,
      );
      expect(session65.formattedDuration, '01:05');

      const session3600 = ChatV2CallSession(
        id: 1,
        channelId: 1,
        callerId: 1,
        callerName: 'A',
        receiverId: 2,
        receiverName: 'B',
        state: ChatV2CallState.connected,
        duration: 125,
      );
      expect(session3600.formattedDuration, '02:05');
    });
  });

  group('ChatV2CallController Lifecycle & State Machine Tests', () {
    late FakeCallApiClient fakeClient;
    late ChatV2CallRepository repo;
    late FakeWebRtcEngine fakeEngine;
    late ChatV2CallController controller;

    setUp(() {
      fakeClient = FakeCallApiClient();
      repo = ChatV2CallRepository(client: fakeClient);
      fakeEngine = FakeWebRtcEngine(repo: repo);
      controller = ChatV2CallController(repo: repo, webrtcEngine: fakeEngine);
    });

    tearDown(() {
      controller.dispose();
    });

    test('TC-03: startCall transitions to outgoingRinging and saves session', () async {
      final success = await controller.startCall(
        channelId: 4255,
        callerName: 'Marc Demo',
        receiverId: 5,
        receiverName: 'Bùi Tuấn Kiệt',
      );

      expect(success, true);
      expect(controller.state, isNotNull);
      expect(controller.state!.id, 101);
      expect(controller.state!.state, ChatV2CallState.outgoingRinging);
      expect(controller.state!.isCaller, true);
    });

    test('TC-04: setIncomingCall and acceptCall transition to connected', () async {
      const incoming = ChatV2CallSession(
        id: 101,
        channelId: 4255,
        callerId: 2,
        callerName: 'Marc Demo',
        receiverId: 5,
        receiverName: 'Bùi Tuấn Kiệt',
        state: ChatV2CallState.incomingRinging,
        isCaller: false,
      );

      controller.setIncomingCall(incoming);
      expect(controller.state?.state, ChatV2CallState.incomingRinging);

      await controller.acceptCall();
      fakeEngine.triggerConnectionState(RTCPeerConnectionState.RTCPeerConnectionStateConnected);
      expect(controller.state?.state, ChatV2CallState.connected);
    });

    test('TC-05: rejectCall transitions to rejected', () async {
      const incoming = ChatV2CallSession(
        id: 101,
        channelId: 4255,
        callerId: 2,
        callerName: 'Marc Demo',
        receiverId: 5,
        receiverName: 'Bùi Tuấn Kiệt',
        state: ChatV2CallState.incomingRinging,
        isCaller: false,
      );

      controller.setIncomingCall(incoming);
      await controller.rejectCall();
      expect(controller.state?.state, ChatV2CallState.rejected);
    });

    test('TC-06: cancelCall transitions to cancelled', () async {
      await controller.startCall(
        channelId: 4255,
        callerName: 'Marc Demo',
        receiverId: 5,
        receiverName: 'Bùi Tuấn Kiệt',
      );

      await controller.cancelCall();
      expect(controller.state?.state, ChatV2CallState.cancelled);
    });

    test('TC-07: endCall transitions to ended', () async {
      const session = ChatV2CallSession(
        id: 101,
        channelId: 4255,
        callerId: 2,
        callerName: 'Marc Demo',
        receiverId: 5,
        receiverName: 'Bùi Tuấn Kiệt',
        state: ChatV2CallState.connected,
        duration: 45,
      );

      controller.setIncomingCall(session);
      await controller.endCall();
      expect(controller.state?.state, ChatV2CallState.ended);
    });

    test('TC-08: toggleMute and toggleSpeaker flip boolean flags', () {
      expect(controller.isMuted, false);
      controller.toggleMute();
      expect(controller.isMuted, true);
      controller.toggleMute();
      expect(controller.isMuted, false);

      expect(controller.isSpeaker, false);
      controller.toggleSpeaker();
      expect(controller.isSpeaker, true);
      controller.toggleSpeaker();
      expect(controller.isSpeaker, false);
    });

    test('TC-09: reset cleans up state safely', () {
      controller.toggleMute();
      controller.reset();
      expect(controller.state, isNull);
      expect(controller.isMuted, false);
      expect(controller.isSpeaker, false);
    });

    test('TC-10: getActiveCall parses incoming call correctly for receiver', () async {
      final active = await repo.getActiveCall();
      expect(active, isNotNull);
      expect(active?.id, 101);
      expect(active?.state, ChatV2CallState.incomingRinging);
      expect(active?.callerName, 'Marc Demo');
    });

    test('TC-11: Call status message strings parse cleanly', () {
      const missedMsg = '❌ Cuộc gọi nhỡ lúc 15:45';
      const successMsg = '📞 Cuộc gọi thoại (02:15)';
      const rejectMsg = '🚫 Cuộc gọi bị từ chối';
      const cancelMsg = '📵 Cuộc gọi đã hủy';

      expect(missedMsg.contains('nhỡ'), true);
      expect(successMsg.contains('Cuộc gọi thoại'), true);
      expect(rejectMsg.contains('từ chối'), true);
      expect(cancelMsg.contains('hủy'), true);
    });
  });

  group('Odoo 17 & 19 Dual-Version RTC & Bus Compatibility Tests', () {
    test('TC-12: Odoo 19 Store format parses localSession and iceServers', () {
      final store19 = {
        'Rtc': {
          'localSession': 14,
          'iceServers': [
            {'urls': 'stun:stun.l.google.com:19302'}
          ],
        },
        'discuss.channel_3': {
          'rtc_session_ids': [
            [
              'ADD',
              [14, 15]
            ]
          ],
        }
      };
      final res = OdooRtcJoinResult.fromStore(store19);
      expect(res.localSessionId, 14);
      expect(res.iceServers.length, 1);
      expect(res.currentRtcSessionIds, contains(15));
      expect(res.currentRtcSessionIds, isNot(contains(14)));
    });

    test('TC-13: Odoo 17 root format parses sessionId, iceServers and rtcSessions', () {
      final store17 = {
        'sessionId': 4,
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'}
        ],
        'rtcSessions': [
          [
            'ADD',
            [
              {'id': 4},
              {'id': 9}
            ]
          ],
          [
            'DELETE',
            [
              {'id': 2}
            ]
          ]
        ],
        'serverInfo': null,
      };
      final res = OdooRtcJoinResult.fromStore(store17);
      expect(res.localSessionId, 4);
      expect(res.iceServers.length, 1);
      expect(res.currentRtcSessionIds, contains(9));
      expect(res.currentRtcSessionIds, isNot(contains(4)));
    });

    test('TC-14: Odoo 17 Thread format rejection emits callEnded event', () async {
      final busService = OdooBusService();
      Map<String, dynamic>? endedData;
      final sub = busService.onCallEnded.listen((data) => endedData = data);

      busService.processBusNotificationForTesting({
        'type': 'mail.record/insert',
        'payload': {
          'Thread': {
            'id': 42,
            'model': 'discuss.channel',
            'rtcInvitingSession': false,
          }
        }
      });

      await Future.delayed(Duration.zero);
      expect(endedData, isNotNull);
      expect(endedData?['channel_id'], 42);
      expect(endedData?['state'], 'rejected');
      await sub.cancel();
      busService.dispose();
    });

    test('TC-15: Odoo 17 Thread format invitedMembers DELETE emits callEnded event', () async {
      final busService = OdooBusService();
      Map<String, dynamic>? endedData;
      final sub = busService.onCallEnded.listen((data) => endedData = data);

      busService.processBusNotificationForTesting({
        'type': 'mail.record/insert',
        'payload': {
          'Thread': {
            'id': 55,
            'model': 'discuss.channel',
            'invitedMembers': [
              [
                'DELETE',
                [10]
              ]
            ],
          }
        }
      });

      await Future.delayed(Duration.zero);
      expect(endedData, isNotNull);
      expect(endedData?['channel_id'], 55);
      expect(endedData?['state'], 'rejected');
      await sub.cancel();
      busService.dispose();
    });

    test('TC-16: Odoo 17 rtc_sessions_update DELETE emits callEnded event', () async {
      final busService = OdooBusService();
      Map<String, dynamic>? endedData;
      final sub = busService.onCallEnded.listen((data) => endedData = data);

      busService.processBusNotificationForTesting({
        'type': 'discuss.channel/rtc_sessions_update',
        'payload': {
          'id': 77,
          'rtcSessions': [
            [
              'DELETE',
              [
                {'id': 12}
              ]
            ]
          ],
        }
      });

      await Future.delayed(Duration.zero);
      expect(endedData, isNotNull);
      expect(endedData?['channel_id'], 77);
      expect(endedData?['state'], 'ended');
      await sub.cancel();
      busService.dispose();
    });

    test('TC-17: Odoo 17 Thread incoming call invitation triggers onIncomingCall', () async {
      final busService = OdooBusService();
      Map<String, dynamic>? incomingData;
      final sub = busService.onIncomingCall.listen((data) => incomingData = data);

      busService.processBusNotificationForTesting({
        'type': 'mail.record/insert',
        'payload': {
          'Thread': {
            'id': 88,
            'model': 'discuss.channel',
            'rtcInvitingSession': {
              'id': 999,
              'channelMember': {
                'id': 12,
                'persona': {
                  'partner': {
                    'id': 99,
                    'name': 'Nguyễn Văn A',
                  }
                }
              }
            }
          }
        }
      });

      await Future.delayed(Duration.zero);
      expect(incomingData, isNotNull);
      expect(incomingData?['channel_id'], 88);
      expect(incomingData?['caller_name'], 'Nguyễn Văn A');
      expect(incomingData?['rtc_inviting_session_id'], 999);
      await sub.cancel();
      busService.dispose();
    });

    test('TC-34: Third-party incoming call while connected triggers fast-busy and preserves active call', () async {
      final fakeClient = FakeCallApiClient();
      final testRepo = ChatV2CallRepository(client: fakeClient);
      final fakeBus = FakeOdooBusService();
      final fakeEngine = FakeWebRtcEngine(repo: testRepo);
      final ctl = ChatV2CallController(repo: testRepo, bus: fakeBus, webrtcEngine: fakeEngine);

      // 1. Phía Receiver: Đang trong cuộc đàm thoại (Call 1: channelId 4255, sessionId 101)
      const currentCall = ChatV2CallSession(
        id: 101,
        channelId: 4255,
        callerId: 2,
        callerName: 'Marc Demo',
        receiverId: 5,
        receiverName: 'Bùi Tuấn Kiệt',
        state: ChatV2CallState.connected,
        duration: 45,
        isCaller: false,
      );
      ctl.setIncomingCall(currentCall);
      await ctl.acceptCall();
      fakeEngine.triggerConnectionState(RTCPeerConnectionState.RTCPeerConnectionStateConnected);
      expect(ctl.state?.state, ChatV2CallState.connected);
      expect(ctl.state?.id, 101);
      fakeClient.recordedCalls.clear();

      // 2. Bên thứ 3 (Người gọi C) thực hiện gọi tới kênh 8888 (Call 2)
      const thirdPartyCall = ChatV2CallSession(
        id: 202,
        channelId: 8888,
        callerId: 99,
        callerName: 'Lê Văn C',
        receiverId: 5,
        receiverName: 'Bùi Tuấn Kiệt',
        state: ChatV2CallState.incomingRinging,
        isCaller: false,
      );

      // Nhận incoming call thứ 3 khi đang connected
      ctl.setIncomingCall(thirdPartyCall);

      // 3. Kiểm chứng phía Receiver:
      // - Đã phát ngầm tín hiệu từ chối về server/bus với reason: 'busy'
      final rejectCalls = fakeClient.recordedCalls.where((c) => c['path'].toString().contains('/reject')).toList();
      final leaveCalls = fakeClient.recordedCalls.where((c) => c['path'].toString().contains('/leave_call')).toList();

      expect(rejectCalls.isNotEmpty, true);
      expect(rejectCalls.first['path'], contains('/202/reject'));
      expect(rejectCalls.first['body'], {'reason': 'busy'});

      expect(leaveCalls.isNotEmpty, true);
      final leaveBody = leaveCalls.first['body'] as Map<String, dynamic>?;
      final leaveParams = leaveBody?['params'] as Map<String, dynamic>?;
      expect(leaveParams?['channel_id'], 8888);
      expect(leaveParams?['reason'], 'busy');

      // - Cuộc gọi hiện tại Call 1 KHÔNG bị gián đoạn, state giữ nguyên 100%
      expect(ctl.state?.id, 101);
      expect(ctl.state?.channelId, 4255);
      expect(ctl.state?.state, ChatV2CallState.connected);
      expect(ctl.state?.duration, 45);

      // 4. Kiểm chứng phía Caller thứ 3:
      // Khi nhận Bus event 'rejected' kèm 'reason: busy', Caller 3 dừng chuông chờ và lưu endReason: 'busy'
      final caller3Client = FakeCallApiClient();
      final caller3Repo = ChatV2CallRepository(client: caller3Client);
      final caller3Bus = FakeOdooBusService();
      final caller3Ctl = ChatV2CallController(repo: caller3Repo, bus: caller3Bus);

      // Caller 3 đang gọi đi trên kênh 8888
      caller3Ctl.setIncomingCall(const ChatV2CallSession(
        id: 202,
        channelId: 8888,
        callerId: 99,
        callerName: 'Lê Văn C',
        receiverId: 5,
        receiverName: 'Bùi Tuấn Kiệt',
        state: ChatV2CallState.outgoingRinging,
        isCaller: true,
      ));

      // Nhận bus event đối phương báo busy
      caller3Bus.emitCallEnded(channelId: 8888, sessionId: 202, state: 'rejected', reason: 'busy');
      await Future.delayed(Duration.zero);

      expect(caller3Ctl.state?.state, ChatV2CallState.rejected);
      expect(caller3Ctl.state?.endReason, 'busy');

      caller3Ctl.dispose();
      caller3Bus.dispose();
      ctl.dispose();
      fakeBus.dispose();
    });

    test('TC-35: ChatV2CallRepository.fetchCallConfig loads STUN and dynamic HMAC TURN configurations from backend', () async {
      final fakeClient = FakeCallApiClient();
      final testRepo = ChatV2CallRepository(client: fakeClient);

      final iceServers = await testRepo.fetchCallConfig();
      expect(iceServers.isNotEmpty, true);
      expect(iceServers.length, 2);

      final stun = iceServers.first;
      expect((stun['urls'] as List).first, contains('stun.l.google.com'));

      final turn = iceServers[1];
      expect((turn['urls'] as List).first, contains('turn:turn.vuahethong.net'));
      expect(turn['username'], contains('vcloud_'));
      expect(turn['credential'], isNotEmpty);
      expect(turn['credential'], isNot('360corp_turn_pass_2026'));
    });

    test('TC-36: ChatV2CallController handles ICE disconnected state with 10s grace period and ends with network_lost', () async {
      final fakeClient = FakeCallApiClient();
      final testRepo = ChatV2CallRepository(client: fakeClient);
      final fakeBus = FakeOdooBusService();
      final fakeEngine = FakeWebRtcEngine(repo: testRepo);
      final ctl = ChatV2CallController(repo: testRepo, bus: fakeBus, webrtcEngine: fakeEngine);

      // Thiết lập cuộc gọi đến
      const call = ChatV2CallSession(
        id: 101,
        channelId: 4255,
        callerId: 2,
        callerName: 'Marc Demo',
        receiverId: 5,
        receiverName: 'Bùi Tuấn Kiệt',
        state: ChatV2CallState.incomingRinging,
        isCaller: false,
      );
      ctl.setIncomingCall(call);
      await ctl.acceptCall();

      // Kích hoạt connected
      fakeEngine.triggerConnectionState(RTCPeerConnectionState.RTCPeerConnectionStateConnected);
      expect(ctl.state?.state, ChatV2CallState.connected);

      // ICE chuyển sang Disconnected (chưa quá 10s -> vẫn connected)
      fakeEngine.triggerConnectionState(RTCPeerConnectionState.RTCPeerConnectionStateDisconnected);
      expect(ctl.state?.state, ChatV2CallState.connected);

      ctl.dispose();
      fakeBus.dispose();
    });

    test('TC-37: ChatV2CallController recovers if ICE reconnects before 10s timeout', () async {
      final fakeClient = FakeCallApiClient();
      final testRepo = ChatV2CallRepository(client: fakeClient);
      final fakeBus = FakeOdooBusService();
      final fakeEngine = FakeWebRtcEngine(repo: testRepo);
      final ctl = ChatV2CallController(repo: testRepo, bus: fakeBus, webrtcEngine: fakeEngine);

      const call = ChatV2CallSession(
        id: 101,
        channelId: 4255,
        callerId: 2,
        callerName: 'Marc Demo',
        receiverId: 5,
        receiverName: 'Bùi Tuấn Kiệt',
        state: ChatV2CallState.incomingRinging,
        isCaller: false,
      );
      ctl.setIncomingCall(call);
      await ctl.acceptCall();

      // Connected
      fakeEngine.triggerConnectionState(RTCPeerConnectionState.RTCPeerConnectionStateConnected);
      expect(ctl.state?.state, ChatV2CallState.connected);

      // Disconnected
      fakeEngine.triggerConnectionState(RTCPeerConnectionState.RTCPeerConnectionStateDisconnected);
      expect(ctl.state?.state, ChatV2CallState.connected);

      // Phục hồi lại Connected trước timeout
      fakeEngine.triggerConnectionState(RTCPeerConnectionState.RTCPeerConnectionStateConnected);
      expect(ctl.state?.state, ChatV2CallState.connected);

      ctl.dispose();
      fakeBus.dispose();
    });

    test('TC-38: OdooBusService parses vmobile.call/accepted and emits onCallAccepted', () async {
      final busService = OdooBusService();
      Map<String, dynamic>? acceptedData;
      final sub = busService.onCallAccepted.listen((data) => acceptedData = data);

      busService.processBusNotificationForTesting({
        'type': 'vmobile.call/accepted',
        'payload': {
          'channel_id': 123,
          'sessionId': 456,
          'sdp_answer': {'type': 'answer', 'sdp': 'v=0...'},
        },
      });

      await Future.delayed(Duration.zero);
      expect(acceptedData, isNotNull);
      expect(acceptedData?['channel_id'], 123);
      expect(acceptedData?['sessionId'], 456);
      expect(acceptedData?['sdp_answer']?['type'], 'answer');
      await sub.cancel();
      busService.dispose();
    });

    test('TC-39: OdooBusService rtc_sessions_update ADD emits onPeerJoined with sessionId', () async {
      final busService = OdooBusService();
      Map<String, dynamic>? joinedData;
      final sub = busService.onPeerJoined.listen((data) => joinedData = data);

      busService.processBusNotificationForTesting({
        'type': 'discuss.channel/rtc_sessions_update',
        'payload': {
          'id': 77,
          'rtcSessions': [
            [
              'ADD',
              [
                {'id': 888, 'channel_id': 77}
              ]
            ]
          ],
        },
      });

      await Future.delayed(Duration.zero);
      expect(joinedData, isNotNull);
      expect(joinedData?['channel_id'], 77);
      expect(joinedData?['sessionId'], 888);
      await sub.cancel();
      busService.dispose();
    });

    test('TC-40: OdooBusService mail.record/insert with discuss.channel.rtc.session emits onPeerJoined', () async {
      final busService = OdooBusService();
      Map<String, dynamic>? joinedData;
      final sub = busService.onPeerJoined.listen((data) => joinedData = data);

      busService.processBusNotificationForTesting({
        'type': 'mail.record/insert',
        'payload': {
          'discuss.channel.rtc.session': [
            {'id': 999, 'channel_id': 55, 'partner_id': 100}
          ]
        },
      });

      await Future.delayed(Duration.zero);
      expect(joinedData, isNotNull);
      expect(joinedData?['channel_id'], 55);
      expect(joinedData?['sessionId'], 999);
      await sub.cancel();
      busService.dispose();
    });

    test('TC-41: Caller onPeerJoined updates target session IDs and triggers createAndSendOffer', () async {
      final fakeClient = FakeCallApiClient();
      final testRepo = ChatV2CallRepository(client: fakeClient);
      final fakeBus = FakeOdooBusService();
      final fakeEngine = FakeWebRtcEngine(repo: testRepo);
      final ctl = ChatV2CallController(repo: testRepo, bus: fakeBus, webrtcEngine: fakeEngine);

      ctl.state = const ChatV2CallSession(
        id: 101,
        channelId: 4255,
        callerId: 2,
        callerName: 'Marc Demo',
        receiverId: 5,
        receiverName: 'Bùi Tuấn Kiệt',
        state: ChatV2CallState.outgoingRinging,
        isCaller: true,
      );

      fakeBus.emitPeerJoined({
        'channel_id': 4255,
        'sessionId': 505,
      });

      await Future.delayed(Duration.zero);
      expect(fakeEngine.lastUpdatedTargetSessionIds, [505]);
      expect(fakeEngine.createAndSendOfferCalled, true);
      expect(ctl.state?.state, ChatV2CallState.connecting);

      ctl.dispose();
      fakeBus.dispose();
    });

    test('TC-42: Caller onCallAccepted transitions smoothly to connected, handles sdp_answer, and starts duration timer', () async {
      final fakeClient = FakeCallApiClient();
      final testRepo = ChatV2CallRepository(client: fakeClient);
      final fakeBus = FakeOdooBusService();
      final fakeEngine = FakeWebRtcEngine(repo: testRepo);
      final ctl = ChatV2CallController(repo: testRepo, bus: fakeBus, webrtcEngine: fakeEngine);

      ctl.state = const ChatV2CallSession(
        id: 101,
        channelId: 4255,
        callerId: 2,
        callerName: 'Marc Demo',
        receiverId: 5,
        receiverName: 'Bùi Tuấn Kiệt',
        state: ChatV2CallState.connecting,
        isCaller: true,
      );

      fakeBus.emitCallAccepted({
        'channel_id': 4255,
        'sessionId': 505,
        'sdp_answer': {'type': 'answer', 'sdp': 'v=0 answer sdp'},
      });

      await Future.delayed(Duration.zero);
      expect(fakeEngine.lastHandledAnswer?['sdp'], 'v=0 answer sdp');
      expect(ctl.state?.state, ChatV2CallState.connected);
      expect(ctl.state?.connectedAt, isNotNull);

      ctl.dispose();
      fakeBus.dispose();
    });

    test('TC-HANDSHAKE-01: Bên A gọi -> Bên B bấm Accept -> Verify bên A nhận event vmobile.call/accepted từ Odoo Bus -> bên A xử lý SDP answer -> State bên A chuyển thành ChatV2CallState.connected', () async {
      final callerClient = FakeCallApiClient();
      final callerRepo = ChatV2CallRepository(client: callerClient);
      final callerBus = OdooBusService();
      final callerEngine = FakeWebRtcEngine(repo: callerRepo);
      final callerCtl = ChatV2CallController(repo: callerRepo, bus: callerBus, webrtcEngine: callerEngine);

      final calleeClient = FakeCallApiClient();
      final calleeRepo = ChatV2CallRepository(client: calleeClient);
      final calleeBus = OdooBusService();
      final calleeEngine = FakeWebRtcEngine(repo: calleeRepo);
      final calleeCtl = ChatV2CallController(repo: calleeRepo, bus: calleeBus, webrtcEngine: calleeEngine);

      // 1. Bên A gọi đi
      final callStarted = await callerCtl.startCall(
        channelId: 4255,
        callerName: 'Marc Demo (Bên A)',
        receiverId: 5,
        receiverName: 'Bùi Tuấn Kiệt (Bên B)',
      );
      expect(callStarted, isTrue);
      expect(callerCtl.state?.state, ChatV2CallState.outgoingRinging);
      expect(callerCtl.state?.isCaller, isTrue);

      // 2. Bên B nhận cuộc gọi đến và bấm Accept
      const incomingToB = ChatV2CallSession(
        id: 101,
        channelId: 4255,
        callerId: 2,
        callerName: 'Marc Demo (Bên A)',
        receiverId: 5,
        receiverName: 'Bùi Tuấn Kiệt (Bên B)',
        state: ChatV2CallState.incomingRinging,
        isCaller: false,
      );
      calleeCtl.setIncomingCall(incomingToB);
      expect(calleeCtl.state?.state, ChatV2CallState.incomingRinging);

      await calleeCtl.acceptCall();
      expect(calleeCtl.state?.state, ChatV2CallState.connected);

      // 3. Phía server / Odoo Bus phát event 'vmobile.call/accepted' về cho Bên A
      const sdpAnswer = {
        'type': 'answer',
        'sdp': 'v=0\r\no=B 2000 2 IN IP4 127.0.0.1\r\ns=-\r\nt=0 0\r\na=sendrecv',
      };
      callerBus.processBusNotificationForTesting({
        'type': 'vmobile.call/accepted',
        'payload': {
          'channel_id': 4255,
          'sessionId': 101,
          'sdp_answer': sdpAnswer,
        },
      });

      await Future.delayed(Duration.zero);

      // 4. Verify Bên A nhận event và xử lý SDP answer
      expect(callerEngine.lastHandledAnswer, isNotNull);
      expect(callerEngine.lastHandledAnswer?['sdp'], sdpAnswer['sdp']);

      // 5. Verify State bên A chuyển thành ChatV2CallState.connected
      expect(callerCtl.state?.state, ChatV2CallState.connected);
      expect(callerCtl.state?.connectedAt, isNotNull);

      callerCtl.dispose();
      calleeCtl.dispose();
      callerBus.dispose();
      calleeBus.dispose();
    });

    test('TC-ICE-QUEUE-02: ICE candidates phát sinh khi targetSessionId rỗng -> được đưa vào hàng đợi _queuedLocalCandidates -> khi updateTargetSessionIds được gọi, tất cả candidate được flush và gửi đi an toàn', () async {
      final fakeClient = FakeCallApiClient();
      final repo = ChatV2CallRepository(client: fakeClient);
      final engine = ChatV2WebRtcEngine(repo: repo);

      // Khởi tạo WebRTC Engine với targetSessionIds rỗng và localSessionId = 101
      await engine.initialize(
        localSessionId: 101,
        targetSessionIds: [],
        iceServersData: [
          {'urls': 'stun:stun.l.google.com:19302'}
        ],
      );

      // Giả lập 2 ICE candidates phát sinh từ native WebRTC khi chưa có peer trong phòng
      const standardCodec = StandardMethodCodec();
      final candidate1 = {
        'event': 'onCandidate',
        'candidate': {
          'candidate': 'candidate:1 1 UDP 2122252543 192.168.1.100 54321 typ host',
          'sdpMid': '0',
          'sdpMLineIndex': 0,
        },
      };
      final candidate2 = {
        'event': 'onCandidate',
        'candidate': {
          'candidate': 'candidate:2 1 UDP 2122252544 192.168.1.100 54322 typ host',
          'sdpMid': '0',
          'sdpMLineIndex': 0,
        },
      };

      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
        'FlutterWebRTC/peerConnectionEventpc-test-101',
        standardCodec.encodeSuccessEnvelope(candidate1),
        (ByteData? reply) {},
      );
      await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
        'FlutterWebRTC/peerConnectionEventpc-test-101',
        standardCodec.encodeSuccessEnvelope(candidate2),
        (ByteData? reply) {},
      );

      // Xác minh: Khi targetSessionIds rỗng, các candidate được xếp hàng và CHƯA gửi qua API
      final signalingBefore = fakeClient.recordedCalls
          .where((c) => c['path'] == '/mail/rtc/session/notify_call_members')
          .toList();
      expect(signalingBefore.isEmpty, isTrue);

      // Callee tham gia phòng -> cập nhật targetSessionIds = [505]
      engine.updateTargetSessionIds([505]);

      // Xác minh: Cả 2 candidate đã được flush khỏi hàng đợi và gửi đi an toàn tới targetSessionIds [505]
      final signalingAfter = fakeClient.recordedCalls
          .where((c) => c['path'] == '/mail/rtc/session/notify_call_members')
          .toList();
      expect(signalingAfter.length, 2);

      final firstNotif = signalingAfter[0]['body']['params']['peer_notifications'][0];
      expect(firstNotif[0], 101); // senderSessionId
      expect(firstNotif[1], [505]); // targetSessionIds
      expect(firstNotif[2], contains('candidate:1 1 UDP 2122252543'));

      final secondNotif = signalingAfter[1]['body']['params']['peer_notifications'][0];
      expect(secondNotif[0], 101); // senderSessionId
      expect(secondNotif[1], [505]); // targetSessionIds
      expect(secondNotif[2], contains('candidate:2 1 UDP 2122252544'));

      // Gọi updateTargetSessionIds lần nữa -> hàng đợi đã được clear, không gửi lặp lại
      fakeClient.recordedCalls.clear();
      engine.updateTargetSessionIds([505]);
      final signalingAfterSecondUpdate = fakeClient.recordedCalls
          .where((c) => c['path'] == '/mail/rtc/session/notify_call_members')
          .toList();
      expect(signalingAfterSecondUpdate.isEmpty, isTrue);

      await engine.dispose();
    });

    test('TC-PEER-JOIN-03: Bên A gọi (phòng ban đầu chưa có B) -> B gia nhập phòng (onPeerJoined) -> Bên A cập nhật _targetSessionIds và kích hoạt createAndSendOffer()', () async {
      final fakeClient = FakeCallApiClient();
      final repo = ChatV2CallRepository(client: fakeClient);
      final fakeBus = FakeOdooBusService();
      final fakeEngine = FakeWebRtcEngine(repo: repo);
      final controller = ChatV2CallController(repo: repo, bus: fakeBus, webrtcEngine: fakeEngine);

      // 1. Bên A gọi đi vào kênh 4255, ban đầu phòng rtcSessions rỗng (chưa có B)
      final started = await controller.startCall(
        channelId: 4255,
        callerName: 'Marc Demo (Bên A)',
        receiverId: 5,
        receiverName: 'Bùi Tuấn Kiệt (Bên B)',
      );
      expect(started, isTrue);
      expect(controller.state?.state, ChatV2CallState.outgoingRinging);
      expect(controller.state?.isCaller, isTrue);
      // Phòng ban đầu chưa có B nên chưa gửi offer
      expect(fakeEngine.createAndSendOfferCalled, isFalse);
      expect(fakeEngine.lastUpdatedTargetSessionIds, isNull);

      // 2. Bên B gia nhập phòng -> Odoo Bus phát event onPeerJoined với sessionId = 606 trên kênh 4255
      fakeBus.emitPeerJoined({
        'channel_id': 4255,
        'sessionId': 606,
      });

      await Future.delayed(Duration.zero);

      // 3. Verify Bên A cập nhật _targetSessionIds và kích hoạt createAndSendOffer()
      expect(fakeEngine.lastUpdatedTargetSessionIds, [606]);
      expect(fakeEngine.createAndSendOfferCalled, isTrue);

      // 4. Verify State bên A chuyển thành ChatV2CallState.connecting
      expect(controller.state?.state, ChatV2CallState.connecting);

      controller.dispose();
      fakeBus.dispose();
    });
  });
}
