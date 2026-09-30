import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:vcloud/features/profile/presentation/about_screen.dart';

void main() {
  testWidgets('AboutScreen displays app info and privacy policy link', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final router = GoRouter(
      initialLocation: '/profile/about',
      routes: [
        GoRoute(
          path: '/profile/about',
          builder: (context, state) => const AboutScreen(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appVersionProvider.overrideWith((ref) => 'v2.9.12+143'),
        ],
        child: MaterialApp.router(
          theme: ThemeData(useMaterial3: false),
          routerConfig: router,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Thông tin'), findsOneWidget);
    expect(find.text('Phiên bản v2.9.12+143'), findsOneWidget);
    expect(find.text('Chính sách quyền riêng tư'), findsOneWidget);
    expect(find.byIcon(LucideIcons.shieldCheck), findsOneWidget);
    expect(find.byIcon(LucideIcons.externalLink), findsOneWidget);
    expect(find.text('© 2026 360 CORP'), findsOneWidget);
  });
}
