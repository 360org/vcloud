import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/shared/widgets/whats_new_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group("What's New in v2.5.0 (Build 82) Sheet Tests", () {
    testWidgets('1. WhatsNewSheet renders version badge, all 4 feature cards, and CTA button', (tester) async {
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
      expect(find.text('PHIÊN BẢN MỚI v2.5.0 (BUILD 88)'), findsOneWidget);
      expect(find.text('Thông Báo Đẩy APNs & Trải Nghiệm Mượt Mà'), findsOneWidget);

      // Check feature cards
      expect(find.text('Thông Báo Đẩy APNs iOS & Firebase'), findsOneWidget);
      expect(find.text('Tin Nhắn Thoại & Stream Âm Thanh'), findsOneWidget);
      expect(find.text('Quyền Thư Viện Ảnh Toàn Diện'), findsOneWidget);
      expect(find.text('Tối Ưu Service Worker & Token Log'), findsOneWidget);

      // Check tags
      expect(find.text('THÔNG BÁO ĐẨY'), findsOneWidget);
      expect(find.text('ĐỒNG BỘ THOẠI'), findsOneWidget);
      expect(find.text('QUYỀN RIÊNG TƯ'), findsOneWidget);
      expect(find.text('HIỆU NĂNG'), findsOneWidget);

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

      expect(find.text('PHIÊN BẢN MỚI v2.5.0 (BUILD 88)'), findsOneWidget);

      // Tap CTA button to close sheet
      await tester.tap(find.text('KHÁM PHÁ & TRẢI NGHIỆM NGAY'));
      await tester.pumpAndSettle();

      expect(find.text('PHIÊN BẢN MỚI v2.5.0 (BUILD 88)'), findsNothing);
    });
  });
}
