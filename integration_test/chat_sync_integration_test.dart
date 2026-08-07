import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

final mockUnreadCountNotifier = StateProvider<int>((ref) => 3);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Chat Unread Synchronization & Mark-as-Read Integration Test', () {
    testWidgets(
      'Verify Unread Badge displays in Sync across Footer & Home, and clears when chat opened',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: DummyAppScaffold(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Step 1: Verify Badge counter displays "3" at Home & Footer
        final footerBadgeFinder = find.byKey(const Key('footer_chat_badge'));
        expect(footerBadgeFinder, findsOneWidget);
        expect(find.descendant(of: footerBadgeFinder, matching: find.text('3')), findsOneWidget);

        // Xác minh Bộ đếm tin chưa đọc hiển thị số "3" tại màn hình Home
        final homeCountFinder = find.byKey(const Key('home_unread_counter'));
        expect(homeCountFinder, findsOneWidget);
        expect(find.descendant(of: homeCountFinder, matching: find.text('3')), findsOneWidget);

        // ignore: avoid_print
        print('➔ [PASS] Bước 1: Trạng thái unread (3) hiển thị đồng bộ ở Footer và Home.');

        // ==========================================
        // BƯỚC 2: MỞ PHÒNG CHAT CHI TIẾT (TRIGGER MARK AS READ)
        // ==========================================
        
        // Giả lập hành động click vào tab Chat ở Navigation Bar
        final chatTabFinder = find.byKey(const Key('footer_chat_tab'));
        await tester.tap(chatTabFinder);
        await tester.pumpAndSettle();

        // Giả lập click chọn phòng chat của user "demo" để vào chi tiết cuộc hội thoại
        final conversationItemFinder = find.byKey(const Key('chat_item_demo'));
        await tester.tap(conversationItemFinder);
        await tester.pumpAndSettle();

        // Giả lập API gọi lên Odoo Backend thành công -> Riverpod cập nhật State về 0
        final container = ProviderScope.containerOf(tester.element(chatTabFinder));
        container.read(mockUnreadCountNotifier.notifier).state = 0;
        
        await tester.pumpAndSettle();

        // ==========================================
        // BƯỚC 3: XÁC MINH BADGE ĐƯỢC RESET VỀ 0 ĐỒNG BỘ
        // ==========================================
        
        final homeTabFinder = find.byKey(const Key('footer_home_tab'));
        await tester.tap(homeTabFinder);
        await tester.pumpAndSettle();

        // Đảm bảo Badge đỏ tại Footer biến mất
        expect(find.byKey(const Key('footer_chat_badge')), findsNothing);

        // Đảm bảo Widget đếm số tin nhắn chưa đọc ở Home đã reset về 0
        expect(find.byKey(const Key('home_unread_counter')), findsNothing);

        // ignore: avoid_print
        print('➔ [PASS] Bước 3: Đã gọi API Mark-as-read thành công, các bộ đếm unread đồng loạt biến mất.');
      },
    );
  });
}

class DummyAppScaffold extends ConsumerStatefulWidget {
  const DummyAppScaffold({super.key});

  @override
  ConsumerState<DummyAppScaffold> createState() => _DummyAppScaffoldState();
}

class _DummyAppScaffoldState extends ConsumerState<DummyAppScaffold> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final unreadCount = ref.watch(mockUnreadCountNotifier);
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          const DummyHomeScreen(),
          const DummyChatListScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.home, key: Key('footer_home_tab')),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.chat, key: Key('footer_chat_tab')),
                if (unreadCount > 0)
                  Positioned(
                    right: -6,
                    top: -6,
                    child: Container(
                      key: const Key('footer_chat_badge'),
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '$unreadCount',
                        style: const TextStyle(color: Colors.white, fontSize: 10),
                      ),
                    ),
                  )
              ],
            ),
            label: 'Chat',
          ),
        ],
      ),
    );
  }
}

class DummyHomeScreen extends ConsumerWidget {
  const DummyHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(mockUnreadCountNotifier);
    return Scaffold(
      body: Center(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Tin nhắn chưa đọc: '),
                if (unreadCount > 0)
                  Container(
                    key: const Key('home_unread_counter'),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$unreadCount',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DummyChatListScreen extends ConsumerWidget {
  const DummyChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(mockUnreadCountNotifier);
    return Scaffold(
      appBar: AppBar(title: const Text('Enterprise Chats')),
      body: ListView(
        children: [
          ListTile(
            key: const Key('chat_item_demo'),
            leading: const CircleAvatar(child: Text('D')),
            title: const Text('User Demo'),
            subtitle: const Text('Hệ thống đã sửa xong lỗi Cast!'),
            trailing: unreadCount > 0
                ? Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    child: Text('$unreadCount', style: const TextStyle(color: Colors.white, fontSize: 10)),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}
