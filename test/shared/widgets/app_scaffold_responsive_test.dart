import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:vcloud/shared/widgets/app_scaffold.dart';

void main() {
  group('AppScaffold Responsive Toolbar Tests', () {
    Widget buildTestWidget({
      required String title,
      bool showBackButton = true,
    }) {
      final router = GoRouter(
        initialLocation: '/test',
        routes: [
          GoRoute(
            path: '/test',
            builder: (context, state) => AppScaffold(
              title: title,
              showBackButton: showBackButton,
              body: const SizedBox.shrink(),
            ),
          ),
        ],
      );

      return ProviderScope(
        child: MaterialApp.router(
          routerConfig: router,
        ),
      );
    }

    testWidgets('Screen < 360dp uses toolbarHeight 40, font 14, icon 16', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildTestWidget(
          title: 'Compact Small',
        ),
      );
      await tester.pumpAndSettle();

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.toolbarHeight, 40.0);

      final titleText = tester.widget<Text>(find.text('Compact Small'));
      expect(titleText.style?.fontSize, 14.0);

      final backIcon = tester.widget<Icon>(find.byIcon(LucideIcons.arrowLeft));
      expect(backIcon.size, 16.0);
    });

    testWidgets('Phone 360dp - 599dp uses toolbarHeight 44, font 15, icon 18', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildTestWidget(
          title: 'Standard Phone',
        ),
      );
      await tester.pumpAndSettle();

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.toolbarHeight, 44.0);

      final titleText = tester.widget<Text>(find.text('Standard Phone'));
      expect(titleText.style?.fontSize, 15.0);

      final backIcon = tester.widget<Icon>(find.byIcon(LucideIcons.arrowLeft));
      expect(backIcon.size, 18.0);
    });

    testWidgets('Tablet >= 600dp uses toolbarHeight 52, font 17, icon 20', (tester) async {
      tester.view.physicalSize = const Size(768, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildTestWidget(
          title: 'Tablet View',
        ),
      );
      await tester.pumpAndSettle();

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.toolbarHeight, 52.0);

      final titleText = tester.widget<Text>(find.text('Tablet View'));
      expect(titleText.style?.fontSize, 17.0);

      final backIcon = tester.widget<Icon>(find.byIcon(LucideIcons.arrowLeft));
      expect(backIcon.size, 20.0);
    });
  });

  group('Odoo Web Responsive CSS Tests', () {
    test('contains responsive media queries and button adjustments', () {
      final file = File('lib/features/menu/presentation/odoo_webview_screen.dart');
      expect(file.existsSync(), isTrue);
      final content = file.readAsStringSync();
      expect(content.contains('@media (max-width: 359.98px)'), isTrue);
      expect(content.contains('html { font-size: 12px !important; }'), isTrue);
      expect(content.contains('@media (min-width: 360px) and (max-width: 599.98px)'), isTrue);
      expect(content.contains('html { font-size: 13px !important; }'), isTrue);
      expect(content.contains('.o_calendar_sync_buttons button, .o_cp_buttons .btn'), isTrue);
      expect(content.contains('padding: 4px 8px !important;'), isTrue);
      expect(content.contains('font-size: 12px !important;'), isTrue);
      expect(content.contains('-webkit-font-smoothing: antialiased !important;'), isTrue);
    });
  });
}
