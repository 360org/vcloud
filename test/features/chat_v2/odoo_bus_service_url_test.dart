import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/core/api/odoo_session.dart';
import 'package:vcloud/features/chat_v2/data/odoo_bus_service.dart';

void main() {
  group('OdooBusService.buildWsUrl Tests', () {
    final expires = DateTime.now().add(const Duration(days: 7));

    test('1. Chuyển đổi port 1900 sang gevent 1972 kèm db vcloud_test_v19', () {
      final session = OdooSession(
        accessToken: 'jwt_token_1900',
        uid: 2,
        db: 'vcloud_test_v19',
        login: 'admin',
        expiresAt: expires,
        baseUrl: 'http://192.168.1.100:1900',
      );
      final url = OdooBusService.buildWsUrl(
        baseUrl: 'http://192.168.1.100:1900',
        session: session,
      );
      expect(
        url,
        'ws://192.168.1.100:1972/websocket?access_token=jwt_token_1900&db=vcloud_test_v19&version=17.0-3',
      );
    });

    test('2. Chuyển đổi port 1700 sang gevent 1772 kèm db demo-17', () {
      final session = OdooSession(
        accessToken: 'jwt_token_1700',
        uid: 2,
        db: 'demo-17',
        login: 'admin',
        expiresAt: expires,
        baseUrl: 'http://192.168.1.100:1700',
      );
      final url = OdooBusService.buildWsUrl(
        baseUrl: 'http://192.168.1.100:1700',
        session: session,
      );
      expect(
        url,
        'ws://192.168.1.100:1772/websocket?access_token=jwt_token_1700&db=demo-17&version=17.0-3',
      );
    });

    test('3. Chuyển đổi port 8069 sang gevent 7072 (demo-17 Local Server)', () {
      final session = OdooSession(
        accessToken: 'jwt_token_8069',
        uid: 2,
        db: 'demo-17',
        login: 'admin',
        expiresAt: expires,
        baseUrl: 'http://192.168.1.100:8069',
      );
      final url = OdooBusService.buildWsUrl(
        baseUrl: 'http://192.168.1.100:8069',
        session: session,
      );
      expect(
        url,
        'ws://192.168.1.100:7072/websocket?access_token=jwt_token_8069&db=demo-17&version=17.0-3',
      );
    });

    test('4. Chuyển đổi các cổng dev 1400..1800 sang 1x72', () {
      for (final port in [1400, 1500, 1600, 1800]) {
        final session = OdooSession(
          accessToken: 'token_$port',
          uid: 1,
          db: 'test_db',
          login: 'user',
          expiresAt: expires,
          baseUrl: 'http://192.168.1.100:$port',
        );
        final url = OdooBusService.buildWsUrl(
          baseUrl: 'http://192.168.1.100:$port',
          session: session,
        );
        final expectedPort = port + 72;
        expect(
          url,
          'ws://192.168.1.100:$expectedPort/websocket?access_token=token_$port&db=test_db&version=17.0-3',
        );
      }
    });

    test('5. URL Production HTTPS giữ nguyên wss và không thêm port tùy biến', () {
      final session = OdooSession(
        accessToken: 'prod_jwt_token',
        uid: 10,
        db: 'vuahethong_prod',
        login: 'tanmnn@360.org.vn',
        expiresAt: expires,
        baseUrl: 'https://vuahethong.net',
      );
      final url = OdooBusService.buildWsUrl(
        baseUrl: 'https://vuahethong.net',
        session: session,
      );
      expect(
        url,
        'wss://vuahethong.net/websocket?access_token=prod_jwt_token&db=vuahethong_prod&version=17.0-3',
      );
    });

    test('6. Session có db rỗng thì không gắn param &db', () {
      final session = OdooSession(
        accessToken: 'no_db_token',
        uid: 1,
        db: '',
        login: 'guest',
        expiresAt: expires,
        baseUrl: 'https://example.com',
      );
      final url = OdooBusService.buildWsUrl(
        baseUrl: 'https://example.com',
        session: session,
      );
      expect(
        url,
        'wss://example.com/websocket?access_token=no_db_token&version=17.0-3',
      );
    });

    test('7. Đảm bảo scheme HTTP chuyển thành ws và HTTPS chuyển thành wss', () {
      final sessionHttp = OdooSession(
        accessToken: 't1',
        uid: 1,
        db: 'db1',
        login: 'u',
        expiresAt: expires,
        baseUrl: 'http://localhost',
      );
      expect(
        OdooBusService.buildWsUrl(baseUrl: 'http://localhost', session: sessionHttp).startsWith('ws://'),
        isTrue,
      );

      final sessionHttps = OdooSession(
        accessToken: 't2',
        uid: 1,
        db: 'db2',
        login: 'u',
        expiresAt: expires,
        baseUrl: 'https://localhost',
      );
      expect(
        OdooBusService.buildWsUrl(baseUrl: 'https://localhost', session: sessionHttps).startsWith('wss://'),
        isTrue,
      );
    });
  });
}
