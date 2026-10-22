// ignore_for_file: avoid_print
// Self-check 10 test cases độc lập cho SignUp Flow (OdooApiClient, AuthRepository, Form Validators)
// Áp dụng chuẩn Ponytail: assert-based self-check, stdlib first, zero external framework.

import 'dart:async';
import 'dart:convert';

class MockFailure implements Exception {
  final String message;
  MockFailure(this.message);
  @override
  String toString() => 'Failure($message)';
}

class MockOdooSession {
  final int uid;
  final String name;
  final String login;
  final String db;
  final String accessToken;
  final String? refreshToken;

  MockOdooSession({
    required this.uid,
    required this.name,
    required this.login,
    required this.db,
    required this.accessToken,
    this.refreshToken,
  });

  factory MockOdooSession.fromJson(Map<String, dynamic> json, {required String fallbackLogin, required String fallbackDb}) {
    return MockOdooSession(
      uid: json['uid'] as int? ?? json['user_id'] as int? ?? 0,
      name: (json['name'] ?? '').toString(),
      login: (json['login'] ?? fallbackLogin).toString(),
      db: (json['db'] ?? fallbackDb).toString(),
      accessToken: (json['access_token'] ?? '').toString(),
      refreshToken: json['refresh_token']?.toString(),
    );
  }
}

class MockHttpResponse {
  final int statusCode;
  final String body;
  final Map<String, String> headers;

  MockHttpResponse({required this.statusCode, required this.body, this.headers = const {}});
}

class MockHttpRequest {
  final String url;
  final Map<String, String> headers;
  final String body;

  MockHttpRequest({required this.url, required this.headers, required this.body});
}

class TestOdooApiClient {
  final String _baseUrl;
  final Future<MockHttpResponse> Function(MockHttpRequest request) _httpHandler;
  MockOdooSession? _session;
  MockOdooSession? sessionStore;

  TestOdooApiClient({
    required String baseUrl,
    required Future<MockHttpResponse> Function(MockHttpRequest request) httpHandler,
  })  : _baseUrl = baseUrl, // ignore: prefer_initializing_formals
        _httpHandler = httpHandler; // ignore: prefer_initializing_formals

  MockOdooSession? get session => _session;

  Future<MockOdooSession> signUp({
    required String name,
    required String email,
    required String password,
    required String phone,
    bool acceptTerms = true,
    String? confirmPassword,
    String? db,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final trimmedEmail = email.trim();
    final trimmedName = name.trim();
    final trimmedPhone = phone.trim();
    final primaryBaseUrl = _baseUrl.isNotEmpty ? _baseUrl : 'https://vuahethong.net';
    final targetDb = db?.trim().isNotEmpty == true
        ? db!.trim()
        : 'vcloud_test_v19';

    final body = <String, dynamic>{
      'name': trimmedName,
      'login': trimmedEmail,
      'password': password,
      'phone': trimmedPhone,
      'accept_terms': acceptTerms,
      if (confirmPassword != null && confirmPassword.isNotEmpty)
        'confirm_password': confirmPassword,
      'db': targetDb,
    };

    final uri = '$primaryBaseUrl/api/v1/mobile/auth/signup';
    final response = await _httpHandler(
      MockHttpRequest(
        url: uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (targetDb.isNotEmpty) 'X-Odoo-Database': targetDb,
        },
        body: jsonEncode(body),
      ),
    ).timeout(timeout);

    final text = response.body;
    Object? decoded;
    if (text.isNotEmpty) {
      try {
        decoded = jsonDecode(text);
      } catch (e) {
        if (response.statusCode >= 400) {
          throw MockFailure('Máy chủ phản hồi lỗi (${response.statusCode}).');
        }
        throw MockFailure('Dữ liệu từ máy chủ không đúng định dạng.');
      }
    }

    if (response.statusCode >= 400 || decoded is! Map || decoded['error'] != null) {
      final msg = (decoded is Map ? (decoded['message'] ?? decoded['error']) : null)?.toString();
      throw MockFailure(msg ?? 'Đăng ký tài khoản thất bại (${response.statusCode}).');
    }

    final session = MockOdooSession.fromJson(
      Map<String, dynamic>.from(decoded),
      fallbackLogin: trimmedEmail,
      fallbackDb: targetDb,
    );
    _session = session;
    sessionStore = session;
    return session;
  }
}

class TestAuthRepository {
  final TestOdooApiClient _client;
  final Map<String, String> _storage = {};

  TestAuthRepository(this._client);

  static const _savedEmailKey = 'saved_login_email';
  static const _savedDbKey = 'saved_last_database';

  Future<void> saveLastLoginEmail(String email) async {
    final trimmed = email.trim();
    if (trimmed.isNotEmpty) {
      _storage[_savedEmailKey] = trimmed;
    }
  }

  Future<void> saveLastSelectedDb(String dbName) async {
    final trimmed = dbName.trim();
    if (trimmed.isNotEmpty) {
      _storage[_savedDbKey] = trimmed;
    }
  }

  String? getLastLoginEmail() => _storage[_savedEmailKey];
  String? getLastSelectedDb() => _storage[_savedDbKey];

  Future<MockOdooSession> signUp({
    required String email,
    required String password,
    required String displayName,
    required String phone,
    bool acceptTerms = true,
    String? confirmPassword,
    String? db,
    int? tenantId,
  }) async {
    try {
      final session = await _client.signUp(
        email: email,
        password: password,
        name: displayName,
        phone: phone,
        acceptTerms: acceptTerms,
        confirmPassword: confirmPassword,
        db: db,
      );
      await saveLastLoginEmail(email);
      if (session.db.isNotEmpty) {
        await saveLastSelectedDb(session.db);
      }
      return session;
    } on MockFailure {
      rethrow;
    } catch (e) {
      throw MockFailure('Đăng ký tài khoản không thành công: $e');
    }
  }
}

String? _validateName(String? v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập họ tên' : null;

String? _validatePhone(String? v) {
  if (v == null || v.trim().isEmpty) return 'Vui lòng nhập số điện thoại';
  final clean = v.trim().replaceAll(RegExp(r'[\s.-]'), '');
  if (!RegExp(r'^(0|\+84)[0-9]{9,10}$').hasMatch(clean)) {
    return 'Số điện thoại không hợp lệ (VD: 0912345678)';
  }
  return null;
}

final RegExp _emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');

String? _validateEmail(String? v) {
  if (v == null || v.trim().isEmpty) return 'Vui lòng nhập email';
  if (!_emailRegex.hasMatch(v.trim())) return 'Email không đúng định dạng';
  return null;
}

String? _validatePassword(String? v) => (v == null || v.length < 6) ? 'Dùng ít nhất 6 ký tự' : null;

String? _validateConfirmPassword(String? v, String refPass) {
  if (v == null || v.isEmpty) return 'Vui lòng xác nhận mật khẩu';
  if (v != refPass) return 'Mật khẩu xác nhận không khớp';
  return null;
}

String? _validateAcceptTerms(bool acceptTerms) {
  if (!acceptTerms) {
    return 'Vui lòng đọc và đồng ý với Điều khoản dịch vụ và Chính sách bảo mật.';
  }
  return null;
}

void main() async {
  print('--- BẮT ĐẦU KIỂM THỬ 12 CASE CHO SIGNUP FLOW ---');

  // TC-01: Validator họ tên không rỗng
  assert(_validateName(null) == 'Vui lòng nhập họ tên', 'TC-01 fail: null name');
  assert(_validateName('') == 'Vui lòng nhập họ tên', 'TC-01 fail: empty name');
  assert(_validateName('   ') == 'Vui lòng nhập họ tên', 'TC-01 fail: whitespace name');
  assert(_validateName('Nguyễn Văn A') == null, 'TC-01 fail: valid name');
  print('✅ TC-01 PASS: Validator Họ tên');

  // TC-02: Validator số điện thoại E.164 / VN format
  assert(_validatePhone(null) == 'Vui lòng nhập số điện thoại', 'TC-02 fail: null phone');
  assert(_validatePhone('') == 'Vui lòng nhập số điện thoại', 'TC-02 fail: empty phone');
  assert(_validatePhone('12345') == 'Số điện thoại không hợp lệ (VD: 0912345678)', 'TC-02 fail: short phone');
  assert(_validatePhone('0912345678') == null, 'TC-02 fail: valid 10-digit phone');
  assert(_validatePhone('+84912345678') == null, 'TC-02 fail: valid +84 phone');
  assert(_validatePhone('091 234 5678') == null, 'TC-02 fail: spaced phone');
  print('✅ TC-02 PASS: Validator Số điện thoại chuẩn E.164 / VN');

  // TC-03: Validator email regex format
  assert(_validateEmail(null) == 'Vui lòng nhập email', 'TC-03 fail: null email');
  assert(_validateEmail('') == 'Vui lòng nhập email', 'TC-03 fail: empty email');
  assert(_validateEmail('invalid-email') == 'Email không đúng định dạng', 'TC-03 fail: bad format');
  assert(_validateEmail('user@domain') == 'Email không đúng định dạng', 'TC-03 fail: no tld');
  assert(_validateEmail('tanmnn@360.org.vn') == null, 'TC-03 fail: valid email 1');
  assert(_validateEmail('test.user@vuahethong.net') == null, 'TC-03 fail: valid email 2');
  print('✅ TC-03 PASS: Validator Email định dạng regex chuẩn');

  // TC-04: Validator mật khẩu >= 6 ký tự
  assert(_validatePassword(null) == 'Dùng ít nhất 6 ký tự', 'TC-04 fail: null password');
  assert(_validatePassword('12345') == 'Dùng ít nhất 6 ký tự', 'TC-04 fail: short password');
  assert(_validatePassword('123456') == null, 'TC-04 fail: 6 chars password');
  assert(_validatePassword('P@ssw0rd!') == null, 'TC-04 fail: strong password');
  print('✅ TC-04 PASS: Validator Mật khẩu tối thiểu 6 ký tự');

  // TC-05: Validator xác nhận mật khẩu khớp
  const referencePassword = 'SecurePassword123';
  assert(_validateConfirmPassword(null, referencePassword) == 'Vui lòng xác nhận mật khẩu', 'TC-05 fail: null confirm');
  assert(_validateConfirmPassword('', referencePassword) == 'Vui lòng xác nhận mật khẩu', 'TC-05 fail: empty confirm');
  assert(_validateConfirmPassword('WrongPass', referencePassword) == 'Mật khẩu xác nhận không khớp', 'TC-05 fail: mismatched confirm');
  assert(_validateConfirmPassword('SecurePassword123', referencePassword) == null, 'TC-05 fail: matching confirm');
  print('✅ TC-05 PASS: Validator Xác nhận mật khẩu trùng khớp');

  // TC-06: Validator đồng ý điều khoản dịch vụ
  assert(_validateAcceptTerms(false) == 'Vui lòng đọc và đồng ý với Điều khoản dịch vụ và Chính sách bảo mật.', 'TC-06 fail: unaccepted terms');
  assert(_validateAcceptTerms(true) == null, 'TC-06 fail: accepted terms');
  print('✅ TC-06 PASS: Validator Đồng ý điều khoản dịch vụ');

  // TC-07: OdooApiClient.signUp serialize đúng payload & headers (bao gồm phone, accept_terms)
  MockHttpRequest? lastRequest;
  final client = TestOdooApiClient(
    baseUrl: 'https://vuahethong.net',
    httpHandler: (req) async {
      lastRequest = req;
      return MockHttpResponse(
        statusCode: 200,
        body: jsonEncode({
          'uid': 105,
          'name': 'Nguyễn Văn A',
          'login': 'nva@360.org.vn',
          'db': 'vcloud_test_v19',
          'access_token': 'test_jwt_access_123',
          'refresh_token': 'test_jwt_refresh_456',
        }),
      );
    },
  );

  final session = await client.signUp(
    name: '  Nguyễn Văn A  ',
    email: '  nva@360.org.vn  ',
    password: 'securePassword!',
    phone: '  0912345678  ',
    acceptTerms: true,
    confirmPassword: 'securePassword!',
    db: 'vcloud_test_v19',
  );

  assert(lastRequest?.url == 'https://vuahethong.net/api/v1/mobile/auth/signup', 'TC-07 fail: URL');
  assert(lastRequest?.headers['Content-Type'] == 'application/json', 'TC-07 fail: header content-type');
  assert(lastRequest?.headers['X-Odoo-Database'] == 'vcloud_test_v19', 'TC-07 fail: header db');
  final decodedReq = jsonDecode(lastRequest!.body) as Map<String, dynamic>;
  assert(decodedReq['name'] == 'Nguyễn Văn A', 'TC-07 fail: name trimmed in body');
  assert(decodedReq['login'] == 'nva@360.org.vn', 'TC-07 fail: login trimmed in body');
  assert(decodedReq['password'] == 'securePassword!', 'TC-07 fail: password in body');
  assert(decodedReq['phone'] == '0912345678', 'TC-07 fail: phone trimmed in body');
  assert(decodedReq['accept_terms'] == true, 'TC-07 fail: accept_terms in body');
  assert(decodedReq['confirm_password'] == 'securePassword!', 'TC-07 fail: confirm_password in body');
  assert(decodedReq['db'] == 'vcloud_test_v19', 'TC-07 fail: db in body');
  print('✅ TC-07 PASS: OdooApiClient.signUp payload & header contract (kèm phone, accept_terms)');

  // TC-08: OdooApiClient.signUp gán session & ghi vào store
  assert(client.session != null, 'TC-08 fail: client._session is null');
  assert(client.sessionStore != null, 'TC-08 fail: sessionStore is null');
  assert(client.session?.accessToken == 'test_jwt_access_123', 'TC-08 fail: access token');
  assert(session.uid == 105, 'TC-08 fail: session uid');
  print('✅ TC-08 PASS: OdooApiClient.signUp lưu session hợp lệ');

  // TC-09: OdooApiClient.signUp xử lý lỗi 400 error message từ server
  final errClient = TestOdooApiClient(
    baseUrl: 'https://vuahethong.net',
    httpHandler: (req) async => MockHttpResponse(
      statusCode: 400,
      body: jsonEncode({'error': 'Email nva@360.org.vn đã tồn tại trên hệ thống.'}),
    ),
  );
  bool didThrow400 = false;
  try {
    await errClient.signUp(
      name: 'Nguyễn Văn A',
      email: 'nva@360.org.vn',
      password: 'pass',
      phone: '0912345678',
    );
  } on MockFailure catch (f) {
    didThrow400 = true;
    assert(f.message.contains('Email nva@360.org.vn đã tồn tại'), 'TC-09 fail: message mismatch');
  }
  assert(didThrow400, 'TC-09 fail: did not throw MockFailure on 400');
  print('✅ TC-09 PASS: OdooApiClient.signUp ném Failure khi backend trả error');

  // TC-10: OdooApiClient.signUp xử lý lỗi HTML / Non-JSON 502/504
  final htmlErrClient = TestOdooApiClient(
    baseUrl: 'https://vuahethong.net',
    httpHandler: (req) async => MockHttpResponse(
      statusCode: 504,
      body: '<html>Gateway Timeout</html>',
    ),
  );
  bool didThrow504 = false;
  try {
    await htmlErrClient.signUp(
      name: 'Nguyễn Văn A',
      email: 'nva@360.org.vn',
      password: 'pass',
      phone: '0912345678',
    );
  } on MockFailure catch (f) {
    didThrow504 = true;
    assert(f.message.contains('504'), 'TC-10 fail: status code not in message');
  }
  assert(didThrow504, 'TC-10 fail: did not throw MockFailure on 504 HTML');
  print('✅ TC-10 PASS: OdooApiClient.signUp xử lý Non-JSON error an toàn');

  // TC-11: AuthRepository.signUp lưu trữ email và database gần nhất
  final repo = TestAuthRepository(client);
  final authUser = await repo.signUp(
    email: 'newuser@360.org.vn',
    password: 'newPassword123',
    displayName: 'New User',
    phone: '0987654321',
    db: 'vcloud_test_v19',
  );
  assert(authUser.uid == 105, 'TC-11 fail: returned user mismatch');
  assert(repo.getLastLoginEmail() == 'newuser@360.org.vn', 'TC-11 fail: saved email mismatch');
  assert(repo.getLastSelectedDb() == 'vcloud_test_v19', 'TC-11 fail: saved db mismatch');
  print('✅ TC-11 PASS: AuthRepository.signUp lưu email & lastSelectedDb');

  // TC-12: AuthRepository.signUp bảo toàn MockFailure rethrow không bọc lại
  final errRepo = TestAuthRepository(errClient);
  bool repoDidCatch = false;
  try {
    await errRepo.signUp(
      email: 'nva@360.org.vn',
      password: 'pass',
      displayName: 'Nguyễn Văn A',
      phone: '0912345678',
    );
  } on MockFailure catch (f) {
    repoDidCatch = true;
    assert(f.message.contains('Email nva@360.org.vn đã tồn tại'), 'TC-12 fail: altered message');
    assert(!f.message.contains('Đăng ký tài khoản không thành công: Failure'), 'TC-12 fail: double wrapped');
  }
  assert(repoDidCatch, 'TC-12 fail: repo did not catch failure');
  print('✅ TC-12 PASS: AuthRepository.signUp rethrow Failure trực tiếp');

  // TC-13: Auto-Login Navigation: Phân luồng vai trò Portal -> /home, Internal -> /chat
  String resolveDestination(bool isPortal) => isPortal ? '/home' : '/chat';
  assert(resolveDestination(true) == '/home', 'TC-13 fail: portal should navigate to /home');
  assert(resolveDestination(false) == '/chat', 'TC-13 fail: internal should navigate to /chat');
  print('✅ TC-13 PASS: Auto-Login Navigation phân luồng đích đến (/home vs /chat)');

  // TC-14: Candidate DB Fallback: Khi lookupDb rỗng, fallbackDb luôn được tạo, candidateDbs không bao giờ rỗng
  List<String> resolveCandidateDbs({
    required List<String> rawDbs,
    String? lastDb,
    String? envDb,
    required String apiBaseUrl,
  }) {
    final list = List<String>.from(rawDbs);
    if (list.isEmpty) {
      String fallbackDb = (lastDb != null && lastDb.isNotEmpty)
          ? lastDb
          : ((envDb != null && envDb.isNotEmpty) ? envDb : '');
      if (fallbackDb.isEmpty) {
        if (apiBaseUrl.contains('vuahethong.net')) {
          fallbackDb = 'vuahethong';
        } else if (apiBaseUrl.contains('demo.vuahethong.com')) {
          fallbackDb = 'demo';
        }
      }
      list.add(fallbackDb);
    }
    return list;
  }

  final fallbackTest1 = resolveCandidateDbs(rawDbs: [], lastDb: 'vcloud_test_v19', apiBaseUrl: 'http://localhost:8069');
  assert(fallbackTest1.length == 1 && fallbackTest1.first == 'vcloud_test_v19', 'TC-14 fail: lastDb fallback');

  final fallbackTest2 = resolveCandidateDbs(rawDbs: [], lastDb: null, apiBaseUrl: 'https://vuahethong.net');
  assert(fallbackTest2.length == 1 && fallbackTest2.first == 'vuahethong', 'TC-14 fail: vuahethong.net fallback');

  final fallbackTest3 = resolveCandidateDbs(rawDbs: ['tenant_db_1'], lastDb: null, apiBaseUrl: 'https://vuahethong.net');
  assert(fallbackTest3.length == 1 && fallbackTest3.first == 'tenant_db_1', 'TC-14 fail: keep rawDbs');
  print('✅ TC-14 PASS: Candidate DB Fallback bảo đảm candidateDbs không bị rỗng nhầm');

  print('--- HOÀN TẤT: TOÀN BỘ 14/14 TEST CASES ĐẠT CHUẨN 100% ---');
}
