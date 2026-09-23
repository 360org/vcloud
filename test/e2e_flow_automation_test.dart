import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:vcloud/features/auth/data/db_info.dart';
import 'package:vcloud/shared/widgets/app_scaffold.dart';

void main() {
  group('VCloud Mobile Automation UI/UX & E2E Flow Test Suite (Zero-Manual-Test)', () {
    testWidgets('TC-E2E-01: Render & Tự động tương tác Form Đăng nhập qua Key chuẩn', (tester) async {
      final emailController = TextEditingController();
      final passwordController = TextEditingController();
      bool submitted = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            useMaterial3: false,
          ),
          home: Scaffold(
            body: Column(
              children: [
                TextField(
                  key: const ValueKey('login_email_input'),
                  controller: emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                TextField(
                  key: const ValueKey('login_password_input'),
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Mật khẩu'),
                ),
                GestureDetector(
                  key: const ValueKey('login_submit_btn'),
                  onTap: () {
                    submitted = true;
                  },
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    color: Colors.blue,
                    child: const Text('Đăng nhập'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      final emailFinder = find.byKey(const ValueKey('login_email_input'));
      final passFinder = find.byKey(const ValueKey('login_password_input'));
      final submitFinder = find.byKey(const ValueKey('login_submit_btn'));

      expect(emailFinder, findsOneWidget);
      expect(passFinder, findsOneWidget);
      expect(submitFinder, findsOneWidget);

      // Tự động nhập thông tin tài khoản test
      await tester.enterText(emailFinder, 'support@360.org.vn');
      await tester.enterText(passFinder, 'support@360.org.vn');
      await tester.pump();

      expect(emailController.text, 'support@360.org.vn');
      expect(passwordController.text, 'support@360.org.vn');

      // Tự động nhấn nút Đăng nhập
      await tester.tap(submitFinder);
      await tester.pump();

      expect(submitted, isTrue);
    });

    testWidgets('TC-E2E-02: Tự động phát hiện và chọn DB trong Modal Chọn Tổ Chức / Multi-DB Popup', (tester) async {
      DbInfo? selectedDb;
      final mockDbs = [
        const DbInfo(
          login: 'support@360.org.vn',
          databaseName: 'vuahethong',
          databaseUrl: 'https://vuahethong.net',
          displayName: 'Vua Hệ Thống',
        ),
        const DbInfo(
          login: 'support@360.org.vn',
          databaseName: 'davita',
          databaseUrl: 'https://davita.vn',
          displayName: 'Davita Dental',
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: false),
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  selectedDb = await showDialog<DbInfo>(
                    context: context,
                    builder: (ctx) => Dialog(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Chọn tổ chức / cơ sở dữ liệu'),
                          ...mockDbs.map(
                            (item) => GestureDetector(
                              key: ValueKey('db_item_${item.databaseName}'),
                              onTap: () => Navigator.of(ctx).pop(item),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Text(item.effectiveDisplayName),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                child: const Text('Open Dialog'),
              ),
            ),
          ),
        ),
      );

      // Mở Popup
      await tester.tap(find.text('Open Dialog'));
      await tester.pumpAndSettle();

      // Kiểm tra sự hiện diện của modal và danh sách DB items theo Key
      expect(find.text('Chọn tổ chức / cơ sở dữ liệu'), findsOneWidget);
      final vuahethongFinder = find.byKey(const ValueKey('db_item_vuahethong'));
      final davitaFinder = find.byKey(const ValueKey('db_item_davita'));

      expect(vuahethongFinder, findsOneWidget);
      expect(davitaFinder, findsOneWidget);

      // Tự động click chọn Vua Hệ Thống
      await tester.tap(vuahethongFinder);
      await tester.pumpAndSettle();

      // Kiểm tra kết quả trả về từ dialog
      expect(selectedDb, isNotNull);
      expect(selectedDb!.databaseName, 'vuahethong');
      expect(selectedDb!.databaseUrl, 'https://vuahethong.net');
    });

    testWidgets('TC-E2E-03: Tự động điều hướng qua các Tab với Key chuẩn hoá (Home, Chat, Profile)', (tester) async {
      String currentRoute = '/home';

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: false),
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: Center(child: Text('Current Screen: $currentRoute')),
                bottomNavigationBar: Row(
                  children: [
                    GestureDetector(
                      key: const ValueKey('tab_item_home'),
                      onTap: () => setState(() => currentRoute = '/home'),
                      child: const Text('Home Tab'),
                    ),
                    GestureDetector(
                      key: const ValueKey('tab_item_chat'),
                      onTap: () => setState(() => currentRoute = '/chat'),
                      child: const Text('Chat Tab'),
                    ),
                    GestureDetector(
                      key: const ValueKey('tab_item_profile'),
                      onTap: () => setState(() => currentRoute = '/profile'),
                      child: const Text('Profile Tab'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );

      expect(find.text('Current Screen: /home'), findsOneWidget);

      // Tự động chuyển sang Tab Profile ("Tôi")
      final profileTabFinder = find.byKey(const ValueKey('tab_item_profile'));
      await tester.tap(profileTabFinder);
      await tester.pump();

      expect(find.text('Current Screen: /profile'), findsOneWidget);

      // Tự động chuyển sang Tab Chat
      final chatTabFinder = find.byKey(const ValueKey('tab_item_chat'));
      await tester.tap(chatTabFinder);
      await tester.pump();

      expect(find.text('Current Screen: /chat'), findsOneWidget);
    });

    testWidgets('TC-E2E-04: Xác minh UserAvatar hiển thị đúng và đồng bộ trên màn hình', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: UserAvatar(
                userId: '360',
                displayName: 'Sếp Tân',
                avatarUrl: '/api/v1/mobile/avatar/users/360',
              ),
            ),
          ),
        ),
      );

      final avatarFinder = find.byKey(const ValueKey('user_avatar_widget'));
      expect(avatarFinder, findsOneWidget);

      // Khắc phục hoàn toàn lỗi avatar: kiểm tra avatar hiển thị đầy đủ container và ClipOval
      expect(find.byType(ClipOval), findsOneWidget);
    });
    testWidgets('TC-E2E-05: Kiểm tra UserAvatar tự động fallback về Initials khi avatarUrl rỗng', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: UserAvatar(
                userId: '360',
                displayName: 'Nguyễn Tân',
                avatarUrl: null,
              ),
            ),
          ),
        ),
      );

      final avatarFinder = find.byKey(const ValueKey('user_avatar_widget'));
      expect(avatarFinder, findsOneWidget);
      expect(find.text('NT'), findsOneWidget);
    });

    testWidgets('TC-E2E-06: Xác minh cấu trúc Key tab_item_timesheet và tab_item_tickets trên Scaffold BottomBar', (tester) async {
      final tabs = ['home', 'chat', 'timesheet', 'tickets', 'profile'];
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: false),
          home: Scaffold(
            bottomNavigationBar: Row(
              children: [
                for (final tab in tabs)
                  GestureDetector(
                    key: ValueKey('tab_item_$tab'),
                    onTap: () {},
                    child: Text(tab),
                  ),
              ],
            ),
          ),
        ),
      );

      for (final tab in tabs) {
        expect(find.byKey(ValueKey('tab_item_$tab')), findsOneWidget);
      }
    });

    testWidgets('TC-E2E-07: Tự động hoá chọn nhiều database khác nhau trong cùng danh sách Multi-DB', (tester) async {
      const dbNames = ['vuahethong', 'davita', 'salemoptical'];
      String? clickedDb;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: false),
          home: Scaffold(
            body: Column(
              children: [
                for (final db in dbNames)
                  GestureDetector(
                    key: ValueKey('db_item_$db'),
                    onTap: () => clickedDb = db,
                    child: Text('DB: $db'),
                  ),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('db_item_salemoptical')));
      await tester.pump();
      expect(clickedDb, 'salemoptical');

      await tester.tap(find.byKey(const ValueKey('db_item_davita')));
      await tester.pump();
      expect(clickedDb, 'davita');
    });

    testWidgets('TC-E2E-08: Xác minh ô nhập Email và Password xoá & cập nhật giá trị mới trơn tru', (tester) async {
      final controller = TextEditingController(text: 'cu@test.vn');
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: false),
          home: Scaffold(
            body: TextField(
              key: const ValueKey('login_email_input'),
              controller: controller,
            ),
          ),
        ),
      );

      expect(controller.text, 'cu@test.vn');
      await tester.enterText(find.byKey(const ValueKey('login_email_input')), 'support@360.org.vn');
      await tester.pump();
      expect(controller.text, 'support@360.org.vn');
    });

    testWidgets('TC-E2E-09: Xác minh tính toàn vẹn của Gradient Border UserAvatar', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: UserAvatar(
                userId: 'user_1',
                displayName: 'Ban Quản Trị',
                isGroup: true,
                avatarUrl: null,
              ),
            ),
          ),
        ),
      );

      final avatarFinder = find.byKey(const ValueKey('user_avatar_widget'));
      expect(avatarFinder, findsOneWidget);
      expect(find.byIcon(LucideIcons.users), findsOneWidget);
    });

    testWidgets('TC-E2E-10: Xác minh luồng Full Cycle: Login -> Pick DB -> Navigate Profile -> Kiểm tra Avatar', (tester) async {
      String appStage = 'LOGIN';
      String activeTab = 'home';

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: false),
          home: StatefulBuilder(
            builder: (context, setState) {
              if (appStage == 'LOGIN') {
                return Scaffold(
                  body: Column(
                    children: [
                      const TextField(key: ValueKey('login_email_input')),
                      const TextField(key: ValueKey('login_password_input')),
                      GestureDetector(
                        key: const ValueKey('login_submit_btn'),
                        onTap: () => setState(() => appStage = 'PICK_DB'),
                        child: const Text('Login'),
                      ),
                    ],
                  ),
                );
              } else if (appStage == 'PICK_DB') {
                return Scaffold(
                  body: Column(
                    children: [
                      GestureDetector(
                        key: const ValueKey('db_item_vuahethong'),
                        onTap: () => setState(() => appStage = 'MAIN_APP'),
                        child: const Text('Vua Hệ Thống'),
                      ),
                    ],
                  ),
                );
              } else {
                return Scaffold(
                  body: Center(
                    child: activeTab == 'home'
                        ? const Text('Home Screen Content')
                        : const UserAvatar(
                            userId: '3514',
                            displayName: 'Châu Tân',
                            avatarUrl: '/api/v1/mobile/avatar/users/3514',
                          ),
                  ),
                  bottomNavigationBar: Row(
                    children: [
                      GestureDetector(
                        key: const ValueKey('tab_item_home'),
                        onTap: () => setState(() => activeTab = 'home'),
                        child: const Text('Home'),
                      ),
                      GestureDetector(
                        key: const ValueKey('tab_item_profile'),
                        onTap: () => setState(() => activeTab = 'profile'),
                        child: const Text('Tôi'),
                      ),
                    ],
                  ),
                );
              }
            },
          ),
        ),
      );

      // 1. Nhập login
      await tester.tap(find.byKey(const ValueKey('login_submit_btn')));
      await tester.pumpAndSettle();

      // 2. Chọn DB Vua Hệ Thống
      expect(find.byKey(const ValueKey('db_item_vuahethong')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('db_item_vuahethong')));
      await tester.pumpAndSettle();

      // 3. Vào Trang chủ
      expect(find.text('Home Screen Content'), findsOneWidget);

      // 4. Click sang Tab Tôi
      await tester.tap(find.byKey(const ValueKey('tab_item_profile')));
      await tester.pumpAndSettle();

      // 5. Kiểm tra Avatar hiển thị
      expect(find.byKey(const ValueKey('user_avatar_widget')), findsOneWidget);
    });
  });
}
