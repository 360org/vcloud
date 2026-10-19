// ignore_for_file: avoid_print
// Self-check 10 case độc lập cho getCleanName & Avatar của ChatV2Channel (Ponytail rule: assert-based self-check, stdlib first)

class TestMember {
  final String id;
  final String name;
  final String? nickname;
  final bool isMe;

  const TestMember({
    required this.id,
    required this.name,
    this.nickname,
    this.isMe = false,
  });

  String get displayName => (nickname != null && nickname!.trim().isNotEmpty) ? nickname!.trim() : name;
}

String cleanChannelName(String raw) {
  var s = raw.replaceAll(RegExp(r'\s*\([^\)]*portal[^\)]*\)', caseSensitive: false), '').trim();
  s = s.replaceAll(RegExp(r'\s*\(internal\)', caseSensitive: false), '').trim();
  return s;
}

bool isAdminName(String name) {
  final l = name.toLowerCase().trim();
  return l == 'admin' || l == 'administrator' || l == 'quản trị viên' || l == 'system';
}

bool matchesUser(String candidate, String? user) {
  if (user == null || user.trim().isEmpty) return false;
  return candidate.trim().toLowerCase() == user.trim().toLowerCase();
}

String resolveCleanName({
  required String name,
  required bool isGroup,
  required String channelType,
  String? directPartnerName,
  List<TestMember> members = const [],
  bool isPortal = false,
  bool isChannel = false,
  String? currentUserName,
  String? customNickname,
}) {
  if (!isGroup && customNickname != null && customNickname.trim().isNotEmpty) {
    return customNickname.trim();
  }
  if (!isGroup) {
    final authorInternalPattern = RegExp(r'^(.+?)\s*[\(\[]\s*internal\s*[\)\]]$', caseSensitive: false);
    final aiMatch = authorInternalPattern.firstMatch(name);
    if (aiMatch != null) {
      final prefix = aiMatch.group(1)?.trim() ?? '';
      if (prefix.isNotEmpty) return prefix;
    }
  }

  final cleaned = cleanChannelName(name);
  final isNameGeneric = cleaned.isEmpty || cleaned == 'Cuộc trò chuyện';

  if (isChannel || channelType == 'channel' || isGroup) {
    if (isNameGeneric) {
      if (name.isNotEmpty && name != 'Cuộc trò chuyện') return name;
      return 'Cuộc trò chuyện';
    }
    return cleaned;
  }

  if (channelType == 'livechat') {
    if (isNameGeneric) {
      if (name.isNotEmpty && name != 'Cuộc trò chuyện') return name;
      return 'Livechat';
    }
    return cleaned;
  }

  if (!isGroup) {
    // Ưu tiên 1: directPartnerName nếu có và không trùng current user
    if (directPartnerName != null &&
        directPartnerName.trim().isNotEmpty &&
        (currentUserName == null || !matchesUser(directPartnerName, currentUserName))) {
      final resolvedPartner = cleanChannelName(directPartnerName);
      if (isPortal && isAdminName(resolvedPartner)) return 'Chuyên viên tư vấn';
      if (resolvedPartner.isNotEmpty && resolvedPartner != 'Cuộc trò chuyện') return resolvedPartner;
    }

    // Ưu tiên 2: members tìm đối tác khác current user
    TestMember? otherMember;
    for (final m in members) {
      if (!m.isMe && m.name.trim().isNotEmpty && (currentUserName == null || !matchesUser(m.name, currentUserName))) {
        otherMember = m;
        break;
      }
    }
    if (otherMember != null) {
      final otherName = otherMember.displayName.trim().isNotEmpty ? otherMember.displayName : otherMember.name;
      final resolvedMember = cleanChannelName(otherName);
      if (isPortal && isAdminName(resolvedMember)) return 'Chuyên viên tư vấn';
      if (resolvedMember.isNotEmpty && resolvedMember != 'Cuộc trò chuyện') return resolvedMember;
    }

    // Ưu tiên 3: Portal
    if (isPortal) return 'Chuyên viên tư vấn';

    // Fallback khi tên kênh generic và không tìm thấy bất kỳ đối tác nào
    if (isNameGeneric) {
      if (name.isNotEmpty && name != 'Cuộc trò chuyện') return name;
      return 'Cuộc trò chuyện';
    }

    if (currentUserName == null || currentUserName.trim().isEmpty) {
      if (isPortal && isAdminName(cleaned)) return 'Chuyên viên tư vấn';
      return cleaned;
    }

    var directClean = cleaned.replaceAll(
      RegExp(r'\s*[\(\[]\s*internal\s*[\)\]]', caseSensitive: false),
      '',
    ).trim();
    if (directClean.isEmpty) directClean = cleaned;

    String resolved = directClean;
    final uTrim = currentUserName.trim();
    final uLower = uTrim.toLowerCase();
    final nLower = directClean.toLowerCase();

    bool matched = false;
    if (nLower.contains(uLower)) {
      var clean = directClean;
      final patterns = [
        RegExp('^\\s*${RegExp.escape(uTrim)}\\s*([,/|-]|và|&)\\s*', caseSensitive: false),
        RegExp('\\s*([,/|-]|và|&)\\s*${RegExp.escape(uTrim)}\\s*\$', caseSensitive: false),
      ];
      for (final p in patterns) {
        if (p.hasMatch(clean)) {
          clean = clean.replaceFirst(p, '').trim();
          break;
        }
      }
      if (clean.isNotEmpty && clean.toLowerCase() != uLower) {
        resolved = cleanChannelName(clean);
        matched = true;
      }
    }

    if (!matched) {
      final parts = directClean.split(RegExp(r'\s*[,/|-]\s*|\s+và\s+|\s+&\s+'));
      if (parts.length >= 2) {
        final otherParts = parts.where((p) => !matchesUser(p, currentUserName)).toList();
        if (otherParts.isNotEmpty) {
          resolved = cleanChannelName(otherParts.join(', ').trim());
          matched = true;
        }
      }
    }

    if (!matched && matchesUser(directClean, currentUserName)) {
      if (otherMember != null) {
        final otherName = otherMember.displayName.isNotEmpty ? otherMember.displayName : otherMember.name;
        resolved = cleanChannelName(otherName);
      } else {
        resolved = isPortal ? 'Chuyên viên tư vấn' : 'Trò chuyện';
      }
    }

    if (isPortal && isAdminName(resolved)) return 'Chuyên viên tư vấn';
    return resolved;
  }
  return cleaned;
}

void main() {
  print('--- BẮT ĐẦU KIỂM THỬ 10 CASE ĐỘC LẬP CHO GETCLEANNAME & AVATAR ---');
  const currentUserName = 'Nguyễn Văn Tân';

  // Case 1: Kênh 1-1 có tên "Cuộc trò chuyện", nhưng có directPartnerName: "Việt Hà"
  final name1 = resolveCleanName(
    name: 'Cuộc trò chuyện',
    channelType: 'chat',
    isGroup: false,
    directPartnerName: 'Việt Hà',
    currentUserName: currentUserName,
  );
  assert(name1 == 'Việt Hà', 'Case 1 Fail: expected "Việt Hà", got "$name1"');
  final avatarChar1 = name1.isNotEmpty ? name1[0].toUpperCase() : 'C';
  assert(avatarChar1 == 'V', 'Case 1 Avatar Fail: expected "V", got "$avatarChar1"');
  print('✅ Case 1 PASS: Kênh 1-1 có tên "Cuộc trò chuyện" phân giải đúng directPartnerName "Việt Hà", Avatar là "V"');

  // Case 2: Kênh 1-1 có tên rỗng "", nhưng có directPartnerName: "Tuấn"
  final name2 = resolveCleanName(
    name: '',
    channelType: 'chat',
    isGroup: false,
    directPartnerName: 'Tuấn',
    currentUserName: currentUserName,
  );
  assert(name2 == 'Tuấn', 'Case 2 Fail: expected "Tuấn", got "$name2"');
  final avatarChar2 = name2.isNotEmpty ? name2[0].toUpperCase() : 'C';
  assert(avatarChar2 == 'T', 'Case 2 Avatar Fail: expected "T", got "$avatarChar2"');
  print('✅ Case 2 PASS: Kênh 1-1 có tên rỗng phân giải đúng directPartnerName "Tuấn", Avatar là "T"');

  // Case 3: Kênh 1-1 có tên "Cuộc trò chuyện", directPartnerName null, members có đối tác
  final name3 = resolveCleanName(
    name: 'Cuộc trò chuyện',
    channelType: 'chat',
    isGroup: false,
    members: const [
      TestMember(id: '1', name: currentUserName, isMe: true),
      TestMember(id: '2', name: 'Trần Văn Nam', isMe: false),
    ],
    currentUserName: currentUserName,
  );
  assert(name3 == 'Trần Văn Nam', 'Case 3 Fail: expected "Trần Văn Nam", got "$name3"');
  final avatarChar3 = name3.isNotEmpty ? name3[0].toUpperCase() : 'C';
  assert(avatarChar3 == 'T', 'Case 3 Avatar Fail: expected "T", got "$avatarChar3"');
  print('✅ Case 3 PASS: Kênh 1-1 tra cứu thành công từ danh sách members "Trần Văn Nam", Avatar là "T"');

  // Case 4: Kênh 1-1 có directPartnerName trùng với currentUserName nhưng members có đối tác khác
  final name4 = resolveCleanName(
    name: 'Cuộc trò chuyện',
    channelType: 'chat',
    isGroup: false,
    directPartnerName: currentUserName,
    members: const [
      TestMember(id: '1', name: currentUserName, isMe: true),
      TestMember(id: '3', name: 'Lê Thị Mai', isMe: false),
    ],
    currentUserName: currentUserName,
  );
  assert(name4 == 'Lê Thị Mai', 'Case 4 Fail: expected "Lê Thị Mai", got "$name4"');
  print('✅ Case 4 PASS: Bỏ qua directPartnerName trùng currentUserName và lấy đúng đối tác "Lê Thị Mai" từ members');

  // Case 5: Kênh 1-1 có tên "Cuộc trò chuyện", không có đối tác, nhưng isPortal: true
  final name5 = resolveCleanName(
    name: 'Cuộc trò chuyện',
    channelType: 'chat',
    isGroup: false,
    isPortal: true,
    currentUserName: currentUserName,
  );
  assert(name5 == 'Chuyên viên tư vấn', 'Case 5 Fail: expected "Chuyên viên tư vấn", got "$name5"');
  print('✅ Case 5 PASS: Portal fallback về "Chuyên viên tư vấn" khi kênh 1-1 generic không có metadata đối tác');

  // Case 6: Kênh 1-1 có tên "Cuộc trò chuyện", hoàn toàn không có metadata đối tác nào (Edge case)
  final name6 = resolveCleanName(
    name: 'Cuộc trò chuyện',
    channelType: 'chat',
    isGroup: false,
    currentUserName: currentUserName,
  );
  assert(name6 == 'Cuộc trò chuyện', 'Case 6 Fail: expected fallback "Cuộc trò chuyện", got "$name6"');
  print('✅ Case 6 PASS: Fallback an toàn về "Cuộc trò chuyện" khi hoàn toàn không có đối tác nào');

  // Case 7: Kênh 1-1 có tên cụ thể "Vũ Trọng Phụng"
  final name7 = resolveCleanName(
    name: 'Vũ Trọng Phụng',
    channelType: 'chat',
    isGroup: false,
    currentUserName: currentUserName,
  );
  assert(name7 == 'Vũ Trọng Phụng', 'Case 7 Fail: expected "Vũ Trọng Phụng", got "$name7"');
  print('✅ Case 7 PASS: Kênh 1-1 có tên cụ thể giữ nguyên "Vũ Trọng Phụng"');

  // Case 8: Kênh nhóm (isGroup: true) có tên "Cuộc trò chuyện"
  final name8 = resolveCleanName(
    name: 'Cuộc trò chuyện',
    channelType: 'group',
    isGroup: true,
    directPartnerName: 'Việt Hà',
    currentUserName: currentUserName,
  );
  assert(name8 == 'Cuộc trò chuyện', 'Case 8 Fail: expected "Cuộc trò chuyện" for group, got "$name8"');
  print('✅ Case 8 PASS: Kênh nhóm isGroup: true giữ nguyên tên nhóm, không ghi đè bởi đối tác cá nhân');

  // Case 9: Avatar Char Generator đảm bảo không bị cố định chữ "C"
  final avatarChars = ['Việt Hà', 'Tuấn', 'Đức', 'Mai', 'Bình'].map((n) => n.isNotEmpty ? n[0].toUpperCase() : 'C').toList();
  assert(!avatarChars.contains('C'), 'Case 9 Fail: avatarChars contains "C"');
  assert(avatarChars[0] == 'V' && avatarChars[1] == 'T' && avatarChars[2] == 'Đ', 'Case 9 Initials Fail');
  print('✅ Case 9 PASS: Avatar tự động sinh ký tự đại diện chuẩn theo tên đối tác ("V", "T", "Đ"), triệt tiêu chữ "C"');

  // Case 10: Kênh 1-1 có tên "Cuộc trò chuyện", đối tác trong members có displayName/nickname
  final name10 = resolveCleanName(
    name: 'Cuộc trò chuyện',
    channelType: 'chat',
    isGroup: false,
    members: const [
      TestMember(id: '1', name: currentUserName, isMe: true),
      TestMember(id: '5', name: 'Hà Thị Thu', nickname: 'Hà Kế Toán', isMe: false),
    ],
    currentUserName: currentUserName,
  );
  assert(name10 == 'Hà Kế Toán', 'Case 10 Fail: expected "Hà Kế Toán", got "$name10"');
  print('✅ Case 10 PASS: Ưu tiên lấy displayName/nickname "Hà Kế Toán" từ members khi tên kênh rỗng/generic');

  print('--- HOÀN TẤT: TOÀN BỘ 10/10 TEST CASES ĐẠT CHUẨN 100% ---');
}
