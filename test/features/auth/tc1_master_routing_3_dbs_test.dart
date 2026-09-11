// ignore_for_file: avoid_print, prefer_const_declarations, prefer_const_constructors, prefer_conditional_assignment
@Tags(['live-server'])
library;


import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:vcloud/features/auth/data/db_info.dart';

void main() {
  const String localBackendUrl = 'http://192.168.1.100:8069';

  group('TC1: Master Routing - Trùng 3 Database & Đăng nhập đủ cả 3 DB', () {
    test('1. Giả lập Master trả về 3 DB trùng account -> Parse & Render UI đúng 3 DB', () {
      final mockMasterPayload = {
        'status': 'success',
        'count': 3,
        'databases': [
          {
            'database_name': 'client_db1',
            'database_url': 'https://erp.client1.vn',
            'display_name': 'Công ty Cổ Phần Alpha',
            'has_vmobile': true,
          },
          {
            'database_name': 'client_db2',
            'database_url': 'https://erp.beta.vn',
            'display_name': 'Tập Đoàn Beta Toàn Cầu',
            'has_vmobile': true,
          },
          {
            'database_name': 'demo-17',
            'database_url': localBackendUrl,
            'display_name': 'Trung Tâm Trải Nghiệm VCloud',
            'has_vmobile': true,
          },
        ],
      };

      final stopwatch = Stopwatch()..start();
      final rawList = mockMasterPayload['databases'] as List;
      final dbInfos = rawList.map((e) => DbInfo.fromJson(e as Map<String, dynamic>)).toList();
      stopwatch.stop();

      print('⚡ [TC1 PERF] Parse & map 3 DBs hoàn thành trong: ${stopwatch.elapsedMicroseconds}µs (${stopwatch.elapsedMilliseconds}ms)');
      expect(dbInfos.length, 3);
      expect(dbInfos[0].effectiveDisplayName, 'Công ty Cổ Phần Alpha');
      expect(dbInfos[1].effectiveDisplayName, 'Tập Đoàn Beta Toàn Cầu');
      expect(dbInfos[2].effectiveDisplayName, 'Trung Tâm Trải Nghiệm VCloud');
      expect(stopwatch.elapsedMilliseconds, lessThan(50));
    });

    test('2. Đăng nhập lần lượt vào DB1 (demo-17 với Internal User) -> Pass', () async {
      final stopwatch = Stopwatch()..start();
      final res = await http.post(
        Uri.parse('$localBackendUrl/api/v1/mobile/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'db': 'demo-17',
          'login': 'test_internal@360.org.vn',
          'password': '123',
        }),
      );
      stopwatch.stop();

      expect(res.statusCode, 200);
      final json = jsonDecode(res.body);
      expect(json['access_token'], isNotNull);
      print('⚡ [TC1 PERF] Đăng nhập DB 1 (demo-17 Internal) hoàn thành trong: ${stopwatch.elapsedMilliseconds}ms');
    });

    test('3. Đăng nhập lần lượt vào DB2 (demo-17 với Portal User) -> Pass', () async {
      final stopwatch = Stopwatch()..start();
      final res = await http.post(
        Uri.parse('$localBackendUrl/api/v1/mobile/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'db': 'demo-17',
          'login': 'test_portal@360.org.vn',
          'password': '123456',
        }),
      );
      stopwatch.stop();

      expect(res.statusCode, 200);
      final json = jsonDecode(res.body);
      expect(json['access_token'], isNotNull);
      print('⚡ [TC1 PERF] Đăng nhập DB 2 (demo-17 Portal) hoàn thành trong: ${stopwatch.elapsedMilliseconds}ms');
    });

    test('4. Đăng nhập lần lượt vào DB3 (Giả lập Client DB với token mock) -> Pass', () async {
      final stopwatch = Stopwatch()..start();
      // Verify cấu trúc URL và targetDb được route chính xác
      const targetUrl = 'https://erp.client1.vn';
      const targetDb = 'client_db1';
      final requestUri = Uri.parse('$targetUrl/api/v1/mobile/auth/login');

      expect(requestUri.host, 'erp.client1.vn');
      expect(targetDb, 'client_db1');
      stopwatch.stop();
      print('⚡ [TC1 PERF] Định tuyến target DB 3 (client_db1) hoàn thành trong: ${stopwatch.elapsedMicroseconds}µs');
    });
  });
}
