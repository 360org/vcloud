import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/core/api/odoo_api_client.dart';

void main() {
  group('Smart DB Resolver Tests (SSOT)', () {
    test('1. Phân giải đúng DB vuahethong khi kết nối https://vuahethong.net', () {
      final db = OdooApiClient.resolveDefaultDbForUrl('https://vuahethong.net');
      expect(db, equals('vuahethong'));
    });

    test('2. Phân giải đúng DB vuahethong khi kết nối https://www.vuahethong.net', () {
      final db = OdooApiClient.resolveDefaultDbForUrl('https://www.vuahethong.net');
      expect(db, equals('vuahethong'));
    });

    test('3. Phân giải đúng DB vuahethong khi kết nối đường dẫn phụ https://vuahethong.net/web/login', () {
      final db = OdooApiClient.resolveDefaultDbForUrl('https://vuahethong.net/web/login');
      expect(db, equals('vuahethong'));
    });

    test('4. Phân giải đúng DB demo khi kết nối https://demo.vuahethong.com', () {
      final db = OdooApiClient.resolveDefaultDbForUrl('https://demo.vuahethong.com');
      expect(db, equals('demo'));
    });

    test('5. Phân giải đúng DB test vcloud_test_v19 khi kết nối Local Server port 1900', () {
      final db = OdooApiClient.resolveDefaultDbForUrl('http://192.168.1.100:1900');
      expect(db, equals('vcloud_test_v19'));
    });

    test('6. Phân giải đúng DB test vcloud_test_v19 khi kết nối Local Server port 8069', () {
      final db = OdooApiClient.resolveDefaultDbForUrl('http://192.168.1.100:8069');
      expect(db, equals('vcloud_test_v19'));
    });

    test('7. Phân giải đúng DB test vcloud_test_v19 khi kết nối localhost', () {
      final db = OdooApiClient.resolveDefaultDbForUrl('http://localhost:8069');
      expect(db, equals('vcloud_test_v19'));
    });

    test('8. Phân giải đúng DB test vcloud_test_v19 khi kết nối 127.0.0.1', () {
      final db = OdooApiClient.resolveDefaultDbForUrl('http://127.0.0.1:8069');
      expect(db, equals('vcloud_test_v19'));
    });

    test('9. Trả về rỗng (để Odoo server tự resolve), tuyệt đối KHÔNG ép vcloud_test_v19 khi kết nối ndsgroup.vn', () {
      final db = OdooApiClient.resolveDefaultDbForUrl('https://ndsgroup.vn');
      expect(db, equals(''));
      expect(db, isNot(contains('vcloud_test_v19')));
    });

    test('10. Trả về rỗng (để Odoo server tự resolve), tuyệt đối KHÔNG ép vcloud_test_v19 khi kết nối salemoptical.vn', () {
      final db = OdooApiClient.resolveDefaultDbForUrl('https://salemoptical.vn');
      expect(db, equals(''));
      expect(db, isNot(contains('vcloud_test_v19')));
    });
  });
}
