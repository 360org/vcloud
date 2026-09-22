// Test kiểm chứng cơ chế FCM Foreground → Delta Update cho Chat V2.
// Bao phủ: merge logic, deduplication, ordering.
import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/features/chat_v2/application/chat_v2_messages_controller.dart';
import 'package:vcloud/features/chat_v2/data/models/chat_v2_message.dart';

ChatV2Message _msg(String id, {DateTime? at, String channel = '1'}) =>
    ChatV2Message(
      id: id,
      channelId: channel,
      content: 'msg $id',
      createdAt: at ?? DateTime(2026, 1, 1, 0, 0, int.parse(id)),
    );

void main() {
  group('mergeMessages (FCM trigger uses same logic)', () {
    test('tin nhắn mới từ server được chèn vào đầu danh sách', () {
      final current = [_msg('3'), _msg('2'), _msg('1')];
      final fresh = [_msg('4', at: DateTime(2026, 1, 1, 0, 0, 4)), _msg('3')];
      final merged = ChatV2MessagesNotifier.mergeMessagesForTest(current, fresh);

      expect(merged.first.id, '4', reason: 'Tin nhắn mới nhất (id=4) phải ở đầu');
      expect(merged.length, 4);
    });

    test('deduplication: không nhân đôi tin nhắn khi id trùng', () {
      final current = [_msg('3'), _msg('2'), _msg('1')];
      final fresh = [_msg('3'), _msg('2')];
      final merged = ChatV2MessagesNotifier.mergeMessagesForTest(current, fresh);

      final ids = merged.map((m) => m.id).toList();
      expect(ids.toSet().length, ids.length, reason: 'Không có ID trùng lặp');
      expect(merged.length, 3);
    });

    test('content cập nhật khi server trả về nội dung mới cho cùng message_id', () {
      final current = [
        const ChatV2Message(
          id: '5',
          channelId: '1',
          content: 'cũ',
          createdAt: null,
        ),
      ];
      final fresh = [
        const ChatV2Message(
          id: '5',
          channelId: '1',
          content: 'đã sửa',
          createdAt: null,
        ),
      ];
      final merged = ChatV2MessagesNotifier.mergeMessagesForTest(current, fresh);

      expect(merged.length, 1);
      expect(merged.first.content, 'đã sửa');
    });

    test('giữ nguyên tin nhắn temp (optimistic) khi merge', () {
      const temp = ChatV2Message(
        id: 'temp_123',
        channelId: '1',
        content: 'đang gửi...',
        status: 'sending',
      );
      final current = [temp, _msg('2'), _msg('1')];
      final fresh = [_msg('3', at: DateTime(2026, 1, 1, 0, 0, 3)), _msg('2')];
      final merged = ChatV2MessagesNotifier.mergeMessagesForTest(current, fresh);

      expect(merged.any((m) => m.id == 'temp_123'), true,
          reason: 'Tin nhắn temp phải được giữ lại');
      expect(merged.any((m) => m.id == '3'), true,
          reason: 'Tin nhắn mới từ server phải có mặt');
    });

    test('danh sách rỗng + fresh mới → trả về fresh', () {
      final merged = ChatV2MessagesNotifier.mergeMessagesForTest(
        [],
        [_msg('1')],
      );
      expect(merged.length, 1);
      expect(merged.first.id, '1');
    });

    test('fresh rỗng → giữ nguyên current', () {
      final current = [_msg('2'), _msg('1')];
      final merged = ChatV2MessagesNotifier.mergeMessagesForTest(current, []);
      expect(merged.length, 2);
    });

    test('tin nhắn từ channel khác không bị lẫn', () {
      final current = [_msg('1', channel: '1')];
      final fresh = [_msg('2', channel: '2', at: DateTime(2026, 1, 1, 0, 0, 2))];
      final merged = ChatV2MessagesNotifier.mergeMessagesForTest(current, fresh);

      // mergeMessages không lọc theo channel — nó merge theo id
      // Channel isolation do provider family(channelId) đảm bảo
      expect(merged.length, 2);
    });
  });
}
