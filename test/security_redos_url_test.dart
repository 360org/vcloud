// ignore_for_file: avoid_print
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Security & ReDoS Verification for URL Regex', () {
    final safeUrlRegex = RegExp(
      r'((?:https?:\/\/|vcloud:\/\/|www\.)[^\s<]+|[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*\.[a-zA-Z]{2,}(?:\/[^\s<]*)?)',
      caseSensitive: false,
    );

    test('1. Valid URLs must match correctly', () {
      expect(safeUrlRegex.hasMatch('Truy cap https://vuahethong.net ngay'), isTrue);
      expect(safeUrlRegex.hasMatch('Xem them tai www.google.com'), isTrue);
      expect(safeUrlRegex.hasMatch('domain.vn/path/to/resource'), isTrue);
      expect(safeUrlRegex.hasMatch('deep.sub.domain.co.uk'), isTrue);
      expect(safeUrlRegex.hasMatch('vcloud://open/channel/123'), isTrue);
    });

    test('2. Adversarial ReDoS payload — max 20ms cho chuỗi 1000 ký tự không khớp', () {
      final attackPayload = '${'a-' * 500}X';
      final stopwatch = Stopwatch()..start();
      final hasMatch = safeUrlRegex.hasMatch(attackPayload);
      stopwatch.stop();

      print('[PERF METRIC] ReDoS payload 1000 chars: ${stopwatch.elapsedMicroseconds} µs (${stopwatch.elapsedMilliseconds} ms)');
      expect(stopwatch.elapsedMilliseconds, lessThan(20), reason: 'Regex too slow — potential ReDoS');
      expect(hasMatch, isFalse);
    });

    test('3. Repetitive dot payload — max 20ms', () {
      final dotPayload = '${'a.b.' * 200}c';
      final stopwatch = Stopwatch()..start();
      safeUrlRegex.allMatches(dotPayload);
      stopwatch.stop();

      print('[PERF METRIC] Repetitive dot payload: ${stopwatch.elapsedMicroseconds} µs');
      expect(stopwatch.elapsedMilliseconds, lessThan(20));
    });
  });
}
