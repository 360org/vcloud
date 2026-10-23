// ignore_for_file: avoid_print
// Self-check kiểm thử độc lập cho Push Notification Routing & In-App Notification Sheet
// (Ponytail rule: assert-based self-check, stdlib first, zero fake precision)

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
  // 3. Timesheet / Công việc (project.task / timesheet)
  else if (model.contains('task') ||
      model.contains('timesheet') ||
      model.contains('project') ||
      data.containsKey('task_id') ||
      (model == 'mail.message' && resModel.contains('task'))) {
    final targetTaskId = data['task_id'] ?? resId;
    if (targetTaskId != null &&
        targetTaskId.toString().isNotEmpty &&
        targetTaskId.toString() != '0') {
      return '/timesheet?task_id=$targetTaskId';
    } else {
      return '/timesheet';
    }
  }
  // 4. Tuyển dụng (hr.applicant / recruitment)
  else if (model.contains('hr.applicant') ||
      model.contains('recruitment') ||
      (model == 'mail.message' && resModel.contains('hr.applicant'))) {
    return '/tickets';
  }
  // 5. Chat V2 / Discuss (chỉ khi có resId kênh hợp lệ, không kiểm tra lỏng lẻo data.containsKey)
  else if ((model.contains('discuss') ||
          model.contains('chat') ||
          (data['channel_id'] != null &&
              data['channel_id'].toString() != '0' &&
              data['channel_id'].toString().isNotEmpty)) &&
      resId != null &&
      resId.toString().isNotEmpty &&
      resId.toString() != '0') {
    final rawChannelName = data['channel_name'] ?? data['name'] ?? notificationTitle ?? '';
    final cleanName = cleanChannelName(rawChannelName.toString());
    final targetChannelId = (data['channel_id'] != null &&
            data['channel_id'].toString() != '0' &&
            data['channel_id'].toString().isNotEmpty)
        ? data['channel_id']
        : resId;
    return '/chat/$targetChannelId?name=${Uri.encodeComponent(cleanName)}';
  }
  // 6. Fallback an toàn về Trang chủ (Tránh đá nhầm vào phòng Chat)
  else {
    return '/';
  }
}

String? resolveInAppRoute({
  required Map<String, dynamic> data,
  String? title,
}) {
  final model = (data['model'] ?? data['type'] ?? '').toString().toLowerCase();
  final resModel = (data['res_model'] ?? '').toString().toLowerCase();
  final resId = data['res_id'];

  // 1. Ticket / Helpdesk
  final ticketId = data['ticket_id'] ??
      (model.contains('helpdesk') || model.contains('ticket') || resModel.contains('helpdesk')
          ? resId
          : null);
  if (ticketId != null &&
      ticketId.toString().isNotEmpty &&
      ticketId.toString() != '0') {
    return '/tickets/$ticketId';
  } else if (model.contains('helpdesk') || model.contains('ticket') || resModel.contains('helpdesk')) {
    return '/tickets';
  }

  // 2. Timesheet / Công việc (project.task / timesheet)
  final taskId = data['task_id'] ??
      (model.contains('task') || model.contains('timesheet') || model.contains('project') || resModel.contains('task')
          ? resId
          : null);
  if (taskId != null &&
      taskId.toString().isNotEmpty &&
      taskId.toString() != '0') {
    return '/timesheet?task_id=$taskId';
  } else if (model.contains('task') || model.contains('timesheet') || model.contains('project') || resModel.contains('task')) {
    return '/timesheet';
  }

  // 3. Chat V2 / Discuss (chỉ khi có channel ID hợp lệ khác 0)
  final conversationId = data['conversation_id'] ??
      (data['channel_id'] != null &&
              data['channel_id'].toString() != '0' &&
              data['channel_id'].toString().isNotEmpty
          ? data['channel_id']
          : (model.contains('discuss') || model.contains('chat') ? resId : null));
  if (conversationId != null &&
      conversationId.toString().isNotEmpty &&
      conversationId.toString() != '0') {
    final cleanTitle = title != null ? cleanChannelName(title) : null;
    if (cleanTitle != null && cleanTitle.isNotEmpty) {
      return '/chat/$conversationId?name=${Uri.encodeComponent(cleanTitle)}';
    }
    return '/chat/$conversationId';
  }
  return null;
}

void main() {
  print('--- BẮT ĐẦU KIỂM THỬ ĐỘC LẬP CHO PUSH NOTIFICATION & IN-APP ROUTING ---');

  // TC-01: Thông báo chấm công (action: checkin)
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

  // TC-09: [ROOT CAUSE REPRODUCTION] Notification Task thực tế từ Odoo (kèm channel_id: 0)
  // Payload thực tế khi Odoo giao việc: model='project.task', res_id=8421, channel_id=0
  final r9 = resolvePushRoute(data: {
    'model': 'project.task',
    'res_id': 8421,
    'channel_id': 0,
    'channel_name': '',
  });
  assert(r9 == '/timesheet?task_id=8421', 'TC-09 Fail: expected /timesheet?task_id=8421, got $r9');
  print('✅ TC-09 PASS: Notification Task thực tế (channel_id: 0) -> /timesheet?task_id=8421 (CHỐNG NHẢY VÀO CHAT)');

  // TC-10: Chatter trên Task thực tế từ Odoo (kèm channel_id: 0)
  final r10 = resolvePushRoute(data: {
    'model': 'mail.message',
    'res_model': 'project.task',
    'res_id': 8421,
    'channel_id': 0,
  });
  assert(r10 == '/timesheet?task_id=8421', 'TC-10 Fail: expected /timesheet?task_id=8421, got $r10');
  print('✅ TC-10 PASS: Chatter trên Task (channel_id: 0) -> /timesheet?task_id=8421');

  // TC-11: Notification Task có task_id trực tiếp
  final r11 = resolvePushRoute(data: {'task_id': 9999, 'model': 'project.task'});
  assert(r11 == '/timesheet?task_id=9999', 'TC-11 Fail: expected /timesheet?task_id=9999, got $r11');
  print('✅ TC-11 PASS: Notification Task có task_id trực tiếp -> /timesheet?task_id=9999');

  // TC-12: Notification Task không có res_id cụ thể -> danh sách Timesheet chung
  final r12 = resolvePushRoute(data: {'model': 'project.task'});
  assert(r12 == '/timesheet', 'TC-12 Fail: expected /timesheet, got $r12');
  print('✅ TC-12 PASS: Notification Task không có ID -> /timesheet');

  // TC-13: In-App Notification Center: Task thực tế (res_id=8421, channel_id=0)
  final r13 = resolveInAppRoute(data: {
    'model': 'project.task',
    'res_id': 8421,
    'channel_id': 0,
  });
  assert(r13 == '/timesheet?task_id=8421', 'TC-13 Fail: expected /timesheet?task_id=8421, got $r13');
  print('✅ TC-13 PASS: In-App Sheet Task thực tế -> /timesheet?task_id=8421');

  // TC-14: In-App Notification Center: Ticket fallback res_id (không có ticket_id riêng)
  final r14 = resolveInAppRoute(data: {
    'model': 'helpdesk.ticket',
    'res_id': 777,
    'channel_id': 0,
  });
  assert(r14 == '/tickets/777', 'TC-14 Fail: expected /tickets/777, got $r14');
  print('✅ TC-14 PASS: In-App Sheet Ticket fallback res_id -> /tickets/777');

  // TC-15: Notification checkout
  final r15 = resolvePushRoute(data: {'action': 'checkout'});
  assert(r15 == '/attendance?action=checkout', 'TC-15 Fail: expected /attendance?action=checkout, got $r15');
  print('✅ TC-15 PASS: Notification checkout -> /attendance?action=checkout');

  print('--- HOÀN TẤT: TOÀN BỘ 15/15 TEST CASES ĐẠT CHUẨN XÁC MINH ---');
}
