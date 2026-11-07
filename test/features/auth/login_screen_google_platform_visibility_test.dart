import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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

  group('Kiểm thử 10 case độc lập: Tuân thủ Apple Guideline 4.8.0 (Build 190)', () {
    testWidgets('1. Trên iOS: Nút "Đăng nhập với Google" hoàn toàn bị ẩn khỏi Widget Tree', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(buildApp());
        await tester.pump();

        expect(find.byKey(const ValueKey('google_signin_btn')), findsNothing);
        expect(find.text('Đăng nhập với Google'), findsNothing);

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 5));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('2. Trên iOS: Đường kẻ và nhãn "Hoặc đăng nhập bằng" hoàn toàn bị ẩn', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(buildApp());
        await tester.pump();

        expect(find.text('Hoặc đăng nhập bằng'), findsNothing);

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 5));
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    });

    testWidgets('3. Trên iOS: Trường nhập Email/Tài khoản vẫn hiển thị đầy đủ', (tester) async {
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

    testWidgets('4. Trên iOS: Trường nhập Mật khẩu vẫn hiển thị đầy đủ', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      try {
        tester.view.physicalSize = const Size(800, 1600);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(buildApp());
        await tester.pump();

        expect(find.text('Mật khẩu'), findsOneWidget);

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

    testWidgets('6. Trên Android: Nút "Đăng nhập với Google" hiển thị đầy đủ với ValueKey chuẩn', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
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

    testWidgets('8. Trên macOS/Desktop: Nút "Đăng nhập với Google" vẫn hiển thị bình thường', (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
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

    testWidgets('9. Trên Linux/Desktop: Nút "Đăng nhập với Google" vẫn hiển thị bình thường', (tester) async {
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

    test('10. Kiểm tra SSOT Versioning trong pubspec.yaml đã nâng lên Build 190', () {
      final pubspecContent = File('pubspec.yaml').readAsStringSync();
      expect(
        pubspecContent.contains('version: 2.9.34+190'),
        isTrue,
        reason: 'Build number trên App Store và TestFlight bắt buộc phải là 190',
      );
    });
  });
}
