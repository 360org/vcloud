import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/shared/widgets/whats_new_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group("What's New in v2.5.0 (Build 92) Sheet Tests", () {
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
      expect(find.text('PHIÊN BẢN MỚI v2.5.0 (BUILD 92)'), findsOneWidget);
      expect(find.text('Tải Tệp Tin Xác Thực & Thông Báo Đẩy APNs'), findsOneWidget);

      // Check feature cards (Build 92)
      expect(find.text('Tải Tệp Tin Trực Tiếp Với Xác Thực JWT'), findsOneWidget);
      expect(find.text('Thông Báo Đẩy APNs & Phát Sóng Toàn Bộ iOS'), findsOneWidget);
      expect(find.text('Đồng Bộ Trạng Thái Online & Tiêu Đề Chat 1-1'), findsOneWidget);
      expect(find.text('Tin Nhắn Thoại & Stream Âm Thanh Mượt Mà'), findsOneWidget);

      // Check tags (Build 92)
      expect(find.text('TẬP TIN ĐÍNH KÈM'), findsOneWidget);
      expect(find.text('THÔNG BÁO ĐẨY'), findsOneWidget);
      expect(find.text('TRẠNG THÁI & UI/UX'), findsOneWidget);
      expect(find.text('ĐỒNG BỘ THOẠI'), findsOneWidget);

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

      expect(find.text('PHIÊN BẢN MỚI v2.5.0 (BUILD 92)'), findsOneWidget);

      // Tap CTA button to close sheet
      await tester.tap(find.text('KHÁM PHÁ & TRẢI NGHIỆM NGAY'));
      await tester.pumpAndSettle();

      expect(find.text('PHIÊN BẢN MỚI v2.5.0 (BUILD 92)'), findsNothing);
    });
  });
}
