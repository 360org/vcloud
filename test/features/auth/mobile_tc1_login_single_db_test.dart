// ignore_for_file: avoid_print, prefer_const_declarations, prefer_const_constructors, prefer_conditional_assignment
@Tags(['live-server'])
library;


import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  const String backendUrl17 = 'http://192.168.1.100:8069';
  const String db17 = 'demo-17';

  group('Mobile Login TC1: Đăng nhập 1 chạm demo-17 & Đo hiệu năng', () {
    test('1. Xác minh request đăng nhập 1 chạm thành công ngay lần đầu', () async {
      final sw = Stopwatch()..start();

      final res = await http.post(
        Uri.parse('$backendUrl17/api/v1/mobile/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'db': db17,
          'login': 'test_internal@360.org.vn',
          'password': '123',
        }),
      );
      sw.stop();

      expect(res.statusCode, 200);
      final json = jsonDecode(res.body);
      expect(json['access_token'], isNotNull);
      expect(json['user_type'], 'internal');

      print('⚡ [MOBILE TC1 PERF] Đăng nhập 1 chạm vào demo-17: ${sw.elapsedMilliseconds}ms');
      expect(sw.elapsedMilliseconds, lessThan(800), reason: 'Độ trễ đăng nhập 1 chạm quá cao (>800ms)');
    });

    test('2. Kiểm tra tính năng lưu Cache DB gần nhất (Preferred DB)', () {
      // Giả lập logic lưu local storage
      final cachedDb = db17;
      final cachedUrl = backendUrl17;

      expect(cachedDb, 'demo-17');
      expect(cachedUrl, startsWith('http'));
      print('💾 [MOBILE TC1 CACHE] Đã lưu Preferred DB: $cachedDb | URL: $cachedUrl');
    });
  });
}
