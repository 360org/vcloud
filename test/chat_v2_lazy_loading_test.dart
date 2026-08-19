import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/features/chat_v2/data/models/chat_v2_channel.dart';

void main() {
  group('ChatV2 Lazy Loading & Channel Deduplication Tests', () {
    test('Channels merge and deduplicate by ID while preserving latest message order', () {
      final page1 = [
        ChatV2Channel(
          id: '1',
          name: 'Phòng Dự Án',
          lastMessage: 'Update mới',
          lastMessageDate: DateTime.parse('2026-08-19T10:00:00Z'),
        ),
        ChatV2Channel(
          id: '2',
          name: 'Tài Chính',
          lastMessage: 'Đã chi',
          lastMessageDate: DateTime.parse('2026-08-19T09:00:00Z'),
        ),
      ];

      final page2 = [
        // Duplicate channel 2 with newer message
        ChatV2Channel(
          id: '2',
          name: 'Tài Chính',
          lastMessage: 'Đã chi (Updated)',
          lastMessageDate: DateTime.parse('2026-08-19T11:00:00Z'),
        ),
        ChatV2Channel(
          id: '3',
          name: 'Hành Chính',
          lastMessage: 'Thông báo nghỉ',
          lastMessageDate: DateTime.parse('2026-08-19T08:00:00Z'),
        ),
      ];

      final map = <String, ChatV2Channel>{};
      for (final c in page1) {
        map[c.id] = c;
      }
      for (final c in page2) {
        map[c.id] = c;
      }

      final merged = map.values.toList();
      merged.sort((a, b) {
        final da = a.lastMessageDate ?? DateTime.fromMillisecondsSinceEpoch(0);
        final db = b.lastMessageDate ?? DateTime.fromMillisecondsSinceEpoch(0);
        return db.compareTo(da);
      });

      expect(merged.length, 3);
      expect(merged[0].id, '2'); // Channel 2 has latest timestamp
      expect(merged[0].lastMessage, 'Đã chi (Updated)');
      expect(merged[1].id, '1');
      expect(merged[2].id, '3');
    });
  });
}
