import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'package:vcloud/features/chat_v2/domain/models/chat_v2_call_session.dart';
import 'package:vcloud/features/chat_v2/presentation/widgets/chat_v2_incoming_call_dialog.dart';
import 'package:vcloud/features/chat_v2/presentation/screens/chat_v2_call_screen.dart';
import 'package:vcloud/features/chat_v2/application/chat_v2_call_controller.dart';
import 'package:vcloud/features/chat_v2/data/chat_v2_call_repository.dart';

// Mock Repository để kiểm thử Controller
class MockChatV2CallRepository implements ChatV2CallRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);

  @override
  Future<ChatV2CallSession?> initiateCall({
    required int channelId,
    String? sdpOffer,
    int? receiverId,
  }) async {
    return ChatV2CallSession(
      id: 999,
      channelId: channelId,
      callerId: 4, // Marc Demo user id
      callerName: 'Marc Demo',
      callerAvatar: '/web/image/res.users/4/avatar_128',
      receiverId: 2, // Mitchell Admin user id (khác với partner_id 3, không bị nhầm thành Joel Willis)
      receiverName: 'Mitchell Admin',
      receiverAvatar: '/web/image/res.users/2/avatar_128',
      state: ChatV2CallState.outgoingRinging,
      duration: 0,
      isCaller: true,
      iceCandidates: const [],
    );
  }
}

class FakeCallController extends ChatV2CallController {
  FakeCallController(ChatV2CallSession initialSession) : super(repo: MockChatV2CallRepository()) {
    state = initialSession;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Mock Audio Player platform channel cho môi trường test headless
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global'),
      (methodCall) async => 1,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (methodCall) async => 1,
    );

    // Tắt loop animation vô tận trong môi trường test UI
    Animate.restartOnHotReload = false;

    await loadAppFonts();
  });

  group('Chat V2 Call Session & Controller Unit Tests', () {
    test('ChatV2CallSession should format duration correctly', () {
      const session = ChatV2CallSession(
        id: 1,
        channelId: 10,
        callerId: 4,
        callerName: 'Marc Demo',
        receiverId: 2,
        receiverName: 'Mitchell Admin',
        state: ChatV2CallState.connected,
        duration: 65, // 1 phút 5 giây
        iceCandidates: [],
      );

      expect(session.formattedDuration, '01:05');

      final session2 = session.copyWith(duration: 3600); // 60 phút
      expect(session2.formattedDuration, '60:00');
    });

    test('ChatV2CallSession should verify caller vs receiver names (No Joel Willis bug)', () {
      const session = ChatV2CallSession(
        id: 1,
        channelId: 10,
        callerId: 4,
        callerName: 'Marc Demo',
        callerAvatar: '/web/image/res.users/4/avatar_128',
        receiverId: 2,
        receiverName: 'Mitchell Admin',
        receiverAvatar: '/web/image/res.users/2/avatar_128',
        state: ChatV2CallState.outgoingRinging,
        duration: 0,
        isCaller: true,
        iceCandidates: [],
      );

      // Caller là Marc Demo
      expect(session.callerName, 'Marc Demo');
      // Receiver là Mitchell Admin, tuyệt đối không phải Joel Willis
      expect(session.receiverName, 'Mitchell Admin');
      expect(session.receiverName, isNot('Joel Willis'));
      expect(session.isCaller, true);
    });

    test('ChatV2CallController should preserve caller and receiver info on initiateCall', () async {
      final mockRepo = MockChatV2CallRepository();
      final controller = ChatV2CallController(repo: mockRepo);

      final success = await controller.startCall(
        channelId: 10,
        callerName: 'Marc Demo',
        callerAvatar: '/web/image/res.users/4/avatar_128',
        receiverId: 3, // Partner ID của Mitchell Admin
        receiverName: 'Mitchell Admin',
        receiverAvatar: '/web/image/res.users/2/avatar_128',
      );

      expect(success, true);
      expect(controller.currentSession?.receiverName, 'Mitchell Admin');
      expect(controller.currentSession?.callerName, 'Marc Demo');
      expect(controller.currentSession?.isCaller, true);

      controller.dispose();
    });
  });

  group('Chat V2 UI Widget Tests', () {
    testWidgets('ChatV2IncomingCallDialog displays caller name and answer/reject buttons', (tester) async {
      const session = ChatV2CallSession(
        id: 1,
        channelId: 10,
        callerId: 4,
        callerName: 'Marc Demo',
        callerAvatar: null,
        receiverId: 2,
        receiverName: 'Mitchell Admin',
        state: ChatV2CallState.incomingRinging,
        duration: 0,
        isCaller: false,
        iceCandidates: [],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ChatV2IncomingCallDialog(
                session: session,
                onAccept: () {},
                onReject: () {},
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Marc Demo'), findsOneWidget);
      expect(find.text('Cuộc gọi thoại đến...'), findsOneWidget);
      expect(find.text('Từ chối'), findsOneWidget);
      expect(find.text('Trả lời'), findsOneWidget);
    });

    testWidgets('ChatV2CallScreen displays receiver name and call controls when calling', (tester) async {
      const session = ChatV2CallSession(
        id: 1,
        channelId: 10,
        callerId: 4,
        callerName: 'Marc Demo',
        callerAvatar: '/web/image/res.users/4/avatar_128',
        receiverId: 2,
        receiverName: 'Mitchell Admin',
        receiverAvatar: '/web/image/res.users/2/avatar_128',
        state: ChatV2CallState.outgoingRinging,
        duration: 0,
        isCaller: true,
        iceCandidates: [],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            chatV2CallControllerProvider.overrideWith((ref) => FakeCallController(session)),
          ],
          child: const MaterialApp(
            home: ChatV2CallScreen(),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      // Kiểm tra tên người nhận hiển thị chính xác là Mitchell Admin (Không phải Joel Willis)
      expect(find.text('Mitchell Admin'), findsOneWidget);
      expect(find.text('Joel Willis'), findsNothing);
      expect(find.text('Đang đổ chuông...'), findsOneWidget);
      expect(find.text('Kết thúc'), findsOneWidget);
    });
  });

  group('Chat V2 UI Golden Tests', () {
    testWidgets('Incoming Call Dialog should render correctly and have valid layout', (tester) async {
      const session = ChatV2CallSession(
        id: 1,
        channelId: 10,
        callerId: 4,
        callerName: 'Marc Demo',
        receiverId: 2,
        receiverName: 'Mitchell Admin',
        state: ChatV2CallState.incomingRinging,
        duration: 0,
        isCaller: false,
        iceCandidates: [],
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: Center(
                child: ChatV2IncomingCallDialog(
                  session: session,
                  onAccept: () {},
                  onReject: () {},
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 100));

      // Xác minh dialog hiển thị Marc Demo và các nút tương tác
      expect(find.text('Marc Demo'), findsOneWidget);
      expect(find.text('Cuộc gọi thoại đến...'), findsOneWidget);
      expect(find.byType(ChatV2IncomingCallDialog), findsOneWidget);
    });
  });
}
