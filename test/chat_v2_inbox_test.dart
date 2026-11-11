import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/features/chat_v2/application/chat_v2_inbox_controller.dart';
import 'package:vcloud/features/chat_v2/domain/models/chat_v2_inbox_item.dart';

void main() {
  group('1. ChatV2InboxItem Domain Model & HTML Sanitization Tests', () {
    test('1.1 parses JSON accurately with all standard fields', () {
      final json = {
        'id': 101,
        'subject': 'Đề xuất tăng ca dự án Vcloud',
        'record_name': 'Project Task: #501',
        'model': 'project.task',
        'res_id': 501,
        'channel_id': 12,
        'body': '<p>Chào anh Tân, em gửi đề xuất ạ.</p>',
        'date': '2026-11-09T08:30:00Z',
        'author_id': 45,
        'author_name': 'Nguyễn Văn A',
        'author_avatar': '/web/image/res.partner/45/avatar_128',
        'is_starred': true,
        'is_needaction': true,
        'message_type': 'comment',
      };

      final item = ChatV2InboxItem.fromJson(json);

      expect(item.id, 101);
      expect(item.subject, 'Đề xuất tăng ca dự án Vcloud');
      expect(item.recordName, 'Project Task: #501');
      expect(item.model, 'project.task');
      expect(item.resId, 501);
      expect(item.channelId, 12);
      expect(item.authorName, 'Nguyễn Văn A');
      expect(item.authorAvatar, '/web/image/res.partner/45/avatar_128');
      expect(item.isStarred, isTrue);
      expect(item.isNeedaction, isTrue);
      expect(item.messageType, 'comment');
      expect(item.date, isNotNull);
    });

    test('1.2 automatically resolves channelId when model is discuss.channel and res_id is provided', () {
      final json = {
        'id': 102,
        'model': 'discuss.channel',
        'res_id': 88,
        'body': 'Tin nhắn kênh chung',
        'author_name': 'Trợ lý Như',
      };

      final item = ChatV2InboxItem.fromJson(json);

      expect(item.channelId, 88);
      expect(item.model, 'discuss.channel');
      expect(item.resId, 88);
    });

    test('1.3 parses attachments and attachment_ids accurately', () {
      final json = {
        'id': 103,
        'record_name': 'Helpdesk Ticket #77',
        'model': 'helpdesk.ticket',
        'res_id': 77,
        'body': 'Đính kèm tài liệu',
        'author_name': 'DevOps Support',
        'attachment_ids': [201, 202, '203'],
        'attachments': [
          {
            'id': 201,
            'name': 'bao_cao_tuan.pdf',
            'mimetype': 'application/pdf',
            'file_size': 1048576,
            'url': '/web/content/201?download=true',
          },
          {
            'id': 202,
            'name': 'screenshot.png',
            'mimetype': 'image/png',
            'file_size': 204800,
            'url': '/web/content/202?download=true',
          },
        ],
      };

      final item = ChatV2InboxItem.fromJson(json);

      expect(item.attachmentIds, [201, 202, 203]);
      expect(item.attachments.length, 2);
      expect(item.attachments[0].name, 'bao_cao_tuan.pdf');
      expect(item.attachments[0].mimetype, 'application/pdf');
      expect(item.attachments[0].fileSize, 1048576);
      expect(item.attachments[1].name, 'screenshot.png');
    });

    test('1.4 plainSnippet strips HTML tags, styles, scripts and entities cleanly', () {
      const rawHtml = '''
        <style>.hidden { display: none; }</style>
        <p>Xin chào &nbsp; <b>Sếp Tân</b>!<br/>
        Hệ thống &amp; tiến độ &lt;Vcloud&gt; đã hoàn tất &quot;100%&quot;.</p>
        <script>alert("test");</script>
      ''';

      const item = ChatV2InboxItem(
        id: 1,
        subject: '',
        recordName: '',
        model: '',
        resId: 0,
        body: rawHtml,
        authorName: 'Như',
      );

      final snippet = item.plainSnippet;

      expect(snippet.contains('<style>'), isFalse);
      expect(snippet.contains('<script>'), isFalse);
      expect(snippet.contains('alert'), isFalse);
      expect(snippet.contains('<p>'), isFalse);
      expect(snippet.contains('&nbsp;'), isFalse);
      expect(snippet.contains('&amp;'), isFalse);
      expect(snippet, 'Xin chào Sếp Tân! Hệ thống & tiến độ <Vcloud> đã hoàn tất "100%".');
    });

    test('1.5 plainSnippet returns empty string when body is empty or contains only whitespace/tags', () {
      const emptyItem = ChatV2InboxItem(
        id: 2,
        subject: '',
        recordName: '',
        model: '',
        resId: 0,
        body: '',
        authorName: 'System',
      );
      expect(emptyItem.plainSnippet, '');

      const onlyTagsItem = ChatV2InboxItem(
        id: 3,
        subject: '',
        recordName: '',
        model: '',
        resId: 0,
        body: '<p><br/>&nbsp;</p>',
        authorName: 'System',
      );
      expect(onlyTagsItem.plainSnippet, '');
    });

    test('1.6 copyWith creates immutable clone with selective overrides', () {
      const original = ChatV2InboxItem(
        id: 50,
        subject: 'Tiêu đề cũ',
        recordName: 'Record 50',
        model: 'mail.channel',
        resId: 50,
        body: 'Nội dung',
        authorName: 'User',
        isStarred: false,
        isNeedaction: true,
      );

      final modified = original.copyWith(
        isStarred: true,
        isNeedaction: false,
      );

      expect(modified.id, 50);
      expect(modified.subject, 'Tiêu đề cũ');
      expect(modified.isStarred, isTrue);
      expect(modified.isNeedaction, isFalse);
      // Kiểm tra immutability của bản gốc
      expect(original.isStarred, isFalse);
      expect(original.isNeedaction, isTrue);
    });
  });

  group('2. ChatV2InboxState & Reducer Logic Tests', () {
    test('2.1 ChatV2InboxState default initialization has correct initial values', () {
      const state = ChatV2InboxState();

      expect(state.inboxItems, isEmpty);
      expect(state.starredItems, isEmpty);
      expect(state.historyItems, isEmpty);
      expect(state.isLoading, isFalse);
      expect(state.error, isNull);
      expect(state.activeTab, ChatV2InboxTabType.inbox);
      expect(state.inboxTotal, 0);
    });

    test('2.2 ChatV2InboxState.copyWith updates activeTab and lists correctly', () {
      const item = ChatV2InboxItem(
        id: 10,
        subject: 'Task A',
        recordName: 'Task #10',
        model: 'project.task',
        resId: 10,
        body: 'Details',
        authorName: 'Lead',
      );

      const state = ChatV2InboxState();
      final updated = state.copyWith(
        activeTab: ChatV2InboxTabType.starred,
        inboxItems: [item],
        inboxTotal: 1,
        isLoading: false,
      );

      expect(updated.activeTab, ChatV2InboxTabType.starred);
      expect(updated.inboxItems.length, 1);
      expect(updated.inboxTotal, 1);
      expect(updated.isLoading, isFalse);
    });
  });

  group('3. ChatV2Inbox State Mutations (Optimistic Updates)', () {
    test('3.1 toggleStar optimistic update adds to starredItems when star is true', () {
      const item = ChatV2InboxItem(
        id: 99,
        subject: 'Báo cáo',
        recordName: 'Sale #99',
        model: 'sale.order',
        resId: 99,
        body: 'Đơn hàng mới',
        authorName: 'Kinh Doanh',
        isStarred: false,
      );

      var state = const ChatV2InboxState(
        inboxItems: [item],
        starredItems: [],
      );

      // Mô phỏng mutation toggleStar(item)
      final newStarred = !item.isStarred;
      final updatedItem = item.copyWith(isStarred: newStarred);
      final updatedInbox = state.inboxItems.map((m) => m.id == item.id ? updatedItem : m).toList();
      final updatedStarred = List<ChatV2InboxItem>.from(state.starredItems);
      if (newStarred) {
        updatedStarred.insert(0, updatedItem);
      } else {
        updatedStarred.removeWhere((m) => m.id == item.id);
      }

      state = state.copyWith(
        inboxItems: updatedInbox,
        starredItems: updatedStarred,
      );

      expect(state.inboxItems.first.isStarred, isTrue);
      expect(state.starredItems.length, 1);
      expect(state.starredItems.first.id, 99);
      expect(state.starredItems.first.isStarred, isTrue);
    });

    test('3.2 markDone removes item from inboxItems, decreases total and adds to historyItems', () {
      const item1 = ChatV2InboxItem(
        id: 1,
        subject: 'Task 1',
        recordName: 'Task #1',
        model: 'project.task',
        resId: 1,
        body: 'Body 1',
        authorName: 'Author 1',
        isNeedaction: true,
      );
      const item2 = ChatV2InboxItem(
        id: 2,
        subject: 'Task 2',
        recordName: 'Task #2',
        model: 'project.task',
        resId: 2,
        body: 'Body 2',
        authorName: 'Author 2',
        isNeedaction: true,
      );

      var state = const ChatV2InboxState(
        inboxItems: [item1, item2],
        historyItems: [],
        inboxTotal: 2,
      );

      // Mô phỏng mutation markDone(item1)
      final updatedInbox = state.inboxItems.where((m) => m.id != item1.id).toList();
      final updatedHistory = [item1.copyWith(isNeedaction: false), ...state.historyItems];
      final newTotal = state.inboxTotal - 1;

      state = state.copyWith(
        inboxItems: updatedInbox,
        historyItems: updatedHistory,
        inboxTotal: newTotal,
      );

      expect(state.inboxItems.length, 1);
      expect(state.inboxItems.first.id, 2);
      expect(state.inboxTotal, 1);
      expect(state.historyItems.length, 1);
      expect(state.historyItems.first.id, 1);
      expect(state.historyItems.first.isNeedaction, isFalse);
    });

    test('3.3 markAllDone clears inboxItems, sets inboxTotal to 0 and transfers all to historyItems', () {
      const item1 = ChatV2InboxItem(
        id: 11,
        subject: 'Thông báo 1',
        recordName: 'Ticket #11',
        model: 'helpdesk.ticket',
        resId: 11,
        body: 'Lỗi phát sinh',
        authorName: 'Tester',
        isNeedaction: true,
      );
      const item2 = ChatV2InboxItem(
        id: 12,
        subject: 'Thông báo 2',
        recordName: 'Ticket #12',
        model: 'helpdesk.ticket',
        resId: 12,
        body: 'Cần xác nhận',
        authorName: 'Tester',
        isNeedaction: true,
      );

      var state = const ChatV2InboxState(
        inboxItems: [item1, item2],
        historyItems: [],
        inboxTotal: 2,
      );

      // Mô phỏng mutation markAllDone()
      final previousInbox = state.inboxItems;
      state = state.copyWith(
        inboxItems: const [],
        inboxTotal: 0,
        historyItems: [...previousInbox, ...state.historyItems],
      );

      expect(state.inboxItems, isEmpty);
      expect(state.inboxTotal, 0);
      expect(state.historyItems.length, 2);
      expect(state.historyItems[0].id, 11);
      expect(state.historyItems[1].id, 12);
    });

    test('3.4 ChatV2InboxTabType enum has exactly 3 tabs matching Odoo Discuss Mailbox standard', () {
      expect(ChatV2InboxTabType.values.length, 3);
      expect(ChatV2InboxTabType.values, contains(ChatV2InboxTabType.inbox));
      expect(ChatV2InboxTabType.values, contains(ChatV2InboxTabType.starred));
      expect(ChatV2InboxTabType.values, contains(ChatV2InboxTabType.history));
    });
  });
}
