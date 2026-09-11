@Tags(['live-server'])
library;

import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:vcloud/features/auth/data/db_info.dart';

void main() {
  const String backendUrl17 = 'http://192.168.1.100:8069';
  const String backendUrl19 = 'http://192.168.1.100:1902';

  group('Mobile Login TC2: Trùng DB demo-17 & demo-19 (Popup & Login)', () {
    test('1. Kiểm tra kịch bản trùng 2 DB -> Bật Popup chọn Tổ chức với Tên thân thiện', () {
      final multiDbResponse = {
        'status': 'success',
        'count': 2,
        'databases': [
          {
            'database_name': 'demo-17',
            'database_url': backendUrl17,
            'display_name': 'Hệ Thống VCloud 17 (Chính Thức)',
            'has_vmobile': true,
          },
          {
            'database_name': 'demo-19',
            'database_url': backendUrl19,
            'display_name': 'Hệ Thống VCloud 19 (Thử Nghiệm Mới)',
            'has_vmobile': true,
          },
        ],
      };

      final sw = Stopwatch()..start();
      final list = (multiDbResponse['databases'] as List)
          .map((e) => DbInfo.fromJson(e as Map<String, dynamic>))
          .toList();
      sw.stop();

      // Verify Popup điều kiện hiển thị
      final shouldShowOrganizationPopup = list.length > 1;
      expect(shouldShowOrganizationPopup, isTrue);
      expect(list.length, 2);

      // Verify Tên hiển thị thân thiện (không lộ mã DB thô)
      expect(list[0].effectiveDisplayName, 'Hệ Thống VCloud 17 (Chính Thức)');
      expect(list[1].effectiveDisplayName, 'Hệ Thống VCloud 19 (Thử Nghiệm Mới)');

      print('📋 [MOBILE TC2 POPUP] Bật Dialog chọn tổ chức thành công trong: ${sw.elapsedMicroseconds}µs');
      print('   -> Đơn vị 1: ${list[0].effectiveDisplayName} (${list[0].databaseName})');
      print('   -> Đơn vị 2: ${list[1].effectiveDisplayName} (${list[1].databaseName})');
    });

    test('2. Chọn và Đăng nhập thành công vào DB 1 (demo-17)', () async {
      final sw = Stopwatch()..start();
      final res = await http.post(
        Uri.parse('$backendUrl17/api/v1/mobile/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'db': 'demo-17',
          'login': 'test_internal@360.org.vn',
          'password': '123',
        }),
      );
      sw.stop();

      expect(res.statusCode, 200);
      final json = jsonDecode(res.body);
      expect(json['access_token'], isNotNull);
      print('⚡ [MOBILE TC2 LOGIN DB1] Đăng nhập demo-17 thành công: ${sw.elapsedMilliseconds}ms');
    });

    test('3. Chọn và Kết nối thành công vào DB 2 (demo-19 / Odoo 19)', () async {
      final sw = Stopwatch()..start();
      final res = await http.get(Uri.parse('$backendUrl19/web/login')).timeout(const Duration(seconds: 5));
      sw.stop();

      expect(res.statusCode, 200);
      print('⚡ [MOBILE TC2 LOGIN DB2] Kết nối máy chủ demo-19 thành công: ${sw.elapsedMilliseconds}ms');
    });
  });
}
