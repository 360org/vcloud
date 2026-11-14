import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/features/chat_v2/data/models/link_metadata.dart';
import 'package:vcloud/features/chat_v2/data/services/link_metadata_service.dart';
import 'package:vcloud/features/chat_v2/presentation/widgets/chat_v2_message_item.dart';
import 'package:vcloud/features/chat_v2/presentation/widgets/link_preview_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Task B: Rich Link Preview & SSRF Protection Tests', () {
    test('1. extractFirstPreviewUrl extracts valid http and https URLs and ignores punctuation', () {
      expect(
        ChatV2MessageItem.extractFirstPreviewUrl('Xin chào, xem tại https://flutter.dev nhé!'),
        equals('https://flutter.dev'),
      );

      expect(
        ChatV2MessageItem.extractFirstPreviewUrl('Trang web http://example.com/docs, rất hay.'),
        equals('http://example.com/docs'),
      );

      expect(
        ChatV2MessageItem.extractFirstPreviewUrl('Kiểm tra github.com/360org để xem code'),
        equals('https://github.com/360org'),
      );
    });

    test('2. extractFirstPreviewUrl ignores non-http schemes and returns null for plain text', () {
      expect(
        ChatV2MessageItem.extractFirstPreviewUrl('Liên hệ email mailto:admin@360.org.vn'),
        isNull,
      );

      expect(
        ChatV2MessageItem.extractFirstPreviewUrl('Gọi số điện thoại tel:0901234567'),
        isNull,
      );

      expect(
        ChatV2MessageItem.extractFirstPreviewUrl('Tin nhắn thuần túy không chứa bất kỳ liên kết nào'),
        isNull,
      );
    });

    test('3. SSRF Guard - isBlockedIpAddress blocks loopback, private RFC1918, metadata and carrier NAT', () {
      // Loopback
      expect(LinkMetadataService.isBlockedIpAddress('127.0.0.1'), isTrue);
      expect(LinkMetadataService.isBlockedIpAddress('127.0.0.2'), isTrue);

      // Private RFC 1918
      expect(LinkMetadataService.isBlockedIpAddress('10.0.0.1'), isTrue);
      expect(LinkMetadataService.isBlockedIpAddress('10.255.255.254'), isTrue);
      expect(LinkMetadataService.isBlockedIpAddress('172.16.0.1'), isTrue);
      expect(LinkMetadataService.isBlockedIpAddress('172.31.255.255'), isTrue);
      expect(LinkMetadataService.isBlockedIpAddress('192.168.1.1'), isTrue);
      expect(LinkMetadataService.isBlockedIpAddress('192.168.0.254'), isTrue);

      // Cloud Metadata / Link-Local
      expect(LinkMetadataService.isBlockedIpAddress('169.254.169.254'), isTrue);
      expect(LinkMetadataService.isBlockedIpAddress('169.254.1.1'), isTrue);

      // Carrier-Grade NAT
      expect(LinkMetadataService.isBlockedIpAddress('100.64.0.1'), isTrue);
      expect(LinkMetadataService.isBlockedIpAddress('100.127.255.255'), isTrue);

      // Current network & Broadcast
      expect(LinkMetadataService.isBlockedIpAddress('0.0.0.0'), isTrue);
      expect(LinkMetadataService.isBlockedIpAddress('255.255.255.255'), isTrue);

      // IPv6 Loopback / Link-Local / Unique Local
      expect(LinkMetadataService.isBlockedIpAddress('::1'), isTrue);
      expect(LinkMetadataService.isBlockedIpAddress('fe80::1'), isTrue);
      expect(LinkMetadataService.isBlockedIpAddress('fc00::1'), isTrue);

      // Public IP (Cho phép)
      expect(LinkMetadataService.isBlockedIpAddress('8.8.8.8'), isFalse);
      expect(LinkMetadataService.isBlockedIpAddress('1.1.1.1'), isFalse);
      expect(LinkMetadataService.isBlockedIpAddress('142.250.190.46'), isFalse);
    });

    test('4. SSRF Guard - isBlockedHostname blocks localhost, local domains, and cloud metadata', () {
      expect(LinkMetadataService.isBlockedHostname('localhost'), isTrue);
      expect(LinkMetadataService.isBlockedHostname('api.localhost'), isTrue);
      expect(LinkMetadataService.isBlockedHostname('server.local'), isTrue);
      expect(LinkMetadataService.isBlockedHostname('internal.lan'), isTrue);
      expect(LinkMetadataService.isBlockedHostname('metadata.google.internal'), isTrue);
      expect(LinkMetadataService.isBlockedHostname('instance-data'), isTrue);

      // Public Hostname (Cho phép)
      expect(LinkMetadataService.isBlockedHostname('github.com'), isFalse);
      expect(LinkMetadataService.isBlockedHostname('flutter.dev'), isFalse);
      expect(LinkMetadataService.isBlockedHostname('vnexpress.net'), isFalse);
    });

    test('5. isSensitiveOrInternalUrl blocks internal auth, token, and sensitive endpoints', () {
      expect(
        LinkMetadataService.isSensitiveOrInternalUrl(Uri.parse('https://example.com/api/v1/mobile/login')),
        isTrue,
      );
      expect(
        LinkMetadataService.isSensitiveOrInternalUrl(Uri.parse('https://example.com/auth/reset-password')),
        isTrue,
      );
      expect(
        LinkMetadataService.isSensitiveOrInternalUrl(Uri.parse('https://example.com/.env')),
        isTrue,
      );
      expect(
        LinkMetadataService.isSensitiveOrInternalUrl(Uri.parse('https://example.com/web/session/token')),
        isTrue,
      );

      // Public normal URL (Cho phép)
      expect(
        LinkMetadataService.isSensitiveOrInternalUrl(Uri.parse('https://flutter.dev/docs/get-started')),
        isFalse,
      );
    });

    test('6. parseHtmlMetadata extracts OpenGraph tags, title, description, and normalizes image URL', () {
      const sampleHtml = '''
        <!DOCTYPE html>
        <html>
        <head>
          <meta property="og:site_name" content="GitHub" />
          <meta property="og:title" content="360org/vcloud: Mobile client" />
          <meta property="og:description" content="Hệ thống ứng dụng di động doanh nghiệp cao cấp" />
          <meta property="og:image" content="/images/banner.png" />
          <title>Fallback Title</title>
        </head>
        <body>
          <h1>Welcome to GitHub</h1>
        </body>
        </html>
      ''';

      final targetUri = Uri.parse('https://github.com/360org/vcloud');
      final metadata = LinkMetadataService.parseHtmlMetadata(
        html: sampleHtml,
        targetUri: targetUri,
        originalUrl: 'github.com/360org/vcloud',
      );

      expect(metadata.domain, equals('GitHub'));
      expect(metadata.title, equals('360org/vcloud: Mobile client'));
      expect(metadata.description, equals('Hệ thống ứng dụng di động doanh nghiệp cao cấp'));
      expect(metadata.imageUrl, equals('https://github.com/images/banner.png'));
      expect(metadata.hasContent, isTrue);
    });

    test('7. parseHtmlMetadata falls back to <title> when og:title is missing', () {
      const sampleHtml = '''
        <html>
        <head>
          <title>Tài liệu Flutter chính thức</title>
          <meta name="description" content="Hướng dẫn phát triển ứng dụng đa nền tảng" />
        </head>
        </html>
      ''';

      final targetUri = Uri.parse('https://flutter.dev/docs');
      final metadata = LinkMetadataService.parseHtmlMetadata(
        html: sampleHtml,
        targetUri: targetUri,
        originalUrl: 'https://flutter.dev/docs',
      );

      expect(metadata.domain, equals('flutter.dev'));
      expect(metadata.title, equals('Tài liệu Flutter chính thức'));
      expect(metadata.description, equals('Hướng dẫn phát triển ứng dụng đa nền tảng'));
      expect(metadata.imageUrl, isNull);
    });

    test('8. LinkMetadata model serialization and freshness TTL test', () {
      final now = DateTime.now();
      final freshMetadata = LinkMetadata(
        url: 'https://flutter.dev',
        originalUrl: 'flutter.dev',
        domain: 'flutter.dev',
        title: 'Flutter Documentation',
        description: 'Multi-platform framework',
        fetchedAt: now,
      );

      expect(freshMetadata.isFresh(), isTrue);
      expect(freshMetadata.hasContent, isTrue);

      final json = freshMetadata.toJson();
      final restored = LinkMetadata.fromJson(json);

      expect(restored.url, equals(freshMetadata.url));
      expect(restored.title, equals(freshMetadata.title));
      expect(restored.domain, equals(freshMetadata.domain));

      // Quá hạn 25 tiếng (TTL là 24h)
      final expiredMetadata = LinkMetadata(
        url: 'https://flutter.dev',
        originalUrl: 'flutter.dev',
        domain: 'flutter.dev',
        fetchedAt: now.subtract(const Duration(hours: 25)),
      );
      expect(expiredMetadata.isFresh(), isFalse);
    });

    testWidgets('9. LinkPreviewCard renders rich preview card when metadata is available', (tester) async {
      const testUrl = 'https://flutter.dev';
      final testMetadata = LinkMetadata(
        url: testUrl,
        originalUrl: testUrl,
        domain: 'flutter.dev',
        title: 'Flutter - Build apps for any screen',
        description: 'Flutter transforms the app development process.',
        fetchedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            linkMetadataProvider(testUrl).overrideWith(
              (ref) => Future.value(testMetadata),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: LinkPreviewCard(url: testUrl),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('flutter.dev'), findsOneWidget);
      expect(find.text('Flutter - Build apps for any screen'), findsOneWidget);
      expect(find.text('Flutter transforms the app development process.'), findsOneWidget);
    });

    testWidgets('10. LinkPreviewCard renders SizedBox.shrink() when metadata is null or has no content', (tester) async {
      const testUrl = 'https://broken-link.com';

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            linkMetadataProvider(testUrl).overrideWith(
              (ref) => Future.value(null),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: LinkPreviewCard(url: testUrl),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Không tìm thấy bất kỳ card hay text nào
      expect(find.byType(InkWell), findsNothing);
      expect(find.text('broken-link.com'), findsNothing);
    });
  });
}
