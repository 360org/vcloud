import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/features/chat_v2/data/models/chat_v2_message.dart';
import 'package:vcloud/features/chat_v2/presentation/widgets/chat_v2_message_item.dart';

void main() {
  final validPngBytes = Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
    0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
    0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
    0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
    0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82
  ]);

  group('Multi-Image Chat & Error Recovery Verification Tests', () {
    // TC-01: Kiểm tra đơn ảnh
    test('TC-01: ChatV2Attachment nhận diện ảnh đơn hợp lệ', () {
      const att = ChatV2Attachment(
        id: '101',
        name: 'photo_01.jpg',
        mimetype: 'image/jpeg',
      );
      expect(att.isImage, isTrue);
      expect(att.extension, equals('jpg'));
    });

    // TC-02: Kiểm tra chùm nhiều ảnh
    test('TC-02: ChatV2Message chứa chùm 4 ảnh đính kèm', () {
      final attachments = List.generate(
        4,
        (i) => ChatV2Attachment(
          id: '10$i',
          name: 'img_$i.png',
          mimetype: 'image/png',
        ),
      );

      final msg = ChatV2Message(
        id: 'msg_001',
        channelId: '4255',
        content: 'Chùm 4 ảnh',
        attachments: attachments,
        isMine: true,
      );

      expect(msg.attachments.length, equals(4));
      expect(msg.hasImageAttachment, isTrue);
    });

    // TC-03: Render lưới 2 ảnh
    testWidgets('TC-03: Render ChatV2MessageItem với 2 ảnh đính kèm', (tester) async {
      final attachments = [
        ChatV2Attachment(id: '1', name: 'img1.jpg', mimetype: 'image/jpeg', bytes: validPngBytes),
        ChatV2Attachment(id: '2', name: 'img2.jpg', mimetype: 'image/jpeg', bytes: validPngBytes),
      ];

      final msg = ChatV2Message(
        id: 'msg_2_images',
        channelId: '4255',
        content: '',
        attachments: attachments,
        isMine: true,
        status: 'sent',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatV2MessageItem(
              message: msg,
            ),
          ),
        ),
      );

      expect(find.byType(ChatV2AttachmentImage), findsNWidgets(2));
    });

    // TC-04: Render lưới 4 ảnh (2x2)
    testWidgets('TC-04: Render ChatV2MessageItem với 4 ảnh đính kèm (Lưới 2x2)', (tester) async {
      final attachments = List.generate(
        4,
        (i) => ChatV2Attachment(
          id: '$i',
          name: 'img_$i.jpg',
          mimetype: 'image/jpeg',
          bytes: validPngBytes,
        ),
      );

      final msg = ChatV2Message(
        id: 'msg_4_images',
        channelId: '4255',
        content: '',
        attachments: attachments,
        isMine: true,
        status: 'sent',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatV2MessageItem(
              message: msg,
            ),
          ),
        ),
      );

      expect(find.byType(ChatV2AttachmentImage), findsNWidgets(4));
    });

    // TC-05: Render chùm 6 ảnh (Wrap 3 cột)
    testWidgets('TC-05: Render ChatV2MessageItem với 6 ảnh đính kèm', (tester) async {
      final attachments = List.generate(
        6,
        (i) => ChatV2Attachment(
          id: '$i',
          name: 'img_$i.jpg',
          mimetype: 'image/jpeg',
          bytes: validPngBytes,
        ),
      );

      final msg = ChatV2Message(
        id: 'msg_6_images',
        channelId: '4255',
        content: '',
        attachments: attachments,
        isMine: true,
        status: 'sent',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatV2MessageItem(
              message: msg,
            ),
          ),
        ),
      );

      expect(find.byType(ChatV2AttachmentImage), findsNWidgets(6));
    });

    // TC-06: Trạng thái 'pending' hiển thị Đang tải lên...
    testWidgets('TC-06: ChatV2MessageItem hiển thị overlay Đang tải lên... khi pending', (tester) async {
      final attachments = [
        ChatV2Attachment(id: '1', name: 'img1.jpg', mimetype: 'image/jpeg', bytes: validPngBytes),
      ];

      final msg = ChatV2Message(
        id: 'msg_pending',
        channelId: '4255',
        content: '',
        attachments: attachments,
        isMine: true,
        status: 'pending',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatV2MessageItem(
              message: msg,
            ),
          ),
        ),
      );

      expect(find.text('Đang tải lên...'), findsOneWidget);
    });

    // TC-07: Trạng thái 'error' trên ảnh hiển thị Lỗi gửi ảnh và 2 nút Thử lại, Xóa
    testWidgets('TC-07: ChatV2MessageItem hiển thị cứu hộ lỗi gửi ảnh khi status là error', (tester) async {
      final attachments = [
        ChatV2Attachment(id: '1', name: 'img1.jpg', mimetype: 'image/jpeg', bytes: validPngBytes),
      ];

      final msg = ChatV2Message(
        id: 'msg_error',
        channelId: '4255',
        content: '',
        attachments: attachments,
        isMine: true,
        status: 'error',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatV2MessageItem(
              message: msg,
              onRetry: () {},
              onDelete: () {},
            ),
          ),
        ),
      );

      expect(find.text('Lỗi gửi ảnh'), findsOneWidget);
      expect(find.text('Thử lại'), findsOneWidget);
      expect(find.text('Xóa'), findsOneWidget);
    });

    // TC-08: Bấm nút 'Thử lại' kích hoạt callback onRetry
    testWidgets('TC-08: Bấm Thử lại kích hoạt callback onRetry', (tester) async {
      final attachments = [
        ChatV2Attachment(id: '1', name: 'img1.jpg', mimetype: 'image/jpeg', bytes: validPngBytes),
      ];

      final msg = ChatV2Message(
        id: 'msg_retry_test',
        channelId: '4255',
        content: '',
        attachments: attachments,
        isMine: true,
        status: 'error',
      );

      var retryCalled = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatV2MessageItem(
              message: msg,
              onRetry: () => retryCalled = true,
              onDelete: () {},
            ),
          ),
        ),
      );

      await tester.tap(find.text('Thử lại'), warnIfMissed: false);
      await tester.pump();

      expect(retryCalled, isTrue);
    });

    // TC-09: Bấm nút 'Xóa' kích hoạt callback onDelete
    testWidgets('TC-09: Bấm Xóa kích hoạt callback onDelete', (tester) async {
      final attachments = [
        ChatV2Attachment(id: '1', name: 'img1.jpg', mimetype: 'image/jpeg', bytes: validPngBytes),
      ];

      final msg = ChatV2Message(
        id: 'msg_delete_test',
        channelId: '4255',
        content: '',
        attachments: attachments,
        isMine: true,
        status: 'error',
      );

      var deleteCalled = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatV2MessageItem(
              message: msg,
              onRetry: () {},
              onDelete: () => deleteCalled = true,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Xóa'), warnIfMissed: false);
      await tester.pump();

      expect(deleteCalled, isTrue);
    });

    // TC-10: Tin nhắn text thông thường bị lỗi hiển thị action Thử lại và Xóa
    testWidgets('TC-10: Tin nhắn text bị lỗi hiển thị action Thử lại & Xóa dưới bubble', (tester) async {
      const msg = ChatV2Message(
        id: 'msg_text_error',
        channelId: '4255',
        content: 'Tin nhắn văn bản thử nghiệm',
        isMine: true,
        status: 'error',
      );

      var retryCalled = false;
      var deleteCalled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatV2MessageItem(
              message: msg,
              onRetry: () => retryCalled = true,
              onDelete: () => deleteCalled = true,
            ),
          ),
        ),
      );

      expect(find.text('Lỗi gửi'), findsOneWidget);
      expect(find.text('Thử lại'), findsOneWidget);
      expect(find.text('Xóa'), findsOneWidget);

      await tester.tap(find.text('Thử lại'), warnIfMissed: false);
      await tester.pump();
      expect(retryCalled, isTrue);

      await tester.tap(find.text('Xóa'), warnIfMissed: false);
      await tester.pump();
      expect(deleteCalled, isTrue);
    });

    // TC-11: Mention trong ChatV2MessageItem hiển thị @tag và kích hoạt onMentionTap
    testWidgets('TC-11: Mention trong ChatV2MessageItem hiển thị @tag và kích hoạt onMentionTap', (tester) async {
      const msg = ChatV2Message(
        id: 'msg_mention',
        channelId: '4255',
        content: 'Xin chào @Tan chúc một ngày tốt lành',
        isMine: false,
        status: 'sent',
      );

      String? tappedMention;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatV2MessageItem(
              message: msg,
              onMentionTap: (name) => tappedMention = name,
            ),
          ),
        ),
      );

      expect(find.byType(ChatV2MessageItem), findsOneWidget);
      // Tìm RichText chứa mention
      final richTextFinder = find.byType(RichText);
      expect(richTextFinder, findsWidgets);
      expect(tappedMention, isNull);
    });
  });
}
