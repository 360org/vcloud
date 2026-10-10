import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vcloud/core/api/auth_user.dart';
import 'package:vcloud/features/auth/application/auth_controller.dart';
import 'package:vcloud/features/profile/presentation/profile_screen.dart';

class _FakeAuthController extends AuthController {
  _FakeAuthController(this._user);
  final AuthUser? _user;

  @override
  Future<AuthUser?> build() async => _user;
}

Widget _buildProfileApp(AuthUser user) {
  final router = GoRouter(
    initialLocation: '/profile',
    routes: [
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/profile/edit',
        builder: (context, state) => const Scaffold(body: Text('Edit Profile')),
      ),
      GoRoute(
        path: '/profile/about',
        builder: (context, state) => const Scaffold(body: Text('About Screen')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      authControllerProvider.overrideWith(() => _FakeAuthController(user)),
    ],
    child: MaterialApp.router(
      routerConfig: router,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Feature 6.4, 6.5 & 6.8: Profile Compliance, Token & Cache Tests', () {
    const testUser = AuthUser(
      id: '99',
      email: 'user_compliance@360.org.vn',
      userMetadata: {'name': 'Người Dùng Test'},
    );

    testWidgets('6.4: Clear cache row displays in profile and triggers confirmation dialog', (tester) async {
      await tester.pumpWidget(_buildProfileApp(testUser));
      await tester.pumpAndSettle();

      // Find clear cache option
      final clearCacheTile = find.text('Xóa bộ nhớ đệm');
      expect(clearCacheTile, findsOneWidget);

      await tester.tap(clearCacheTile);
      await tester.pumpAndSettle();

      // Check dialog
      expect(find.text('Dọn dẹp bộ nhớ đệm?'), findsOneWidget);
      expect(find.text('Hủy'), findsOneWidget);
      expect(find.text('Dọn dẹp'), findsOneWidget);

      // Dismiss dialog
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();

      expect(find.text('Dọn dẹp bộ nhớ đệm?'), findsNothing);
    });

    testWidgets('6.5: FCM Device Token is safely unexposed on general profile screen', (tester) async {
      await tester.pumpWidget(_buildProfileApp(testUser));
      await tester.pumpAndSettle();

      // Sensitive FCM token string should never be exposed in plaintext on public profile UI
      expect(find.textContaining('fcm_token_'), findsNothing);
      expect(find.textContaining('FCM Token:'), findsNothing);
    });

    testWidgets('6.8: Account deletion compliance dialog displays 30-day notice and action buttons', (tester) async {
      await tester.pumpWidget(_buildProfileApp(testUser));
      await tester.pumpAndSettle();

      // Find delete account option (may require scrolling in ListView)
      final deleteAccountTile = find.text('Yêu cầu xóa tài khoản');
      await tester.scrollUntilVisible(deleteAccountTile, 100);
      expect(deleteAccountTile, findsOneWidget);

      await tester.tap(deleteAccountTile);
      await tester.pumpAndSettle();

      // Verify deletion compliance dialog content
      expect(find.text('Yêu cầu xóa tài khoản'), findsWidgets);
      expect(find.textContaining('30 ngày'), findsOneWidget);
      expect(find.text('Hủy'), findsOneWidget);
      expect(find.text('Gửi yêu cầu'), findsOneWidget);

      // Cancel dismissal
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();

      expect(find.textContaining('30 ngày'), findsNothing);
    });
  });
}
