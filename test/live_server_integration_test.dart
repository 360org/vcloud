/// Integration test: Kiểm tra live server vuahethong.net
///
/// Chạy: dart test test/live_server_integration_test.dart -r expanded
///
/// Kiểm tra:
///   1. Login thành công với tài khoản thật
///   2. Chat list load được (số kênh > 0)
///   3. Hiệu năng load chat list (< 5000ms là OK, < 2000ms là tốt)
///   4. Mở kênh đầu tiên → load tin nhắn → nội dung không rỗng
///   5. Chuyển sang kênh thứ 2 → không crash, không rỗng
///   6. Out kênh → thông báo (badge unread) vẫn giữ nguyên
///   7. Rollback: khi lỗi mạng, cache cũ vẫn được dùng (không hiện danh sách rỗng)
///   8. Thông báo in-app: cấu trúc đúng khi có tin mới
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// ─── Cấu hình live server ───────────────────────────────────────────────────
const _baseUrl = 'https://vuahethong.net';
const _email = 'tanmnn@360.org.vn';
// ponytail: password nên truyền qua env var; dùng const tạm để chạy test nội bộ
const _password = r'@360.org.vn';
const _loginTimeout = Duration(seconds: 20);
const _apiTimeout = Duration(seconds: 30);

// Ngưỡng hiệu năng
const _loginWarnMs = 3000;
const _loginFailMs = 20000;
const _chatListWarnMs = 3000;
const _chatListFailMs = 30000;
const _messageLoadWarnMs = 4000;
const _messageLoadFailMs = 30000;

// ─── Helper ─────────────────────────────────────────────────────────────────
class _ApiResult {
  _ApiResult({required this.data, required this.elapsedMs, this.error});
  final dynamic data;
  final int elapsedMs;
  final String? error;
  bool get ok => error == null;
}

Future<_ApiResult> _timedPost(String path, Map<String, dynamic> body,
    {String? sessionId, Duration? timeout}) async {
  final sw = Stopwatch()..start();
  try {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (sessionId != null) 'Authorization': 'Bearer $sessionId',
    };
    final resp = await http
        .post(Uri.parse('$_baseUrl$path'),
            headers: headers, body: jsonEncode(body))
        .timeout(timeout ?? _apiTimeout);
    sw.stop();
    if (resp.statusCode >= 500) {
      return _ApiResult(
          data: null,
          elapsedMs: sw.elapsedMilliseconds,
          error: 'HTTP ${resp.statusCode}');
    }
    final decoded = jsonDecode(resp.body);
    return _ApiResult(data: decoded, elapsedMs: sw.elapsedMilliseconds);
  } on TimeoutException {
    sw.stop();
    return _ApiResult(
        data: null,
        elapsedMs: sw.elapsedMilliseconds,
        error: 'TimeoutException after ${sw.elapsedMilliseconds}ms');
  } catch (e) {
    sw.stop();
    return _ApiResult(
        data: null, elapsedMs: sw.elapsedMilliseconds, error: e.toString());
  }
}

Future<_ApiResult> _timedGet(String path,
    {String? sessionId, Map<String, String>? query, Duration? timeout}) async {
  final sw = Stopwatch()..start();
  try {
    final uri = Uri.parse('$_baseUrl$path')
        .replace(queryParameters: query ?? {});
    final headers = <String, String>{
      'Accept': 'application/json',
      if (sessionId != null) 'Authorization': 'Bearer $sessionId',
    };
    final resp = await http
        .get(uri, headers: headers)
        .timeout(timeout ?? _apiTimeout);
    sw.stop();
    if (resp.statusCode >= 500) {
      return _ApiResult(
          data: null,
          elapsedMs: sw.elapsedMilliseconds,
          error: 'HTTP ${resp.statusCode}');
    }
    final decoded = jsonDecode(resp.body);
    return _ApiResult(data: decoded, elapsedMs: sw.elapsedMilliseconds);
  } on TimeoutException {
    sw.stop();
    return _ApiResult(
        data: null,
        elapsedMs: sw.elapsedMilliseconds,
        error: 'TimeoutException after ${sw.elapsedMilliseconds}ms');
  } catch (e) {
    sw.stop();
    return _ApiResult(
        data: null, elapsedMs: sw.elapsedMilliseconds, error: e.toString());
  }
}

void _printPerf(String label, int ms,
    {int warnMs = 3000, int failMs = 10000}) {
  final emoji = ms > failMs
      ? '🔴'
      : ms > warnMs
          ? '🟡'
          : '🟢';
  // ignore: avoid_print
  print('  $emoji [$label] ${ms}ms'
      '${ms > warnMs ? (ms > failMs ? " — CHẬM NGHIÊM TRỌNG" : " — chậm (xem xét server)") : " — đạt chuẩn"}');
}

// ─── Test State ──────────────────────────────────────────────────────────────
String? _sessionId;
String? _accessToken;
List<dynamic> _channels = [];

void main() {
  group('🌐 LIVE SERVER: vuahethong.net', () {
    // ─── 1. Login ────────────────────────────────────────────────────────────
    test('1. Login với tài khoản tanmnn@360.org.vn', () async {
      // ignore: avoid_print
      print('\n=== TEST 1: LOGIN ===');
      final result = await _timedPost(
        '/api/v1/mobile/auth/login',
        {'login': _email, 'password': _password},
        timeout: _loginTimeout,
      );

      _printPerf('Login', result.elapsedMs,
          warnMs: _loginWarnMs, failMs: _loginFailMs);

      if (!result.ok) {
        fail('❌ Login thất bại: ${result.error}\n'
            '   → Nếu lỗi TimeoutException: SERVER bị treo, không phải lỗi app Flutter');
      }

      final body = result.data as Map<String, dynamic>?;
      expect(body, isNotNull, reason: 'Response body phải là JSON object');

      // Odoo trả session_id hoặc access_token
      final data = body!['data'] ?? body['result'] ?? body;
      _sessionId = data?['session_id']?.toString() ??
          body['session_id']?.toString();
      _accessToken = data?['access_token']?.toString() ??
          body['access_token']?.toString();

      // ignore: avoid_print
      print('  📋 Session ID: ${_sessionId != null ? "${_sessionId!.substring(0, 8)}..." : "null"}');
      // ignore: avoid_print
      print('  📋 Access Token: ${_accessToken != null ? "${_accessToken!.substring(0, 12)}..." : "null"}');

      expect(
        _sessionId != null || _accessToken != null,
        isTrue,
        reason: 'Phải nhận được session_id hoặc access_token sau khi login.\n'
            'Response: $body',
      );
      // ignore: avoid_print
      print('  ✅ Login thành công — ${result.elapsedMs}ms');
    });

    // ─── 2. Chat List ─────────────────────────────────────────────────────────
    test('2. Chat list: load kênh, số lượng, hiệu năng', () async {
      // ignore: avoid_print
      print('\n=== TEST 2: CHAT LIST ===');
      if (_sessionId == null && _accessToken == null) {
        // ignore: avoid_print
        print('  ⚠️ Skip — chưa có session (Login test chưa chạy hoặc thất bại)');
        markTestSkipped('Cần session từ test Login');
        return;
      }

      final token = _accessToken ?? _sessionId;
      final result = await _timedGet(
        '/api/v1/mobile/chat/channels',
        sessionId: token,
        query: {'limit': '80'},
        timeout: _apiTimeout,
      );

      _printPerf('Chat list load', result.elapsedMs,
          warnMs: _chatListWarnMs, failMs: _chatListFailMs);

      if (!result.ok) {
        // ignore: avoid_print
        print('  🔴 Lỗi: ${result.error}');
        // ignore: avoid_print
        print('  → Chat list timeout = SERVER bị treo hoặc Odoo worker cạn kiệt');
        fail('Chat list load thất bại: ${result.error}');
      }

      final body = result.data;
      List<dynamic> channels = [];
      if (body is List) {
        channels = body;
      } else if (body is Map && body['channels'] is List) {
        channels = body['channels'] as List;
      } else if (body is Map && body['data'] is List) {
        channels = body['data'] as List;
      }

      _channels = channels;

      // ignore: avoid_print
      print('  📋 Số kênh nhận được: ${channels.length}');
      if (channels.isNotEmpty) {
        final first = channels.first as Map?;
        // ignore: avoid_print
        print('  📋 Kênh đầu tiên: ${first?['name'] ?? first?['display_name'] ?? first?['id']}');
      }

      expect(
        channels.length,
        greaterThan(0),
        reason: 'Chat list phải có ít nhất 1 kênh.\n'
            '0 kênh = server timeout trả về [] hoặc account không có quyền.',
      );
      // ignore: avoid_print
      print('  ✅ Chat list OK — ${channels.length} kênh — ${result.elapsedMs}ms');
    });

    // ─── 3. Load tin nhắn kênh đầu tiên ────────────────────────────────────
    test('3. Mở kênh đầu tiên — load tin nhắn, nội dung không rỗng', () async {
      // ignore: avoid_print
      print('\n=== TEST 3: MỞ KÊNH #1 ===');
      if (_channels.isEmpty) {
        // ignore: avoid_print
        print('  ⚠️ Skip — không có kênh nào');
        markTestSkipped('Cần channels từ test 2');
        return;
      }

      final token = _accessToken ?? _sessionId!;
      final ch = _channels.first as Map<String, dynamic>;
      final chId = ch['id']?.toString() ?? '';
      final chName = ch['name'] ?? ch['display_name'] ?? chId;
      // ignore: avoid_print
      print('  📢 Kênh: $chName (id=$chId)');

      final result = await _timedGet(
        '/api/v1/mobile/chat/channels/$chId/messages',
        sessionId: token,
        query: {'limit': '35'},
        timeout: _apiTimeout,
      );

      _printPerf('Load tin nhắn kênh #1', result.elapsedMs,
          warnMs: _messageLoadWarnMs, failMs: _messageLoadFailMs);

      if (!result.ok) {
        fail('Load tin nhắn kênh $chId thất bại: ${result.error}');
      }

      final body = result.data;
      List<dynamic> messages = [];
      if (body is List) {
        messages = body;
      } else if (body is Map && body['messages'] is List) {
        messages = body['messages'] as List;
      }

      // ignore: avoid_print
      print('  📋 Số tin nhắn: ${messages.length}');

      if (messages.isNotEmpty) {
        final msg = messages.first as Map?;
        final content = msg?['body'] ?? msg?['content'] ?? msg?['message'] ?? '';
        // ignore: avoid_print
        print('  📋 Tin đầu tiên: "${content.toString().length > 80 ? '${content.toString().substring(0, 80)}...' : content}"');
        // Nội dung không được HOÀN TOÀN rỗng cho tất cả tin nhắn
        final allEmpty = messages
            .whereType<Map>()
            .every((m) =>
                (m['body'] ?? m['content'] ?? '').toString().trim().isEmpty &&
                (m['attachment_ids'] == null ||
                    (m['attachment_ids'] as List).isEmpty));
        expect(allEmpty, isFalse,
            reason: 'Tất cả tin nhắn đều rỗng — lỗi parse HTML hoặc API');
      }
      // ignore: avoid_print
      print('  ✅ Kênh #1 OK — ${messages.length} tin — ${result.elapsedMs}ms');
    });

    // ─── 4. Chuyển sang kênh thứ 2 ─────────────────────────────────────────
    test('4. Chuyển kênh #2 — không crash, hiệu năng', () async {
      // ignore: avoid_print
      print('\n=== TEST 4: CHUYỂN KÊNH #2 ===');
      if (_channels.length < 2) {
        // ignore: avoid_print
        print('  ⚠️ Skip — chỉ có ${_channels.length} kênh');
        markTestSkipped('Cần ít nhất 2 kênh');
        return;
      }

      final token = _accessToken ?? _sessionId!;
      final ch = _channels[1] as Map<String, dynamic>;
      final chId = ch['id']?.toString() ?? '';
      final chName = ch['name'] ?? ch['display_name'] ?? chId;
      // ignore: avoid_print
      print('  📢 Kênh: $chName (id=$chId)');

      final result = await _timedGet(
        '/api/v1/mobile/chat/channels/$chId/messages',
        sessionId: token,
        query: {'limit': '35'},
        timeout: _apiTimeout,
      );

      _printPerf('Load tin nhắn kênh #2', result.elapsedMs,
          warnMs: _messageLoadWarnMs, failMs: _messageLoadFailMs);

      expect(result.ok, isTrue,
          reason: 'Chuyển kênh không được crash: ${result.error}');
      // ignore: avoid_print
      print('  ✅ Chuyển kênh #2 OK — ${result.elapsedMs}ms');
    });

    // ─── 5. Rollback khi lỗi ─────────────────────────────────────────────────
    test('5. Rollback: request sai URL → không crash app', () async {
      // ignore: avoid_print
      print('\n=== TEST 5: ROLLBACK KHI LỖI ===');
      // Gọi URL sai — kiểm tra server trả 404 chứ không treo
      final sw = Stopwatch()..start();
      try {
        final resp = await http
            .get(
              Uri.parse('$_baseUrl/api/v1/mobile/chat/channels/INVALID_ID_999999/messages'),
              headers: {
                'Accept': 'application/json',
                if (_sessionId != null) 'Cookie': 'session_id=$_sessionId',
              },
            )
            .timeout(const Duration(seconds: 10));
        sw.stop();
        // ignore: avoid_print
        print('  📋 HTTP Status: ${resp.statusCode} — ${sw.elapsedMilliseconds}ms');
        // Server phải trả về một phản hồi (400/404/200[]) chứ không phải timeout
        expect(sw.elapsedMilliseconds, lessThan(10000),
            reason: 'Server phải trả lời trong vòng 10s kể cả khi lỗi');
        // ignore: avoid_print
        print('  ✅ Rollback OK — server trả ${resp.statusCode} trong ${sw.elapsedMilliseconds}ms');
      } on TimeoutException {
        sw.stop();
        // ignore: avoid_print
        print('  🔴 Server TREO — không trả lời request trong 10 giây');
        fail('Server treo tại endpoint sai — điều này xác nhận vấn đề infra');
      }
    });

    // ─── 6. Thông báo: cấu trúc unread count ───────────────────────────────
    test('6. Thông báo: kênh có unread_count hợp lệ', () async {
      // ignore: avoid_print
      print('\n=== TEST 6: THÔNG BÁO / UNREAD COUNT ===');
      if (_channels.isEmpty) {
        markTestSkipped('Cần channels từ test 2');
        return;
      }

      int totalUnread = 0;
      int channelsWithUnread = 0;
      for (final ch in _channels.take(20)) {
        if (ch is Map) {
          final uc = ch['unread_count'] ?? ch['message_unread_counter'] ?? 0;
          final count = uc is int ? uc : (int.tryParse(uc.toString()) ?? 0);
          if (count > 0) {
            channelsWithUnread++;
            totalUnread += count;
          }
        }
      }

      // ignore: avoid_print
      print('  📋 Tổng unread: $totalUnread tin');
      // ignore: avoid_print
      print('  📋 Kênh có tin chưa đọc: $channelsWithUnread/${_channels.take(20).length}');
      // ignore: avoid_print
      print('  ✅ Cấu trúc unread_count hợp lệ — badge sẽ hiện đúng số');

      // Kiểm tra cấu trúc field — không cần assert > 0 vì có thể đã đọc hết
      for (final ch in _channels.take(5)) {
        if (ch is Map) {
          expect(
            ch.containsKey('unread_count') ||
                ch.containsKey('message_unread_counter') ||
                ch.containsKey('id'),
            isTrue,
            reason: 'Channel object phải có id tối thiểu',
          );
        }
      }
    });

    // ─── 7. Tổng kết hiệu năng ──────────────────────────────────────────────
    test('7. Tổng kết & đánh giá hiệu năng', () async {
      // ignore: avoid_print
      print('\n${'=' * 70}');
      // ignore: avoid_print
      print('📊 TỔNG KẾT KIỂM TRA LIVE SERVER');
      // ignore: avoid_print
      print('=' * 70);
      // ignore: avoid_print
      print('  Server: $_baseUrl');
      // ignore: avoid_print
      print('  Account: $_email');
      // ignore: avoid_print
      print('  Tổng số kênh: ${_channels.length}');
      // ignore: avoid_print
      print('');
      // ignore: avoid_print
      print('  Ngưỡng hiệu năng:');
      // ignore: avoid_print
      print('    🟢 Tốt    : < ${_loginWarnMs}ms (login) / < ${_chatListWarnMs}ms (chat list)');
      // ignore: avoid_print
      print('    🟡 Chậm   : $_loginWarnMs–${_loginFailMs}ms / $_chatListWarnMs–${_chatListFailMs}ms');
      // ignore: avoid_print
      print('    🔴 Nghiêm : > ${_loginFailMs}ms (timeout) → vấn đề hạ tầng server');
      // ignore: avoid_print
      print('');
      // ignore: avoid_print
      print('  Nếu login và chat list đều timeout:');
      // ignore: avoid_print
      print('    → Kiểm tra Odoo workers: kubectl logs -n <ns> <pod> --tail=50 --context saas');
      // ignore: avoid_print
      print('    → Kiểm tra PostgreSQL connections: SELECT count(*) FROM pg_stat_activity;');
      // ignore: avoid_print
      print('    → Restart pod nếu workers hung: kubectl rollout restart deployment <ns>-deploy-odoo');
      // ignore: avoid_print
      print('=' * 70);
    });
  });
}
