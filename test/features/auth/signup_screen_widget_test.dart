import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vcloud/core/api/auth_user.dart';
import 'package:vcloud/core/error/failure.dart';
import 'package:vcloud/features/auth/application/auth_controller.dart';
import 'package:vcloud/features/auth/presentation/signup_screen.dart';

class _FakeAuthController extends AuthController {
  _FakeAuthController({this.signUpHandler});

  final Future<void> Function({
    required String email,
    required String password,
    required String displayName,
    required String phone,
    bool acceptTerms,
    String? confirmPassword,
    int? tenantId,
  })? signUpHandler;

  @override
  Future<AuthUser?> build() async => null;

  @override
  Future<void> signUp({
    required String email,
    required String password,
    required String displayName,
    required String phone,
    bool acceptTerms = true,
    String? confirmPassword,
    int? tenantId,
  }) async {
    if (signUpHandler != null) {
      await signUpHandler!(
        email: email,
        password: password,
        displayName: displayName,
        phone: phone,
        acceptTerms: acceptTerms,
        confirmPassword: confirmPassword,
        tenantId: tenantId,
      );
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestApp({
    _FakeAuthController? controller,
    String initialLocation = '/signup',
  }) {
    final fakeController = controller ?? _FakeAuthController();
    final router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => Scaffold(
            body: Center(
              child: TextButton(
                key: const ValueKey('login_to_signup_btn'),
                onPressed: () => context.push('/signup'),
                child: const Text('Đăng ký ngay'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/signup',
          builder: (context, state) => const SignupScreen(),
        ),
        GoRoute(
          path: '/home',
          builder: (context, state) => const Scaffold(
            body: Center(child: Text('Home Screen')),
          ),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(() => fakeController),
      ],
      child: MaterialApp.router(
        theme: ThemeData(useMaterial3: false),
        routerConfig: router,
      ),
    );
  }

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  group('SignupScreen Widget & Validation Tests', () {
    testWidgets('1. Render đầy đủ các trường và nút trên giao diện SignupScreen', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      expect(find.text('Đăng ký'), findsOneWidget); // ElevatedButton label
      expect(find.byKey(const ValueKey('signup_back_btn')), findsOneWidget); // Floating back button
      expect(find.text('Đăng ký tài khoản'), findsOneWidget);
      expect(find.text('Tự đăng ký bằng email công việc của bạn.'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(5)); // Name, Phone, Email, Pass, ConfirmPass
      expect(find.byType(Checkbox), findsOneWidget);
      expect(find.textContaining('Điều khoản dịch vụ', findRichText: true), findsOneWidget);
      expect(find.byKey(const ValueKey('signup_submit_btn')), findsOneWidget);
      expect(find.byKey(const ValueKey('signup_to_login_btn')), findsOneWidget);
    });

    testWidgets('2. Validation: Không điền họ tên hiển thị lỗi "Vui lòng nhập họ tên"', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      final submitBtn = find.byKey(const ValueKey('signup_submit_btn'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Vui lòng nhập họ tên'), findsOneWidget);
    });

    testWidgets('3. Validation: Điền họ tên nhưng bỏ trống số điện thoại hiển thị "Vui lòng nhập số điện thoại"', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'Nguyễn Văn Test');
      final submitBtn = find.byKey(const ValueKey('signup_submit_btn'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Vui lòng nhập họ tên'), findsNothing);
      expect(find.text('Vui lòng nhập số điện thoại'), findsOneWidget);
    });

    testWidgets('4. Validation: Số điện thoại không hợp lệ hiển thị lỗi định dạng', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'Nguyễn Văn Test');
      await tester.enterText(find.byType(TextFormField).at(1), '12345');
      final submitBtn = find.byKey(const ValueKey('signup_submit_btn'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Số điện thoại không hợp lệ (VD: 0912345678)'), findsOneWidget);
    });

    testWidgets('5. Validation: Email sai định dạng hiển thị "Email không đúng định dạng"', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'Nguyễn Văn Test');
      await tester.enterText(find.byType(TextFormField).at(1), '0912345678');
      await tester.enterText(find.byType(TextFormField).at(2), 'invalid-email-format');
      final submitBtn = find.byKey(const ValueKey('signup_submit_btn'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Email không đúng định dạng'), findsOneWidget);
    });

    testWidgets('6. Validation: Mật khẩu < 6 ký tự hiển thị "Dùng ít nhất 6 ký tự"', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'Nguyễn Văn Test');
      await tester.enterText(find.byType(TextFormField).at(1), '0912345678');
      await tester.enterText(find.byType(TextFormField).at(2), 'valid@vcloud.vn');
      await tester.enterText(find.byType(TextFormField).at(3), '12345');
      final submitBtn = find.byKey(const ValueKey('signup_submit_btn'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Dùng ít nhất 6 ký tự'), findsOneWidget);
    });

    testWidgets('7. Validation: Mật khẩu xác nhận không khớp hiển thị lỗi', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'Nguyễn Văn Test');
      await tester.enterText(find.byType(TextFormField).at(1), '0912345678');
      await tester.enterText(find.byType(TextFormField).at(2), 'valid@vcloud.vn');
      await tester.enterText(find.byType(TextFormField).at(3), '123456');
      await tester.enterText(find.byType(TextFormField).at(4), '654321');
      final submitBtn = find.byKey(const ValueKey('signup_submit_btn'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Mật khẩu xác nhận không khớp'), findsOneWidget);
    });

    testWidgets('8. Validation: Chưa tick đồng ý điều khoản hiển thị thông báo lỗi', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'Nguyễn Văn Test');
      await tester.enterText(find.byType(TextFormField).at(1), '0912345678');
      await tester.enterText(find.byType(TextFormField).at(2), 'valid@vcloud.vn');
      await tester.enterText(find.byType(TextFormField).at(3), '123456');
      await tester.enterText(find.byType(TextFormField).at(4), '123456');

      final submitBtn = find.byKey(const ValueKey('signup_submit_btn'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Vui lòng đọc và đồng ý với Điều khoản dịch vụ và Chính sách bảo mật.'), findsOneWidget);
    });

    testWidgets('9. Obscure Password Toggle: Icon mắt ẩn/hiện mật khẩu hoạt động đúng', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp());
      await tester.pumpAndSettle();

      // Kiểm tra ban đầu obscureText = true trên field Mật khẩu (index 3)
      final passField = tester.widget<TextField>(find.descendant(
        of: find.byType(TextFormField).at(3),
        matching: find.byType(TextField),
      ));
      expect(passField.obscureText, isTrue);

      // Nhấn toggle button
      final toggleIcon = find.descendant(
        of: find.byType(TextFormField).at(3),
        matching: find.byType(IconButton),
      );
      await tester.tap(toggleIcon);
      await tester.pumpAndSettle();

      final passFieldToggled = tester.widget<TextField>(find.descendant(
        of: find.byType(TextFormField).at(3),
        matching: find.byType(TextField),
      ));
      expect(passFieldToggled.obscureText, isFalse);
    });

    testWidgets('10. Điều hướng liên kết: Chuyển đổi qua lại giữa Login và Signup', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(buildTestApp(initialLocation: '/login'));
      await tester.pumpAndSettle();

      expect(find.text('Đăng ký ngay'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('login_to_signup_btn')));
      await tester.pumpAndSettle();

      expect(find.text('Đăng ký tài khoản'), findsOneWidget);
      expect(find.byKey(const ValueKey('signup_to_login_btn')), findsOneWidget);

      final backToLoginBtn = find.byKey(const ValueKey('signup_to_login_btn'));
      await tester.tap(backToLoginBtn);
      await tester.pumpAndSettle();

      expect(find.text('Đăng ký ngay'), findsOneWidget);
      expect(find.text('Đăng ký tài khoản'), findsNothing);
    });

    testWidgets('11. Xử lý lỗi API: Hiển thị error banner khi đăng ký thất bại từ server', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final controllerWithErr = _FakeAuthController(
        signUpHandler: ({
          required String email,
          required String password,
          required String displayName,
          required String phone,
          bool acceptTerms = true,
          String? confirmPassword,
          int? tenantId,
        }) async {
          throw Failure('Email này đã được đăng ký tài khoản');
        },
      );

      await tester.pumpWidget(buildTestApp(controller: controllerWithErr));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'Nguyễn Văn Test');
      await tester.enterText(find.byType(TextFormField).at(1), '0912345678');
      await tester.enterText(find.byType(TextFormField).at(2), 'existing@vcloud.vn');
      await tester.enterText(find.byType(TextFormField).at(3), '123456');
      await tester.enterText(find.byType(TextFormField).at(4), '123456');

      // Tick checkbox
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      final submitBtn = find.byKey(const ValueKey('signup_submit_btn'));
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Email này đã được đăng ký tài khoản'), findsOneWidget);
    });
  });
}
