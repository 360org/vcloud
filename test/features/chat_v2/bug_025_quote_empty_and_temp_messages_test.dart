import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:vcloud/features/chat_v2/application/chat_v2_messages_controller.dart';
import 'package:vcloud/features/chat_v2/data/models/chat_v2_message.dart';
import 'package:vcloud/features/chat_v2/presentation/widgets/chat_v2_message_item.dart';

void main() {
  group('BUG-025: Lỗi 1 - Bỏ Quote Card rỗng khi parentBody thiếu nội dung', () {
    testWidgets('1. Không vẽ Quote Card khi parentBody = null', (tester) async {
      const msg = ChatV2Message(
        id: '1001',
        channelId: '1',
        content: 'Oke anh',
        parentId: '999',
        parentBody: null,
        parentAuthorName: null,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChatV2MessageItem(
              message: msg,
              isGroup: true,
            ),
          ),
        ),
      );

      // Quote Card có icon LucideIcons.reply
      expect(find.byIcon(LucideIcons.reply), findsNothing);
      expect(find.text('Tin nhắn'), findsNothing);
      expect(find.text('...'), findsNothing);
      expect(find.text('Oke anh'), findsOneWidget);
    });

    testWidgets('2. Không vẽ Quote Card khi parentBody rỗng hoặc toàn khoảng trắng', (tester) async {
      const msg = ChatV2Message(
        id: '1002',
        channelId: '1',
        content: 'Em tới cổng rồi',
        parentId: '999',
        parentBody: '   ',
        parentAuthorName: 'Admin',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChatV2MessageItem(
              message: msg,
              isGroup: true,
            ),
          ),
        ),
      );

      expect(find.byIcon(LucideIcons.reply), findsNothing);
      expect(find.text('Tin nhắn'), findsNothing);
      expect(find.text('...'), findsNothing);
      expect(find.text('Em tới cổng rồi'), findsOneWidget);
    });

    testWidgets('3. Vẽ Quote Card khi parentBody có nội dung hợp lệ', (tester) async {
      const msg = ChatV2Message(
        id: '1003',
        channelId: '1',
        content: 'Tôi đồng ý',
        parentId: '999',
        parentBody: 'Nội dung tin nhắn gốc',
        parentAuthorName: 'Sếp Tân',
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChatV2MessageItem(
              message: msg,
              isGroup: true,
            ),
          ),
        ),
      );

      expect(find.byIcon(LucideIcons.reply), findsOneWidget);
      expect(find.text('Sếp Tân'), findsOneWidget);
      expect(find.text('Nội dung tin nhắn gốc'), findsOneWidget);
      expect(find.text('Tôi đồng ý'), findsOneWidget);
    });

    testWidgets('4. Khi không có parentAuthorName thì không fallback chuỗi "Tin nhắn"', (tester) async {
      const msg = ChatV2Message(
        id: '1004',
        channelId: '1',
        content: 'Phản hồi tin nhắn',
        parentId: '999',
        parentBody: 'Nội dung trích dẫn',
        parentAuthorName: null,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChatV2MessageItem(
              message: msg,
              isGroup: true,
            ),
          ),
        ),
      );

      expect(find.text('Tin nhắn'), findsNothing);
      expect(find.text('Nội dung trích dẫn'), findsOneWidget);
      expect(find.text('Phản hồi tin nhắn'), findsOneWidget);
    });
  });

  group('BUG-025: Lỗi 2 - TTL 5 phút dọn tin temp_* & Sắp xếp timestamp chuẩn', () {
    test('5. isStaleTempMessage phát hiện chính xác tin temp_* quá 5 phút', () {
      final oldTemp = ChatV2Message(
        id: 'temp_1727333880000',
        channelId: '1',
        content: 'Đang ngủ',
        createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
      );
      final freshTemp = ChatV2Message(
        id: 'temp_1727333890000',
        channelId: '1',
        content: 'Vừa gửi',
        createdAt: DateTime.now().subtract(const Duration(seconds: 30)),
      );
      final normalMsg = ChatV2Message(
        id: '12345',
        channelId: '1',
        content: 'Tin bình thường',
        createdAt: DateTime.now().subtract(const Duration(days: 30)),
      );

      expect(ChatV2MessageLocalCache.isStaleTempMessage(oldTemp), isTrue);
      expect(ChatV2MessageLocalCache.isStaleTempMessage(freshTemp), isFalse);
      expect(ChatV2MessageLocalCache.isStaleTempMessage(normalMsg), isFalse);
    });

    test('6. _mergeMessages dọn dẹp các tin temp_* quá hạn (> 5 phút)', () {
      final oldTemp = ChatV2Message(
        id: 'temp_stale_1',
        channelId: '1',
        content: 'Đang ngủ',
        createdAt: DateTime(2026, 9, 26, 8, 0),
      );
      final serverMsg = ChatV2Message(
        id: '2001',
        channelId: '1',
        content: 'Tin hôm nay',
        createdAt: DateTime.now(),
      );

      final current = [oldTemp, serverMsg];
      final fresh = [serverMsg];

      final merged = ChatV2MessagesNotifier.mergeMessagesForTest(current, fresh);

      expect(merged.any((m) => m.id == 'temp_stale_1'), isFalse,
          reason: 'Tin temp cũ ngày 26/09 phải bị loại bỏ hoàn toàn');
      expect(merged.length, 1);
      expect(merged.first.id, '2001');
    });

    test('7. _mergeMessages giữ lại tin temp_* còn hạn (< 5 phút)', () {
      final recentTemp = ChatV2Message(
        id: 'temp_recent_1',
        channelId: '1',
        content: 'Tin vừa gửi',
        createdAt: DateTime.now().subtract(const Duration(seconds: 15)),
      );
      final serverMsg = ChatV2Message(
        id: '2002',
        channelId: '1',
        content: 'Tin trước đó',
        createdAt: DateTime.now().subtract(const Duration(minutes: 1)),
      );

      final current = [recentTemp, serverMsg];
      final fresh = [serverMsg];

      final merged = ChatV2MessagesNotifier.mergeMessagesForTest(current, fresh);

      expect(merged.any((m) => m.id == 'temp_recent_1'), isTrue);
      expect(merged.length, 2);
      expect(merged.first.id, 'temp_recent_1');
    });

    test('8. Deduplication: Loại bỏ temp_* nếu server đã trả về tin nhắn tương ứng', () {
      final now = DateTime.now();
      final tempMsg = ChatV2Message(
        id: 'temp_dup_1',
        channelId: '1',
        content: 'Anh có sạc dự phòng ko anh',
        isMine: true,
        createdAt: now.subtract(const Duration(seconds: 10)),
      );
      final confirmedServerMsg = ChatV2Message(
        id: '5001',
        channelId: '1',
        content: 'Anh có sạc dự phòng ko anh',
        isMine: true,
        createdAt: now.subtract(const Duration(seconds: 8)),
      );

      final current = [tempMsg];
      final fresh = [confirmedServerMsg];

      final merged = ChatV2MessagesNotifier.mergeMessagesForTest(current, fresh);

      expect(merged.length, 1, reason: 'Không được nhân đôi tin nhắn');
      expect(merged.first.id, '5001', reason: 'Tin nhắn thật từ server phải thay thế temp_*');
    });

    test('9. Sắp xếp chuẩn timestamp: Tin temp_* không bị ép cưỡng bức lên index 0 nếu có tin mới hơn', () {
      final now = DateTime.now();
      final tempOlder = ChatV2Message(
        id: 'temp_older',
        channelId: '1',
        content: 'Gửi trước đó 2 phút',
        createdAt: now.subtract(const Duration(minutes: 2)),
      );
      final serverNewer = ChatV2Message(
        id: '3001',
        channelId: '1',
        content: 'Gửi trước đó 30 giây',
        createdAt: now.subtract(const Duration(seconds: 30)),
      );

      final merged = ChatV2MessagesNotifier.mergeMessagesForTest([tempOlder], [serverNewer]);

      expect(merged.length, 2);
      expect(merged.first.id, '3001', reason: 'Tin mới hơn phải đứng trước (index 0)');
      expect(merged[1].id, 'temp_older', reason: 'Tin cũ hơn phải đứng sau');
    });

    test('10. ChatV2MessageLocalCache.set dọn dẹp tin temp_* quá hạn khi lưu', () {
      final staleTemp = ChatV2Message(
        id: 'temp_cache_stale',
        channelId: '99',
        content: 'Tin rác',
        createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
      );
      final validMsg = ChatV2Message(
        id: '4001',
        channelId: '99',
        content: 'Tin hợp lệ',
        createdAt: DateTime.now(),
      );

      ChatV2MessageLocalCache.set('99', [staleTemp, validMsg], persist: false);

      final cached = ChatV2MessageLocalCache.get('99');
      expect(cached, isNotNull);
      expect(cached!.length, 1);
      expect(cached.first.id, '4001');
      expect(cached.any((m) => m.id == 'temp_cache_stale'), isFalse);
    });
  });
}
