import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/shared/widgets/whats_new_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group("What's New in v2.5.0 (Build 80) Sheet Tests", () {
    testWidgets('1. WhatsNewSheet renders version badge, all 5 feature cards, and CTA button', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WhatsNewSheet(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check header and badge
      expect(find.text('PHIÊN BẢN MỚI v2.5.0 (BUILD 80)'), findsOneWidget);
      expect(find.text('Hiệu Năng Vượt Trội & Trải Nghiệm Chat Mượt Mà'), findsOneWidget);

      // Check feature cards
      expect(find.text('RAM Cache SWR Siêu Tốc 16ms'), findsOneWidget);
      expect(find.text('Tab Trò Chuyện & Nút Tạo Nổi FAB'), findsOneWidget);
      expect(find.text('Chuẩn Hóa Odoo 17 Native & Index O(1)'), findsOneWidget);
      expect(find.text('Auto Dark Mode & Splash Warm-up'), findsOneWidget);
      expect(find.text('HTML Boot Loader Web Sắc Nét'), findsOneWidget);

      // Check tags
      expect(find.text('HIỆU NĂNG'), findsOneWidget);
      expect(find.text('TRẢI NGHIỆM'), findsOneWidget);
      expect(find.text('ĐỒNG BỘ'), findsOneWidget);
      expect(find.text('GIAO DIỆN'), findsOneWidget);
      expect(find.text('THƯƠNG HIỆU'), findsOneWidget);

      // Check CTA button
      expect(find.text('KHÁM PHÁ & TRẢI NGHIỆM NGAY'), findsOneWidget);
    });

    testWidgets('2. WhatsNewSheet dismisses when tapping CTA button', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => GestureDetector(
                onTap: () => WhatsNewSheet.show(context),
                child: const Text('Show Sheet'),
              ),
            ),
          ),
        ),
      );

      // Tap to open sheet
      await tester.tap(find.text('Show Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('PHIÊN BẢN MỚI v2.5.0 (BUILD 80)'), findsOneWidget);

      // Tap CTA button to close sheet
      await tester.tap(find.text('KHÁM PHÁ & TRẢI NGHIỆM NGAY'));
      await tester.pumpAndSettle();

      expect(find.text('PHIÊN BẢN MỚI v2.5.0 (BUILD 80)'), findsNothing);
    });
  });
}
