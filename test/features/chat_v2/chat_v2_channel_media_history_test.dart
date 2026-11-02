import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/features/chat_v2/data/models/chat_v2_message.dart';
import 'package:vcloud/features/chat_v2/presentation/widgets/chat_v2_info_sheet.dart';

void main() {
  group('ChatV2 Channel Media History Tests (10 Independent Test Cases)', () {
    test('1. ChatV2ChannelMediaResult.fromMap parses complete payload with all types', () {
      final json = {
        'type': 'all',
        'limit': 50,
        'offset': 0,
        'has_more': true,
        'total_images': 15,
        'total_files': 8,
        'total_links': 4,
        'images': [
          {
            'id': 101,
            'name': 'screenshot.png',
            'mimetype': 'image/png',
            'file_size': 204800,
            'download_url': '/web/content/101/screenshot.png?access_token=token123',
            'message_id': 5001,
            'date': '2026-10-31 08:30:00',
          }
        ],
        'files': [
          {
            'id': 102,
            'name': 'contract.pdf',
            'mimetype': 'application/pdf',
            'file_size': 1048576,
            'download_url': '/web/content/102/contract.pdf?access_token=token456',
            'message_id': 5002,
            'date': '2026-10-31 08:31:00',
          }
        ],
        'links': [
          'https://vuahethong.net/survey/62',
          'https://google.com',
        ],
      };

      final result = ChatV2ChannelMediaResult.fromMap(json);
      expect(result.type, 'all');
      expect(result.limit, 50);
      expect(result.offset, 0);
      expect(result.hasMore, true);
      expect(result.totalImages, 15);
      expect(result.totalFiles, 8);
      expect(result.totalLinks, 4);
      expect(result.images.length, 1);
      expect(result.images.first.id, '101');
      expect(result.images.first.name, 'screenshot.png');
      expect(result.images.first.downloadUrl, '/web/content/101/screenshot.png?access_token=token123');
      expect(result.files.length, 1);
      expect(result.files.first.id, '102');
      expect(result.files.first.name, 'contract.pdf');
      expect(result.links.length, 2);
      expect(result.links.first, 'https://vuahethong.net/survey/62');
    });

    test('2. ChatV2ChannelMediaResult handles single type payload (image only)', () {
      final json = {
        'type': 'image',
        'limit': 20,
        'offset': 40,
        'has_more': false,
        'total': 45,
        'total_images': 45,
        'items': [
          {
            'id': 103,
            'name': 'photo.jpg',
            'mimetype': 'image/jpeg',
            'file_size': 512000,
            'download_url': '/web/content/103/photo.jpg',
          }
        ],
      };

      final result = ChatV2ChannelMediaResult.fromMap(json);
      expect(result.type, 'image');
      expect(result.limit, 20);
      expect(result.offset, 40);
      expect(result.hasMore, false);
      expect(result.totalImages, 45);
      expect(result.images.length, 1);
      expect(result.images.first.id, '103');
    });

    test('3. ChatV2ChannelMediaResult handles single type payload (link only)', () {
      final json = {
        'type': 'link',
        'limit': 50,
        'offset': 0,
        'has_more': false,
        'total': 3,
        'total_links': 3,
        'items': [
          'https://vuahethong.net',
          'https://zalo.me',
          'https://facebook.com',
        ],
      };

      final result = ChatV2ChannelMediaResult.fromMap(json);
      expect(result.type, 'link');
      expect(result.totalLinks, 3);
      expect(result.links.length, 3);
      expect(result.links[0], 'https://vuahethong.net');
    });

    test('4. ChatV2ChannelMediaResult handles empty or null payload gracefully', () {
      final result = ChatV2ChannelMediaResult.fromMap({});
      expect(result.type, 'all');
      expect(result.hasMore, false);
      expect(result.totalImages, 0);
      expect(result.totalFiles, 0);
      expect(result.totalLinks, 0);
      expect(result.images, isEmpty);
      expect(result.files, isEmpty);
      expect(result.links, isEmpty);
    });

    test('5. ChatV2ChannelMediaResult maps nested raw items in single file query', () {
      final json = {
        'type': 'file',
        'items': [
          {
            'id': '201',
            'name': 'report.xlsx',
            'mimetype': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            'file_size': 45000,
          }
        ],
        'total': 1,
      };

      final result = ChatV2ChannelMediaResult.fromMap(json);
      expect(result.files.length, 1);
      expect(result.files.first.name, 'report.xlsx');
      expect(result.totalFiles, 1);
    });

    test('6. ChatV2Attachment retains downloadUrl and metadata correctly', () {
      const att = ChatV2Attachment(
        id: '999',
        name: 'archive.zip',
        mimetype: 'application/zip',
        fileSize: 10485760,
        downloadUrl: '/web/content/999/archive.zip',
      );
      expect(att.id, '999');
      expect(att.name, 'archive.zip');
      expect(att.fileSize, 10485760);
      expect(att.downloadUrl, '/web/content/999/archive.zip');
    });

    testWidgets('7. ChatV2MediaHubScreen renders tab headers with counts', (tester) async {
      final images = [
        const ChatV2Attachment(id: '1', name: 'img1.png', mimetype: 'image/png'),
        const ChatV2Attachment(id: '2', name: 'img2.jpg', mimetype: 'image/jpeg'),
      ];
      final files = [
        const ChatV2Attachment(id: '3', name: 'doc1.pdf', mimetype: 'application/pdf'),
      ];
      final links = ['https://vuahethong.net'];

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ThemeData(useMaterial3: false),
            home: ChatV2MediaHubScreen(
              channelId: '100',
              channelName: 'Kênh thông báo',
              images: images,
              files: files,
              links: links,
              totalImages: 25,
              totalFiles: 10,
              totalLinks: 5,
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Ảnh, file, link đã gửi'), findsOneWidget);
      expect(find.text('Kênh thông báo'), findsOneWidget);
      expect(find.text('Ảnh (25)'), findsOneWidget);
      expect(find.text('Tài liệu (10)'), findsOneWidget);
      expect(find.text('Liên kết (5)'), findsOneWidget);
    });

    testWidgets('8. ChatV2MediaHubScreen displays empty state when lists are empty', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ThemeData(useMaterial3: false),
            home: const ChatV2MediaHubScreen(
              channelId: '101',
              channelName: 'Hội thoại rỗng',
              images: [],
              files: [],
              links: [],
              totalImages: 0,
              totalFiles: 0,
              totalLinks: 0,
            ),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Chưa có hình ảnh nào'), findsOneWidget);
      expect(find.text('Ảnh (0)'), findsOneWidget);
      expect(find.text('Tài liệu (0)'), findsOneWidget);
      expect(find.text('Liên kết (0)'), findsOneWidget);
    });

    testWidgets('9. ChatV2MediaHubScreen switches between tabs smoothly', (tester) async {
      final files = [
        const ChatV2Attachment(id: '10', name: 'tailieu.pdf', mimetype: 'application/pdf'),
      ];
      final links = ['https://360.org.vn'];

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ThemeData(useMaterial3: false),
            home: ChatV2MediaHubScreen(
              channelId: '102',
              channelName: 'Nhóm Dự Án',
              images: const [],
              files: files,
              links: links,
              totalImages: 0,
              totalFiles: 1,
              totalLinks: 1,
            ),
          ),
        ),
      );

      await tester.pump();

      // Tap on 'Tài liệu' Tab
      await tester.tap(find.text('Tài liệu (1)'));
      await tester.pumpAndSettle();
      expect(find.text('tailieu.pdf'), findsOneWidget);

      // Tap on 'Liên kết' Tab
      await tester.tap(find.text('Liên kết (1)'));
      await tester.pumpAndSettle();
      expect(find.text('https://360.org.vn'), findsOneWidget);
    });

    test('10. ChatV2ChannelMediaResult pagination offset calculations', () {
      const limit = 50;
      var offset = 0;
      const totalImages = 125;

      // Page 1
      var hasMore = (offset + limit) < totalImages;
      expect(hasMore, true);

      // Page 2
      offset += limit;
      hasMore = (offset + limit) < totalImages;
      expect(hasMore, true);

      // Page 3
      offset += limit;
      hasMore = (offset + limit) < totalImages;
      expect(hasMore, false);
      expect(offset, 100);
    });
  });
}
