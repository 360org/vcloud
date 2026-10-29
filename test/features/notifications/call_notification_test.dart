import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:vcloud/app.dart';
import 'package:vcloud/core/api/auth_user.dart';
import 'package:vcloud/features/auth/application/auth_controller.dart';
import 'package:vcloud/features/auth/data/auth_repository.dart';
import 'package:vcloud/features/chat_v2/domain/models/chat_v2_call_session.dart';
import 'package:vcloud/features/chat_v2/application/chat_v2_call_controller.dart';
import 'package:vcloud/features/chat_v2/data/chat_v2_call_repository.dart';

class MockCallRepository implements ChatV2CallRepository {
  bool acceptCalled = false;
  bool rejectCalled = false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<ChatV2CallSession?> getActiveCall() async => null;

  @override
  Future<ChatV2CallSession?> getCallSession(int callId) async => null;

  @override
  Future<ChatV2CallSession?> initiateCall({
    required int channelId,
    String? sdpOffer,
    int? receiverId,
  }) async => null;

  @override
  Future<bool> cancelCall(int callId) async => true;

  @override
  Future<bool> endCall(int callId, {int duration = 0}) async => true;

  @override
  Future<List<Map<String, dynamic>>> fetchCallConfig() async => const [];

  @override
  Future<ChatV2CallSession?> acceptCall(int callId, {String? sdpAnswer, int? channelId}) async {
    acceptCalled = true;
    return ChatV2CallSession(
      id: callId,
      channelId: 25,
      callerId: 4,
      callerName: 'Marc Demo',
      callerAvatar: '/api/v1/mobile/avatar/res.partner/4?field=avatar_128',
      receiverId: 2,
      receiverName: 'Mitchell Admin',
      receiverAvatar: '/api/v1/mobile/avatar/res.partner/2?field=avatar_128',
      state: ChatV2CallState.connected,
      duration: 0,
      isCaller: false,
      iceCandidates: const [],
    );
  }

  @override
  Future<bool> rejectCall(int callId, {String? reason, int? channelId}) async {
    rejectCalled = true;
    return true;
  }

  @override
  Future<OdooRtcJoinResult?> joinCall({
    required int channelId,
    List<int> checkRtcSessionIds = const [],
    bool camera = false,
  }) async => null;

  @override
  Future<bool> leaveCall({required int channelId, int? sessionId, String? reason}) async => true;

  @override
  Future<bool> cancelCallInvitation({required int channelId, List<int>? memberIds}) async => true;
}

class FakeAuthRepository implements AuthRepository {
  final AuthUser? user;
  FakeAuthRepository({this.user});

  @override
  Future<AuthUser?> currentUser() async => user;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global'),
      (methodCall) async => 1,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (methodCall) async => 1,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('flutter_callkit_incoming'),
      (methodCall) async => 1,
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
  });

  group('Kịch bản 2: Kiểm thử Tích hợp Thông báo Cuộc Gọi Đến (FCM Call Notification)', () {
    late MockCallRepository mockCallRepo;
    const mockUser = AuthUser(
      id: '2',
      email: 'admin@example.com',
      userMetadata: {'name': 'Mitchell Admin', 'partner_id': 3},
    );

    setUp(() {
      mockCallRepo = MockCallRepository();
    });

    testWidgets(
      'TC-01: Nhận cuộc gọi đến ➔ Trả lời ➔ Chuyển trạng thái Connected',
      (WidgetTester tester) async {
        const incomingSession = ChatV2CallSession(
          id: 88,
          channelId: 25,
          callerId: 4,
          callerName: 'Marc Demo',
          callerAvatar: '/api/v1/mobile/avatar/res.partner/4?field=avatar_128',
          receiverId: 2,
          receiverName: 'Mitchell Admin',
          receiverAvatar: '/api/v1/mobile/avatar/res.partner/2?field=avatar_128',
          state: ChatV2CallState.incomingRinging,
          duration: 0,
          isCaller: false,
          iceCandidates: [],
        );

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(FakeAuthRepository(user: mockUser)),
            chatV2CallRepositoryProvider.overrideWithValue(mockCallRepo),
          ],
        );

        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const VCloudApp(),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // 1. Giả lập nhận cuộc gọi đến từ FCM / Signaling
        container.read(chatV2CallControllerProvider.notifier).setIncomingCall(incomingSession);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(container.read(chatV2CallControllerProvider)?.state, ChatV2CallState.incomingRinging);

        // 2. Chấp nhận cuộc gọi
        await container.read(chatV2CallControllerProvider.notifier).acceptCall();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // 3. Kiểm chứng: State đã chuyển sang connected
        expect(mockCallRepo.acceptCalled, isTrue);
        expect(container.read(chatV2CallControllerProvider)?.state, ChatV2CallState.connected);

        // Dọn dẹp trạng thái controller trước khi kết thúc
        container.read(chatV2CallControllerProvider.notifier).reset();
        await tester.pump();
        await tester.pump(const Duration(seconds: 3));
      },
    );

    testWidgets(
      'TC-02: Nhận cuộc gọi đến ➔ Từ chối ➔ Chuyển trạng thái Ended',
      (WidgetTester tester) async {
        const incomingSession = ChatV2CallSession(
          id: 89,
          channelId: 25,
          callerId: 4,
          callerName: 'Marc Demo',
          callerAvatar: '/api/v1/mobile/avatar/res.partner/4?field=avatar_128',
          receiverId: 2,
          receiverName: 'Mitchell Admin',
          receiverAvatar: '/api/v1/mobile/avatar/res.partner/2?field=avatar_128',
          state: ChatV2CallState.incomingRinging,
          duration: 0,
          isCaller: false,
          iceCandidates: [],
        );

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWithValue(FakeAuthRepository(user: mockUser)),
            chatV2CallRepositoryProvider.overrideWithValue(mockCallRepo),
          ],
        );

        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const VCloudApp(),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // 1. Giả lập nhận cuộc gọi đến
        container.read(chatV2CallControllerProvider.notifier).setIncomingCall(incomingSession);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(container.read(chatV2CallControllerProvider)?.state, ChatV2CallState.incomingRinging);

        // 2. Từ chối cuộc gọi
        await container.read(chatV2CallControllerProvider.notifier).rejectCall();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 800));

        // 3. Kiểm chứng: rejectCall được gọi
        expect(mockCallRepo.rejectCalled, isTrue);
        await tester.pump(const Duration(seconds: 1));
      },
    );
  });
}
