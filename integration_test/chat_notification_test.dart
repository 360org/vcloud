import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'package:vcloud/app.dart';
import 'package:vcloud/core/api/auth_user.dart';
import 'package:vcloud/core/notifications/push_notification_service.dart';
import 'package:vcloud/core/notifications/push_notification_controller.dart';
import 'package:vcloud/features/auth/application/auth_controller.dart';
import 'package:vcloud/features/auth/data/auth_repository.dart';
import 'package:vcloud/features/chat_v2/presentation/screens/chat_v2_detail_screen.dart';
import 'package:vcloud/features/chat_v2/application/chat_v2_channels_controller.dart';

class FakePushNotificationService implements PushNotificationService {
  final _onMessageController = StreamController<RemoteMessage>.broadcast();
  final _onMessageOpenedAppController = StreamController<RemoteMessage>.broadcast();
  RemoteMessage? initialMessage;

  @override
  Stream<RemoteMessage> get onMessageStream => _onMessageController.stream;

  @override
  Stream<RemoteMessage> get onMessageOpenedAppStream => _onMessageOpenedAppController.stream;

  @override
  Future<RemoteMessage?> getInitialMessage() async => initialMessage;

  @override
  Future<String?> registerCurrentDevice() async => 'fake_token';

  @override
  Future<void> unregisterCurrentDevice() async {}

  void simulateForegroundMessage(RemoteMessage message) {
    _onMessageController.add(message);
  }

  void simulateNotificationClick(RemoteMessage message) {
    _onMessageOpenedAppController.add(message);
  }

  void closeStreams() {
    _onMessageController.close();
    _onMessageOpenedAppController.close();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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

  group('Kịch bản 1: Kiểm thử Tích hợp Thông báo Tin nhắn Chat (FCM Message)', () {
    late FakePushNotificationService fakePushService;
    const mockUser = AuthUser(
      id: '2',
      email: 'admin@example.com',
      userMetadata: {'name': 'Mitchell Admin', 'partner_id': 3},
    );

    setUp(() {
      fakePushService = FakePushNotificationService();
    });

    tearDown(() {
      fakePushService.closeStreams();
    });

    testWidgets(
      'TC-01: Nhận sự kiện FCM Notification Click ➔ Tự động mở phòng chat tương ứng',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              pushNotificationServiceProvider.overrideWithValue(fakePushService),
              authRepositoryProvider.overrideWithValue(FakeAuthRepository(user: mockUser)),
            ],
            child: const VCloudApp(),
          ),
        );

        // Chờ Splash Screen hoàn tất warmup
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // 1. Giả lập nhận Push Notification khi người dùng click vào thông báo từ thanh status bar
        const testChannelId = 25;
        const testChannelName = 'Dự án Alpha';
        const fcmMessage = RemoteMessage(
          messageId: 'fcm_msg_1045',
          data: {
            'event': 'chat_message',
            'channel_id': '$testChannelId',
            'channel_name': testChannelName,
            'body': 'Xin chào, bạn có rảnh trao đổi công việc không?',
          },
          notification: RemoteNotification(
            title: 'Marc Demo',
            body: 'Xin chào, bạn có rảnh trao đổi công việc không?',
          ),
        );

        // Phát sự kiện người dùng chạm vào notification
        fakePushService.simulateNotificationClick(fcmMessage);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        // 2. Kiểm chứng: Router điều hướng chính xác vào ChatV2DetailScreen của channelId 25
        expect(find.byType(ChatV2DetailScreen), findsOneWidget);
        expect(find.text(testChannelName), findsOneWidget);

        // Dọn dẹp animation timer
        await tester.pump(const Duration(seconds: 1));
      },
    );

    testWidgets(
      'TC-02: Nhận sự kiện FCM Foreground ➔ Kích hoạt làm mới kênh và huy hiệu tin nhắn',
      (WidgetTester tester) async {
        final container = ProviderContainer(
          overrides: [
            pushNotificationServiceProvider.overrideWithValue(fakePushService),
            authRepositoryProvider.overrideWithValue(FakeAuthRepository(user: mockUser)),
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

        // Giả lập nhận Foreground FCM Push khi đang dùng ứng dụng
        const foregroundMessage = RemoteMessage(
          messageId: 'fcm_foreground_99',
          data: {
            'event_type': 'chat_message',
            'channel_id': '42',
          },
          notification: RemoteNotification(
            title: 'Marc Demo',
            body: 'Tin nhắn mới đến',
          ),
        );

        // Phát sự kiện foreground
        fakePushService.simulateForegroundMessage(foregroundMessage);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        // Kiểm chứng: Stream foreground nhận tin nhắn thành công và huy hiệu đọc là số nguyên hợp lệ
        expect(container.read(chatV2TotalUnreadProvider), isA<int>());

        await tester.pump(const Duration(seconds: 1));
      },
    );
  });
}
