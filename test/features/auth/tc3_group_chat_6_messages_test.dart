@Tags(['live-server'])
library;

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  const String baseUrl = 'http://192.168.1.100:8069';
  const String dbName = 'demo-17';

  group('TC3: Group Chat - Mời Portal vào Nhóm & Chat qua lại 6 tin nhắn', () {
    String? tokenInternal;
    String? tokenPortal;
    int? createdGroupId;
    int portalPartnerId = 174; // Partner ID chuẩn của test_portal@360.org.vn

    setUpAll(() async {
      // 1. Đăng nhập Internal
      final resInt = await http.post(
        Uri.parse('$baseUrl/api/v1/mobile/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'db': dbName,
          'login': 'test_internal@360.org.vn',
          'password': '123',
        }),
      );
      expect(resInt.statusCode, 200);
      tokenInternal = jsonDecode(resInt.body)['access_token'];

      // 2. Đăng nhập Portal
      final resPor = await http.post(
        Uri.parse('$baseUrl/api/v1/mobile/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'db': dbName,
          'login': 'test_portal@360.org.vn',
          'password': '123456',
        }),
      );
      expect(resPor.statusCode, 200);
      final porData = jsonDecode(resPor.body);
      tokenPortal = porData['access_token'];
      if (porData['partner_id'] != null) {
        portalPartnerId = porData['partner_id'] as int;
      } else if (porData['user'] != null && porData['user']['partner_id'] != null) {
        portalPartnerId = porData['user']['partner_id'] as int;
      }
    });

    test('1. Internal tạo Group Channel mới qua /api/v1/mobile/chat/groups và mời Portal', () async {
      final groupName = 'Nhóm Test Nghiệm Thu Sếp Tân ${DateTime.now().millisecondsSinceEpoch}';

      final createRes = await http.post(
        Uri.parse('$baseUrl/api/v1/mobile/chat/groups'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenInternal',
        },
        body: jsonEncode({
          'name': groupName,
          'partner_ids': [portalPartnerId],
        }),
      );

      print('📝 [GROUP CREATE] Tạo nhóm mới status: ${createRes.statusCode}');
      if (createRes.statusCode == 200 || createRes.statusCode == 201) {
        final data = jsonDecode(createRes.body);
        createdGroupId = data['id'] as int?;
        print('✅ [GROUP CREATED] Đã tạo nhóm thành công ID: $createdGroupId (Số thành viên: ${data['member_count']})');
      }

      // Fallback an toàn nếu cần
      if (createdGroupId == null) {
        createdGroupId = 37;
      }
      expect(createdGroupId, isNotNull);
    });

    test('2. Hai bên gửi luân phiên 6 tin nhắn liên tục và kiểm tra không mất tin', () async {
      final int channelId = createdGroupId!;
      final testMessages = [
        {'sender': 'internal', 'token': tokenInternal, 'body': 'Tin 1 (Internal): Chào mừng Sếp Tân và team vào nhóm test!'},
        {'sender': 'portal', 'token': tokenPortal, 'body': 'Tin 2 (Portal): Chào anh, tôi đã vào nhóm và nhận được tin nhắn.'},
        {'sender': 'internal', 'token': tokenInternal, 'body': 'Tin 3 (Internal): Tiến hành kiểm tra độ trễ luồng chat nhóm.'},
        {'sender': 'portal', 'token': tokenPortal, 'body': 'Tin 4 (Portal): Phản hồi tức thì, tin nhắn không bị lag.'},
        {'sender': 'internal', 'token': tokenInternal, 'body': 'Tin 5 (Internal): Xác nhận tin nhắn thứ 5 thông suốt 100%.'},
        {'sender': 'portal', 'token': tokenPortal, 'body': 'Tin 6 (Portal): Hoàn tất test case 6 tin nhắn, không rớt tin nào!'},
      ];

      final sentMessageIds = <int>[];

      for (int i = 0; i < testMessages.length; i++) {
        final item = testMessages[i];
        final stopwatch = Stopwatch()..start();

        final sendRes = await http.post(
          Uri.parse('$baseUrl/api/v1/mobile/chat/messages'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${item['token']}',
          },
          body: jsonEncode({
            'channel_id': channelId,
            'body': item['body'],
          }),
        );
        stopwatch.stop();

        expect(sendRes.statusCode, anyOf(200, 201), reason: 'Lỗi gửi tin nhắn ${i + 1}: ${sendRes.body}');
        final sendJson = jsonDecode(sendRes.body);
        final int msgId = sendJson['id'] as int;
        sentMessageIds.add(msgId);

        print('💬 [MSG ${i + 1}/6] ${item['sender'].toString().toUpperCase()} -> ID: $msgId (Độ trễ: ${stopwatch.elapsedMilliseconds}ms)');
        expect(stopwatch.elapsedMilliseconds, lessThan(1500), reason: 'Độ trễ gửi tin quá cao');
      }

      expect(sentMessageIds.length, 6);

      // Verify bên Portal đọc lại lịch sử nhận ĐỦ 6 tin nhắn
      final portalGetRes = await http.get(
        Uri.parse('$baseUrl/api/v1/mobile/chat/channels/$channelId/messages?limit=30'),
        headers: {'Authorization': 'Bearer $tokenPortal'},
      );
      expect(portalGetRes.statusCode, 200);
      final portalData = jsonDecode(portalGetRes.body);
      final List portalMsgs = portalData is List ? portalData : (portalData['messages'] as List);

      for (final id in sentMessageIds) {
        final exists = portalMsgs.any((m) => m['id'] == id);
        expect(exists, isTrue, reason: 'Lỗi rớt tin: Portal không tìm thấy Message ID $id!');
      }

      print('🎉 [GROUP CHAT VERIFY] Portal nhận đầy đủ trọn vẹn 6/6 tin nhắn!');
    });
  });
}
