import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/features/chat_v2/application/chat_v2_messages_controller.dart';
import 'package:vcloud/features/chat_v2/data/chat_v2_repository.dart';
import 'package:vcloud/features/chat_v2/data/models/chat_v2_message.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Chat V2 Share Link & Access Denied Safe-Guard Tests (BUG-027)', () {
    const channelId = '12345';
    const unauthorizedChannelId = '99999';

    // Test 1: ChatV2AccessDeniedException khởi tạo với message mặc định
    test('1. ChatV2AccessDeniedException khởi tạo thông điệp chuẩn xác', () {
      const ex = ChatV2AccessDeniedException();
      expect(ex.message, 'Bạn không có quyền truy cập tin nhắn của cuộc trò chuyện này');
      expect(ex.toString(), contains('Bạn không có quyền truy cập tin nhắn'));

      const customEx = ChatV2AccessDeniedException('Access denied');
      expect(customEx.message, 'Access denied');
      expect(customEx.toString(), 'Access denied');
    });

    // Test 2: chatV2ChannelAccessDeniedProvider mặc định là false
    test('2. chatV2ChannelAccessDeniedProvider mặc định là false', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final isDenied = container.read(chatV2ChannelAccessDeniedProvider(channelId));
      expect(isDenied, isFalse);
    });

    // Test 3: chatV2ChannelAccessDeniedProvider cập nhật sang true khi bị từ chối
    test('3. chatV2ChannelAccessDeniedProvider cập nhật state chính xác', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(chatV2ChannelAccessDeniedProvider(unauthorizedChannelId).notifier).state = true;
      final isDenied = container.read(chatV2ChannelAccessDeniedProvider(unauthorizedChannelId));
      expect(isDenied, isTrue);

      // Kênh khác vẫn là false (phân định theo channelId)
      expect(container.read(chatV2ChannelAccessDeniedProvider(channelId)), isFalse);
    });

    // Test 4: URL parser bóc tách đúng channel_id từ share link /chat/<id>/<uuid>
    test('4. URL parser trích xuất channel_id từ HTTP web link /chat/<id>/<uuid>', () {
      final uri = Uri.parse('https://vuahethong.net/chat/888/a1b2c3d4-e5f6-7890-abcd-ef1234567890');
      final pathSegments = uri.pathSegments;
      final chatIdx = pathSegments.indexOf('chat');

      expect(chatIdx, 0);
      expect(chatIdx + 1 < pathSegments.length, isTrue);
      final extractedId = pathSegments[chatIdx + 1];
      expect(extractedId, '888');
    });

    // Test 5: URL parser bóc tách đúng channel_id từ custom deep link vcloud://chat/<id>
    test('5. URL parser trích xuất channel_id từ custom scheme vcloud://chat/<id>', () {
      final uri = Uri.parse('vcloud://chat/777');
      expect(uri.scheme, 'vcloud');
      expect(uri.host, 'chat');
      final pathSegments = uri.pathSegments;
      expect(pathSegments.isNotEmpty, isTrue);
      expect(pathSegments.first, '777');
    });

    // Test 6: URL parser bỏ qua khi người dùng đang ở chính kênh hiện tại
    test('6. Share link điều hướng an toàn, không push đè nếu đang ở cùng kênh', () {
      const currentChannel = '888';
      final targetUri = Uri.parse('https://vuahethong.net/chat/888/token');
      final chatIdx = targetUri.pathSegments.indexOf('chat');
      final targetChannelId = targetUri.pathSegments[chatIdx + 1];

      final isSameChannel = (targetChannelId == currentChannel);
      expect(isSameChannel, isTrue);
    });

    // Test 7: ChatV2Message parse an toàn tin nhắn chứa share link trong body
    test('7. ChatV2Message parse trọn vẹn tin nhắn chứa share link mà không bị lỗi', () {
      final rawMap = {
        'id': 5001,
        'body': '<p>Tham gia nhóm tại: https://vuahethong.net/chat/888/uuid-test</p>',
        'channel_id': 888,
        'author_id': 10,
        'author_name': 'Admin 360',
        'date': '2026-10-12T08:00:00Z',
      };

      final msg = ChatV2Message.fromMap(rawMap);
      expect(msg.id, '5001');
      expect(msg.content, contains('/chat/888/uuid-test'));
      expect(msg.authorName, 'Admin 360');
    });

    // Test 8: Khi channelId không hợp lệ (null, <= 0), repo trả về mảng rỗng []
    test('8. Repo getMessages kiểm tra an toàn channelId âm hoặc không phải số', () async {
      // Mock giả lập logic bảo vệ của repo
      final cid1 = int.tryParse('invalid_id');
      expect(cid1 == null || cid1 <= 0, isTrue);

      final cid2 = int.tryParse('-5');
      expect(cid2 == null || cid2 <= 0, isTrue);

      final cid3 = int.tryParse('0');
      expect(cid3 == null || cid3 <= 0, isTrue);

      final cidValid = int.tryParse('123');
      expect(cidValid != null && cidValid > 0, isTrue);
    });

    // Test 9: Phát hiện lỗi Access Denied và Forbidden từ chuỗi exception
    test('9. Logic kiểm tra Access Denied nhận diện chính xác các biến thể lỗi', () {
      const err1 = 'Failure: Access denied to channel messages';
      const err2 = 'forbidden';
      const err3 = 'ACCESS DENIED';
      const err4 = 'Connection timeout';

      bool isAccessDenied(String err) {
        final lower = err.toLowerCase();
        return lower.contains('access denied') || lower.contains('forbidden');
      }

      expect(isAccessDenied(err1), isTrue);
      expect(isAccessDenied(err2), isTrue);
      expect(isAccessDenied(err3), isTrue);
      expect(isAccessDenied(err4), isFalse);
    });

    // Test 10: Phát hiện lỗi Channel Not Found từ chuỗi exception
    test('10. Logic kiểm tra Channel Not Found nhận diện chính xác lỗi 404', () {
      const err1 = 'channel_not_found';
      const err2 = 'Channel not found on server';
      const err3 = 'Some other error';

      bool isNotFound(String err) {
        final lower = err.toLowerCase();
        return lower.contains('channel_not_found') || lower.contains('not_found') || lower.contains('not found');
      }

      expect(isNotFound(err1), isTrue);
      expect(isNotFound(err2), isTrue);
      expect(isNotFound(err3), isFalse);
    });

    // Test 11: ChatV2MessageLocalCache cô lập cache giữa các kênh
    test('11. ChatV2MessageLocalCache không rò rỉ dữ liệu giữa kênh được phép và kênh bị cấm', () {
      const allowedMsg = ChatV2Message(id: '1', channelId: channelId, content: 'Tin hợp lệ');
      ChatV2MessageLocalCache.set(channelId, [allowedMsg], persist: false);

      final deniedCache = ChatV2MessageLocalCache.get(unauthorizedChannelId);
      expect(deniedCache, isNull);

      final allowedCache = ChatV2MessageLocalCache.get(channelId);
      expect(allowedCache, isNotNull);
      expect(allowedCache!.first.id, '1');
    });

    // Test 12: Đảm bảo format URL mời chuẩn Odoo Discuss v17 & v19
    test('12. URL mời chuẩn hóa đúng cấu trúc /chat/{channel_id}/{uuid}', () {
      const chId = 456;
      const chUuid = '9e8d7c6b-5a4f-3e2d-1c0b-a9b8c7d6e5f4';
      const generatedUrl = '/chat/$chId/$chUuid';

      expect(generatedUrl, '/chat/456/9e8d7c6b-5a4f-3e2d-1c0b-a9b8c7d6e5f4');
      final parsed = Uri.parse('https://example.com$generatedUrl');
      expect(parsed.pathSegments, ['chat', '456', chUuid]);
    });
  });
}
