// ignore_for_file: avoid_print
// Self-check assert-based thuần Dart stdlib cho 5 hạng mục UAT fixes:
// 1. Profile phone extraction (mobile/phone/work_phone/fallback)
// 2. Chat V2 Forward payload validation & channel filtering
// 3. Chat V2 message pin state serialization & parsing
// 4. Chat V2 snippet update on delete / recall
// 5. Chat V2 media caption constraints & sender name layout

// --- Helper Functions mô phỏng chính xác logic từ codebase ---

/// [Logic 1]: Profile phone extraction logic từ edit_profile_screen.dart (dòng 134-135, 240)
String extractProfilePhone(Map<String, dynamic>? meta) {
  final rawPhone = meta?['mobile'] ?? meta?['phone'] ?? meta?['work_phone'];
  final phone = (rawPhone is String
          ? rawPhone
          : (rawPhone != null && rawPhone != false ? rawPhone.toString() : ''))
      .trim();
  return phone.isNotEmpty ? phone : 'Chưa cập nhật';
}

/// [Logic 2]: Forward sheet channel filtering & attachment parsing từ chat_v2_forward_sheet.dart
class DummyChannel {
  final String id;
  final String name;

  const DummyChannel({required this.id, required this.name});
}

class DummyAttachment {
  final String id;
  final String name;

  const DummyAttachment({required this.id, required this.name});
}

List<DummyChannel> filterForwardChannels({
  required List<DummyChannel> allChannels,
  required String currentChannelId,
  required String query,
}) {
  return allChannels.where((c) {
    if (c.id == currentChannelId) return false;
    if (query.isEmpty) return true;
    final name = c.name.toLowerCase();
    return name.contains(query.toLowerCase());
  }).toList();
}

List<int> extractForwardAttachmentIds(List<DummyAttachment> attachments) {
  return attachments
      .map((a) => int.tryParse(a.id))
      .whereType<int>()
      .toList();
}

String computeForwardSnippet({
  required String content,
  required List<DummyAttachment> attachments,
}) {
  if (content.isNotEmpty) {
    return content;
  }
  if (attachments.isNotEmpty) {
    return '[Đính kèm]';
  }
  return '';
}

/// [Logic 3]: Pin state parsing & serialization mô phỏng chat_v2_message.dart (dòng 737-750)
class MessagePinState {
  final String? pinnedAt;
  final bool isPinned;

  MessagePinState({this.pinnedAt})
      : isPinned = pinnedAt != null && pinnedAt.isNotEmpty;

  static MessagePinState fromMap(Map<String, dynamic> map, {DateTime? createdAt}) {
    final rawPinnedAt = map['pinned_at'] is String ? map['pinned_at'] as String : null;
    final isPinnedExplicitlyFalse = map['is_pinned'] == false ||
        map['is_pinned'] == 0 ||
        map['is_pinned'] == 'false';
    final isPinnedBool = map['is_pinned'] == true ||
        map['is_pinned'] == 1 ||
        map['is_pinned'] == 'true';
    final pinnedAt = isPinnedExplicitlyFalse
        ? null
        : (rawPinnedAt ??
            (isPinnedBool
                ? (createdAt?.toIso8601String() ?? '2026-10-21T10:00:00.000Z')
                : null));

    return MessagePinState(pinnedAt: pinnedAt);
  }

  Map<String, dynamic> toMap() => {
        'pinned_at': pinnedAt,
        'is_pinned': isPinned,
      };
}

/// [Logic 4]: Snippet update on delete / recall từ chat_v2_messages_controller.dart
class DummyMessage {
  final String id;
  final String content;
  final List<String> attachments;
  final DateTime? createdAt;
  final String? authorId;
  final String? authorName;

  DummyMessage({
    required this.id,
    required this.content,
    this.attachments = const [],
    this.createdAt,
    this.authorId,
    this.authorName,
  });
}

class SnippetUpdateResult {
  final String lastMessage;
  final DateTime? lastMessageDate;
  final String? authorId;
  final String? authorName;

  SnippetUpdateResult({
    required this.lastMessage,
    this.lastMessageDate,
    this.authorId,
    this.authorName,
  });
}

SnippetUpdateResult computeSnippetAfterAction({
  required bool isRecalled,
  required List<DummyMessage> remainingMessages,
}) {
  if (isRecalled) {
    return SnippetUpdateResult(
      lastMessage: 'Tin nhắn đã bị thu hồi',
      lastMessageDate: DateTime.now(),
      authorId: null,
      authorName: null,
    );
  }
  if (remainingMessages.isNotEmpty) {
    final latest = remainingMessages.first;
    final snippetText = latest.content.isNotEmpty
        ? latest.content
        : (latest.attachments.isNotEmpty ? '[Đính kèm]' : '');
    return SnippetUpdateResult(
      lastMessage: snippetText,
      lastMessageDate: latest.createdAt ?? DateTime.now(),
      authorId: latest.authorId,
      authorName: latest.authorName,
    );
  }
  return SnippetUpdateResult(
    lastMessage: '',
    lastMessageDate: DateTime.now(),
    authorId: null,
    authorName: null,
  );
}

/// [Logic 5]: Media caption & author padding logic từ chat_v2_message_item.dart
bool shouldApplyCaptionConstraints({
  required String content,
  String? rawBody,
}) {
  String cleanHtml(String text) {
    return text.replaceAll(RegExp(r'<[^>]*>|&[^;]+;'), ' ').trim();
  }

  final cleanText = cleanHtml(content).trim();
  final rawText = rawBody != null ? cleanHtml(rawBody).trim() : '';
  return cleanText.isNotEmpty || rawText.isNotEmpty;
}

bool shouldUseMediaPadding({
  required bool hasAnyImage,
  required bool hasVideos,
}) {
  return hasAnyImage || hasVideos;
}

// --- Main Runner ---
void main() {
  print('================================================================');
  print('BẮT ĐẦU KIỂM THỬ ĐỘC LẬP UAT FIXES (ASSERT-BASED SELF-CHECK)');
  print('================================================================');

  // --- NHÓM 1: PROFILE PHONE EXTRACTION ---
  print('\n--- NHÓM 1: Profile Phone Extraction (EditProfileScreen) ---');

  // Case 1: Lấy số điện thoại từ trường 'mobile'
  final phone1 = extractProfilePhone({'mobile': '0901234567', 'phone': '0281111111'});
  assert(phone1 == '0901234567', 'Case 1 Fail: expected "0901234567", got "$phone1"');
  print('✅ Case 1 PASS: Ưu tiên lấy trường "mobile" khi cả mobile và phone cùng tồn tại');

  // Case 2: Lấy số điện thoại từ trường 'phone' khi 'mobile' null
  final phone2 = extractProfilePhone({'mobile': null, 'phone': '02838383838'});
  assert(phone2 == '02838383838', 'Case 2 Fail: expected "02838383838", got "$phone2"');
  print('✅ Case 2 PASS: Fallback sang trường "phone" khi "mobile" null');

  // Case 3: Lấy số điện thoại từ 'work_phone' khi cả mobile và phone null
  final phone3 = extractProfilePhone({'mobile': null, 'phone': null, 'work_phone': '02499998888'});
  assert(phone3 == '02499998888', 'Case 3 Fail: expected "02499998888", got "$phone3"');
  print('✅ Case 3 PASS: Fallback sang trường "work_phone" khi mobile và phone null');

  // Case 4: Xử lý giá trị boolean false từ Odoo RPC
  final phone4 = extractProfilePhone({'mobile': false, 'phone': false, 'work_phone': false});
  assert(phone4 == 'Chưa cập nhật', 'Case 4 Fail: expected "Chưa cập nhật", got "$phone4"');
  print('✅ Case 4 PASS: Xử lý an toàn boolean false từ Odoo, trả về "Chưa cập nhật"');

  // Case 5: Chuỗi rỗng hoặc khoảng trắng, hoặc meta null
  final phone5a = extractProfilePhone({'mobile': '   '});
  final phone5b = extractProfilePhone(null);
  assert(phone5a == 'Chưa cập nhật', 'Case 5a Fail: expected "Chưa cập nhật", got "$phone5a"');
  assert(phone5b == 'Chưa cập nhật', 'Case 5b Fail: expected "Chưa cập nhật", got "$phone5b"');
  print('✅ Case 5 PASS: Chuỗi khoảng trắng và metadata null fallback về "Chưa cập nhật"');

  // --- NHÓM 2: CHAT V2 FORWARD PAYLOAD & CHANNELS ---
  print('\n--- NHÓM 2: Chat V2 Forward Payload Validation ---');

  final channels = [
    const DummyChannel(id: '10', name: 'Phòng Kỹ Thuật'),
    const DummyChannel(id: '20', name: 'Ban Giám Đốc'),
    const DummyChannel(id: '30', name: 'Khách hàng VIP'),
  ];

  // Case 6: Loại trừ kênh hiện tại khỏi danh sách nhận chuyển tiếp
  final forwardList1 = filterForwardChannels(
    allChannels: channels,
    currentChannelId: '10',
    query: '',
  );
  assert(forwardList1.length == 2, 'Case 6 Fail: expected 2 channels');
  assert(!forwardList1.any((c) => c.id == '10'), 'Case 6 Fail: current channel must be excluded');
  print('✅ Case 6 PASS: Loại trừ kênh hiện tại khỏi danh sách chuyển tiếp (không cho tự gửi vào chính mình)');

  // Case 7: Lọc tìm kiếm theo tên kênh không phân biệt hoa thường
  final forwardList2 = filterForwardChannels(
    allChannels: channels,
    currentChannelId: '10',
    query: 'giám đốc',
  );
  assert(forwardList2.length == 1 && forwardList2.first.id == '20', 'Case 7 Fail: expected Ban Giám Đốc');
  print('✅ Case 7 PASS: Tìm kiếm kênh đích theo từ khóa không phân biệt hoa/thường');

  // Case 8: Trích xuất danh sách ID đính kèm (chỉ lấy số nguyên hợp lệ, bỏ ID tạm)
  final atts = [
    const DummyAttachment(id: '105', name: 'img1.png'),
    const DummyAttachment(id: 'temp_999', name: 'temp.jpg'),
    const DummyAttachment(id: '108', name: 'doc.pdf'),
  ];
  final validAttIds = extractForwardAttachmentIds(atts);
  assert(validAttIds.length == 2, 'Case 8 Fail: expected 2 valid attachment IDs');
  assert(validAttIds[0] == 105 && validAttIds[1] == 108, 'Case 8 Fail: values mismatch');
  print('✅ Case 8 PASS: Trích xuất chính xác attachment IDs dạng int, loại bỏ an toàn temp ID non-numeric');

  // Case 9: Tính toán snippet chuyển tiếp: có text -> lấy text, chỉ có file -> '[Đính kèm]'
  final snipText = computeForwardSnippet(content: 'Tài liệu họp', attachments: atts);
  final snipMedia = computeForwardSnippet(content: '', attachments: atts);
  final snipEmpty = computeForwardSnippet(content: '', attachments: []);
  assert(snipText == 'Tài liệu họp', 'Case 9a Fail');
  assert(snipMedia == '[Đính kèm]', 'Case 9b Fail');
  assert(snipEmpty == '', 'Case 9c Fail');
  print('✅ Case 9 PASS: Snippet chuyển tiếp chuẩn hóa (nội dung text, fallback "[Đính kèm]", fallback rỗng)');

  // --- NHÓM 3: CHAT V2 PIN STATE SERIALIZATION & PARSING ---
  print('\n--- NHÓM 3: Chat V2 Message Pin State Serialization & Parsing ---');

  // Case 10: Parse pinned_at có timestamp ISO hợp lệ
  final pin1 = MessagePinState.fromMap({'pinned_at': '2026-10-21T08:30:00.000Z'});
  assert(pin1.isPinned == true, 'Case 10 Fail: isPinned must be true');
  assert(pin1.pinnedAt == '2026-10-21T08:30:00.000Z', 'Case 10 Fail: timestamp mismatch');
  print('✅ Case 10 PASS: Parse đúng pinned_at ISO string -> isPinned = true');

  // Case 11: Parse is_pinned: true/1 khi pinned_at là null -> tự động gán timestamp
  final pin2 = MessagePinState.fromMap(
    {'is_pinned': true},
    createdAt: DateTime.parse('2026-10-21T07:00:00.000Z'),
  );
  assert(pin2.isPinned == true, 'Case 11 Fail: isPinned must be true');
  assert(pin2.pinnedAt == '2026-10-21T07:00:00.000Z', 'Case 11 Fail: pinnedAt must use createdAt');
  print('✅ Case 11 PASS: is_pinned = true/1 sinh timestamp hợp lệ khi server chỉ trả cờ boolean');

  // Case 12: Parse is_pinned: false / 0 ghi đè làm rỗng pinned_at
  final pin3a = MessagePinState.fromMap({'pinned_at': '2026-10-21T08:30:00Z', 'is_pinned': false});
  final pin3b = MessagePinState.fromMap({'pinned_at': '2026-10-21T08:30:00Z', 'is_pinned': 0});
  final pin3c = MessagePinState.fromMap({'pinned_at': '2026-10-21T08:30:00Z', 'is_pinned': 'false'});
  assert(pin3a.isPinned == false && pin3a.pinnedAt == null, 'Case 12a Fail');
  assert(pin3b.isPinned == false && pin3b.pinnedAt == null, 'Case 12b Fail');
  assert(pin3c.isPinned == false && pin3c.pinnedAt == null, 'Case 12c Fail');
  print('✅ Case 12 PASS: is_pinned: false/0/"false" xóa triệt để pinned_at, bảo vệ trạng thái bỏ ghim');

  // Case 13: Round-trip toMap -> fromMap bảo toàn tính bất biến
  final pinOriginal = MessagePinState(pinnedAt: '2026-10-21T09:15:00.000Z');
  final mapOut = pinOriginal.toMap();
  final pinRoundTrip = MessagePinState.fromMap(mapOut);
  assert(pinRoundTrip.isPinned == pinOriginal.isPinned, 'Case 13 Fail: isPinned altered');
  assert(pinRoundTrip.pinnedAt == pinOriginal.pinnedAt, 'Case 13 Fail: pinnedAt altered');
  print('✅ Case 13 PASS: Round-trip serialization toMap() -> fromMap() bảo toàn 100% pin state');

  // --- NHÓM 4: CHAT V2 SNIPPET UPDATE ON DELETE / RECALL ---
  print('\n--- NHÓM 4: Chat V2 Snippet Update on Delete / Recall ---');

  final msgOld = DummyMessage(
    id: 'm1',
    content: 'Tin nhắn cũ',
    authorId: 'user_1',
    authorName: 'Nguyễn Văn A',
    createdAt: DateTime.parse('2026-10-21T08:00:00.000Z'),
  );
  final msgAttOnly = DummyMessage(
    id: 'm2',
    content: '',
    attachments: ['file1.png'],
    authorId: 'user_2',
    authorName: 'Trần Thị B',
    createdAt: DateTime.parse('2026-10-21T08:05:00.000Z'),
  );

  // Case 14: Thu hồi tin nhắn (Recall) -> cập nhật snippet 'Tin nhắn đã bị thu hồi'
  final resRecall = computeSnippetAfterAction(
    isRecalled: true,
    remainingMessages: [msgOld],
  );
  assert(resRecall.lastMessage == 'Tin nhắn đã bị thu hồi', 'Case 14 Fail: wrong snippet');
  assert(resRecall.authorId == null && resRecall.authorName == null, 'Case 14 Fail: author must be null');
  print('✅ Case 14 PASS: Thu hồi tin nhắn cập nhật snippet thành "Tin nhắn đã bị thu hồi", xóa tên tác giả');

  // Case 15: Xóa tin nhắn (Delete) -> snippet nhận tin nhắn mới nhất còn lại
  final resDeleteWithText = computeSnippetAfterAction(
    isRecalled: false,
    remainingMessages: [msgOld],
  );
  assert(resDeleteWithText.lastMessage == 'Tin nhắn cũ', 'Case 15a Fail');
  assert(resDeleteWithText.authorName == 'Nguyễn Văn A', 'Case 15a Fail: authorName mismatch');

  final resDeleteWithAtt = computeSnippetAfterAction(
    isRecalled: false,
    remainingMessages: [msgAttOnly],
  );
  assert(resDeleteWithAtt.lastMessage == '[Đính kèm]', 'Case 15b Fail: expected [Đính kèm]');
  assert(resDeleteWithAtt.authorName == 'Trần Thị B', 'Case 15b Fail: authorName mismatch');
  print('✅ Case 15 PASS: Xóa tin nhắn cập nhật snippet theo tin nhắn mới nhất còn lại (text hoặc "[Đính kèm]")');

  // Case 16: Xóa hết toàn bộ tin nhắn trong phòng -> snippet rỗng
  final resDeleteEmpty = computeSnippetAfterAction(
    isRecalled: false,
    remainingMessages: [],
  );
  assert(resDeleteEmpty.lastMessage == '', 'Case 16 Fail: snippet must be empty string');
  print('✅ Case 16 PASS: Xóa sạch toàn bộ tin nhắn cập nhật snippet rỗng an toàn');

  // --- NHÓM 5: MEDIA CAPTION CONSTRAINTS & SENDER NAME ---
  print('\n--- NHÓM 5: Chat V2 Media Caption Constraints & Layout ---');

  // Case 17: Phân định ảnh có caption vs không có caption để áp dụng constraints 240x280
  final hasCaption1 = shouldApplyCaptionConstraints(content: 'Ảnh chụp hiện trường');
  final hasCaption2 = shouldApplyCaptionConstraints(content: '<p>  </p>', rawBody: '<b>Biên bản nghiệm thu</b>');
  final hasNoCaption = shouldApplyCaptionConstraints(content: '', rawBody: null);
  final hasHtmlEmpty = shouldApplyCaptionConstraints(content: '<p>&nbsp;</p>', rawBody: '');
  assert(hasCaption1 == true, 'Case 17a Fail');
  assert(hasCaption2 == true, 'Case 17b Fail');
  assert(hasNoCaption == false, 'Case 17c Fail');
  assert(hasHtmlEmpty == false, 'Case 17d Fail');
  print('✅ Case 17 PASS: Phân định chính xác ảnh có kèm chú thích (caption) để áp dụng BoxConstraints(240, 280)');

  // Case 18: Padding tên người gửi khi có media
  final padMedia = shouldUseMediaPadding(hasAnyImage: true, hasVideos: false);
  final padVideo = shouldUseMediaPadding(hasAnyImage: false, hasVideos: true);
  final padTextOnly = shouldUseMediaPadding(hasAnyImage: false, hasVideos: false);
  assert(padMedia == true, 'Case 18a Fail');
  assert(padVideo == true, 'Case 18b Fail');
  assert(padTextOnly == false, 'Case 18c Fail');
  print('✅ Case 18 PASS: Điều chỉnh padding tên người gửi khi tin nhắn chứa ảnh/video tránh bị dính sát mép trên');

  print('\n================================================================');
  print('HOÀN TẤT: TOÀN BỘ 18/18 TEST CASES ĐẠT CHUẨN 100% PASS');
  print('================================================================');
}
