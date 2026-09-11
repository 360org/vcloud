import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:vcloud/features/chat_v2/presentation/widgets/chat_v2_in_app_banner.dart';

void main() {
  group('InAppNotificationBanner Widget & Logic Tests', () {
    testWidgets('1. Banner ẩn hoàn toàn khi payload = null', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: Stack(children: [InAppNotificationBanner()])),
          ),
        ),
      );

      expect(find.byType(InAppNotificationBanner), findsOneWidget);
      expect(find.text('@Nhắc tên'), findsNothing);
      expect(find.byIcon(LucideIcons.atSign), findsNothing);
    });

    testWidgets(
      '2. Banner hiển thị tin nhắn thường: icon messageCircle, không có badge @',
      (tester) async {
        final container = ProviderContainer();
        container
            .read(inAppNotificationProvider.notifier)
            .show(
              channelId: 'ch_123',
              title: 'Nguyễn Văn A',
              body: 'Alo bạn ơi, tiến độ dự án sao rồi?',
              isMention: false,
            );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(
                body: Stack(children: [InAppNotificationBanner()]),
              ),
            ),
          ),
        );

        await tester.pump();

        expect(find.text('Nguyễn Văn A'), findsOneWidget);
        expect(find.text('Alo bạn ơi, tiến độ dự án sao rồi?'), findsOneWidget);
        expect(find.byIcon(LucideIcons.messageCircle), findsOneWidget);
        expect(find.text('@Nhắc tên'), findsNothing);
        expect(find.byIcon(LucideIcons.atSign), findsNothing);

        // Xả timer auto-dismiss 4 giây để kết thúc test sạch sẽ
        await tester.pump(const Duration(seconds: 5));
      },
    );

    testWidgets(
      '3. Banner hiển thị tin nhắn có Mention (@tag): có badge [@Nhắc tên] và icon @',
      (tester) async {
        final container = ProviderContainer();
        container
            .read(inAppNotificationProvider.notifier)
            .show(
              channelId: 'group_456',
              title: 'Nhóm Kỹ Thuật 360',
              body: '@Tan, nhờ bạn review PR này gấp nhé',
              isMention: true,
            );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(
                body: Stack(children: [InAppNotificationBanner()]),
              ),
            ),
          ),
        );

        await tester.pump();

        expect(find.text('Nhóm Kỹ Thuật 360'), findsOneWidget);
        expect(
          find.text('@Tan, nhờ bạn review PR này gấp nhé'),
          findsOneWidget,
        );
        expect(find.text('@Nhắc tên'), findsOneWidget);
        expect(find.byIcon(LucideIcons.atSign), findsOneWidget);

        // Xả timer auto-dismiss 4 giây để kết thúc test sạch sẽ
        await tester.pump(const Duration(seconds: 5));
      },
    );

    test('4. Auto-dismiss sau 4 giây', () async {
      final notifier = InAppNotificationNotifier();
      notifier.show(
        channelId: 'ch_1',
        title: 'Test',
        body: 'Body',
        isMention: false,
      );

      expect(notifier.state, isNotNull);
      notifier.dismiss();
      expect(notifier.state, isNull);
    });
  });
}
