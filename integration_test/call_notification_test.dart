import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import 'package:vcloud/app.dart';
import 'package:vcloud/core/api/auth_user.dart';
import 'package:vcloud/features/auth/application/auth_controller.dart';
import 'package:vcloud/features/auth/data/auth_repository.dart';
import 'package:vcloud/features/chat_v2/domain/models/chat_v2_call_session.dart';
import 'package:vcloud/features/chat_v2/application/chat_v2_call_controller.dart';
import 'package:vcloud/features/chat_v2/application/chat_v2_call_watcher.dart';
import 'package:vcloud/features/chat_v2/data/chat_v2_call_repository.dart';
import 'package:vcloud/features/chat_v2/presentation/widgets/chat_v2_incoming_call_dialog.dart';
import 'package:vcloud/features/chat_v2/presentation/screens/chat_v2_call_screen.dart';

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
  Future<ChatV2CallSession?> acceptCall(int callId, {String? sdpAnswer}) async {
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
  Future<bool> rejectCall(int callId) async {
    rejectCalled = true;
    return true;
  }
}

class FakeAuthRepository implements AuthRepository {
  final AuthUser? user;
  FakeAuthRepository({this.user});

  @override
  Future<AuthUser?> currentUser() async => user;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeCallWatcher implements ChatV2CallWatcher {
  @override
  void dispose() {}

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
      'TC-01: Nhận cuộc gọi đến ➔ Hiển thị Popup ➔ Nhấn Trả Lời ➔ Mở ChatV2CallScreen (Connected)',
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
            chatV2CallWatcherProvider.overrideWithValue(FakeCallWatcher()),
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

        // 2. Kiểm chứng: Dialog cuộc gọi đến xuất hiện với thông tin người gọi
        expect(find.byType(ChatV2IncomingCallDialog), findsOneWidget);
        expect(find.text('Marc Demo'), findsOneWidget);
        expect(find.text('Cuộc gọi thoại đến...'), findsOneWidget);

        // 3. Người dùng chạm nút Trả lời (Nút màu xanh lá phone)
        final acceptBtn = find.byIcon(LucideIcons.phone);
        expect(acceptBtn, findsOneWidget);
        await tester.tap(acceptBtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // 4. Kiểm chứng: State đã chuyển sang connected và ChatV2CallScreen đã được mở
        expect(mockCallRepo.acceptCalled, isTrue);
        expect(container.read(chatV2CallControllerProvider)?.state, ChatV2CallState.connected);
        expect(find.byType(ChatV2CallScreen), findsOneWidget);

        // Dọn dẹp trạng thái controller trước khi kết thúc
        container.read(chatV2CallControllerProvider.notifier).reset();
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
      },
    );

    testWidgets(
      'TC-02: Nhận cuộc gọi đến ➔ Nhấn Từ chối ➔ Hủy cuộc gọi và đóng Popup',
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
            chatV2CallWatcherProvider.overrideWithValue(FakeCallWatcher()),
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

        expect(find.byType(ChatV2IncomingCallDialog), findsOneWidget);

        // 2. Chạm nút Từ chối (phoneOff)
        final rejectBtn = find.byIcon(LucideIcons.phoneOff);
        expect(rejectBtn, findsOneWidget);
        await tester.tap(rejectBtn);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 800));

        // 3. Kiểm chứng: rejectCall được gọi, dialog biến mất
        expect(mockCallRepo.rejectCalled, isTrue);
        expect(find.byType(ChatV2IncomingCallDialog), findsNothing);

        await tester.pump(const Duration(seconds: 1));
      },
    );
  });
}
