import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/features/chat_v2/data/models/chat_v2_message.dart';

void main() {
  group('ChatV2Message Ticket Link Extraction Tests', () {
    test('TC1: Parses standard Odoo Discuss Bot message with data-oe-model and data-oe-id', () {
      final msg = ChatV2Message(
        id: '1',
        channelId: '10',
        content: 'Đã tạo ticket mới: Ticket sự cố kết nối (#01948)',
        rawBody: '<span class="o_mail_notification">Đã tạo ticket mới: <a href="#" data-oe-model="helpdesk.ticket" data-oe-id="1948">Ticket sự cố kết nối (#01948)</a></span>',
        authorName: 'OdooBot',
        createdAt: DateTime.now(),
        isMine: false,
      );

      final ticketInfo = msg.ticketLinkInfo;
      expect(ticketInfo, isNotNull);
      expect(ticketInfo!.ticketId, '1948');
      expect(ticketInfo.ticketName, 'Ticket sự cố kết nối (#01948)');
      expect(ticketInfo.model, 'helpdesk.ticket');
    });

    test('TC2: Parses inverted attributes: data-oe-id before data-oe-model', () {
      final msg = ChatV2Message(
        id: '2',
        channelId: '10',
        content: 'Đã tạo ticket',
        rawBody: '<div><a href="#" data-oe-id="2026" data-oe-model="helpdesk.ticket">Phiếu hỗ trợ kỹ thuật VCloud</a></div>',
        authorName: 'OdooBot',
        createdAt: DateTime.now(),
        isMine: false,
      );

      final ticketInfo = msg.ticketLinkInfo;
      expect(ticketInfo, isNotNull);
      expect(ticketInfo!.ticketId, '2026');
      expect(ticketInfo.ticketName, 'Phiếu hỗ trợ kỹ thuật VCloud');
      expect(ticketInfo.model, 'helpdesk.ticket');
    });

    test('TC3: Parses project.task model fallback link', () {
      final msg = ChatV2Message(
        id: '3',
        channelId: '10',
        content: 'Đã tạo task mới',
        rawBody: '<p>Tạo từ chat: <a href="#" data-oe-model="project.task" data-oe-id="999">Task dự án mobile #999</a></p>',
        authorName: 'OdooBot',
        createdAt: DateTime.now(),
        isMine: false,
      );

      final ticketInfo = msg.ticketLinkInfo;
      expect(ticketInfo, isNotNull);
      expect(ticketInfo!.ticketId, '999');
      expect(ticketInfo.ticketName, 'Task dự án mobile #999');
      expect(ticketInfo.model, 'project.task');
    });

    test('TC4: Parses URL path /tickets/1948 from plain text content', () {
      final msg = ChatV2Message(
        id: '4',
        channelId: '10',
        content: 'Vui lòng kiểm tra phiếu tại https://vuahethong.net/tickets/1948 nhé',
        rawBody: null,
        authorName: 'Nguyễn Văn A',
        createdAt: DateTime.now(),
        isMine: false,
      );

      final ticketInfo = msg.ticketLinkInfo;
      expect(ticketInfo, isNotNull);
      expect(ticketInfo!.ticketId, '1948');
      expect(ticketInfo.ticketName, 'Ticket #1948');
      expect(ticketInfo.model, 'helpdesk.ticket');
    });

    test('TC5: Parses HTML anchor with relative /tickets/555 href', () {
      final msg = ChatV2Message(
        id: '5',
        channelId: '10',
        content: 'Ticket #555',
        rawBody: '<a href="/tickets/555">Xem chi tiết</a>',
        authorName: 'Admin',
        createdAt: DateTime.now(),
        isMine: true,
      );

      final ticketInfo = msg.ticketLinkInfo;
      expect(ticketInfo, isNotNull);
      expect(ticketInfo!.ticketId, '555');
    });

    test('TC6: Returns null for regular message without ticket link', () {
      final msg = ChatV2Message(
        id: '6',
        channelId: '10',
        content: 'Chào buổi sáng cả nhóm!',
        rawBody: '<p>Chào buổi sáng cả nhóm!</p>',
        authorName: 'User 1',
        createdAt: DateTime.now(),
        isMine: true,
      );

      expect(msg.ticketLinkInfo, isNull);
    });

    test('TC7: Returns null for empty and whitespace messages', () {
      final msg = ChatV2Message(
        id: '7',
        channelId: '10',
        content: '   ',
        rawBody: '',
        authorName: 'User 1',
        createdAt: DateTime.now(),
        isMine: false,
      );

      expect(msg.ticketLinkInfo, isNull);
    });

    test('TC8: Sanitizes inner HTML inside ticket anchor tag correctly', () {
      final msg = ChatV2Message(
        id: '8',
        channelId: '10',
        content: 'Đã tạo ticket',
        rawBody: '<a href="#" data-oe-model="helpdesk.ticket" data-oe-id="777"><b>#00777</b> <i>Lỗi thanh toán POS</i></a>',
        authorName: 'OdooBot',
        createdAt: DateTime.now(),
        isMine: false,
      );

      final ticketInfo = msg.ticketLinkInfo;
      expect(ticketInfo, isNotNull);
      expect(ticketInfo!.ticketId, '777');
      expect(ticketInfo.ticketName, '#00777 Lỗi thanh toán POS');
    });

    test('TC9: Fallback to Ticket #id when anchor text is empty', () {
      final msg = ChatV2Message(
        id: '9',
        channelId: '10',
        content: 'Ticket',
        rawBody: '<a href="#" data-oe-model="helpdesk.ticket" data-oe-id="888">   </a>',
        authorName: 'OdooBot',
        createdAt: DateTime.now(),
        isMine: false,
      );

      final ticketInfo = msg.ticketLinkInfo;
      expect(ticketInfo, isNotNull);
      expect(ticketInfo!.ticketId, '888');
      expect(ticketInfo.ticketName, 'Ticket #888');
    });

    test('TC10: Handles single-quoted HTML attributes gracefully', () {
      final msg = ChatV2Message(
        id: '10',
        channelId: '10',
        content: 'Ticket link',
        rawBody: "<a href='#' data-oe-model='helpdesk.ticket' data-oe-id='12345'>Vé hỗ trợ VIP</a>",
        authorName: 'OdooBot',
        createdAt: DateTime.now(),
        isMine: false,
      );

      final ticketInfo = msg.ticketLinkInfo;
      expect(ticketInfo, isNotNull);
      expect(ticketInfo!.ticketId, '12345');
      expect(ticketInfo.ticketName, 'Vé hỗ trợ VIP');
    });
  });
}
