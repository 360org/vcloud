import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/shared/widgets/app_scaffold.dart';

void main() {
  group('Avatar Resilience & Normalization Tests', () {
    testWidgets('UserAvatar renders initials when avatarUrl is null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UserAvatar(
              userId: '1',
              displayName: 'Morpheus',
              size: 40,
            ),
          ),
        ),
      );

      expect(find.text('M'), findsOneWidget);
    });

    testWidgets('UserAvatar renders initials for two-part name', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UserAvatar(
              userId: '2',
              displayName: 'Mitchell Admin',
              size: 40,
            ),
          ),
        ),
      );

      expect(find.text('MA'), findsOneWidget);
    });

    testWidgets('UserAvatar handles group icon fallback', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: UserAvatar(
              userId: '3',
              displayName: 'Team Chat',
              isGroup: true,
              size: 40,
            ),
          ),
        ),
      );

      expect(find.text('TC'), findsNothing);
      expect(find.byType(UserAvatar), findsOneWidget);
    });

    test('Normalization replaces /web/image/res.users with mobile API', () {
      const raw = '/web/image/res.users/42/avatar_128';
      final match = RegExp(r'/web/image/res\.users/(\d+)').firstMatch(raw);
      expect(match, isNotNull);
      final normalized = '/api/v1/mobile/avatar/users/${match!.group(1)}';
      expect(normalized, equals('/api/v1/mobile/avatar/users/42'));
    });

    test('Normalization replaces /web/image/res.partner with mobile API', () {
      const raw = '/web/image/res.partner/99/avatar_128';
      final match = RegExp(r'/web/image/res\.partner/(\d+)').firstMatch(raw);
      expect(match, isNotNull);
      final normalized = '/api/v1/mobile/avatar/partners/${match!.group(1)}';
      expect(normalized, equals('/api/v1/mobile/avatar/partners/99'));
    });
  });
}
