import 'package:flutter/foundation.dart';
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
    refreshListenable: listenable,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final sub = ref.read(authControllerProvider);

      // Hold/screenshots on /splash until the controller resolves.
      if (sub.isLoading) {
        return loc == '/splash' ? null : '/splash';
      }

      final user = sub.value;
      final onAuthScreen = loc == '/login' || loc == '/signup';

      if (user == null && !onAuthScreen && loc != '/splash') return '/login';
      if (user != null && (loc == '/splash' || onAuthScreen)) return '/home';
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
        builder: (_, _) => const TelegramConversationListScreen(),
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
        builder: (_, _) => const CreateTicketScreen(),
      ),
      GoRoute(
        path: '/tickets/:id',
        builder: (_, s) =>
            TicketDetailScreen(ticketId: s.pathParameters['id']!),
      ),
    ],
  );
});
