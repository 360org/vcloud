// Part of ENV_17. See LICENSE file for full copyright and licensing details.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:vcloud/features/chat_v2/application/chat_v2_channels_controller.dart';
import 'package:vcloud/features/chat_v2/application/chat_v2_messages_controller.dart';
import 'package:vcloud/features/chat_v2/data/chat_v2_repository.dart';
import 'package:vcloud/features/chat_v2/data/models/chat_v2_channel.dart';
import 'package:vcloud/features/chat_v2/data/models/chat_v2_message.dart';
import 'package:vcloud/features/chat_v2/presentation/screens/chat_v2_detail_screen.dart';
import 'package:vcloud/features/chat_v2/presentation/widgets/chat_v2_info_sheet.dart';

class _FakeChatV2Repository extends Fake implements ChatV2Repository {
  @override
  Future<ChatV2Channel?> getChannel(String channelId) async {
    return ChatV2Channel(
      id: channelId,
      name: 'Nhóm Kỹ Thuật 360',
      channelType: 'group',
      isGroup: true,
      memberCount: 3,
    );
  }

  @override
  Future<List<ChatV2Message>> getMessages(
    String channelId, {
    String? currentPartnerId,
    String? currentUserId,
    int limit = 35,
    String? beforeId,
  }) async {
    return const [];
  }

  @override
  Future<void> markAsRead(String channelId) async {}

  @override
  Future<List<ChatV2Member>> fetchChannelMembers(String channelId) async {
    return const [
      ChatV2Member(id: '1', name: 'Nguyễn Văn A', isMe: true),
    ];
  }

  @override
  Future<ChatV2ChannelMediaResult> getChannelMedia(
    String channelId, {
    String type = 'all',
    int limit = 50,
    int offset = 0,
  }) async {
    return const ChatV2ChannelMediaResult();
  }
}

class _FakeChannelsNotifier extends ChatV2ChannelsNotifier {
  @override
  Future<List<ChatV2Channel>> build() async => [
        const ChatV2Channel(
          id: '999',
          name: 'Nhóm Kỹ Thuật 360',
          channelType: 'group',
          isGroup: true,
          memberCount: 3,
        ),
      ];
}

class _FakeMessagesNotifier extends ChatV2MessagesNotifier {
  @override
  FutureOr<List<ChatV2Message>> build(String arg) async => const [];
}

Widget createChatDetailTestApp({
  required String channelId,
  String? title,
}) {
  final router = GoRouter(
    initialLocation: '/chat/$channelId',
    routes: [
      GoRoute(
        path: '/chat/:id',
        builder: (context, state) => ChatV2DetailScreen(
          channelId: channelId,
          title: title,
        ),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      chatV2RepositoryProvider.overrideWithValue(_FakeChatV2Repository()),
      chatV2ChannelsProvider.overrideWith(() => _FakeChannelsNotifier()),
      chatV2MessagesProvider.overrideWith(() => _FakeMessagesNotifier()),
    ],
    child: MaterialApp.router(
      theme: ThemeData(useMaterial3: false),
      routerConfig: router,
    ),
  );
}

void main() {
  group('ChatV2 AppBar Actions & Media Hub Tests (Phương án B - 10 Test Cases)', () {
    test('TC-01: extractMedia trích xuất đúng ảnh từ formal attachments', () {
      final msg = ChatV2Message(
        id: 'msg-1',
        channelId: '100',
        authorId: '1',
        authorName: 'Tester',
        content: 'Đây là ảnh đính kèm',
        createdAt: DateTime.now(),
        attachments: const [
          ChatV2Attachment(
            id: 'att-1',
            name: 'photo.png',
            mimetype: 'image/png',
            url: 'https://example.com/photo.png',
          ),
          ChatV2Attachment(
            id: 'att-2',
            name: 'doc.pdf',
            mimetype: 'application/pdf',
            url: 'https://example.com/doc.pdf',
          ),
        ],
      );

      final result = ChatV2InfoSheet.extractMedia([msg]);
      expect(result.images.length, 1);
      expect(result.images.first.name, 'photo.png');
      expect(result.files.length, 1);
      expect(result.files.first.name, 'doc.pdf');
    });

    test('TC-02: extractMedia trích xuất ảnh theo đuôi mở rộng khi mimetype không chuẩn', () {
      final msg = ChatV2Message(
        id: 'msg-2',
        channelId: '100',
        authorId: '1',
        authorName: 'Tester',
        content: 'Ảnh file',
        createdAt: DateTime.now(),
        attachments: const [
          ChatV2Attachment(
            id: 'att-3',
            name: 'capture.webp',
            mimetype: 'application/octet-stream',
            url: 'https://example.com/capture.webp',
          ),
          ChatV2Attachment(
            id: 'att-4',
            name: 'chart.heic',
            mimetype: 'application/octet-stream',
            url: 'https://example.com/chart.heic',
          ),
        ],
      );

      final result = ChatV2InfoSheet.extractMedia([msg]);
      expect(result.images.length, 2);
      expect(result.images.map((a) => a.name), containsAll(['capture.webp', 'chart.heic']));
    });

    test('TC-03: extractMedia trích xuất ảnh từ thẻ HTML <img> trong rawBody hoặc content', () {
      final msg = ChatV2Message(
        id: 'msg-3',
        channelId: '100',
        authorId: '1',
        authorName: 'Tester',
        content: 'Xem ảnh',
        rawBody: '<p>Xem ảnh: <img src="https://example.com/inline_img.jpg" /></p>',
        createdAt: DateTime.now(),
      );

      final result = ChatV2InfoSheet.extractMedia([msg]);
      expect(result.images.length, 1);
      expect(result.images.first.url, 'https://example.com/inline_img.jpg');
      expect(result.images.first.name, 'inline_img.jpg');
    });

    test('TC-04: extractMedia trích xuất danh sách link và loại trừ trùng lặp', () {
      final msg1 = ChatV2Message(
        id: 'msg-4',
        channelId: '100',
        authorId: '1',
        authorName: 'Tester',
        content: 'Truy cập https://vuahethong.net và https://360.org.vn',
        createdAt: DateTime.now(),
      );
      final msg2 = ChatV2Message(
        id: 'msg-5',
        channelId: '100',
        authorId: '2',
        authorName: 'Tester 2',
        content: 'Link dự án https://vuahethong.net nhé',
        createdAt: DateTime.now(),
      );

      final result = ChatV2InfoSheet.extractMedia([msg1, msg2]);
      expect(result.links.length, 2);
      expect(result.links, containsAll(['https://vuahethong.net', 'https://360.org.vn']));
    });

    test('TC-05: extractMedia xử lý danh sách tin nhắn rỗng an toàn', () {
      final result = ChatV2InfoSheet.extractMedia([]);
      expect(result.images, isEmpty);
      expect(result.files, isEmpty);
      expect(result.links, isEmpty);
    });

    testWidgets('TC-06: AppBar hiển thị đầy đủ 2 action icons: Search và Kho Media (Images)', (tester) async {
      await tester.pumpWidget(
        createChatDetailTestApp(
          channelId: '999',
          title: 'Nhóm Kỹ Thuật 360',
        ),
      );
      await tester.pumpAndSettle();

      // Kiểm tra tiêu đề kênh
      expect(find.text('Nhóm Kỹ Thuật 360'), findsOneWidget);

      // Kiểm tra 2 icon theo Phương án B
      expect(find.byIcon(LucideIcons.search), findsOneWidget);
      expect(find.byIcon(LucideIcons.images), findsOneWidget);

      // Tooltip kiểm tra tính trực quan cho người dùng
      final searchButton = tester.widget<IconButton>(find.ancestor(
        of: find.byIcon(LucideIcons.search),
        matching: find.byType(IconButton),
      ));
      expect(searchButton.tooltip, 'Tìm kiếm tin nhắn');

      final mediaButton = tester.widget<IconButton>(find.ancestor(
        of: find.byIcon(LucideIcons.images),
        matching: find.byType(IconButton),
      ));
      expect(mediaButton.tooltip, 'Ảnh, file, link đã gửi');

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('TC-07: Bấm icon Search kích hoạt thanh tìm kiếm tin nhắn tại chỗ', (tester) async {
      await tester.pumpWidget(
        createChatDetailTestApp(
          channelId: '999',
          title: 'Nhóm Kỹ Thuật 360',
        ),
      );
      await tester.pumpAndSettle();

      // Lúc đầu chưa tìm kiếm, không có TextField hintText 'Tìm kiếm tin nhắn...'
      expect(find.text('Tìm kiếm tin nhắn...'), findsNothing);

      // Bấm nút Search
      await tester.tap(find.byIcon(LucideIcons.search));
      await tester.pumpAndSettle();

      // Thanh tìm kiếm mở ra với hint text chuẩn
      expect(find.text('Tìm kiếm tin nhắn...'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('TC-08: Bấm nút Đóng tìm kiếm phục hồi 2 icon AppBar', (tester) async {
      await tester.pumpWidget(
        createChatDetailTestApp(
          channelId: '999',
          title: 'Nhóm Kỹ Thuật 360',
        ),
      );
      await tester.pumpAndSettle();

      // Bấm nút Search
      await tester.tap(find.byIcon(LucideIcons.search));
      await tester.pumpAndSettle();
      expect(find.text('Tìm kiếm tin nhắn...'), findsOneWidget);

      // Bấm nút Đóng tìm kiếm (tooltip: 'Đóng tìm kiếm')
      await tester.tap(find.byTooltip('Đóng tìm kiếm'));
      await tester.pumpAndSettle();

      // Trở lại trạng thái bình thường với 2 icon
      expect(find.text('Tìm kiếm tin nhắn...'), findsNothing);
      expect(find.byIcon(LucideIcons.search), findsOneWidget);
      expect(find.byIcon(LucideIcons.images), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('TC-09: Bấm icon Media gọi ChatV2InfoSheet.openMediaHub mở MediaHubScreen', (tester) async {
      await tester.pumpWidget(
        createChatDetailTestApp(
          channelId: '999',
          title: 'Nhóm Kỹ Thuật 360',
        ),
      );
      await tester.pumpAndSettle();

      // Bấm icon Media
      await tester.tap(find.byIcon(LucideIcons.images));
      await tester.pumpAndSettle();

      // Kiểm tra Media Hub Screen được mở
      expect(find.text('Ảnh, file, link đã gửi'), findsOneWidget);
      expect(find.textContaining('Ảnh'), findsWidgets);
      expect(find.textContaining('Tài liệu'), findsWidgets);
      expect(find.textContaining('Liên kết'), findsWidgets);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('TC-10: Đóng MediaHub bằng nút quay lại phục hồi màn hình ChatV2DetailScreen bình thường', (tester) async {
      await tester.pumpWidget(
        createChatDetailTestApp(
          channelId: '999',
          title: 'Nhóm Kỹ Thuật 360',
        ),
      );
      await tester.pumpAndSettle();

      // Mở Media Hub
      await tester.tap(find.byIcon(LucideIcons.images));
      await tester.pumpAndSettle();
      expect(find.text('Ảnh, file, link đã gửi'), findsOneWidget);

      // Bấm nút Back trên Media Hub (leading IconButton trên Media Hub)
      await tester.tap(find.byIcon(LucideIcons.arrowLeft));
      await tester.pumpAndSettle();

      // Quay lại màn hình chat
      expect(find.text('Nhóm Kỹ Thuật 360'), findsOneWidget);
      expect(find.byIcon(LucideIcons.search), findsOneWidget);
      expect(find.byIcon(LucideIcons.images), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 5));
    });
  });
}
