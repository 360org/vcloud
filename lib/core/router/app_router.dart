import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/attendance/presentation/attendance_history_screen.dart';
import '../../features/attendance/presentation/attendance_screen.dart';
import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/signup_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/chat/presentation/chat_detail_screen.dart';
import '../../features/chat/presentation/conversation_list_screen.dart';
import '../../features/chat/presentation/new_chat_screen.dart';
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
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (_, _) => const SignupScreen()),
      GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
      GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
      GoRoute(
        path: '/profile/edit',
        builder: (_, _) => const EditProfileScreen(),
      ),
      GoRoute(path: '/profile/about', builder: (_, _) => const AboutScreen()),

      // Chat
      GoRoute(
        path: '/chat',
        builder: (_, s) => TelegramConversationListScreen(
          unreadOnly: s.uri.queryParameters['filter'] == 'unread',
        ),
      ),
      GoRoute(path: '/chat/new', builder: (_, _) => const NewChatScreen()),
      GoRoute(
        path: '/chat/:id',
        builder: (_, s) =>
            ChatDetailScreen(conversationId: s.pathParameters['id']!),
      ),

      // Attendance
      GoRoute(path: '/attendance', builder: (_, _) => const AttendanceScreen()),
      GoRoute(
        path: '/attendance/history',
        builder: (_, _) => const AttendanceHistoryScreen(),
      ),

      // Timesheets
      GoRoute(
        path: '/timesheet',
        builder: (_, _) => const TimesheetListScreen(),
      ),
      GoRoute(
        path: '/timesheet/new',
        builder: (_, _) => const CreateEntryScreen(),
      ),

      // Tickets
      GoRoute(path: '/tickets', builder: (_, _) => const TicketListScreen()),
      GoRoute(
        path: '/tickets/new',
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: const CreateTicketScreen(),
          transitionDuration: const Duration(milliseconds: 380),
          reverseTransitionDuration: const Duration(milliseconds: 320),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curvedSlide = CurvedAnimation(
              parent: animation,
              curve: Curves.fastOutSlowIn,
            );
            final curvedFade = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            );
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.0, 1.0),
                end: Offset.zero,
              ).animate(curvedSlide),
              child: FadeTransition(
                opacity: curvedFade,
                child: child,
              ),
            );
          },
        ),
      ),
      GoRoute(
        path: '/tickets/:id',
        pageBuilder: (context, state) => CustomTransitionPage<void>(
          key: state.pageKey,
          child: TicketDetailScreen(ticketId: state.pathParameters['id']!),
          transitionDuration: const Duration(milliseconds: 320),
          reverseTransitionDuration: const Duration(milliseconds: 280),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curvedAnimation = CurvedAnimation(
              parent: animation,
              curve: Curves.fastEaseInToSlowEaseOut,
              reverseCurve: Curves.fastOutSlowIn,
            );
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.2, 0.0),
                end: Offset.zero,
              ).animate(curvedAnimation),
              child: FadeTransition(
                opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
                  ),
                ),
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.98, end: 1.0).animate(curvedAnimation),
                  child: child,
                ),
              ),
            );
          },
        ),
      ),
    ],
  );
});
