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
  });
}
