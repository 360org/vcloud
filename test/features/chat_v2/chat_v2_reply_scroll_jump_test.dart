import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:vcloud/features/chat_v2/data/models/chat_v2_message.dart';
import 'package:vcloud/features/chat_v2/presentation/widgets/chat_v2_message_item.dart';

void main() {
  group('Chat V2 Reply Scroll & Jump - Quote Card Validation', () {
    testWidgets('1. Bấm vào Quote Card với parentId hợp lệ kích hoạt onReplyTap với đúng ID gốc', (tester) async {
      String? tappedParentId;
      const msg = ChatV2Message(
        id: '101',
        channelId: '1',
        content: 'Dạ em đồng ý',
        parentId: '99',
        parentBody: 'Sếp Tân: Dự án đã chốt xong chưa?',
        parentAuthorName: 'Sếp Tân',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatV2MessageItem(
              message: msg,
              isGroup: true,
              onReplyTap: (pId) {
                tappedParentId = pId;
              },
            ),
          ),
        ),
      );

      // Quote card hiển thị icon LucideIcons.reply
      final quoteCardFinder = find.byIcon(LucideIcons.reply);
      expect(quoteCardFinder, findsOneWidget);

      await tester.tap(quoteCardFinder);
      await tester.pump();

      expect(tappedParentId, '99');
    });

    testWidgets('2. Bấm vào Quote Card với parentId == "quote" (ID ảo) không gọi onReplyTap và hiện SnackBar thông báo', (tester) async {
      var wasTapped = false;
      const msg = ChatV2Message(
        id: '102',
        channelId: '1',
        content: 'Phản hồi tin nhắn',
        parentId: 'quote',
        parentBody: 'Nội dung trích dẫn không có ID',
        parentAuthorName: 'Admin',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatV2MessageItem(
              message: msg,
              isGroup: true,
              onReplyTap: (_) {
                wasTapped = true;
              },
            ),
          ),
        ),
      );

      final quoteCardFinder = find.byIcon(LucideIcons.reply);
      expect(quoteCardFinder, findsOneWidget);

      await tester.tap(quoteCardFinder);
      await tester.pump();

      expect(wasTapped, isFalse);
      expect(find.text('Không tìm thấy thông tin tin nhắn gốc'), findsOneWidget);
    });

    testWidgets('3. Bấm vào Quote Card với parentId rỗng không gọi onReplyTap và hiện SnackBar', (tester) async {
      var wasTapped = false;
      const msg = ChatV2Message(
        id: '103',
        channelId: '1',
        content: 'Trả lời tin nhắn cũ',
        parentId: '',
        parentBody: 'Trích dẫn không rõ ID',
        parentAuthorName: 'Người dùng',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatV2MessageItem(
              message: msg,
              isGroup: true,
              onReplyTap: (_) {
                wasTapped = true;
              },
            ),
          ),
        ),
      );

      final quoteCardFinder = find.byIcon(LucideIcons.reply);
      expect(quoteCardFinder, findsOneWidget);

      await tester.tap(quoteCardFinder);
      await tester.pump();

      expect(wasTapped, isFalse);
      expect(find.text('Không tìm thấy thông tin tin nhắn gốc'), findsOneWidget);
    });

    testWidgets('4. Bấm vào Quote Card khi parentId == null không gọi onReplyTap và hiện SnackBar', (tester) async {
      var wasTapped = false;
      const msg = ChatV2Message(
        id: '104',
        channelId: '1',
        content: 'Trả lời tin nhắn',
        parentId: null,
        parentBody: 'Tin nhắn trích dẫn từ clipboard',
        parentAuthorName: 'Thành viên',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatV2MessageItem(
              message: msg,
              isGroup: true,
              onReplyTap: (_) {
                wasTapped = true;
              },
            ),
          ),
        ),
      );

      final quoteCardFinder = find.byIcon(LucideIcons.reply);
      expect(quoteCardFinder, findsOneWidget);

      await tester.tap(quoteCardFinder);
      await tester.pump();

      expect(wasTapped, isFalse);
      expect(find.text('Không tìm thấy thông tin tin nhắn gốc'), findsOneWidget);
    });
  });

  group('Chat V2 Reply Scroll & Jump - Data & Logic Verification', () {
    test('5. ChatV2Message giữ nguyên parentId và parentBody khi khởi tạo', () {
      const msg = ChatV2Message(
        id: '500',
        channelId: '1',
        content: 'Tin nhắn con',
        parentId: '250',
        parentBody: 'Tin nhắn cha',
        parentAuthorName: 'Author',
      );

      expect(msg.parentId, '250');
      expect(msg.parentBody, 'Tin nhắn cha');
      expect(msg.parentAuthorName, 'Author');
    });

    test('6. ChatV2Message copyWith cập nhật parentId chính xác', () {
      const original = ChatV2Message(
        id: '501',
        channelId: '1',
        content: 'Tin nhắn gốc',
      );
      final updated = original.copyWith(
        parentId: '123',
        parentBody: 'Trích dẫn',
        parentAuthorName: 'User A',
      );

      expect(updated.parentId, '123');
      expect(updated.parentBody, 'Trích dẫn');
      expect(updated.parentAuthorName, 'User A');
    });

    test('7. ChatV2Message fromMap parse data-reply-id và gán parentId', () {
      final map = {
        'id': '600',
        'channel_id': '1',
        'body': '<div data-reply-id="456" data-reply-author="Châu" data-reply-body="Nội dung">...</div>Câu trả lời',
        'author_id': '10',
        'author_name': 'Tân',
      };

      final parsed = ChatV2Message.fromMap(map);
      expect(parsed.parentId, '456');
      expect(parsed.parentAuthorName, 'Châu');
      expect(parsed.content, 'Câu trả lời');
    });

    test('8. ChatV2Message fromMap từ chối blockquote không có ID thành "quote"', () {
      final map = {
        'id': '601',
        'channel_id': '1',
        'body': '<blockquote>Đoạn trích dẫn không ID</blockquote>Ý kiến phản hồi',
        'author_id': '10',
        'author_name': 'Tân',
      };

      final parsed = ChatV2Message.fromMap(map);
      expect(parsed.parentId, 'quote');
      expect(parsed.content, 'Ý kiến phản hồi');
    });

    test('9. formatReplyPreviewBody chuẩn hoá file ảnh thành [Hình ảnh]', () {
      expect(ChatV2Message.formatReplyPreviewBody('image_picker_123.jpg'), '[Hình ảnh]');
      expect(ChatV2Message.formatReplyPreviewBody('photo.png'), '[Hình ảnh]');
    });

    test('10. formatReplyPreviewBody chuẩn hoá file tài liệu và âm thanh', () {
      expect(ChatV2Message.formatReplyPreviewBody('document.pdf'), '[Tài liệu] document.pdf');
      expect(ChatV2Message.formatReplyPreviewBody('voice_recording.m4a'), '[Tin nhắn thoại]');
    });

    test('11. formatReplyPreviewBody trả về chuỗi rỗng khi nội dung null hoặc rỗng (BUG-025)', () {
      expect(ChatV2Message.formatReplyPreviewBody(null), '');
      expect(ChatV2Message.formatReplyPreviewBody('   '), '');
    });
  });
}
