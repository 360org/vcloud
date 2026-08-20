import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/shared/widgets/whats_new_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group("What's New in v2.4.0 (Build 76) Sheet Tests", () {
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
      expect(find.text('PHIÊN BẢN MỚI v2.5.0 (BUILD 79)'), findsOneWidget);
      expect(find.text('Bình Chọn Trực Tuyến & Tối Ưu Toàn Diện'), findsOneWidget);

      // Check feature cards
      expect(find.text('Bình Chọn & Thăm Dò Chat V2'), findsOneWidget);
      expect(find.text('Thông Báo Nổi Đa Tầng AppToast'), findsOneWidget);
      expect(find.text('Bong Bóng Chat Ôm Sát & Xem Trước'), findsOneWidget);
      expect(find.text('Đồng Bộ Ảnh iOS & Tự Động Tải'), findsOneWidget);
      expect(find.text('Phân Luồng Timesheet & Tạo Ticket 1-Chạm'), findsOneWidget);

      // Check tags
      expect(find.text('MỚI'), findsOneWidget);
      expect(find.text('TRẢI NGHIỆM'), findsOneWidget);
      expect(find.text('TỐI ƯU'), findsOneWidget);
      expect(find.text('ĐỒNG BỘ'), findsOneWidget);
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

      expect(find.text('PHIÊN BẢN MỚI v2.5.0 (BUILD 79)'), findsOneWidget);

      // Tap CTA button to close sheet
      await tester.tap(find.text('KHÁM PHÁ & TRẢI NGHIỆM NGAY'));
      await tester.pumpAndSettle();

      expect(find.text('PHIÊN BẢN MỚI v2.4.0 (BUILD 76)'), findsNothing);
    });
  });
}
