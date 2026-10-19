// ignore_for_file: avoid_print
// Self-check 10 ca kiểm thử độc lập cho Push Notification Routing (Ponytail rule: assert-based self-check, stdlib first)

String cleanChannelName(String raw) {
  var s = raw.replaceAll(RegExp(r'\s*\([^\)]*portal[^\)]*\)', caseSensitive: false), '').trim();
  s = s.replaceAll(RegExp(r'\s*\(internal\)', caseSensitive: false), '').trim();
  return s;
}

String resolvePushRoute({
  required Map<String, dynamic> data,
  String? notificationTitle,
}) {
  final resId = data['res_id'] ?? data['channel_id'] ?? data['discuss_channel_id'] ?? data['chat_id'];
  final model = (data['model'] ?? data['type'] ?? '').toString().toLowerCase();
  final resModel = (data['res_model'] ?? '').toString().toLowerCase();
  final ticketId = data['ticket_id'] ?? data['helpdesk_ticket_id'];
  final eventType = (data['event_type'] ?? '').toString().toLowerCase();
  final action = (data['action'] ?? '').toString().toLowerCase();

  // 1. Chấm công (Attendance)
  if (eventType.contains('attendance') || action == 'checkin' || action == 'checkout') {
    if (action == 'checkout') {
      return '/attendance?action=checkout';
    } else {
      return '/attendance';
    }
  }
  // 2. Ticket / Helpdesk
  else if (model.contains('helpdesk') ||
      model.contains('ticket') ||
      data.containsKey('ticket_id') ||
      data.containsKey('helpdesk_ticket_id') ||
      (model == 'mail.message' && resModel.contains('helpdesk'))) {
    final targetTicketId = ticketId ?? resId;
    if (targetTicketId != null &&
        targetTicketId.toString().isNotEmpty &&
        targetTicketId.toString() != '0') {
      return '/tickets/$targetTicketId';
    } else {
      return '/tickets';
    }
  }
  // 3. Tuyển dụng (hr.applicant / recruitment)
  else if (model.contains('hr.applicant') ||
      model.contains('recruitment') ||
      (model == 'mail.message' && resModel.contains('hr.applicant'))) {
    return '/tickets';
  }
  // 4. Chat V2 / Discuss (chỉ khi có resId kênh hợp lệ)
  else if ((model.contains('discuss') || model.contains('chat') || data.containsKey('channel_id')) &&
      resId != null &&
      resId.toString().isNotEmpty &&
      resId.toString() != '0') {
    final rawChannelName = data['channel_name'] ?? data['name'] ?? notificationTitle ?? '';
    final cleanName = cleanChannelName(rawChannelName.toString());
    return '/chat/$resId?name=${Uri.encodeComponent(cleanName)}';
  }
  // 5. Fallback an toàn về Trang chủ (Tránh đá nhầm vào phòng Chat)
  else {
    return '/';
  }
}

void main() {
  print('--- BẮT ĐẦU KIỂM THỬ 10 CASE ĐỘC LẬP CHO PUSH NOTIFICATION ROUTING ---');

  // TC-01: Thông báo chấm công
  final r1 = resolvePushRoute(data: {'action': 'checkin'});
  assert(r1 == '/attendance', 'TC-01 Fail: expected /attendance, got $r1');
  print('✅ TC-01 PASS: Thông báo chấm công (action: checkin) -> /attendance');

  // TC-02: Thông báo Ticket Helpdesk (có ticket_id)
  final r2 = resolvePushRoute(data: {'ticket_id': 123, 'model': 'helpdesk.ticket'});
  assert(r2 == '/tickets/123', 'TC-02 Fail: expected /tickets/123, got $r2');
  print('✅ TC-02 PASS: Thông báo Ticket Helpdesk có ticket_id -> /tickets/123');

  // TC-03: Thông báo Ticket Helpdesk (chỉ có res_id, không có ticket_id)
  final r3 = resolvePushRoute(data: {'model': 'helpdesk.ticket', 'res_id': 456});
  assert(r3 == '/tickets/456', 'TC-03 Fail: expected /tickets/456, got $r3');
  print('✅ TC-03 PASS: Thông báo Ticket Helpdesk chỉ có res_id -> /tickets/456');

  // TC-04: Chatter trên Ticket (model = mail.message)
  final r4 = resolvePushRoute(data: {
    'model': 'mail.message',
    'res_model': 'helpdesk.ticket',
    'res_id': 789,
  });
  assert(r4 == '/tickets/789', 'TC-04 Fail: expected /tickets/789, got $r4');
  print('✅ TC-04 PASS: Chatter trên Ticket (model = mail.message) -> /tickets/789');

  // TC-05: Thư mời ứng viên (hr.applicant)
  final r5 = resolvePushRoute(data: {'model': 'hr.applicant', 'res_id': 55});
  assert(r5 == '/tickets', 'TC-05 Fail: expected /tickets, got $r5');
  print('✅ TC-05 PASS: Thư mời ứng viên (hr.applicant) -> /tickets (danh sách chung)');

  // TC-06: Chatter trên ứng viên
  final r6 = resolvePushRoute(data: {
    'model': 'mail.message',
    'res_model': 'hr.applicant',
    'res_id': 66,
  });
  assert(r6 == '/tickets', 'TC-06 Fail: expected /tickets, got $r6');
  print('✅ TC-06 PASS: Chatter trên ứng viên -> /tickets');

  // TC-07: Tin nhắn Chat V2 thật sự
  final r7 = resolvePushRoute(
    data: {'model': 'discuss.channel', 'channel_id': 100, 'channel_name': 'Team Tech'},
  );
  assert(r7 == '/chat/100?name=Team%20Tech', 'TC-07 Fail: expected /chat/100?name=Team%20Tech, got $r7');
  print('✅ TC-07 PASS: Tin nhắn Chat V2 thật sự -> /chat/100?name=Team%20Tech');

  // TC-08: Notification rỗng / không xác định model
  final r8 = resolvePushRoute(data: {});
  assert(r8 == '/', 'TC-08 Fail: expected /, got $r8');
  print('✅ TC-08 PASS: Notification rỗng / không xác định model -> / (trang chủ)');

  // TC-09: Notification có model: 'project.task'
  final r9 = resolvePushRoute(data: {'model': 'project.task', 'res_id': 200});
  assert(r9 == '/', 'TC-09 Fail: expected /, got $r9');
  print('✅ TC-09 PASS: Notification có model: project.task -> / (fallback, không đá vào chat)');

  // TC-10: Notification checkout
  final r10 = resolvePushRoute(data: {'action': 'checkout'});
  assert(r10 == '/attendance?action=checkout', 'TC-10 Fail: expected /attendance?action=checkout, got $r10');
  print('✅ TC-10 PASS: Notification checkout -> /attendance?action=checkout');

  print('--- HOÀN TẤT: TOÀN BỘ 10/10 TEST CASES ĐẠT CHUẨN 100% ---');
}
