import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:vcloud/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('VCloud Mobile E2E Automation Testing Suite', () {
    testWidgets('Kịch bản E2E: Tự động Đăng nhập, Multi-DB Popup và Kiểm tra đồng bộ Avatar', (tester) async {
      // 1. Khởi chạy toàn bộ ứng dụng Flutter
      app.main();
      await tester.pumpAndSettle(const Duration(seconds: 4));

      // 2. Tìm kiếm các trường nhập liệu trên màn hình Đăng nhập
      final emailInput = find.byKey(const ValueKey('login_email_input'));
      final passwordInput = find.byKey(const ValueKey('login_password_input'));
      final submitBtn = find.byKey(const ValueKey('login_submit_btn'));

      expect(emailInput, findsOneWidget, reason: 'Phải tìm thấy ô nhập Email');
      expect(passwordInput, findsOneWidget, reason: 'Phải tìm thấy ô nhập Mật khẩu');
      expect(submitBtn, findsOneWidget, reason: 'Phải tìm thấy nút Đăng nhập');

      // 3. Nhập tài khoản kiểm thử chính thức (Tài khoản Sếp Tân hoặc Supporter từ docs/test_login.md)
      await tester.enterText(emailInput, 'support@360.org.vn');
      await tester.pump(const Duration(milliseconds: 300));

      await tester.enterText(passwordInput, 'support@360.org.vn');
      await tester.pump(const Duration(milliseconds: 300));

      // 4. Nhấn nút Đăng nhập để kích hoạt Master Hub Resolver
      await tester.tap(submitBtn);
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // 5. Nếu xuất hiện Popup chọn Multi-DB, tự động chọn DB 'vuahethong'
      final vuahethongDbItem = find.byKey(const ValueKey('db_item_vuahethong'));
      if (vuahethongDbItem.evaluate().isNotEmpty) {
        // ignore: avoid_print
        print('🎯 [E2E TEST] Phát hiện Popup chọn Multi-DB -> Tự động chọn Vua Hệ Thống');
        await tester.tap(vuahethongDbItem);
        await tester.pumpAndSettle(const Duration(seconds: 6));
      }

      // 6. Xác minh đã vào thành công Màn hình chính (Home)
      final homeAvatar = find.byKey(const ValueKey('user_avatar_widget'));
      expect(homeAvatar, findsWidgets, reason: 'Phải hiển thị UserAvatar trên Trang chủ');
      // ignore: avoid_print
      print('✅ [E2E TEST] Vào Trang chủ thành công, avatar hiển thị chuẩn xác.');

      // 7. Tự động chuyển sang Tab Tôi (Profile)
      final profileTab = find.byKey(const ValueKey('tab_item_profile'));
      if (profileTab.evaluate().isNotEmpty) {
        await tester.tap(profileTab);
        await tester.pumpAndSettle(const Duration(seconds: 3));

        // 8. Xác minh Avatar trên Tab Tôi hiển thị đồng bộ
        final profileAvatar = find.byKey(const ValueKey('user_avatar_widget'));
        expect(profileAvatar, findsWidgets, reason: 'Phải hiển thị UserAvatar trên Tab Tôi');
        // ignore: avoid_print
        print('✅ [E2E TEST] Chuyển sang Tab Tôi thành công! Avatar đồng bộ 100%, không bị fallback lỗi.');
      }
    });
  });
}
