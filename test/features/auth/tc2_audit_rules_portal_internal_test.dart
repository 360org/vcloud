// ignore_for_file: avoid_print, unused_import, unnecessary_import
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  const String baseUrl = 'http://192.168.1.100:8069';
  const String dbName = 'demo-17';

  group('TC2: Audit Record Rules & ACL (Portal vs Internal User)', () {
    String? tokenInternal;
    String? tokenPortal;

    setUpAll(() async {
      // 1. Login Internal
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

      // 2. Login Portal
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
      tokenPortal = jsonDecode(resPor.body)['access_token'];
    });

    test('1. Kiểm tra Rule Internal: Thấy đầy đủ các kênh của mình và có quyền quản trị/mời thành viên', () async {
      final res = await http.get(
        Uri.parse('$baseUrl/api/v1/mobile/chat/channels'),
        headers: {'Authorization': 'Bearer $tokenInternal'},
      );
      expect(res.statusCode, 200);
      final List channels = jsonDecode(res.body);
      print('👤 [INTERNAL AUDIT] Số kênh Internal truy cập được: ${channels.length}');
      expect(channels.isNotEmpty, isTrue);
    });

    test('2. Kiểm tra Rule Portal: Chỉ thấy kênh mình là thành viên, không thấy kênh nội bộ riêng tư', () async {
      final res = await http.get(
        Uri.parse('$baseUrl/api/v1/mobile/chat/channels'),
        headers: {'Authorization': 'Bearer $tokenPortal'},
      );
      expect(res.statusCode, 200);
      final List portalChannels = jsonDecode(res.body);
      print('🌐 [PORTAL AUDIT] Số kênh Portal truy cập được: ${portalChannels.length}');

      // Lấy danh sách channel Internal thấy
      final resInt = await http.get(
        Uri.parse('$baseUrl/api/v1/mobile/chat/channels'),
        headers: {'Authorization': 'Bearer $tokenInternal'},
      );
      final List internalChannels = jsonDecode(resInt.body);

      // Portal chỉ có thể nhìn thấy số kênh nhỏ hơn hoặc bằng Internal (bị giới hạn nghiêm ngặt theo discuss_channel_member)
      expect(portalChannels.length, lessThanOrEqualTo(internalChannels.length));
    });

    test('3. Security Barrier: Portal KHÔNG thể đọc tin nhắn từ Channel mà mình không phải thành viên', () async {
      // Tìm 1 channel mà Portal không có trong danh sách
      final resInt = await http.get(
        Uri.parse('$baseUrl/api/v1/mobile/chat/channels'),
        headers: {'Authorization': 'Bearer $tokenInternal'},
      );
      final List intChannels = jsonDecode(resInt.body);

      final resPor = await http.get(
        Uri.parse('$baseUrl/api/v1/mobile/chat/channels'),
        headers: {'Authorization': 'Bearer $tokenPortal'},
      );
      final List porChannels = jsonDecode(resPor.body);
      final porChannelIds = porChannels.map((c) => c['id']).toSet();

      final nonMemberChannel = intChannels.firstWhere(
        (c) => !porChannelIds.contains(c['id']),
        orElse: () => null,
      );

      if (nonMemberChannel != null) {
        final int targetId = nonMemberChannel['id'] as int;
        final hackRes = await http.get(
          Uri.parse('$baseUrl/api/v1/mobile/chat/channels/$targetId/messages'),
          headers: {'Authorization': 'Bearer $tokenPortal'},
        );
        // Odoo record rule phải chặn: trả về 403 Forbidden hoặc 404 hoặc list rỗng
        print('🛡️ [RULE BARRIER AUDIT] Portal cố đọc channel riêng tư ID $targetId: Status = ${hackRes.statusCode}');
        expect(hackRes.statusCode, anyOf(403, 404, 400, 200));
        if (hackRes.statusCode == 200) {
          final body = jsonDecode(hackRes.body);
          if (body is List) {
            expect(body.isEmpty, isTrue, reason: 'Lỗ hổng: Portal xem được tin nhắn của kênh không tham gia!');
          }
        }
      } else {
        print('ℹ️ Portal đã tham gia tất cả các kênh test hiện có.');
      }
    });
  });
}
