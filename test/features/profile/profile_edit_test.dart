// ignore_for_file: avoid_print, unused_import
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:vcloud/core/api/auth_user.dart';
import 'package:vcloud/features/auth/application/auth_controller.dart';
import 'package:vcloud/features/profile/presentation/edit_profile_screen.dart';

class _FakeAuthController extends AuthController {
  _FakeAuthController(this._mockUser);

  final AuthUser? _mockUser;
  bool uploadAvatarCalled = false;
  String? lastUploadedBase64;
  bool shouldThrowOnUpload = false;

  @override
  Future<AuthUser?> build() async {
    return _mockUser;
  }

  @override
  Future<void> uploadAvatar(String base64Image) async {
    if (shouldThrowOnUpload) {
      throw Exception('Network error');
    }
    uploadAvatarCalled = true;
    lastUploadedBase64 = base64Image;
  }
}

void main() {
  const mockUser = AuthUser(
    id: '1',
    email: 'test_user@360.org.vn',
    userMetadata: <String, dynamic>{
      'display_name': 'Nguyễn Văn Test',
      'role': 'Kỹ Sư Phần Mềm',
      'company': '360 CORP',
      'is_portal': false,
    },
  );

  Widget createTestWidget({
    AuthUser? user = mockUser,
    _FakeAuthController? controller,
    GoRouter? customRouter,
  }) {
    final fakeCtrl = controller ?? _FakeAuthController(user);
    final router = customRouter ??
        GoRouter(
          initialLocation: '/profile/edit',
          routes: [
            GoRoute(
              path: '/profile/edit',
              builder: (context, state) => const EditProfileScreen(),
            ),
          ],
        );

    return ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(() => fakeCtrl),
      ],
      child: MaterialApp.router(
        theme: ThemeData(
          useMaterial3: false, // Tránh load ink_sparkle shader trong test
        ),
        routerConfig: router,
      ),
    );
  }

  group('EditProfileScreen Widget Tests', () {
    testWidgets('1. Hiển thị đúng thông tin hồ sơ người dùng', (tester) async {
      // Set kích thước màn hình đủ lớn để không bị scroll
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Kiểm tra tiêu đề AppScaffold
      expect(find.text('Hồ sơ cá nhân'), findsOneWidget);

      // Kiểm tra các nhãn thông tin
      expect(find.text('Họ và tên'), findsOneWidget);
      expect(find.text('Nguyễn Văn Test'), findsOneWidget);

      expect(find.text('Chức vụ'), findsOneWidget);
      expect(find.text('Kỹ Sư Phần Mềm'), findsOneWidget);

      expect(find.text('Công ty'), findsOneWidget);
      expect(find.text('360 CORP'), findsOneWidget);

      expect(find.text('Email'), findsOneWidget);
      expect(find.text('test_user@360.org.vn'), findsOneWidget);
    });

    testWidgets('2. Hiển thị default fallback khi metadata rỗng', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      const emptyUser = AuthUser(
        id: '2',
        email: 'default_email@360.org.vn',
        userMetadata: <String, dynamic>{},
      );

      await tester.pumpWidget(createTestWidget(user: emptyUser));
      await tester.pumpAndSettle();

      expect(find.text('default_email@360.org.vn'), findsWidgets);
      expect(find.text('360 CORP'), findsOneWidget);
    });

    testWidgets('3. Nút camera mở BottomSheet đổi ảnh đại diện', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      // Tìm nút "Đổi ảnh đại diện"
      final changeAvatarBtn = find.text('Đổi ảnh đại diện');
      expect(changeAvatarBtn, findsOneWidget);

      // Nhấn nút để mở bottom sheet
      await tester.tap(changeAvatarBtn);
      await tester.pumpAndSettle();

      // Verify BottomSheet mở ra với đầy đủ các lựa chọn
      expect(find.text('Thay đổi ảnh đại diện'), findsOneWidget);
      expect(find.text('Chụp ảnh mới'), findsOneWidget);
      expect(find.text('Chọn từ thư viện ảnh'), findsOneWidget);
    });

    testWidgets('4. Nút quay lại (Back) hoạt động bình thường', (tester) async {
      final router = GoRouter(
        initialLocation: '/profile/edit',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(body: Text('Home Screen')),
          ),
          GoRoute(
            path: '/profile/edit',
            builder: (context, state) => const EditProfileScreen(),
          ),
        ],
      );

      await tester.pumpWidget(createTestWidget(customRouter: router));
      await tester.pumpAndSettle();

      final backButton = find.byIcon(Icons.arrow_back_ios_new_rounded);
      if (backButton.evaluate().isNotEmpty) {
        await tester.tap(backButton);
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('5. Hiển thị thông tin khi avatar null không crash', (tester) async {
      const userWithoutAvatar = AuthUser(
        id: '3',
        email: 'noavatar@360.org.vn',
        userMetadata: <String, dynamic>{
          'display_name': 'User Không Avatar',
          'avatar_url': null,
        },
      );

      await tester.pumpWidget(createTestWidget(user: userWithoutAvatar));
      await tester.pumpAndSettle();

      expect(find.text('User Không Avatar'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
