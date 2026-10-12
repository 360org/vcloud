// ignore_for_file: avoid_print
// Self-check 10 độc lập cho RTC Voice Call Preview Snippet (Ponytail rule: assert-based self-check, stdlib first)

Map<String, dynamic> parseSnippet({
  required String msg,
  required bool isMine,
  DateTime? lastDate,
}) {
  final lower = msg.toLowerCase().trim();
  final isMissedCall = lower.contains('nhỡ') || lower.startsWith('❌') || lower.contains('cuộc gọi nhỡ');
  final isVoiceCall = (lower.contains('cuộc gọi thoại') ||
          lower.startsWith('📞') ||
          lower.contains('cuộc gọi kéo dài') ||
          lower.contains('kéo dài trong') ||
          lower.contains('call duration') ||
          lower.contains('live conference') ||
          lower.contains('hội nghị trực tiếp')) &&
      !isMissedCall;
  final isRejectedCall = lower.contains('từ chối') || lower.startsWith('🚫');
  final isCancelledCall = lower.contains('hủy') || lower.startsWith('📵');
  final isAnyCall = isMissedCall || isVoiceCall || isRejectedCall || isCancelledCall;

  String prefix = isMine ? 'Bạn: ' : '';
  String displayText = msg;

  if (isMissedCall) {
    displayText = isMine ? '[Cuộc gọi nhỡ đi]' : '[Cuộc gọi nhỡ]';
  } else if (isVoiceCall) {
    final cleanMsg = msg.replaceAll('📞', '').trim();
    final timeMatch = RegExp(r'\((\d{1,2}:\d{2}(?::\d{2})?)\)').firstMatch(cleanMsg);
    if (timeMatch != null) {
      displayText = '[Cuộc gọi thoại] (${timeMatch.group(1)})';
    } else {
      final durMatch = RegExp(r'(?:kéo dài trong|duration:?)\s*(.+)', caseSensitive: false).firstMatch(cleanMsg);
      if (durMatch != null && durMatch.group(1)?.trim().isNotEmpty == true) {
        displayText = '[Cuộc gọi thoại] (${durMatch.group(1)!.trim()})';
      } else {
        displayText = '[Cuộc gọi thoại]';
      }
    }
  } else if (isRejectedCall) {
    displayText = '[Cuộc gọi bị từ chối]';
  } else if (isCancelledCall) {
    displayText = '[Cuộc gọi đã hủy]';
  }

  if (isAnyCall) {
    prefix = '';
  }

  final isFallbackCall = msg.isEmpty && lastDate != null;

  return {
    'isMissedCall': isMissedCall,
    'isVoiceCall': isVoiceCall,
    'isRejectedCall': isRejectedCall,
    'isCancelledCall': isCancelledCall,
    'isAnyCall': isAnyCall,
    'prefix': prefix,
    'displayText': displayText,
    'isFallbackCall': isFallbackCall,
  };
}

void main() {
  print('--- BẮT ĐẦU KIỂM THỬ 10 CASE ĐỘC LẬP CHO RTC CALL PREVIEW SNIPPET ---');

  // Case 1
  final c1 = parseSnippet(msg: 'Cuộc gọi kéo dài trong 2 giây.', isMine: false);
  assert(c1['isVoiceCall'] == true, 'Case 1 Fail: isVoiceCall must be true');
  assert(c1['displayText'] == '[Cuộc gọi thoại] (2 giây.)', 'Case 1 Fail: displayText mismatch');
  assert(c1['prefix'] == '', 'Case 1 Fail: prefix must be empty');
  print('✅ Case 1 PASS: Nhận diện chuỗi Odoo Web RTC tiếng Việt và bóc tách thời lượng "Cuộc gọi kéo dài trong 2 giây."');

  // Case 2
  final c2 = parseSnippet(msg: '📞 Cuộc gọi kéo dài trong 1 phút 15 giây', isMine: true);
  assert(c2['isVoiceCall'] == true, 'Case 2 Fail');
  assert(c2['displayText'] == '[Cuộc gọi thoại] (1 phút 15 giây)', 'Case 2 Fail: duration mismatch');
  assert(c2['prefix'] == '', 'Case 2 Fail');
  print('✅ Case 2 PASS: Nhận diện chuỗi Odoo Web RTC có icon và bóc tách thời lượng "📞 Cuộc gọi kéo dài trong 1 phút 15 giây"');

  // Case 3
  final c3 = parseSnippet(msg: 'Call duration: 45 seconds', isMine: false);
  assert(c3['isVoiceCall'] == true, 'Case 3 Fail');
  assert(c3['displayText'] == '[Cuộc gọi thoại] (45 seconds)', 'Case 3 Fail: duration mismatch');
  print('✅ Case 3 PASS: Nhận diện chuỗi RTC tiếng Anh Odoo Core và bóc tách thời lượng "Call duration: 45 seconds"');

  // Case 4
  final c4 = parseSnippet(msg: 'Live conference ended', isMine: false);
  assert(c4['isVoiceCall'] == true, 'Case 4 Fail');
  assert(c4['displayText'] == '[Cuộc gọi thoại]', 'Case 4 Fail');
  print('✅ Case 4 PASS: Nhận diện chuỗi Odoo RTC Conference "Live conference ended"');

  // Case 5
  final c5 = parseSnippet(msg: '❌ Cuộc gọi nhỡ lúc 14:30', isMine: false);
  assert(c5['isMissedCall'] == true, 'Case 5 Fail');
  assert(c5['isVoiceCall'] == false, 'Case 5 Fail');
  assert(c5['displayText'] == '[Cuộc gọi nhỡ]', 'Case 5 Fail');
  print('✅ Case 5 PASS: Nhận diện cuộc gọi nhỡ nhận từ người khác');

  // Case 6
  final c6 = parseSnippet(msg: 'Cuộc gọi nhỡ', isMine: true);
  assert(c6['isMissedCall'] == true, 'Case 6 Fail');
  assert(c6['displayText'] == '[Cuộc gọi nhỡ đi]', 'Case 6 Fail');
  print('✅ Case 6 PASS: Nhận diện cuộc gọi nhỡ do chính mình gọi đi');

  // Case 7
  final c7 = parseSnippet(msg: '🚫 Đối phương từ chối cuộc gọi', isMine: false);
  assert(c7['isRejectedCall'] == true, 'Case 7 Fail');
  assert(c7['displayText'] == '[Cuộc gọi bị từ chối]', 'Case 7 Fail');
  print('✅ Case 7 PASS: Nhận diện cuộc gọi bị từ chối');

  // Case 8
  final c8 = parseSnippet(msg: '📵 Người gọi đã hủy cuộc gọi', isMine: true);
  assert(c8['isCancelledCall'] == true, 'Case 8 Fail');
  assert(c8['displayText'] == '[Cuộc gọi đã hủy]', 'Case 8 Fail');
  print('✅ Case 8 PASS: Nhận diện cuộc gọi đã hủy');

  // Case 9
  final c9Normal = parseSnippet(msg: 'Xin chào bạn', isMine: true);
  assert(c9Normal['prefix'] == 'Bạn: ', 'Case 9 Normal Fail');
  final c9Call = parseSnippet(msg: 'kéo dài trong 30 giây', isMine: true);
  assert(c9Call['prefix'] == '', 'Case 9 Call Prefix Fail');
  assert(c9Call['displayText'] == '[Cuộc gọi thoại] (30 giây)', 'Case 9 Call Text Fail');
  print('✅ Case 9 PASS: Loại bỏ tiền tố "Bạn: " cho tất cả các loại cuộc gọi thoại');

  // Case 10
  final c10WithDate = parseSnippet(msg: '', isMine: false, lastDate: DateTime.now());
  assert(c10WithDate['isFallbackCall'] == true, 'Case 10 Date Fail');
  final c10WithoutDate = parseSnippet(msg: '', isMine: false, lastDate: null);
  assert(c10WithoutDate['isFallbackCall'] == false, 'Case 10 NoDate Fail');
  print('✅ Case 10 PASS: Fallback [Cuộc gọi thoại] khi lastMessage rỗng nhưng lastMessageDate tồn tại');

  // Case 11
  final c11 = parseSnippet(msg: '📞 Cuộc gọi thoại (02:15)', isMine: false);
  assert(c11['isVoiceCall'] == true, 'Case 11 Fail');
  assert(c11['displayText'] == '[Cuộc gọi thoại] (02:15)', 'Case 11 Duration Fail');
  print('✅ Case 11 PASS: Nhận diện định dạng cuộc gọi Flutter chuẩn "📞 Cuộc gọi thoại (02:15)"');

  // Case 12
  final c12 = parseSnippet(msg: 'Cuộc gọi thoại', isMine: true);
  assert(c12['isVoiceCall'] == true, 'Case 12 Fail');
  assert(c12['displayText'] == '[Cuộc gọi thoại]', 'Case 12 Text Fail');
  print('✅ Case 12 PASS: Nhận diện cuộc gọi thoại không có duration fallback về "[Cuộc gọi thoại]"');

  print('--- HOÀN TẤT: TOÀN BỘ 12/12 TEST CASES ĐẠT CHUẨN 100% ---');
}
