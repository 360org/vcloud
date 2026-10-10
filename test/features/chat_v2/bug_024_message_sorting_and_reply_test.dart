import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/features/chat_v2/application/chat_v2_messages_controller.dart';
import 'package:vcloud/features/chat_v2/data/models/chat_v2_message.dart';
import 'package:vcloud/features/chat_v2/data/chat_v2_repository.dart';
import 'package:vcloud/core/api/odoo_api_client.dart';

class MockOdooApiClient implements OdooApiClient {
  Map<String, dynamic>? lastPostBody;

  @override
  Future<dynamic> post(
    String path, {
    dynamic body,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    bool auth = true,
    Duration? timeout,
  }) async {
    if (body is Map<String, dynamic>) {
      lastPostBody = body;
    }
    return {
      'id': 9999,
      'body': body is Map ? body['body'] : '',
      'channel_id': 1,
      'author_id': 2,
      'date': '2026-10-03T10:00:00Z',
      'parent_id': body is Map ? body['parent_id'] : null,
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('BUG-024: Message Sorting Invariant (ListView reverse: true)', () {
    test('1. Tin nhắn mới nhất (hôm nay) luôn ở index 0, tin cũ (tuần trước) ở index sau', () {
      final todayDate = DateTime(2026, 10, 3, 10, 0, 0);
      final pastDate = DateTime(2026, 9, 26, 15, 30, 0);

      final currentList = [
        ChatV2Message(
          id: '200',
          channelId: '1',
          content: 'Tin nhắn hôm nay',
          createdAt: todayDate,
        ),
      ];

      // Giả lập server trả về 3 tin nhắn: 1 tin hôm nay và 2 tin cũ từ 26/09/2026
      final freshList = [
        ChatV2Message(
          id: '200',
          channelId: '1',
          content: 'Tin nhắn hôm nay (đã cập nhật)',
          createdAt: todayDate,
        ),
        ChatV2Message(
          id: '102',
          channelId: '1',
          content: 'Tin nhắn cũ 2',
          createdAt: pastDate.add(const Duration(minutes: 5)),
        ),
        ChatV2Message(
          id: '101',
          channelId: '1',
          content: 'Tin nhắn cũ 1',
          createdAt: pastDate,
        ),
      ];

      final merged = ChatV2MessagesNotifier.mergeMessagesForTest(currentList, freshList);

      // Invariant cho ListView(reverse: true):
      // Index 0 là tin mới nhất (đáy màn hình)
      expect(merged.length, 3);
      expect(merged[0].id, '200', reason: 'Tin hôm nay 03/10 phải ở index 0');
      expect(merged[1].id, '102', reason: 'Tin cũ 2 26/09 phải ở index 1');
      expect(merged[2].id, '101', reason: 'Tin cũ 1 26/09 phải ở index 2 (đỉnh màn hình)');
    });

    test('2. Sắp xếp giảm dần theo createdAt desc khi nhận danh sách xáo trộn', () {
      final t1 = DateTime(2026, 10, 1, 8, 0);
      final t2 = DateTime(2026, 10, 2, 9, 0);
      final t3 = DateTime(2026, 10, 3, 10, 0);

      final shuffledFresh = [
        ChatV2Message(id: '1', channelId: '1', content: 'Ngày 1', createdAt: t1),
        ChatV2Message(id: '3', channelId: '1', content: 'Ngày 3', createdAt: t3),
        ChatV2Message(id: '2', channelId: '1', content: 'Ngày 2', createdAt: t2),
      ];

      final merged = ChatV2MessagesNotifier.mergeMessagesForTest([], shuffledFresh);

      expect(merged.map((m) => m.id).toList(), ['3', '2', '1']);
    });

    test('3. Tie-breaker bằng ID khi trùng thời gian createdAt', () {
      final sameTime = DateTime(2026, 10, 3, 12, 0);

      final fresh = [
        ChatV2Message(id: '50', channelId: '1', content: 'ID 50', createdAt: sameTime),
        ChatV2Message(id: '150', channelId: '1', content: 'ID 150', createdAt: sameTime),
        ChatV2Message(id: '100', channelId: '1', content: 'ID 100', createdAt: sameTime),
      ];

      final merged = ChatV2MessagesNotifier.mergeMessagesForTest([], fresh);

      expect(merged.map((m) => m.id).toList(), ['150', '100', '50']);
    });

    test('4. Tin nhắn tạm temp_* luôn đứng ở đầu (index 0) phía trên các tin đã lưu', () {
      final todayDate = DateTime(2026, 10, 3, 10, 0, 0);
      final currentList = [
        const ChatV2Message(
          id: 'temp_999999',
          channelId: '1',
          content: 'Đang gửi...',
          status: 'sending',
        ),
        ChatV2Message(
          id: '200',
          channelId: '1',
          content: 'Tin nhắn hôm nay',
          createdAt: todayDate,
        ),
      ];

      final freshList = [
        ChatV2Message(
          id: '200',
          channelId: '1',
          content: 'Tin nhắn hôm nay',
          createdAt: todayDate,
        ),
        ChatV2Message(
          id: '199',
          channelId: '1',
          content: 'Tin nhắn trước đó',
          createdAt: todayDate.subtract(const Duration(minutes: 1)),
        ),
      ];

      final merged = ChatV2MessagesNotifier.mergeMessagesForTest(currentList, freshList);

      expect(merged.first.id, 'temp_999999', reason: 'Temp message phải luôn ở index 0');
      expect(merged[1].id, '200');
      expect(merged[2].id, '199');
    });

    test('5. Khử trùng lặp bản ghi (Deduplication) khi server và local trùng ID', () {
      final msg = ChatV2Message(
        id: '555',
        channelId: '1',
        content: 'Nội dung ban đầu',
        createdAt: DateTime(2026, 10, 3, 11, 0),
      );
      final updatedMsg = msg.copyWith(content: 'Nội dung đã chỉnh sửa');

      final merged = ChatV2MessagesNotifier.mergeMessagesForTest([msg], [updatedMsg]);

      expect(merged.length, 1);
      expect(merged.first.content, 'Nội dung đã chỉnh sửa');
    });
  });

  group('BUG-024: Clean Reply Quote & Odoo Discuss Integration', () {
    test('6. formatReplyPreviewBody chuẩn hóa tên file ảnh hệ thống thành [Hình ảnh]', () {
      expect(
        ChatV2Message.formatReplyPreviewBody('image_picker_D26C93AF-D616-4318-97F8-E3CE743825EB-9494-000000000000.jpg'),
        '[Hình ảnh]',
      );
      expect(ChatV2Message.formatReplyPreviewBody('scaled_image_12345.png'), '[Hình ảnh]');
      expect(ChatV2Message.formatReplyPreviewBody('photo.webp'), '[Hình ảnh]');
    });

    test('7. formatReplyPreviewBody chuẩn hóa tên file video thành [Video]', () {
      expect(ChatV2Message.formatReplyPreviewBody('video_1788931234.mp4'), '[Video]');
      expect(ChatV2Message.formatReplyPreviewBody('recording.mov'), '[Video]');
    });

    test('8. formatReplyPreviewBody chuẩn hóa file ghi âm thành [Tin nhắn thoại]', () {
      expect(ChatV2Message.formatReplyPreviewBody('voice_1788931234.m4a'), '[Tin nhắn thoại]');
      expect(ChatV2Message.formatReplyPreviewBody('audio_clip.opus'), '[Tin nhắn thoại]');
    });

    test('9. formatReplyPreviewBody giữ nguyên văn bản thông thường và khử rỗng (BUG-025)', () {
      expect(ChatV2Message.formatReplyPreviewBody('Chào buổi sáng mọi người!'), 'Chào buổi sáng mọi người!');
      expect(ChatV2Message.formatReplyPreviewBody(null), '');
      expect(ChatV2Message.formatReplyPreviewBody('   '), '');
    });

    test('10. sendMessage KHÔNG chèn thẻ HTML <div data-reply-id=...> vào body', () async {
      final mockClient = MockOdooApiClient();
      final repo = ChatV2Repository(mockClient);

      await repo.sendMessage(
        '1',
        'Tôi đồng ý với ý kiến này',
        parentId: '646670',
        parentAuthorName: 'Ma Nguyễn Nhật Tân',
        parentBody: 'Tin nhắn gốc cần reply',
      );

      final payload = mockClient.lastPostBody;
      expect(payload, isNotNull);
      expect(payload!['body'], 'Tôi đồng ý với ý kiến này',
          reason: 'Body phải là văn bản thuần túy của user, KHÔNG chứa thẻ div rác');
      expect(payload['body'].contains('<div data-reply-id='), isFalse);
      expect(payload['parent_id'], 646670,
          reason: 'parent_id phải được truyền chuẩn số nguyên cho Odoo Discuss');
    });
  });
}
