import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vcloud/core/api/auth_user.dart';
import 'package:vcloud/features/auth/application/auth_controller.dart';
import 'package:vcloud/features/auth/data/auth_repository.dart';
import 'package:vcloud/features/auth/presentation/splash_screen.dart';

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository(this._completer);
  final Completer<AuthUser?> _completer;

  @override
  Future<AuthUser?> currentUser() => _completer.future;
}

void main() {
  testWidgets('SplashScreen does not prematurely flash /login while auth is loading', (tester) async {
    final authCompleter = Completer<AuthUser?>();
    final fakeRepo = _FakeAuthRepository(authCompleter);

    String? currentLocation;

    final router = GoRouter(
      initialLocation: '/splash',
      routes: [
        GoRoute(
          path: '/splash',
          builder: (context, state) {
            currentLocation = '/splash';
            return const SplashScreen();
          },
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) {
            currentLocation = '/login';
            return const Scaffold(body: Text('LOGIN SCREEN'));
          },
        ),
        GoRoute(
          path: '/home',
          builder: (context, state) {
            currentLocation = '/home';
            return const Scaffold(body: Text('HOME SCREEN'));
          },
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: MaterialApp.router(
          routerConfig: router,
        ),
      ),
    );

    // Initial pump -> shows Splash
    await tester.pump();
    expect(currentLocation, equals('/splash'));

    // Advance 2 seconds (longer than previous 1.5s fallback)
    await tester.pump(const Duration(seconds: 2));

    // MUST STILL BE on /splash, NOT flashed to /login!
    expect(currentLocation, equals('/splash'));
    expect(find.text('LOGIN SCREEN'), findsNothing);

    // Now resolve auth with a valid portal user
    authCompleter.complete(
      const AuthUser(
        id: '1',
        email: 'tan123456',
        userMetadata: {'is_portal': true},
      ),
    );

    await tester.pumpAndSettle();

    // Directly transitions to /home, never passing through /login
    expect(currentLocation, equals('/home'));
    expect(find.text('HOME SCREEN'), findsOneWidget);
    expect(find.text('LOGIN SCREEN'), findsNothing);
  });
}
