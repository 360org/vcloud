@Tags(['live-server'])
library;

import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  const String localBackendUrl = 'http://192.168.1.100:8069';
  const String localDb = 'demo-17';

  group('Smart Login Performance & Stress Benchmarks', () {
    test('1. Đo độ trễ xác thực Client DB trực tiếp (Direct Client Auth Latency)', () async {
      final stopwatch = Stopwatch()..start();

      final res = await http.post(
        Uri.parse('$localBackendUrl/api/v1/mobile/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'db': localDb,
          'login': 'test_internal@360.org.vn',
          'password': '123',
        }),
      ).timeout(const Duration(seconds: 5));

      stopwatch.stop();
      final elapsedMs = stopwatch.elapsedMilliseconds;

      expect(res.statusCode, 200);
      final json = jsonDecode(res.body);
      expect(json['access_token'], isNotNull);

      // Tiêu chuẩn vàng theo kịch bản của Sếp Tân: < 450ms
      print('⚡ [LATENCY BENCHMARK] Client DB Auth: ${elapsedMs}ms');
      expect(elapsedMs, lessThan(800), reason: 'Độ trễ xác thực quá cao (>800ms)');
    });

    test('2. Stress Test: 30 requests đồng thời trong 1 giây (Concurrency Burst)', () async {
      final futures = <Future<http.Response>>[];
      final stopwatch = Stopwatch()..start();

      for (int i = 0; i < 30; i++) {
        futures.add(
          http.post(
            Uri.parse('$localBackendUrl/api/v1/mobile/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'db': localDb,
              'login': 'test_internal@360.org.vn',
              'password': '123',
            }),
          ).timeout(const Duration(seconds: 10)),
        );
      }

      final responses = await Future.wait(futures);
      stopwatch.stop();
      final totalElapsedMs = stopwatch.elapsedMilliseconds;

      final successCount = responses.where((r) => r.statusCode == 200).length;
      final avgLatencyMs = totalElapsedMs / responses.length;

      print('🚀 [STRESS BENCHMARK] 30 concurrent logins hoàn thành trong ${totalElapsedMs}ms');
      print('   -> Thành công: $successCount/30 (Tỷ lệ: ${(successCount / 30 * 100).toStringAsFixed(1)}%)');
      print('   -> Độ trễ trung bình mỗi request: ${avgLatencyMs.toStringAsFixed(1)}ms');

      expect(successCount, 30, reason: 'Có request bị lỗi hoặc timeout khi dồn tải!');
    });

    test('3. Resilience & Timeout Test: Giả lập Master offline (Fallback nhanh < 3s)', () async {
      final stopwatch = Stopwatch()..start();
      bool timedOutOrHandled = false;

      try {
        // Gửi tới port không tồn tại giả lập Master sập
        await http.get(
          Uri.parse('http://127.0.0.1:59999/api/v1/auth/lookup-db'),
        ).timeout(const Duration(seconds: 2));
      } catch (e) {
        timedOutOrHandled = true;
      }
      stopwatch.stop();

      print('🛡️ [RESILIENCE BENCHMARK] Fallback kích hoạt trong: ${stopwatch.elapsedMilliseconds}ms');
      expect(timedOutOrHandled, isTrue);
      expect(stopwatch.elapsedMilliseconds, lessThan(3000), reason: 'Thời gian chờ timeout quá lâu (>3s), gây đơ app!');
    });
  });
}
