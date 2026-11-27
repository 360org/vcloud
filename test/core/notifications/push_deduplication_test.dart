import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/core/api/auth_user.dart';
import 'package:vcloud/core/api/odoo_api_client.dart';
import 'package:vcloud/core/api/odoo_session.dart';
import 'package:vcloud/core/notifications/push_notification_controller.dart';
import 'package:vcloud/core/notifications/push_notification_service.dart';
import 'package:vcloud/features/auth/application/auth_controller.dart';
import 'package:vcloud/features/auth/data/auth_repository.dart';
import 'package:vcloud/features/auth/data/db_info.dart';
import 'package:vcloud/features/chat_v2/presentation/widgets/chat_v2_in_app_banner.dart';

class _TrackingPushNotificationService implements PushNotificationService {
  int unregisterCalls = 0;
  int registerCalls = 0;
  Duration unregisterDelay = Duration.zero;
  bool hangUnregister = false;
  final List<String> events = [];

  @override
  Future<void> unregisterCurrentDevice() async {
    unregisterCalls++;
    events.add('unregister');
    if (hangUnregister) {
      await Completer<void>().future;
    }
    if (unregisterDelay > Duration.zero) {
      await Future<void>.delayed(unregisterDelay);
    }
  }

  @override
  Future<String?> registerCurrentDevice() async {
    registerCalls++;
    events.add('register');
    return 'mock_token';
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository(this.events);

  final List<String> events;

  @override
  Future<AuthUser?> currentUser() async => null;

  @override
  Future<AuthUser> authenticateOnClient({
    required DbInfo db,
    required String login,
    required String password,
  }) async {
    events.add('authenticate:${db.databaseName}');
    return AuthUser(
      id: '10',
      email: login,
      userMetadata: {'db': db.databaseName, 'name': 'Test User'},
    );
  }

  @override
  Future<AuthUser> activateVerifiedSession({
    required DbInfo db,
    required OdooSession session,
    required String login,
  }) async {
    events.add('activate:${db.databaseName}');
    return AuthUser(
      id: '10',
      email: login,
      userMetadata: {'db': db.databaseName, 'name': 'Test User'},
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    const secureChannel = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureChannel, (call) async {
          if (call.method == 'read') return null;
          if (call.method == 'readAll') return <String, String>{};
          return null;
        });
  });

  group('InAppNotificationNotifier — Dual-Key 5s Deduplication', () {
    test('deduplicates repeated calls with same messageId within 5s', () {
      var now = DateTime(2026, 11, 25, 10, 0, 0);
      final notifier = InAppNotificationNotifier(nowReader: () => now);
      addTearDown(notifier.dispose);

      final emitted = <InAppNotificationPayload?>[];
      notifier.addListener(emitted.add, fireImmediately: false);

      notifier.show(
        title: 'Anh Tân',
        body: 'Tin nhắn A',
        channelId: '42',
        messageId: '1001',
      );
      now = now.add(const Duration(seconds: 2));
      notifier.show(
        title: 'Anh Tân',
        body: 'Tin nhắn A (edited)',
        channelId: '42',
        messageId: '1001',
      );

      expect(emitted.length, 1);
      expect(emitted.single?.body, 'Tin nhắn A');
    });

    test(
      'cross-source dedup: messageId first (FCM) blocks null messageId (WebSocket Bus) with same channelId+body',
      () {
        var now = DateTime(2026, 11, 25, 10, 0, 0);
        final notifier = InAppNotificationNotifier(nowReader: () => now);
        addTearDown(notifier.dispose);

        final emitted = <InAppNotificationPayload?>[];
        notifier.addListener(emitted.add, fireImmediately: false);

        notifier.show(
          title: 'Anh Tân',
          body: '  Alo kiểm tra tiến độ  ',
          channelId: '42',
          messageId: '2001',
        );
        now = now.add(const Duration(seconds: 1));
        notifier.show(
          title: 'Anh Tân',
          body: 'Alo kiểm tra tiến độ',
          channelId: '42',
          messageId: null,
        );

        expect(emitted.length, 1);
      },
    );

    test(
      'cross-source dedup reverse: null messageId first (WebSocket Bus) blocks messageId (FCM) with same channelId+body',
      () {
        var now = DateTime(2026, 11, 25, 10, 0, 0);
        final notifier = InAppNotificationNotifier(nowReader: () => now);
        addTearDown(notifier.dispose);

        final emitted = <InAppNotificationPayload?>[];
        notifier.addListener(emitted.add, fireImmediately: false);

        notifier.show(
          title: 'Anh Tân',
          body: 'Chốt phương án nhé',
          channelId: '42',
          messageId: null,
        );
        now = now.add(const Duration(seconds: 1));
        notifier.show(
          title: 'Anh Tân',
          body: 'Chốt phương án nhé',
          channelId: '42',
          messageId: '2002',
        );

        expect(emitted.length, 1);
      },
    );

    test('allows distinct messages and allows same message after >= 5s', () {
      var now = DateTime(2026, 11, 25, 10, 0, 0);
      final notifier = InAppNotificationNotifier(nowReader: () => now);
      addTearDown(notifier.dispose);

      final emitted = <InAppNotificationPayload?>[];
      notifier.addListener(emitted.add, fireImmediately: false);

      notifier.show(
        title: 'Anh Tân',
        body: 'Tin 1',
        channelId: '42',
        messageId: '3001',
      );
      now = now.add(const Duration(seconds: 1));
      notifier.show(
        title: 'Anh Tân',
        body: 'Tin 2',
        channelId: '42',
        messageId: '3002',
      );
      now = now.add(const Duration(seconds: 5));
      notifier.show(
        title: 'Anh Tân',
        body: 'Tin 1',
        channelId: '42',
        messageId: '3001',
      );

      expect(emitted.length, 3);
      expect(emitted.map((e) => e?.body).toList(), ['Tin 1', 'Tin 2', 'Tin 1']);
    });
  });

  group('InAppNotificationNotifier — Active Room Guard', () {
    test('blocks /chat/42 and /chat/42/info while allowing channel 99', () {
      var currentPath = '/chat/42';
      final notifier = InAppNotificationNotifier(
        currentPathReader: () => currentPath,
      );
      addTearDown(notifier.dispose);

      final emitted = <InAppNotificationPayload?>[];
      notifier.addListener(emitted.add, fireImmediately: false);

      notifier.show(
        title: 'User A',
        body: 'Should be suppressed in /chat/42',
        channelId: '42',
        messageId: '4001',
      );
      expect(emitted, isEmpty);

      currentPath = '/chat/42/info';
      notifier.show(
        title: 'User A',
        body: 'Should be suppressed in /chat/42/info',
        channelId: '42',
        messageId: '4002',
      );
      expect(emitted, isEmpty);

      currentPath = '/chat/42';
      notifier.show(
        title: 'User B',
        body: 'Should show for channel 99',
        channelId: '99',
        messageId: '4003',
      );
      expect(emitted.length, 1);
      expect(emitted.single?.channelId, '99');
    });
  });

  group('PushNotificationService Classification Matrix', () {
    test('classifies chat vs ticket vs task vs attendance vs chatter vs call', () {
      expect(
        PushNotificationService.isChatPush({
          'event_type': 'chat_message',
          'channel_id': '42',
        }),
        isTrue,
      );
      expect(
        PushNotificationService.isChatPush({
          'model': 'discuss.channel',
          'res_id': '42',
        }),
        isTrue,
      );
      expect(
        PushNotificationService.isChatPush({
          'channel_id': '42',
        }),
        isTrue,
      );

      // Crucial: non-chat modules carrying res_id MUST return false
      expect(
        PushNotificationService.isChatPush({
          'event_type': 'ticket_message',
          'res_id': '501',
        }),
        isFalse,
      );
      expect(
        PushNotificationService.isChatPush({
          'event_type': 'task_message',
          'res_id': '88',
        }),
        isFalse,
      );
      expect(
        PushNotificationService.isChatPush({
          'event_type': 'attendance',
          'action': 'checkin',
        }),
        isFalse,
      );
      expect(
        PushNotificationService.isChatPush({
          'event_type': 'mail_notification',
          'res_id': '12',
        }),
        isFalse,
      );
      expect(
        PushNotificationService.isChatPush({
          'model': 'helpdesk.ticket',
          'res_id': '501',
        }),
        isFalse,
      );
      expect(
        PushNotificationService.isChatPush({
          'model': 'project.task',
          'res_id': '88',
        }),
        isFalse,
      );
      expect(
        PushNotificationService.isChatPush({
          'model': 'hr.attendance',
          'res_id': '15',
        }),
        isFalse,
      );
      expect(
        PushNotificationService.isChatPush({
          'model': 'hr.applicant',
          'res_id': '21',
        }),
        isFalse,
      );
      expect(
        PushNotificationService.isChatPush({
          'channel_id': '0',
        }),
        isFalse,
      );
      expect(
        PushNotificationService.isChatPush({
          'channel_id': false,
        }),
        isFalse,
      );

      // Call events: isCallPush true, isChatPush false (even if channel_id is present)
      for (final callEvent in [
        'vmobile_call_incoming',
        'incoming_call',
        'vmobile_call_ended',
        'call_ended',
        'call_cancelled',
      ]) {
        final payload = {'event_type': callEvent, 'channel_id': '42'};
        expect(
          PushNotificationService.isCallPush(payload),
          isTrue,
          reason: '$callEvent must be classified as call push',
        );
        expect(
          PushNotificationService.isChatPush(payload),
          isFalse,
          reason: '$callEvent must NOT be classified as chat push',
        );
      }
    });
  });

  group('AuthController Multi-DB Switch Unregister', () {
    test(
      'unregisters previous DB before clearing session when switching to a different DB',
      () async {
        final pushService = _TrackingPushNotificationService();
        final authRepo = _FakeAuthRepository(pushService.events);

        await odooApiClient.setSession(
          OdooSession(
            accessToken: 'token_db_a',
            uid: 1,
            db: 'db_a',
            login: 'tan@360.org.vn',
            expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
            baseUrl: 'https://db-a.example.com',
          ),
        );

        final container = ProviderContainer(
          overrides: [
            pushNotificationServiceProvider.overrideWithValue(pushService),
            authRepositoryProvider.overrideWithValue(authRepo),
          ],
        );
        addTearDown(container.dispose);

        await container.read(authControllerProvider.future);

        await container.read(authControllerProvider.notifier).authenticateOnClient(
          db: const DbInfo(
            login: 'tan@360.org.vn',
            databaseName: 'db_b',
            databaseUrl: 'https://db-b.example.com',
          ),
          login: 'tan@360.org.vn',
          password: 'secret',
        );

        expect(pushService.unregisterCalls, 1);
        expect(
          pushService.events.indexOf('unregister'),
          lessThan(pushService.events.indexOf('authenticate:db_b')),
        );
      },
    );

    test('skips unregister when re-authenticating on the same DB', () async {
      final pushService = _TrackingPushNotificationService();
      final authRepo = _FakeAuthRepository(pushService.events);

      await odooApiClient.setSession(
        OdooSession(
          accessToken: 'token_db_a',
          uid: 1,
          db: 'db_a',
          login: 'tan@360.org.vn',
          expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
          baseUrl: 'https://db-a.example.com',
        ),
      );

      final container = ProviderContainer(
        overrides: [
          pushNotificationServiceProvider.overrideWithValue(pushService),
          authRepositoryProvider.overrideWithValue(authRepo),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authControllerProvider.future);

      await container.read(authControllerProvider.notifier).activateVerifiedSession(
        db: const DbInfo(
          login: 'tan@360.org.vn',
          databaseName: 'db_a',
          databaseUrl: 'https://db-a.example.com',
        ),
        session: OdooSession(
          accessToken: 'token_db_a_2',
          uid: 1,
          db: 'db_a',
          login: 'tan@360.org.vn',
          expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
          baseUrl: 'https://db-a.example.com',
        ),
        login: 'tan@360.org.vn',
      );

      expect(pushService.unregisterCalls, 0);
    });

    test(
      'times out after 2s and never blocks login to new DB when old DB hangs',
      () async {
        final pushService = _TrackingPushNotificationService()
          ..hangUnregister = true;
        final authRepo = _FakeAuthRepository(pushService.events);

        await odooApiClient.setSession(
          OdooSession(
            accessToken: 'token_db_a',
            uid: 1,
            db: 'db_a',
            login: 'tan@360.org.vn',
            expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
            baseUrl: 'https://db-a.example.com',
          ),
        );

        final container = ProviderContainer(
          overrides: [
            pushNotificationServiceProvider.overrideWithValue(pushService),
            authRepositoryProvider.overrideWithValue(authRepo),
          ],
        );
        addTearDown(container.dispose);

        await container.read(authControllerProvider.future);

        final sw = Stopwatch()..start();
        await container.read(authControllerProvider.notifier).authenticateOnClient(
          db: const DbInfo(
            login: 'tan@360.org.vn',
            databaseName: 'db_b',
            databaseUrl: 'https://db-b.example.com',
          ),
          login: 'tan@360.org.vn',
          password: 'secret',
        );
        sw.stop();

        expect(pushService.unregisterCalls, 1);
        expect(pushService.events, contains('authenticate:db_b'));
        expect(sw.elapsed, lessThan(const Duration(seconds: 4)));
      },
    );
  });
}
