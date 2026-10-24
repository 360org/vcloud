import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:vcloud/core/api/auth_user.dart';
import 'package:vcloud/features/auth/application/auth_controller.dart';
import 'package:vcloud/features/ticket/application/ticket_controller.dart';
import 'package:vcloud/features/ticket/data/ticket_comment_repository.dart';
import 'package:vcloud/features/ticket/data/ticket_repository.dart';
import 'package:vcloud/features/ticket/presentation/ticket_detail_screen.dart';
import 'package:vcloud/shared/models/ticket.dart';
import 'package:vcloud/shared/models/ticket_activity.dart';
import 'package:vcloud/shared/models/ticket_comment.dart';

class _MockAuthController extends AuthController {
  _MockAuthController(this._user);
  final AuthUser? _user;

  @override
  Future<AuthUser?> build() async => _user;
}

class _MockTicketRepository extends TicketRepository {
  _MockTicketRepository(this._ticket);
  final Ticket _ticket;

  @override
  Future<Ticket> one(String id) async => _ticket;

  @override
  Future<List<TicketActivity>> activities(String ticketId, {bool includeDone = false}) async => const [];
}

class _MockTicketCommentRepository extends TicketCommentRepository {
  _MockTicketCommentRepository();

  @override
  Stream<List<TicketComment>> watchByTicket(String ticketId) => Stream.value(const []);
}

void main() {
  const adminUser = AuthUser(
    id: '2',
    email: 'admin@vcloud.com',
    userMetadata: {
      'is_portal': false,
      'display_name': 'Chau, Le Ba',
    },
  );

  final testTicket = Ticket(
    id: '1738',
    title: '[TICKET-VIP] Đề xuất duyệt bản vẽ thiết kế Gateway & App Mobile',
    description: 'Chi tiết bản vẽ kỹ thuật.',
    status: TicketStatus.doing,
    priority: TicketPriority.p4,
    createdBy: '2',
    createdAt: DateTime(2026, 10, 24, 10, 0),
    updatedAt: DateTime(2026, 10, 24, 10, 0),
    assignedTo: '2',
    assignedUserName: 'Chau, Le Ba',
    partnerName: 'Công ty Cổ phần Đầu tư Phát triển...',
  );

  final overrides = [
    authControllerProvider.overrideWith(() => _MockAuthController(adminUser)),
    ticketRepositoryProvider.overrideWithValue(_MockTicketRepository(testTicket)),
    ticketCommentRepositoryProvider.overrideWithValue(_MockTicketCommentRepository()),
  ];

  testWidgets(
    'Nút Back trên TicketDetailScreen: Pop khi có trang trước trong stack',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final router = GoRouter(
        initialLocation: '/tickets',
        routes: [
          GoRoute(
            path: '/tickets',
            builder: (context, state) => Scaffold(
              body: ElevatedButton(
                onPressed: () => context.push('/tickets/1738'),
                child: const Text('Go to Detail'),
              ),
            ),
          ),
          GoRoute(
            path: '/tickets/:id',
            builder: (context, state) => TicketDetailScreen(ticketId: state.pathParameters['id']!),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: MaterialApp.router(
            theme: ThemeData(useMaterial3: false),
            routerConfig: router,
          ),
        ),
      );

      expect(find.text('Go to Detail'), findsOneWidget);

      await tester.tap(find.text('Go to Detail'));
      await tester.pumpAndSettle();

      expect(find.text('#1738 · Ticket'), findsOneWidget);

      final backButton = find.byIcon(LucideIcons.chevronLeft);
      expect(backButton, findsOneWidget);
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      expect(find.text('Go to Detail'), findsOneWidget);
      expect(find.text('#1738 · Ticket'), findsNothing);
    },
  );

  testWidgets(
    'Nút Back trên TicketDetailScreen: Fallback về /tickets khi mở từ Push Notification (stack rỗng)',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final router = GoRouter(
        initialLocation: '/tickets/1738',
        routes: [
          GoRoute(
            path: '/tickets',
            builder: (context, state) => const Scaffold(body: Text('Màn hình Danh sách Ticket')),
          ),
          GoRoute(
            path: '/tickets/:id',
            builder: (context, state) => TicketDetailScreen(ticketId: state.pathParameters['id']!),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: MaterialApp.router(
            theme: ThemeData(useMaterial3: false),
            routerConfig: router,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('#1738 · Ticket'), findsOneWidget);

      final backButton = find.byIcon(LucideIcons.chevronLeft);
      expect(backButton, findsOneWidget);
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      expect(find.text('Màn hình Danh sách Ticket'), findsOneWidget);
      expect(find.text('#1738 · Ticket'), findsNothing);
    },
  );
}
