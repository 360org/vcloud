import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/features/chat_v2/data/models/chat_v2_channel.dart';

String _removeVietnameseDiacritics(String str) {
  const withDiacritics =
      'àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ';
  const withoutDiacritics =
      'aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd';
  var result = str;
  for (int i = 0; i < withDiacritics.length; i++) {
    result = result.replaceAll(withDiacritics[i], withoutDiacritics[i]);
  }
  return result;
}

List<ChatV2Member> filterMentionMembers({
  required List<ChatV2Member> members,
  required String query,
  bool isGroup = true,
}) {
  if (!isGroup) return const [];
  final qLower = query.toLowerCase().trim();
  final qNormalized = _removeVietnameseDiacritics(qLower);

  final scored = <({ChatV2Member member, int score})>[];
  for (final m in members) {
    if (m.isMe) continue;
    if (qLower.isEmpty) {
      scored.add((member: m, score: 0));
      continue;
    }

    final nLower = m.name.toLowerCase();
    final nNormalized = _removeVietnameseDiacritics(nLower);

    final emailRaw = m.email ?? '';
    final emailUser = emailRaw.contains('@')
        ? emailRaw.split('@').first.toLowerCase()
        : emailRaw.toLowerCase();

    int score = 0;
    if (nLower.startsWith(qLower) || nNormalized.startsWith(qNormalized)) {
      score = 100;
    } else {
      final wordsLower = nLower.split(RegExp(r'\s+'));
      final wordsNormalized = nNormalized.split(RegExp(r'\s+'));
      final hasWordStart = wordsLower.any((w) => w.startsWith(qLower)) ||
          wordsNormalized.any((w) => w.startsWith(qNormalized));
      if (hasWordStart) {
        score = 80;
      } else if (nLower.contains(qLower) || nNormalized.contains(qNormalized)) {
        score = 60;
      } else if (emailUser.isNotEmpty && emailUser.startsWith(qLower)) {
        score = 40;
      } else if (emailUser.isNotEmpty && emailUser.contains(qLower)) {
        score = 20;
      } else if (qLower.contains('@') && emailRaw.toLowerCase().contains(qLower)) {
        score = 10;
      }
    }

    if (score > 0) {
      scored.add((member: m, score: score));
    }
  }

  if (qLower.isNotEmpty) {
    scored.sort((a, b) => b.score.compareTo(a.score));
  }

  return scored.map((e) => e.member).toList();
}

bool checkMentionBadge({
  required bool isGroup,
  required bool isMine,
  required bool hasUnread,
  required String? currentUserName,
  required String messageText,
}) {
  if (!isGroup || isMine || !hasUnread) return false;
  if (currentUserName == null || currentUserName.isEmpty) return false;
  final lower = messageText.toLowerCase();
  return lower.contains('@${currentUserName.toLowerCase()}') ||
      lower.contains('@all') ||
      lower.contains('@everyone');
}

void main() {
  group('Kiểm thử logic lọc & kích hoạt @mention Chat V2', () {
    const testMembers = [
      ChatV2Member(
        id: '101',
        name: 'Nguyễn Văn A',
        email: 'vana@360.org.vn',
        isMe: false,
      ),
      ChatV2Member(
        id: '102',
        name: 'Trần Thị B',
        email: 'thib@360.org.vn',
        isMe: false,
      ),
      ChatV2Member(
        id: '103',
        name: 'Chính Tôi',
        email: 'me@360.org.vn',
        isMe: true,
      ),
    ];

    test(
      '1. Gõ @ không kèm từ khóa trong Nhóm: trả về tất cả thành viên khác, loại trừ isMe',
      () {
        final matches = filterMentionMembers(
          members: testMembers,
          query: '',
          isGroup: true,
        );
        expect(matches.length, 2);
        expect(
          matches.map((m) => m.name),
          containsAll(['Nguyễn Văn A', 'Trần Thị B']),
        );
        expect(matches.any((m) => m.isMe), isFalse);
      },
    );

    test('2. Chat 1-1: gõ @ không trả về bất kỳ gợi ý mention nào', () {
      final matchesDirect = filterMentionMembers(
        members: testMembers,
        query: '',
        isGroup: false,
      );
      expect(matchesDirect, isEmpty);

      final matchesQueryDirect = filterMentionMembers(
        members: testMembers,
        query: 'van',
        isGroup: false,
      );
      expect(matchesQueryDirect, isEmpty);
    });

    test('3. Gõ @ kèm từ khóa không dấu tìm ra tên có dấu', () {
      final matchesVan = filterMentionMembers(
        members: testMembers,
        query: 'van',
        isGroup: true,
      );
      expect(matchesVan.length, 1);
      expect(matchesVan.first.name, 'Nguyễn Văn A');

      final matchesThi = filterMentionMembers(
        members: testMembers,
        query: 'thi',
        isGroup: true,
      );
      expect(matchesThi.length, 1);
      expect(matchesThi.first.name, 'Trần Thị B');
    });

    test('4. Gõ @ kèm email tìm chính xác thành viên', () {
      final matchesEmail = filterMentionMembers(
        members: testMembers,
        query: 'vana@360',
        isGroup: true,
      );
      expect(matchesEmail.length, 1);
      expect(matchesEmail.first.name, 'Nguyễn Văn A');
    });

    test('5. Kiểm tra badge nhắc tên trong danh sách hội thoại', () {
      const currentUserName = 'Nguyễn Văn A';
      const msg1 = 'Chào @Nguyễn Văn A, bạn kiểm tra giúp mình nhé';

      // Trong nhóm: có badge [@ Nhắc đến bạn]
      expect(
        checkMentionBadge(
          isGroup: true,
          isMine: false,
          hasUnread: true,
          currentUserName: currentUserName,
          messageText: msg1,
        ),
        isTrue,
      );

      // Trong chat 1-1: tuyệt đối KHÔNG có badge nhắc tên
      expect(
        checkMentionBadge(
          isGroup: false,
          isMine: false,
          hasUnread: true,
          currentUserName: currentUserName,
          messageText: msg1,
        ),
        isFalse,
      );

      // Tin do chính mình gửi: không có badge
      expect(
        checkMentionBadge(
          isGroup: true,
          isMine: true,
          hasUnread: true,
          currentUserName: currentUserName,
          messageText: msg1,
        ),
        isFalse,
      );

      // Tag @all / @everyone trong nhóm
      const msg2 = 'Chào cả nhà @all';
      expect(
        checkMentionBadge(
          isGroup: true,
          isMine: false,
          hasUnread: true,
          currentUserName: currentUserName,
          messageText: msg2,
        ),
        isTrue,
      );

      // Nhắc tên người khác
      const msg3 = 'Chào @Trần Thị B nhé';
      expect(
        checkMentionBadge(
          isGroup: true,
          isMine: false,
          hasUnread: true,
          currentUserName: currentUserName,
          messageText: msg3,
        ),
        isFalse,
      );
    });

    test('6. Gõ @t: KHÔNG match domain email vuahethong.net (Nguyễn Đào Quốc Anh) và match đúng người có tên chứa chữ T', () {
      const complexMembers = [
        ChatV2Member(
          id: '201',
          name: 'Nguyễn Đào Quốc Anh',
          email: 'anhndq@vuahethong.net',
          isMe: false,
        ),
        ChatV2Member(
          id: '202',
          name: 'Ma Nguyễn Nhật Tân',
          email: 'tanmnn@360.org.vn',
          isMe: false,
        ),
        ChatV2Member(
          id: '203',
          name: 'Trần Văn Tuấn',
          email: 'tuantv@vuahethong.net',
          isMe: false,
        ),
      ];

      final matchesT = filterMentionMembers(
        members: complexMembers,
        query: 't',
        isGroup: true,
      );

      // Nguyễn Đào Quốc Anh KHÔNG được xuất hiện vì tên và username email 'anhndq' không có chữ 't'
      expect(matchesT.any((m) => m.name == 'Nguyễn Đào Quốc Anh'), isFalse);

      // Ma Nguyễn Nhật Tân và Trần Văn Tuấn phải xuất hiện
      expect(matchesT.map((m) => m.name), containsAll(['Ma Nguyễn Nhật Tân', 'Trần Văn Tuấn']));
      expect(matchesT.first.name, 'Trần Văn Tuấn'); // Họ tên bắt đầu bằng chữ T (100 điểm) ưu tiên hơn từ trong tên (80 điểm)
    });
  });
}
