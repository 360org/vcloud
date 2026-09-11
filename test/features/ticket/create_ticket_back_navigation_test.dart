import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:vcloud/features/ticket/application/ticket_controller.dart';
import 'package:vcloud/features/ticket/presentation/create_ticket_screen.dart';
import 'package:vcloud/shared/models/ticket.dart';

void main() {
  final overrideProviders = [
    ticketTeamsProvider.overrideWith(
      (ref) => Future.value(const [
        TicketTeamOption(id: 1, name: 'Hỗ trợ kỹ thuật'),
      ]),
    ),
    ticketTagsProvider.overrideWith(
      (ref) => Future.value(const [TicketTagOption(id: 10, name: 'Bug')]),
    ),
  ];

  testWidgets(
    'Nút Back trên CreateTicketScreen: Pop khi có trang trước trong stack',
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
                onPressed: () => context.push('/tickets/new'),
                child: const Text('Go to New'),
              ),
            ),
          ),
          GoRoute(
            path: '/tickets/new',
            builder: (context, state) => const CreateTicketScreen(),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: overrideProviders,
          child: MaterialApp.router(
            theme: ThemeData(useMaterial3: false),
            routerConfig: router,
          ),
        ),
      );

      // Bắt đầu từ /tickets
      expect(find.text('Go to New'), findsOneWidget);

      // Push sang /tickets/new
      await tester.tap(find.text('Go to New'));
      await tester.pumpAndSettle();

      // Xác nhận đã vào màn hình CreateTicketScreen với nhãn "Tạo ticket"
      expect(find.text('Tạo ticket'), findsOneWidget);

      // Bấm nút Back (<)
      final backButton = find.byIcon(LucideIcons.chevronLeft);
      expect(backButton, findsOneWidget);
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      // Đã pop thành công về /tickets
      expect(find.text('Go to New'), findsOneWidget);
      expect(find.text('Tạo ticket'), findsNothing);
    },
  );

  testWidgets(
    'Nút Back trên CreateTicketScreen: Fallback về /tickets khi vào trực tiếp URL/Deep-link (stack rỗng)',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final router = GoRouter(
        initialLocation: '/tickets/new',
        routes: [
          GoRoute(
            path: '/tickets',
            builder: (context, state) =>
                const Scaffold(body: Text('Màn hình Danh sách Ticket')),
          ),
          GoRoute(
            path: '/tickets/new',
            builder: (context, state) => const CreateTicketScreen(),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: overrideProviders,
          child: MaterialApp.router(
            theme: ThemeData(useMaterial3: false),
            routerConfig: router,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Đang ở màn hình CreateTicketScreen trực tiếp không có trang trước
      expect(find.text('Tạo ticket'), findsOneWidget);

      // Bấm nút Back (<)
      final backButton = find.byIcon(LucideIcons.chevronLeft);
      expect(backButton, findsOneWidget);
      await tester.tap(backButton);
      await tester.pumpAndSettle();

      // Fallback chính xác về /tickets
      expect(find.text('Màn hình Danh sách Ticket'), findsOneWidget);
      expect(find.text('Tạo ticket'), findsNothing);
    },
  );
}
