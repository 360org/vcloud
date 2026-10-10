import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vcloud/core/api/auth_user.dart';
import 'package:vcloud/features/auth/application/auth_controller.dart';
import 'package:vcloud/features/auth/data/auth_repository.dart';
import 'package:vcloud/features/auth/presentation/splash_screen.dart';
import 'package:vcloud/features/chat_v2/application/chat_v2_channels_controller.dart';
import 'package:vcloud/features/chat_v2/data/models/chat_v2_channel.dart';
import 'package:vcloud/features/home/application/home_summary_controller.dart';
import 'package:vcloud/features/home/data/dashboard_repository.dart';
import 'package:vcloud/features/ticket/application/ticket_controller.dart';

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({this.userToReturn});
  final AuthUser? userToReturn;

  @override
  Future<AuthUser?> currentUser() async => userToReturn;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubAuthController extends AuthController {
  _StubAuthController(this._stubUser);
  final AuthUser? _stubUser;

  @override
  Future<AuthUser?> build() async => _stubUser;
}

class _FakeChannelsNotifier extends ChatV2ChannelsNotifier {
  @override
  Future<List<ChatV2Channel>> build() async => const [];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Feature 1.4: Auto-Restore Session & Splash Route Tests', () {
    test('AuthController restores user session from repository when token is valid', () async {
      const mockUser = AuthUser(
        id: '42',
        email: 'tanmnn@360.org.vn',
        userMetadata: {'name': 'Ma Nguyễn Nhật Tân'},
      );

      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository(userToReturn: mockUser)),
        ],
      );
      addTearDown(container.dispose);

      final restored = await container.read(authControllerProvider.future);
      expect(restored, isNotNull);
      expect(restored?.id, '42');
      expect(restored?.email, 'tanmnn@360.org.vn');
    });

    test('AuthController returns null when no stored session or token expired', () async {
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(_FakeAuthRepository(userToReturn: null)),
        ],
      );
      addTearDown(container.dispose);

      final restored = await container.read(authControllerProvider.future);
      expect(restored, isNull);
    });

    testWidgets('SplashScreen redirects to /login when user is not authenticated', (tester) async {
      String currentLocation = '/splash';

      final router = GoRouter(
        initialLocation: '/splash',
        routes: [
          GoRoute(
            path: '/splash',
            builder: (context, state) => const SplashScreen(),
          ),
          GoRoute(
            path: '/login',
            builder: (context, state) {
              currentLocation = '/login';
              return const Scaffold(body: Text('Login Screen'));
            },
          ),
          GoRoute(
            path: '/chat',
            builder: (context, state) {
              currentLocation = '/chat';
              return const Scaffold(body: Text('Chat Screen'));
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(() => _StubAuthController(null)),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );

      // Trigger initState frame callback
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(currentLocation, '/login');
      expect(find.text('Login Screen'), findsOneWidget);
    });

    testWidgets('SplashScreen warms up and redirects to /chat when session is valid', (tester) async {
      const mockUser = AuthUser(
        id: '1',
        email: 'admin@vuahethong.net',
        userMetadata: {'name': 'Administrator'},
      );

      String currentLocation = '/splash';

      final router = GoRouter(
        initialLocation: '/splash',
        routes: [
          GoRoute(
            path: '/splash',
            builder: (context, state) => const SplashScreen(),
          ),
          GoRoute(
            path: '/login',
            builder: (context, state) {
              currentLocation = '/login';
              return const Scaffold(body: Text('Login Screen'));
            },
          ),
          GoRoute(
            path: '/chat',
            builder: (context, state) {
              currentLocation = '/chat';
              return const Scaffold(body: Text('Chat Screen'));
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(() => _StubAuthController(mockUser)),
            // Warm-up provider overrides to avoid actual network calls
            mobileDashboardSummaryProvider.overrideWith((ref) => Future.value(const MobileDashboardSummary())),
            chatV2ChannelsProvider.overrideWith(() => _FakeChannelsNotifier()),
            ticketsProvider.overrideWith((ref) => Stream.value(const [])),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );

      await tester.pump();
      // Pump past warmup timeout (800ms)
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpAndSettle();

      expect(currentLocation, '/chat');
      expect(find.text('Chat Screen'), findsOneWidget);
    });
  });
}
