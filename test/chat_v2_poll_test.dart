import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/features/chat_v2/domain/models/chat_v2_poll_model.dart';

void main() {
  group('ChatV2Poll Model Tests', () {
    test('1. Creates and parses message body with POLL_DATA correctly', () {
      final body = ChatV2Poll.buildMessageBody(
        question: 'Trưa nay ăn gì các bạn?',
        options: ['Cơm tấm', 'Bún bò', 'Phở bò'],
        allowMultiple: false,
        creatorId: 2,
        creatorName: 'Mitchell Admin',
      );

      expect(body.contains('<!-- POLL_DATA:'), isTrue);
      expect(body.contains('data-poll='), isTrue);

      final poll = ChatV2Poll.tryParseFromBody(body);
      expect(poll, isNotNull);
      expect(poll!.question, 'Trưa nay ăn gì các bạn?');
      expect(poll.options.length, 3);
      expect(poll.options[0].text, 'Cơm tấm');
      expect(poll.options[1].text, 'Bún bò');
      expect(poll.options[2].text, 'Phở bò');
      expect(poll.allowMultiple, isFalse);
      expect(poll.creatorId, 2);
      expect(poll.totalVotes, 0);
      expect(poll.hasUserVoted(2), isFalse);
    });

    test('2. Parses poll with existing votes and checks user vote status', () {
      final pollData = {
        'id': 'poll_123456',
        'question': 'Chọn địa điểm team building',
        'options': [
          {
            'id': 1,
            'text': 'Đà Lạt',
            'voters': [
              {'id': 2, 'name': 'Mitchell Admin'},
              {'id': 7, 'name': 'Marc Demo'},
            ],
            'voter_ids': [2, 7],
            'vote_count': 2,
          },
          {
            'id': 2,
            'text': 'Phú Quốc',
            'voters': [
              {'id': 10, 'name': 'Nguyễn Văn A'},
            ],
            'voter_ids': [10],
            'vote_count': 1,
          },
        ],
        'allow_multiple': true,
        'creator_id': 2,
        'creator_name': 'Mitchell Admin',
        'total_votes': 3,
        'total_voters': 3,
      };

      final jsonStr = json.encode(pollData);
      final body = '<!-- POLL_DATA:$jsonStr --><div>Poll</div>';

      final poll = ChatV2Poll.tryParseFromBody(body);
      expect(poll, isNotNull);
      expect(poll!.question, 'Chọn địa điểm team building');
      expect(poll.allowMultiple, isTrue);
      expect(poll.totalVotes, 3);

      // Check user 2 (Admin)
      expect(poll.hasUserVoted(2), isTrue);
      expect(poll.options[0].hasVoted(2), isTrue);
      expect(poll.options[1].hasVoted(2), isFalse);
      expect(poll.getUserVotedOptionIds(2), [1]);

      // Check user 99 (Not voted)
      expect(poll.hasUserVoted(99), isFalse);
      expect(poll.getUserVotedOptionIds(99), isEmpty);
    });

    test('3. Returns null on regular non-poll messages', () {
      const normalBody = '<p>Xin chào mọi người nhé!</p>';
      final poll = ChatV2Poll.tryParseFromBody(normalBody);
      expect(poll, isNull);
    });

    test('4. Parses poll from o_poll_json HTML tag', () {
      const bodyWithTag = '<div class="o_poll_card"><div class="o_poll_json" style="display:none">{"id":"poll_123","question":"Họp lúc mấy giờ?","options":[{"id":1,"text":"9h00","voters":[],"vote_count":0},{"id":2,"text":"14h00","voters":[],"vote_count":0}],"allow_multiple":false,"creator_id":2,"creator_name":"Admin"}</div><p>📊 Họp lúc mấy giờ?</p></div>';
      final poll = ChatV2Poll.tryParseFromBody(bodyWithTag);
      expect(poll, isNotNull);
      expect(poll!.question, 'Họp lúc mấy giờ?');
      expect(poll.options.length, 2);
    });

    test('5. Parses poll from raw stripped JSON string', () {
      const strippedBody = '{"id":"poll_1787047943793","question":"check đơn hàng","options":[{"id":1,"text":"hang 1","voters":[],"vote_count":0},{"id":2,"text":"hang 2","voters":[],"vote_count":0}],"allow_multiple":false,"creator_id":2,"creator_name":"Admin","total_votes":0,"total_voters":0,"is_closed":false} 📊 check đơn hàng';
      final poll = ChatV2Poll.tryParseFromBody(strippedBody);
      expect(poll, isNotNull);
      expect(poll!.question, 'check đơn hàng');
      expect(poll.options.length, 2);
    });

    test('6. Parses poll from Odoo sanitized HTML fallback structure', () {
      const sanitizedHtml = '<p>📊 <b>hello</b></p><ul><li><b>1</b> (0 phiếu)</li><li><b>2</b> (0 phiếu)</li></ul><p><i>Tổng cộng: 0 lượt bình chọn</i></p>';
      final poll = ChatV2Poll.tryParseFromBody(sanitizedHtml);
      expect(poll, isNotNull);
      expect(poll!.question, 'hello');
      expect(poll.options.length, 2);
      expect(poll.options[0].text, '1');
      expect(poll.options[1].text, '2');
      expect(poll.totalVotes, 0);
    });

    test('7. Parses poll from plain text fallback format', () {
      const plainText = '📊 hello\n1 (0 phiếu)\n2 (0 phiếu)\nTổng cộng: 0 lượt bình chọn';
      final poll = ChatV2Poll.tryParseFromBody(plainText);
      expect(poll, isNotNull);
      expect(poll!.question, 'hello');
      expect(poll.options.length, 2);
      expect(poll.options[0].text, '1');
      expect(poll.options[1].text, '2');
      expect(poll.totalVotes, 0);
    });

    test('8. Parses poll from dynamic runtime Map<dynamic, dynamic> without dropping options', () {
      final dynamicMap = <dynamic, dynamic>{
        'id': 'poll_dyn_999',
        'question': 'Kiểm tra Map động',
        'options': <dynamic>[
          <dynamic, dynamic>{
            'id': 1,
            'text': 'Phương án A',
            'voters': <dynamic>[
              <dynamic, dynamic>{'id': 5, 'name': 'User 5'},
            ],
            'vote_count': 1,
          },
          <dynamic, dynamic>{
            'id': 2,
            'text': 'Phương án B',
            'voters': <dynamic>[],
            'vote_count': 0,
          },
        ],
        'allow_multiple': false,
        'creator_id': 1,
        'creator_name': 'Admin',
        'total_votes': 1,
        'total_voters': 1,
      };

      final poll = ChatV2Poll.fromJson(Map<String, dynamic>.from(dynamicMap));
      expect(poll.id, 'poll_dyn_999');
      expect(poll.options.length, 2);
      expect(poll.options[0].text, 'Phương án A');
      expect(poll.options[0].voterIds, [5]);
      expect(poll.options[0].voterNames, ['User 5']);
      expect(poll.options[0].hasVoted(5), isTrue);
      expect(poll.options[1].text, 'Phương án B');
    });

    test('9. toMessageHtml preserves full HTML poll card and allows lossless roundtrip parsing', () {
      const poll = ChatV2Poll(
        id: 'poll_roundtrip',
        question: 'Dự án ra mắt ngày nào?',
        options: [
          ChatV2PollOption(id: 1, text: 'Thứ 2', voterIds: [2], voterNames: ['Admin'], voteCount: 1),
          ChatV2PollOption(id: 2, text: 'Thứ 6', voterIds: [], voterNames: [], voteCount: 0),
        ],
        allowMultiple: false,
        creatorId: 2,
        creatorName: 'Admin',
        totalVotes: 1,
        totalVoters: 1,
      );

      final html = poll.toMessageHtml();
      expect(html.contains('class="o_poll_card"'), isTrue);
      expect(html.contains('class="o_poll_json"'), isTrue);
      expect(html.contains('<!-- POLL_DATA:'), isTrue);
      expect(html.contains('Dự án ra mắt ngày nào?'), isTrue);

      final parsed = ChatV2Poll.tryParseFromBody(html);
      expect(parsed, isNotNull);
      expect(parsed!.id, 'poll_roundtrip');
      expect(parsed.question, 'Dự án ra mắt ngày nào?');
      expect(parsed.options.length, 2);
      expect(parsed.options[0].hasVoted(2), isTrue);
      expect(parsed.totalVotes, 1);
    });

    test('10. Unescape HTML entities correctly recovers encoded poll payloads', () {
      const encodedBody = '&lt;div class=&quot;o_poll_card&quot; data-poll=&quot;{&amp;quot;id&amp;quot;:&amp;quot;p1&amp;quot;,&amp;quot;question&amp;quot;:&amp;quot;Trà sữa hay Cà phê?&amp;quot;,&amp;quot;options&amp;quot;:[{&amp;quot;id&amp;quot;:1,&amp;quot;text&amp;quot;:&amp;quot;Trà sữa&amp;quot;,&amp;quot;vote_count&amp;quot;:0},{&amp;quot;id&amp;quot;:2,&amp;quot;text&amp;quot;:&amp;quot;Cà phê&amp;quot;,&amp;quot;vote_count&amp;quot;:0}]}&quot;&gt;&lt;!-- POLL_DATA:{&quot;id&quot;:&quot;p1&quot;,&quot;question&quot;:&quot;Trà sữa hay Cà phê?&quot;,&quot;options&quot;:[{&quot;id&quot;:1,&quot;text&quot;:&quot;Trà sữa&quot;,&quot;vote_count&quot;:0},{&quot;id&quot;:2,&quot;text&quot;:&quot;Cà phê&quot;,&quot;vote_count&quot;:0}]} --&gt;&lt;/div&gt;';
      final poll = ChatV2Poll.tryParseFromBody(encodedBody);
      expect(poll, isNotNull);
      expect(poll!.question, 'Trà sữa hay Cà phê?');
      expect(poll.options.length, 2);
      expect(poll.options[0].text, 'Trà sữa');
      expect(poll.options[1].text, 'Cà phê');
    });
  });
}
