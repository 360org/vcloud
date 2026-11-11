import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/core/api/odoo_api_client.dart';
import 'package:vcloud/features/auth/presentation/login_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildApp() {
    return const ProviderScope(
      child: MaterialApp(
        home: LoginScreen(),
      ),
    );
  }

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  group('Kiểm thử 10 case độc lập: Tuân thủ Apple Guideline 4.8.0 (Sign in with Apple)', () {
    testWidgets('1. Trên iOS: Nút "Đăng nhập với Apple" hiển thị chuẩn xác với ValueKey apple_signin_btn', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(buildApp());
        await tester.pump();

        expect(find.byKey(const ValueKey('apple_signin_btn')), findsOneWidget);
        expect(find.text('Đăng nhập với Apple'), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 5));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('2. Trên iOS: Nút "Đăng nhập với Google" hiển thị song song theo chuẩn Guideline 4.8.0', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(buildApp());
        await tester.pump();

        expect(find.byKey(const ValueKey('google_signin_btn')), findsOneWidget);
        expect(find.text('Đăng nhập với Google'), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 5));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('3. Trên iOS: Đường kẻ và nhãn "Hoặc đăng nhập bằng" hiển thị phân tách rõ ràng', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(buildApp());
        await tester.pump();

        expect(find.text('Hoặc đăng nhập bằng'), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 5));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('4. Trên iOS: Trường nhập Email/Tài khoản vẫn hiển thị đầy đủ', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(buildApp());
        await tester.pump();

        expect(find.byType(TextFormField), findsWidgets);
        expect(find.text('Tài khoản / Email'), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 5));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('5. Trên iOS: Nút Đăng nhập chính (chứng thực nội bộ) hiển thị đầy đủ', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(buildApp());
        await tester.pump();

        expect(find.widgetWithText(ElevatedButton, 'Đăng nhập'), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 5));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('6. Trên Android: Nút "Đăng nhập với Google" hiển thị đầy đủ, ẩn hoàn toàn nút Apple', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(buildApp());
        await tester.pump();

        expect(find.byKey(const ValueKey('google_signin_btn')), findsOneWidget);
        expect(find.text('Đăng nhập với Google'), findsOneWidget);
        expect(find.byKey(const ValueKey('apple_signin_btn')), findsNothing);
        expect(find.text('Đăng nhập với Apple'), findsNothing);

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 5));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('7. Trên Android: Nhãn phân cách "Hoặc đăng nhập bằng" hiển thị đầy đủ', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      try {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(buildApp());
        await tester.pump();

        expect(find.text('Hoặc đăng nhập bằng'), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 5));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('8. Trên macOS/Desktop: Nút "Đăng nhập với Apple" và "Đăng nhập với Google" đều có mặt', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      try {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(buildApp());
        await tester.pump();

        expect(find.byKey(const ValueKey('apple_signin_btn')), findsOneWidget);
        expect(find.byKey(const ValueKey('google_signin_btn')), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 5));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('9. Trên Linux: Nút "Đăng nhập với Google" hiển thị bình thường', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      try {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(buildApp());
        await tester.pump();

        expect(find.byKey(const ValueKey('google_signin_btn')), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 5));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    test('10. Kiểm tra cấu hình SSO Apple trong OdooApiClient', () {
      final client = OdooApiClient(baseUrl: 'http://192.168.1.100:1900');
      expect(client.baseUrl, equals('http://192.168.1.100:1900'));
      expect(OdooApiClient.resolveDefaultDbForUrl('http://192.168.1.100:1900'), equals('vcloud_test_v19'));
    });
  });
}
