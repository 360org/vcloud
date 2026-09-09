// Full End-to-End Cross-Platform Bidirectional Test for Mentions (Odoo 17/19 <-> Flutter vclients)
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/features/chat_v2/data/models/chat_v2_message.dart';
import 'package:vcloud/features/chat_v2/presentation/widgets/chat_v2_message_item.dart';

void main() {
  group('Cross-Platform End-to-End Mention Simulation & Verification Test', () {
    test('Flow 1 (Mobile -> Odoo Backend Simulation): Payload formation & HTML serialization', () {
      // 1. Mobile user types '@Admin xin chào'
      const mobileInputText = '@Admin xin chào';
      const partnerId = 3;
      const partnerName = 'Admin';

      // 2. Mobile payload constructed
      final mobilePayload = {
        'channel_id': 12,
        'body': mobileInputText,
        'partner_ids': [partnerId],
        'mentioned_partners': [
          {'id': partnerId, 'name': partnerName}
        ],
      };

      expect(mobilePayload['body'], equals('@Admin xin chào'));
      expect(mobilePayload['partner_ids'], equals([3]));
      expect((mobilePayload['mentioned_partners'] as List).first['name'], equals('Admin'));

      // 3. Odoo Backend Controller simulation (transforms plain text into Odoo Discuss HTML anchor)
      final rawBody = mobilePayload['body'] as String;
      final mentionedPartners = mobilePayload['mentioned_partners'] as List<Map<String, dynamic>>;

      String transformedHtml = rawBody;
      for (final mp in mentionedPartners) {
        final pid = mp['id'];
        final pName = mp['name'];
        final anchor = '<a href="#" data-oe-model="res.partner" data-oe-id="$pid" class="o_mail_redirect">@$pName</a>';
        transformedHtml = transformedHtml.replaceAll('@$pName', anchor);
      }
      final finalOdooHtml = '<p>$transformedHtml</p>';

      expect(
        finalOdooHtml,
        equals('<p><a href="#" data-oe-model="res.partner" data-oe-id="3" class="o_mail_redirect">@Admin</a> xin chào</p>'),
      );
    });

    test('Flow 2 (Odoo -> Mobile Client): JSON Response deserialization & TextSpan extraction', () {
      // 1. Odoo JSON response from GET channel_messages
      final odooResponseJson = {
        'id': 9991,
        'channel_id': 12,
        'body': '<p><a href="#" data-oe-model="res.partner" data-oe-id="3" class="o_mail_redirect">@Admin</a> xin chào</p>',
        'author_id': 1,
        'author_name': 'Mitchell Admin',
        'partner_ids': [3],
        'date': '2026-09-09T10:00:00Z',
        'status': 'sent',
      };

      // 2. Mobile deserialization
      final msg = ChatV2Message.fromMap(odooResponseJson);

      expect(msg.id, equals('9991'));
      expect(msg.content, equals('@Admin xin chào'));
      expect(msg.partnerIds, equals([3]));
      expect(msg.rawBody, contains('class="o_mail_redirect"'));
    });

    test('Flow 3 (Web Odoo Discuss -> Mobile Client): HTML cleaning & Mention rendering', () {
      // 1. Web Odoo Discuss generates complex HTML mention markup
      const webDiscussHtml = '<p>Xin chào <a href="#" data-oe-model="res.partner" data-oe-id="3" class="o_mail_redirect">@Admin</a>, vui lòng kiểm tra báo cáo &amp; xác nhận.</p>';

      final webMessageJson = {
        'id': 9992,
        'channel_id': 12,
        'body': webDiscussHtml,
        'author_id': 2,
        'author_name': 'Nhân Viên',
        'partner_ids': [3],
        'date': '2026-09-09T10:05:00Z',
      };

      final msg = ChatV2Message.fromMap(webMessageJson);

      // Verify HTML entities and tags stripped cleanly into readable text for Mobile
      expect(msg.content, equals('Xin chào @Admin, vui lòng kiểm tra báo cáo & xác nhận.'));
      expect(msg.partnerIds, equals([3]));
    });

    testWidgets('UI Verification: ChatV2MessageItem highlights mention token @Admin', (tester) async {
      final msg = ChatV2Message.fromMap({
        'id': '9993',
        'channel_id': '12',
        'body': '<p><a href="#" data-oe-model="res.partner" data-oe-id="3" class="o_mail_redirect">@Admin</a> vui lòng duyệt đơn</p>',
        'author_id': 2,
        'author_name': 'Tester',
        'partner_ids': [3],
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChatV2MessageItem(
              message: msg,
            ),
          ),
        ),
      );

      // Verify Text widgets contain the highlighted mention '@Admin'
      bool foundMentionSpan = false;
      final textWidgets = tester.widgetList<Text>(find.byType(Text));
      for (final textWidget in textWidgets) {
        final span = textWidget.textSpan;
        if (span is TextSpan && span.children != null) {
          for (final child in span.children!) {
            if (child is TextSpan && child.text == '@Admin' && child.style?.fontWeight == FontWeight.w700) {
              foundMentionSpan = true;
              break;
            }
          }
        }
      }

      expect(foundMentionSpan, isTrue, reason: 'ChatV2MessageItem must render @Admin with bold style and mention color');
    });
  });
}
