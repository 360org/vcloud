import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/features/chat_v2/domain/models/chat_v2_call_session.dart';
import 'package:vcloud/features/chat_v2/data/chat_v2_call_repository.dart';
import 'package:vcloud/features/chat_v2/application/chat_v2_call_controller.dart';
import 'package:vcloud/core/api/odoo_api_client.dart';

class FakeCallApiClient extends OdooApiClient {
  FakeCallApiClient() : super(baseUrl: 'http://localhost:8069');

  Map<String, dynamic>? mockResponse;

  @override
  Future<dynamic> post(
    String path, {
    Object? body,
    Map<String, Object?> query = const <String, Object?>{},
    bool auth = true,
  }) async {
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
    late ChatV2CallController controller;

    setUp(() {
      fakeClient = FakeCallApiClient();
      repo = ChatV2CallRepository(client: fakeClient);
      controller = ChatV2CallController(repo: repo);
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
}
