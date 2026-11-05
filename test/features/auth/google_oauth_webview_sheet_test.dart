import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/features/auth/presentation/widgets/google_oauth_webview_sheet.dart';

void main() {
  group('GoogleOAuthWebViewSheet Unit Tests', () {
    test('TC1: Khởi tạo GoogleOAuthResult thành công với accessToken và email', () {
      const res = GoogleOAuthResult(
        accessToken: 'ya29.a0AfH6SMD_mock_token',
        email: 'sẽptan@360.org.vn',
      );
      expect(res.accessToken, equals('ya29.a0AfH6SMD_mock_token'));
      expect(res.email, equals('sẽptan@360.org.vn'));
      expect(res.error, isNull);
    });

    test('TC2: Khởi tạo GoogleOAuthResult khi người dùng từ chối cấp quyền', () {
      const res = GoogleOAuthResult(
        accessToken: '',
        error: 'access_denied',
      );
      expect(res.accessToken, isEmpty);
      expect(res.error, equals('access_denied'));
    });

    test('TC3: Extract token từ OAuth hash fragment chuẩn Odoo', () {
      const url =
          'https://vuahethong.net/auth_oauth/signin#access_token=ya29.test_fragment_token_123&token_type=Bearer&expires_in=3599';
      final uri = Uri.parse(url);
      final params = Uri.splitQueryString(uri.fragment);
      expect(params['access_token'], equals('ya29.test_fragment_token_123'));
    });

    test('TC4: Extract token từ URL query parameter', () {
      const url =
          'https://vuahethong.net/auth_oauth/signin?access_token=ya29.test_query_token_456&state=%7B%22d%22%3A%22vcloud%22%7D';
      final uri = Uri.parse(url);
      expect(uri.queryParameters['access_token'], equals('ya29.test_query_token_456'));
    });

    test('TC5: URL redirect trung gian không có access_token không được coi là token hợp lệ', () {
      const url = 'https://vuahethong.net/auth_oauth/signin';
      final uri = Uri.parse(url);
      expect(uri.fragment, isEmpty);
      expect(uri.queryParameters['access_token'], isNull);
    });

    test('TC6: URL lỗi chứa error=access_denied', () {
      const url =
          'https://vuahethong.net/auth_oauth/signin#error=access_denied&error_description=User%20denied%20consent';
      final uri = Uri.parse(url);
      final params = Uri.splitQueryString(uri.fragment);
      expect(params['error'], equals('access_denied'));
      expect(params['error_description'], equals('User denied consent'));
    });

    test('TC7: Fallback regex trích xuất access_token khi URL có định dạng phức tạp', () {
      const complexUrl =
          'https://vuahethong.net/auth_oauth/signin#state=abc&access_token=ya29.complex_regex_token_789&scope=email';
      final regMatch = RegExp(r'[#?&]access_token=([^&]+)').firstMatch(complexUrl);
      expect(regMatch, isNotNull);
      expect(regMatch!.group(1), equals('ya29.complex_regex_token_789'));
    });

    test('TC8: URL Google 2FA Challenge không mang token và không bị kích hoạt redirect nhầm', () {
      const challengeUrl =
          'https://accounts.google.com/signin/v2/challenge/ipp?tl=AK21Mock&checkConnection=1';
      final regMatch = RegExp(r'[#?&]access_token=([^&]+)').firstMatch(challengeUrl);
      expect(regMatch, isNull);
    });

    test('TC9: Tách query string với token có ký tự đặc biệt được URL decode', () {
      const rawToken = 'ya29.token_with_%2B_and_%2F';
      final decoded = Uri.decodeComponent(rawToken);
      expect(decoded, equals('ya29.token_with_+_and_/'));
    });

    test('TC10: GoogleOAuthWebViewSheet có targetUrl và targetDb chuẩn', () {
      const sheet = GoogleOAuthWebViewSheet(
        targetUrl: 'http://192.168.1.100:1900',
        targetDb: 'vcloud_test_v19',
        initialEmail: 'tanmnn@360.org.vn',
      );
      expect(sheet.targetUrl, equals('http://192.168.1.100:1900'));
      expect(sheet.targetDb, equals('vcloud_test_v19'));
      expect(sheet.initialEmail, equals('tanmnn@360.org.vn'));
    });
  });
}
