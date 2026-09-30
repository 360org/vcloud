import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/features/chat_v2/data/models/chat_v2_reaction.dart';
import 'package:vcloud/features/chat_v2/presentation/widgets/chat_v2_reaction_details_sheet.dart';

void main() {
  group('ChatV2ReactionDetailsSheet Widget Tests', () {
    testWidgets('renders all tabs and members with correct name and emoji', (tester) async {
      const reactions = [
        ChatV2Reaction(
          content: '❤️',
          count: 1,
          partners: [
            {'id': 6713, 'name': 'Ma Nguyễn Nhật Tân'},
          ],
          hasMe: true,
        ),
        ChatV2Reaction(
          content: '👍',
          count: 1,
          partners: [
            {'id': 4255, 'name': 'Bùi Tuấn Kiệt'},
          ],
          hasMe: false,
        ),
      ];

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChatV2ReactionDetailsSheet(
              reactions: reactions,
              currentUserName: 'Ma Nguyễn Nhật Tân',
              currentUserAvatar: 'https://vuahethong.net/api/v1/mobile/avatar/partners/6713',
            ),
          ),
        ),
      );

      // Verify title & tabs
      expect(find.text('Biểu tượng cảm xúc'), findsOneWidget);
      expect(find.text('Tất cả 2'), findsOneWidget);
      expect(find.text('❤️ 1'), findsOneWidget);
      expect(find.text('👍 1'), findsOneWidget);

      // Verify members in "Tất cả" tab
      expect(find.text('Ma Nguyễn Nhật Tân (Bạn)'), findsOneWidget);
      expect(find.text('Bùi Tuấn Kiệt'), findsOneWidget);
    });

    testWidgets('identifies current user with (Bạn) label', (tester) async {
      const reactions = [
        ChatV2Reaction(
          content: '❤️',
          count: 1,
          partners: [
            {'id': 6713, 'name': 'Ma Nguyễn Nhật Tân'},
          ],
          hasMe: true,
        ),
      ];

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChatV2ReactionDetailsSheet(
              reactions: reactions,
              currentUserName: 'Ma Nguyễn Nhật Tân',
            ),
          ),
        ),
      );

      expect(find.text('Ma Nguyễn Nhật Tân (Bạn)'), findsOneWidget);
    });

    testWidgets('shows empty state when members list is empty', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChatV2ReactionDetailsSheet(
              reactions: [],
            ),
          ),
        ),
      );

      expect(find.text('Không có dữ liệu'), findsOneWidget);
    });
  });
}
