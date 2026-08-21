import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/attendance/presentation/attendance_history_screen.dart';
import '../../features/attendance/presentation/attendance_screen.dart';
import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/signup_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/chat/presentation/new_chat_screen.dart';
import '../../features/chat_v2/presentation/screens/chat_v2_detail_screen.dart';
import '../../features/chat_v2/presentation/screens/chat_v2_list_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/profile/presentation/about_screen.dart';
import '../../features/profile/presentation/edit_profile_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/ticket/presentation/create_ticket_screen.dart';
import '../../features/ticket/presentation/ticket_detail_screen.dart';
import '../../features/ticket/presentation/ticket_list_screen.dart';
import '../../features/timesheet/presentation/create_entry_screen.dart';
import '../../features/timesheet/presentation/timesheet_list_screen.dart';

/// Bridges the async auth provider into a `Listenable` so GoRouter
/// re-evaluates its redirect on every auth-state change.
class _AuthListenable extends ChangeNotifier {
  _AuthListenable(this._ref) {
    _ref.listen(authControllerProvider, (_, _) => notifyListeners());
  }
  final Ref _ref;
}

CustomTransitionPage<void> _buildFadePage({
  required GoRouterState state,
  required Widget child,
  Duration duration = const Duration(milliseconds: 240),
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        ),
        child: child,
      );
    },
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  final listenable = _AuthListenable(ref);
  ref.onDispose(listenable.dispose);

  return GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: false,
    refreshListenable: listenable,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final fullPath = state.uri.toString();
      final sub = ref.read(authControllerProvider);

      final isSplash = loc == '/splash' || loc.startsWith('/splash');
      final isLogin = loc == '/login' || loc.startsWith('/login');
      final isSignup = loc == '/signup' || loc.startsWith('/signup');
      final onAuthScreen = isLogin || isSignup;

      if (sub.isLoading) {
        return isSplash ? null : '/splash';
      }

      final user = sub.value;

      if (user == null) {
        if (isSplash || onAuthScreen) return null;
        final fromParam = Uri.encodeQueryComponent(fullPath);
        return '/login?from=$fromParam';
      }

      if (isSplash || onAuthScreen) {
        final fromParam = state.uri.queryParameters['from'];
        if (fromParam != null && fromParam.isNotEmpty) {
          try {
            final decoded = Uri.decodeQueryComponent(fromParam);
            if (decoded.isNotEmpty &&
                !decoded.startsWith('/login') &&
                !decoded.startsWith('/signup') &&
                !decoded.startsWith('/splash')) {
              return decoded;
            }
          } catch (_) {}
        }
        return '/chat';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: const SplashScreen(),
          transitionDuration: const Duration(milliseconds: 350),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
              child: child,
            );
          },
        ),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: const LoginScreen(),
          transitionDuration: const Duration(milliseconds: 350),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
              child: child,
            );
          },
        ),
      ),
      GoRoute(
        path: '/signup',
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: const SignupScreen(),
          transitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
              child: child,
            );
          },
        ),
      ),
      GoRoute(
        path: '/home',
        pageBuilder: (context, state) => _buildFadePage(
          state: state,
          child: const HomeScreen(),
        ),
      ),
      GoRoute(
        path: '/profile',
        pageBuilder: (context, state) => _buildFadePage(
          state: state,
          child: const ProfileScreen(),
        ),
      ),
      GoRoute(
        path: '/profile/edit',
        builder: (_, _) => const EditProfileScreen(),
      ),
      GoRoute(
        path: '/profile/about',
        pageBuilder: (context, state) => _buildFadePage(
          state: state,
          child: const AboutScreen(),
        ),
      ),

      // Chat (V2 - Độc lập, tin cậy)
      GoRoute(
        path: '/chat',
        pageBuilder: (context, state) => _buildFadePage(
          state: state,
          child: ChatV2ListScreen(
            initialFilter: state.uri.queryParameters['filter'],
          ),
        ),
      ),
      GoRoute(path: '/chat/new', builder: (_, _) => const NewChatScreen()),
      GoRoute(
        path: '/chat/:id',
        builder: (_, s) => ChatV2DetailScreen(
          channelId: s.pathParameters['id']!,
          title: s.uri.queryParameters['name'],
          initialAvatarUrl: s.uri.queryParameters['avatar'],
          initialPartnerId: s.uri.queryParameters['partner_id'],
        ),
      ),

      // Attendance
      GoRoute(
        path: '/attendance',
        pageBuilder: (context, state) => _buildFadePage(
          state: state,
          child: const AttendanceScreen(),
        ),
      ),
      GoRoute(
        path: '/attendance/history',
        pageBuilder: (context, state) => _buildFadePage(
          state: state,
          child: const AttendanceHistoryScreen(),
        ),
      ),

      // Timesheets
      GoRoute(
        path: '/timesheet',
        pageBuilder: (context, state) => _buildFadePage(
          state: state,
          child: const TimesheetListScreen(),
        ),
      ),
      GoRoute(
        path: '/timesheet/new',
        builder: (_, _) => const CreateEntryScreen(),
      ),

      // Tickets
      GoRoute(
        path: '/tickets',
        pageBuilder: (context, state) => _buildFadePage(
          state: state,
          child: const TicketListScreen(),
        ),
      ),
      GoRoute(
        path: '/tickets/new',
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: const CreateTicketScreen(),
          transitionDuration: const Duration(milliseconds: 260),
          reverseTransitionDuration: const Duration(milliseconds: 220),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curvedAnimation = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1.0, 0.0),
                end: Offset.zero,
              ).animate(curvedAnimation),
              child: child,
            );
          },
        ),
      ),
      GoRoute(
        path: '/tickets/:id',
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: TicketDetailScreen(ticketId: state.pathParameters['id']!),
          transitionDuration: const Duration(milliseconds: 260),
          reverseTransitionDuration: const Duration(milliseconds: 220),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curvedAnimation = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1.0, 0.0),
                end: Offset.zero,
              ).animate(curvedAnimation),
              child: child,
            );
          },
        ),
      ),
    ],
  );
});
