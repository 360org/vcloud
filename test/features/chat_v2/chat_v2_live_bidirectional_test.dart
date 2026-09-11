@Tags(['live-server'])
library;

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  const String baseUrl = 'http://192.168.1.100:8069';
  const String dbName = 'demo-17';

  group('VCloud Chat V2 Integration Test - 2 Users Bidirectional Messaging', () {
    String? tokenInternal;
    String? tokenPortal;
    const int channelId = 37;

    test('1. Đăng nhập User 1 (Nhân Viên Nội Bộ 360) lấy access_token', () async {
      final res = await http.post(
        Uri.parse('$baseUrl/api/v1/mobile/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'db': dbName,
          'login': 'test_internal@360.org.vn',
          'password': '123',
        }),
      );

      expect(res.statusCode, 200, reason: 'Login Internal failed: ${res.body}');
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      tokenInternal = data['access_token'] as String?;
      expect(tokenInternal, isNotNull);
      expect(data['user_type'], 'internal');
    });

    test('2. Đăng nhập User 2 (Khách Hàng Portal 360) lấy access_token', () async {
      final res = await http.post(
        Uri.parse('$baseUrl/api/v1/mobile/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'db': dbName,
          'login': 'test_portal@360.org.vn',
          'password': '123456',
        }),
      );

      expect(res.statusCode, 200, reason: 'Login Portal failed: ${res.body}');
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      tokenPortal = data['access_token'] as String?;
      expect(tokenPortal, isNotNull);
      expect(data['user_type'], 'portal');
    });

    test('3. Xác minh cả 2 User đều là thành viên của Kênh Chat chung (Channel ID: 37)', () async {
      final resInt = await http.get(
        Uri.parse('$baseUrl/api/v1/mobile/chat/channels'),
        headers: {'Authorization': 'Bearer $tokenInternal'},
      );
      expect(resInt.statusCode, 200);
      final channelsInt = jsonDecode(resInt.body) as List;
      final hasChanInt = channelsInt.any((c) => c['id'] == channelId);
      expect(hasChanInt, isTrue, reason: 'User Internal không thấy channel $channelId');

      final resPor = await http.get(
        Uri.parse('$baseUrl/api/v1/mobile/chat/channels'),
        headers: {'Authorization': 'Bearer $tokenPortal'},
      );
      expect(resPor.statusCode, 200);
      final channelsPor = jsonDecode(resPor.body) as List;
      final hasChanPor = channelsPor.any((c) => c['id'] == channelId);
      expect(hasChanPor, isTrue, reason: 'User Portal không thấy channel $channelId');
    });

    test('4. Luồng 1: User Internal gửi tin nhắn -> User Portal nhận được ngay', () async {
      final sentContent = 'Tin nhắn từ Internal: ${DateTime.now().toIso8601String()}';
      final sendRes = await http.post(
        Uri.parse('$baseUrl/api/v1/mobile/chat/messages'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenInternal',
        },
        body: jsonEncode({
          'channel_id': channelId,
          'body': sentContent,
        }),
      );

      expect(sendRes.statusCode, anyOf(200, 201), reason: 'Gửi tin thất bại: ${sendRes.body}');
      final sendJson = jsonDecode(sendRes.body) as Map<String, dynamic>;
      final int msgId = sendJson['id'] as int;

      // User Portal đọc lại danh sách tin nhắn
      final getRes = await http.get(
        Uri.parse('$baseUrl/api/v1/mobile/chat/channels/$channelId/messages?limit=20'),
        headers: {'Authorization': 'Bearer $tokenPortal'},
      );
      expect(getRes.statusCode, 200);
      final getJson = jsonDecode(getRes.body);
      final List messages = getJson is List ? getJson : (getJson['messages'] as List);

      final found = messages.any((m) => m['id'] == msgId);
      expect(found, isTrue, reason: 'User Portal không tìm thấy tin nhắn vừa gửi từ Internal!');
    });

    test('5. Luồng 2: User Portal gửi tin nhắn trả lời -> User Internal nhận được ngay', () async {
      final replyContent = 'Phản hồi từ Portal: ${DateTime.now().toIso8601String()}';
      final sendRes = await http.post(
        Uri.parse('$baseUrl/api/v1/mobile/chat/messages'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $tokenPortal',
        },
        body: jsonEncode({
          'channel_id': channelId,
          'body': replyContent,
        }),
      );

      expect(sendRes.statusCode, anyOf(200, 201), reason: 'Portal gửi phản hồi thất bại: ${sendRes.body}');
      final sendJson = jsonDecode(sendRes.body) as Map<String, dynamic>;
      final int replyMsgId = sendJson['id'] as int;

      // User Internal đọc lại danh sách tin nhắn
      final getRes = await http.get(
        Uri.parse('$baseUrl/api/v1/mobile/chat/channels/$channelId/messages?limit=20'),
        headers: {'Authorization': 'Bearer $tokenInternal'},
      );
      expect(getRes.statusCode, 200);
      final getJson = jsonDecode(getRes.body);
      final List messages = getJson is List ? getJson : (getJson['messages'] as List);

      final found = messages.any((m) => m['id'] == replyMsgId);
      expect(found, isTrue, reason: 'User Internal không tìm thấy tin nhắn phản hồi từ Portal!');
    });
  });
}
