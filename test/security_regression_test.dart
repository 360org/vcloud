// Regression tests — security fixes v2.9.9+135
// 1) lookupDb must NOT include password in request body (Finding 1.1)
// 2) LocalAttachmentCache.clearAllCache is callable (logout cache wipe)
// Run: flutter test test/security_regression_test.dart

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vcloud/core/api/odoo_api_client.dart';
import 'package:vcloud/core/utils/local_attachment_cache.dart';

void main() {
  group('Security Regression (v2.9.9+135)', () {
    // ── Finding 1.1: lookupDb không được gửi password lên Master ──────────────
    test('lookupDb request body must not contain "password" key', () async {
      String? capturedBody;

      final mockClient = MockClient((request) async {
        if (request.url.path.contains('lookup-db')) {
          capturedBody = request.body;
          // Trả 200 empty list để vượt qua parse
          return http.Response(
            jsonEncode({'databases': []}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final client = OdooApiClient(httpClient: mockClient);
      await client.lookupDb('test@example.com', preferredDb: null);

      expect(capturedBody, isNotNull,
          reason: 'lookup-db endpoint should have been called');
      final bodyMap = jsonDecode(capturedBody!) as Map;
      expect(bodyMap.containsKey('password'), isFalse,
          reason: 'payload to Master Router MUST NOT contain password field');
    });

    // ── Finding 2.2 / Logout cache wipe: clearAllCache callable ────────────────
    test('LocalAttachmentCache.clearAllCache exists and is callable', () {
      // Chỉ verify symbol tồn tại — môi trường test không có file system thực
      expect(LocalAttachmentCache.clearAllCache, isA<Function>());
    });
  });
}
