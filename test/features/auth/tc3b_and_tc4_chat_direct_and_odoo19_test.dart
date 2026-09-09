@Tags(['live-server'])
library;

import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  const String baseUrl17 = 'http://192.168.1.100:8069';
  const String dbName17 = 'demo-17';
  const String baseUrl19 = 'http://192.168.1.100:1902'; // Instance Odoo 19 trên Local Server

  group('TC3b & TC4: Chat 1-1 6 tin nhắn & Đăng nhập Odoo 19 & Đo hiệu năng', () {
    String? tokenInternal;
    String? tokenPortal;
    const int directChannelId = 37; // Kênh chat 1-1 có sẵn giữa Internal & Portal

    setUpAll(() async {
      // Login Internal
      final resInt = await http.post(
        Uri.parse('$baseUrl17/api/v1/mobile/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'db': dbName17,
          'login': 'test_internal@360.org.vn',
          'password': '123',
        }),
      );
      expect(resInt.statusCode, 200);
      tokenInternal = jsonDecode(resInt.body)['access_token'];

      // Login Portal
      final resPor = await http.post(
        Uri.parse('$baseUrl17/api/v1/mobile/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'db': dbName17,
          'login': 'test_portal@360.org.vn',
          'password': '123456',
        }),
      );
      expect(resPor.statusCode, 200);
      tokenPortal = jsonDecode(resPor.body)['access_token'];
    });

    test('1. TC3b: Chat 1-1 gửi luân phiên 6 tin nhắn và đo độ trễ từng tin', () async {
      final messages = [
        {'role': 'INTERNAL', 'token': tokenInternal, 'msg': 'Tin 1-1 số 1 từ Internal: Bắt đầu test chat 1-1'},
        {'role': 'PORTAL', 'token': tokenPortal, 'msg': 'Tin 1-1 số 2 từ Portal: Đã nhận tin 1, phản hồi ngay'},
        {'role': 'INTERNAL', 'token': tokenInternal, 'msg': 'Tin 1-1 số 3 từ Internal: Kiểm tra độ ổn định kết nối'},
        {'role': 'PORTAL', 'token': tokenPortal, 'msg': 'Tin 1-1 số 4 từ Portal: Kết nối rất tốt, không delay'},
        {'role': 'INTERNAL', 'token': tokenInternal, 'msg': 'Tin 1-1 số 5 từ Internal: Xác nhận tin nhắn thứ 5'},
        {'role': 'PORTAL', 'token': tokenPortal, 'msg': 'Tin 1-1 số 6 từ Portal: Hoàn tất 6/6 tin nhắn 1-1'},
      ];

      final sentIds = <int>[];
      final latencies = <int>[];

      for (int i = 0; i < messages.length; i++) {
        final item = messages[i];
        final sw = Stopwatch()..start();

        final res = await http.post(
          Uri.parse('$baseUrl17/api/v1/mobile/chat/messages'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${item['token']}',
          },
          body: jsonEncode({
            'channel_id': directChannelId,
            'body': item['msg'],
          }),
        );
        sw.stop();
        latencies.add(sw.elapsedMilliseconds);

        expect(res.statusCode, anyOf(200, 201), reason: 'Lỗi gửi tin 1-1 số ${i + 1}: ${res.body}');
        final data = jsonDecode(res.body);
        final int id = data['id'] as int;
        sentIds.add(id);

        print('📨 [CHAT 1-1] Tin ${i + 1}/6 (${item['role']}) -> ID: $id (Độ trễ: ${sw.elapsedMilliseconds}ms)');
        expect(sw.elapsedMilliseconds, lessThan(1500));
      }

      // Verify bên Portal đọc lại đủ 6 tin
      final getRes = await http.get(
        Uri.parse('$baseUrl17/api/v1/mobile/chat/channels/$directChannelId/messages?limit=30'),
        headers: {'Authorization': 'Bearer $tokenPortal'},
      );
      expect(getRes.statusCode, 200);
      final listData = jsonDecode(getRes.body);
      final List allMsgs = listData is List ? listData : (listData['messages'] as List);

      for (final id in sentIds) {
        expect(allMsgs.any((m) => m['id'] == id), isTrue, reason: 'Tin ID $id bị thất lạc!');
      }

      final avgLatency = latencies.reduce((a, b) => a + b) / latencies.length;
      print('📊 [TC3b PERF] Độ trễ trung bình chat 1-1: ${avgLatency.toStringAsFixed(1)}ms | Nhận đủ 6/6 tin!');
    });

    test('2. TC4: Kiểm tra kết nối & Handshake với Odoo 19 Backend', () async {
      // Warm up connection
      try {
        await http.get(Uri.parse('$baseUrl19/web/health')).timeout(const Duration(seconds: 2));
      } catch (_) {}

      final sw = Stopwatch()..start();
      final res = await http.get(Uri.parse('$baseUrl19/web/login')).timeout(const Duration(seconds: 5));
      sw.stop();

      print('🌐 [TC4 ODOO 19] Kết nối tới Odoo 19 port 1902: Status = ${res.statusCode} (Độ trễ: ${sw.elapsedMilliseconds}ms)');
      expect(res.statusCode, 200);
      expect(sw.elapsedMilliseconds, lessThan(2500), reason: 'Kết nối tới Odoo 19 quá chậm');
    });
  });
}
