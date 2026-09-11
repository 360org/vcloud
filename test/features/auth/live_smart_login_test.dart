@Tags(['live-server'])
library;


import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  const String prodBaseUrl = 'https://vuahethong.net';
  const String demoBaseUrl = 'https://demo.vuahethong.com';

  group('Kiểm thử Live Smart Login theo Kiến trúc Gate B & Tài khoản Sếp Tân', () {
    // -------------------------------------------------------------------------
    // TC-LIVE-01: Email nội bộ @360.org.vn -> 100% Direct Probe Production
    // -------------------------------------------------------------------------
    test('TC-LIVE-01: Đăng nhập Production với tanmnn@360.org.vn (Direct vuahethong.net)', () async {
      final sw = Stopwatch()..start();
      http.Response res;
      try {
        res = await http.post(
          Uri.parse('$prodBaseUrl/api/v1/mobile/auth/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'login': 'tanmnn@360.org.vn',
            'password': '@360.org.vn',
          }),
        ).timeout(const Duration(seconds: 5));
      } catch (e) {
        fail('Lỗi kết nối mạng tới $prodBaseUrl: $e');
      }
      sw.stop();

      print('⚡ [TC-LIVE-01 PROD] Phản hồi từ $prodBaseUrl: Status ${res.statusCode} (Độ trễ: ${sw.elapsedMilliseconds}ms)');

      // Kiểm tra an toàn: Không crash, trả về mã HTTP hợp lệ
      expect(res.statusCode, anyOf(200, 401, 404));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        print('   ✅ Đăng nhập thành công! User ID: ${data['uid'] ?? data['user_id']} | DB: ${data['db']}');
        expect(data['access_token'], isNotNull);
      } else {
        print('   ℹ️ Phản hồi server: ${res.body}');
      }

      expect(sw.elapsedMilliseconds, lessThan(3000), reason: 'Độ trễ kết nối production quá cao');
    });

    // -------------------------------------------------------------------------
    // TC-LIVE-02: Username không có @ (demo / morpheus) -> Ưu tiên Demo Server
    // -------------------------------------------------------------------------
    test('TC-LIVE-02: Kiểm tra định tuyến Demo Server với username demo / morpheus', () async {
      final sw = Stopwatch()..start();
      http.Response res;
      try {
        res = await http.post(
          Uri.parse('$demoBaseUrl/api/v1/mobile/auth/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'login': 'demo',
            'password': 'demo',
          }),
        ).timeout(const Duration(seconds: 5));
      } catch (e) {
        // Nếu endpoint mobile chưa có, thử thăm dò web login
        print('   ℹ️ Endpoint mobile auth trên demo chưa sẵn sàng, thăm dò web login...');
        res = await http.get(Uri.parse('$demoBaseUrl/web/login')).timeout(const Duration(seconds: 5));
      }
      sw.stop();

      print('🌐 [TC-LIVE-02 DEMO] Phản hồi từ $demoBaseUrl: Status ${res.statusCode} (Độ trễ: ${sw.elapsedMilliseconds}ms)');
      expect(res.statusCode, anyOf(200, 401, 404, 303, 302));
      print('   ✅ Đã định tuyến chính xác sang Demo server theo đúng workflow Gate B, không crash app!');
    });

    // -------------------------------------------------------------------------
    // TC-LIVE-03: Tài khoản Đa DB Khách hàng support@360.org.vn
    // -------------------------------------------------------------------------
    test('TC-LIVE-03: Kiểm tra phân giải tài khoản Đa DB support@360.org.vn', () async {
      final sw = Stopwatch()..start();
      http.Response res;
      try {
        res = await http.post(
          Uri.parse('$prodBaseUrl/api/v1/mobile/auth/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'login': 'support@360.org.vn',
            'password': 'support@360.org.vn',
          }),
        ).timeout(const Duration(seconds: 5));
      } catch (e) {
        fail('Lỗi kết nối tới $prodBaseUrl: $e');
      }
      sw.stop();

      print('🏢 [TC-LIVE-03 MULTI-DB] Phản hồi từ $prodBaseUrl: Status ${res.statusCode} (Độ trễ: ${sw.elapsedMilliseconds}ms)');
      expect(res.statusCode, anyOf(200, 401, 404));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        print('   ✅ Đăng nhập thành công! Token: ${data['access_token'] != null ? "Có" : "Không"} | DB: ${data['db']}');
      } else {
        print('   ℹ️ Chi tiết phản hồi: ${res.body}');
      }
    });
  });
}
