import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:vcloud/features/chat_v2/domain/models/chat_v2_call_session.dart';
import 'package:vcloud/features/chat_v2/data/chat_v2_call_repository.dart';
import 'package:vcloud/features/chat_v2/application/chat_v2_call_controller.dart';
import 'package:vcloud/features/chat_v2/presentation/screens/chat_v2_call_screen.dart';
import 'package:vcloud/features/chat_v2/presentation/widgets/chat_v2_incoming_call_dialog.dart';
import 'package:vcloud/core/api/odoo_api_client.dart';

class FakeWidgetCallApiClient extends OdooApiClient {
  FakeWidgetCallApiClient() : super(baseUrl: 'http://localhost:8069');

  @override
  Future<dynamic> post(
    String path, {
    Object? body,
    Map<String, Object?> query = const <String, Object?>{},
    bool auth = true,
  }) async {
    return {'status': 'success'};
  }

  @override
  Future<dynamic> get(
    String path, {
    Map<String, Object?> query = const <String, Object?>{},
    bool auth = true,
  }) async {
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
}

class MockCallController extends ChatV2CallController {
  MockCallController({required super.repo, ChatV2CallSession? initialSession}) {
    state = initialSession;
  }

  @override
  void setIncomingCall(ChatV2CallSession session) {
    state = session;
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

  group('ChatV2CallScreen Widget Tests', () {
    late FakeWidgetCallApiClient fakeClient;
    late ChatV2CallRepository repo;

    setUp(() {
      Animate.restartOnHotReload = false;
      fakeClient = FakeWidgetCallApiClient();
      repo = ChatV2CallRepository(client: fakeClient);
    });

    testWidgets('TC-10: Outgoing Ringing Screen renders avatar, receiver name, and cancel button', (tester) async {
      const session = ChatV2CallSession(
        id: 101,
        channelId: 4255,
        callerId: 2,
        callerName: 'Marc Demo',
        receiverId: 5,
        receiverName: 'Bùi Tuấn Kiệt',
        state: ChatV2CallState.outgoingRinging,
        isCaller: true,
      );

      final ctrl = MockCallController(repo: repo, initialSession: session);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            chatV2CallRepositoryProvider.overrideWithValue(repo),
            chatV2CallControllerProvider.overrideWith((ref) => ctrl),
          ],
          child: MaterialApp(
            theme: ThemeData(splashFactory: InkRipple.splashFactory),
            home: const ChatV2CallScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Bùi Tuấn Kiệt'), findsOneWidget);
      expect(find.text('Đang đổ chuông...'), findsOneWidget);
      expect(find.byIcon(LucideIcons.phoneOff), findsOneWidget);
      expect(find.text('Kết thúc'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('TC-11: Connected Active Call Screen renders duration and 3 control buttons', (tester) async {
      const session = ChatV2CallSession(
        id: 101,
        channelId: 4255,
        callerId: 2,
        callerName: 'Marc Demo',
        receiverId: 5,
        receiverName: 'Bùi Tuấn Kiệt',
        state: ChatV2CallState.connected,
        duration: 85, // 01:25
        isCaller: true,
      );

      final ctrl = MockCallController(repo: repo, initialSession: session);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            chatV2CallRepositoryProvider.overrideWithValue(repo),
            chatV2CallControllerProvider.overrideWith((ref) => ctrl),
          ],
          child: MaterialApp(
            theme: ThemeData(splashFactory: InkRipple.splashFactory),
            home: const ChatV2CallScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Bùi Tuấn Kiệt'), findsOneWidget);
      expect(find.text('01:25'), findsOneWidget);
      expect(find.text('Tắt mic'), findsOneWidget);
      expect(find.text('Loa ngoài'), findsOneWidget);
      expect(find.text('Kết thúc'), findsOneWidget);

      // Tap Mute button (by icon)
      await tester.tap(find.byIcon(LucideIcons.mic));
      await tester.pump();
      expect(ctrl.isMuted, true);

      // Tap Speaker button (by icon)
      await tester.tap(find.byIcon(LucideIcons.volumeX));
      await tester.pump();
      expect(ctrl.isSpeaker, true);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('TC-12: Incoming Call Dialog renders caller and Accept / Reject buttons', (tester) async {
      const session = ChatV2CallSession(
        id: 101,
        channelId: 4255,
        callerId: 2,
        callerName: 'Marc Demo',
        receiverId: 5,
        receiverName: 'Bùi Tuấn Kiệt',
        state: ChatV2CallState.incomingRinging,
        isCaller: false,
      );

      final ctrl = MockCallController(repo: repo, initialSession: session);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            chatV2CallRepositoryProvider.overrideWithValue(repo),
            chatV2CallControllerProvider.overrideWith((ref) => ctrl),
          ],
          child: MaterialApp(
            theme: ThemeData(splashFactory: InkRipple.splashFactory),
            home: const Scaffold(
              body: ChatV2IncomingCallDialog(session: session),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Marc Demo'), findsOneWidget);
      expect(find.text('Cuộc gọi thoại đến...'), findsOneWidget);
      expect(find.text('Trả lời'), findsOneWidget);
      expect(find.text('Từ chối'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
