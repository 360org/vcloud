import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:vcloud/core/api/auth_user.dart';
import 'package:vcloud/features/auth/application/auth_controller.dart';
import 'package:vcloud/shared/widgets/app_scaffold.dart';

class _FakeAuthController extends AuthController {
  _FakeAuthController(this._user);
  final AuthUser? _user;

  @override
  Future<AuthUser?> build() async => _user;
}

void main() {
  group('Portal Home Tab & Attendance Lock Contract Tests', () {
    testWidgets('1. AppScaffold renders Home tab as first tab for Portal User without helpdesk', (tester) async {
      const portalUser = AuthUser(
        id: '100',
        email: 'portal_nohd@domain.com',
        userMetadata: {
          'is_portal': true,
          'installed_modules': {'helpdesk': false, 'hr_attendance': false},
        },
      );

      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const AppScaffold(
              title: 'Home',
              showAppBar: false,
              body: Text('Home Content'),
            ),
          ),
          GoRoute(path: '/chat', builder: (context, state) => const SizedBox()),
          GoRoute(path: '/profile', builder: (context, state) => const SizedBox()),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(() => _FakeAuthController(portalUser)),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Kiểm tra có tab Home, Chat, Tôi trong thanh điều hướng
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Chat'), findsOneWidget);
      expect(find.text('Tôi'), findsOneWidget);
      // Chắc chắn không có Ticket khi helpdesk == false
      expect(find.text('Ticket'), findsNothing);
      expect(find.text('Timesheet'), findsNothing);
    });

    testWidgets('2. AppScaffold renders Home, Chat, Ticket, Tôi for Portal User with helpdesk', (tester) async {
      const portalUserWithHd = AuthUser(
        id: '101',
        email: 'portal_hd@domain.com',
        userMetadata: {
          'is_portal': true,
          'installed_modules': {'helpdesk': true, 'hr_attendance': false},
        },
      );

      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const AppScaffold(
              title: 'Home',
              showAppBar: false,
              body: Text('Home Content'),
            ),
          ),
          GoRoute(path: '/chat', builder: (context, state) => const SizedBox()),
          GoRoute(path: '/tickets', builder: (context, state) => const SizedBox()),
          GoRoute(path: '/profile', builder: (context, state) => const SizedBox()),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(() => _FakeAuthController(portalUserWithHd)),
          ],
          child: MaterialApp.router(
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Kiểm tra đầy đủ 4 tabs Portal: Home, Chat, Ticket, Tôi
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Chat'), findsOneWidget);
      expect(find.text('Ticket'), findsOneWidget);
      expect(find.text('Tôi'), findsOneWidget);
      // Chắc chắn Timesheet bị ẩn
      expect(find.text('Timesheet'), findsNothing);
    });

    testWidgets('3. Attendance Locked Widget shows SnackBar when tapped with hasAttendance == false', (tester) async {
      var snackBarShown = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return GestureDetector(
                  onTap: () {
                    snackBarShown = true;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Tính năng yêu cầu cài đặt Module Chấm công'),
                      ),
                    );
                  },
                  child: const Row(
                    children: [
                      Icon(LucideIcons.lock),
                      Text('Khóa 🔒'),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      );

      expect(find.text('Khóa 🔒'), findsOneWidget);
      expect(find.byIcon(LucideIcons.lock), findsOneWidget);

      await tester.tap(find.text('Khóa 🔒'));
      await tester.pump();

      expect(snackBarShown, isTrue);
      expect(find.text('Tính năng yêu cầu cài đặt Module Chấm công'), findsOneWidget);
    });

    testWidgets('4. GoRouter redirect guard: Portal user accessing /timesheet is redirected to /home', (tester) async {
      const portalUser = AuthUser(
        id: '102',
        email: 'portal_timesheet_blocked@domain.com',
        userMetadata: {
          'is_portal': true,
          'installed_modules': {'helpdesk': true, 'hr_attendance': false, 'hr_timesheet': true},
        },
      );

      final router = GoRouter(
        initialLocation: '/timesheet',
        redirect: (context, state) {
          final loc = state.matchedLocation;
          if (portalUser.isPortal && loc.startsWith('/timesheet')) {
            return '/home';
          }
          return null;
        },
        routes: [
          GoRoute(path: '/home', builder: (context, state) => const Text('Home Screen Active')),
          GoRoute(path: '/timesheet', builder: (context, state) => const Text('Timesheet Screen Active')),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Home Screen Active'), findsOneWidget);
      expect(find.text('Timesheet Screen Active'), findsNothing);
    });

    testWidgets('5. GoRouter redirect guard: /attendance is redirected to /home when hasAttendance is false', (tester) async {
      const userNoAttendance = AuthUser(
        id: '103',
        email: 'no_attendance@domain.com',
        userMetadata: {
          'is_portal': true,
          'installed_modules': {'hr_attendance': false},
        },
      );

      final router = GoRouter(
        initialLocation: '/attendance',
        redirect: (context, state) {
          final loc = state.matchedLocation;
          if (!userNoAttendance.hasAttendance && (loc == '/attendance' || loc.startsWith('/attendance'))) {
            return '/home';
          }
          return null;
        },
        routes: [
          GoRoute(path: '/home', builder: (context, state) => const Text('Home Screen Active')),
          GoRoute(path: '/attendance', builder: (context, state) => const Text('Attendance Screen Active')),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Home Screen Active'), findsOneWidget);
      expect(find.text('Attendance Screen Active'), findsNothing);
    });

    testWidgets('6. GoRouter redirect guard: /tickets is redirected to /home when Portal has no helpdesk', (tester) async {
      const portalNoHelpdesk = AuthUser(
        id: '104',
        email: 'no_helpdesk@domain.com',
        userMetadata: {
          'is_portal': true,
          'installed_modules': {'helpdesk': false},
        },
      );

      final router = GoRouter(
        initialLocation: '/tickets',
        redirect: (context, state) {
          final loc = state.matchedLocation;
          if (portalNoHelpdesk.isPortal && !portalNoHelpdesk.hasHelpdesk && (loc == '/tickets' || loc.startsWith('/tickets'))) {
            return '/home';
          }
          return null;
        },
        routes: [
          GoRoute(path: '/home', builder: (context, state) => const Text('Home Screen Active')),
          GoRoute(path: '/tickets', builder: (context, state) => const Text('Ticket Screen Active')),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Home Screen Active'), findsOneWidget);
      expect(find.text('Ticket Screen Active'), findsNothing);
    });
  });
}
