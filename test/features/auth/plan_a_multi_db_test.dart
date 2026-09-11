// ignore_for_file: avoid_print, prefer_const_declarations, prefer_const_constructors, prefer_conditional_assignment
import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/features/auth/data/db_info.dart';

void main() {
  group('Kịch bản Phương án A: Multi-DB & Multi-Domain Routing Tests', () {
    test(
      'TC-A-01: Nhận diện và giữ nguyên domain & DB của khách hàng davita.vn',
      () {
        final davitaDb = DbInfo(
          login: 'support@360.org.vn',
          databaseName: 'davita_live',
          databaseUrl: 'https://davita.vn',
          displayName: 'Davita Dental Clinic',
          hasVMobile: true,
        );

        expect(davitaDb.databaseUrl, equals('https://davita.vn'));
        expect(davitaDb.databaseName, equals('davita_live'));
        expect(davitaDb.effectiveDisplayName, contains('Davita'));

        // Kiểm tra Uri host parsing chuẩn xác, không bị nhầm lẫn
        final uri = Uri.parse(davitaDb.databaseUrl);
        expect(uri.host, equals('davita.vn'));
        expect(uri.host.contains('vuahethong.net'), isFalse);
      },
    );

    test('TC-A-02: Nhận diện đúng danh sách 2 DB (Multi-DB Popup)', () {
      final rawList = [
        {
          'login': 'support@360.org.vn',
          'database_name': 'vuahethong',
          'database_url': 'https://vuahethong.net',
          'display_name': '360 CORP Nội Bộ',
          'has_v_mobile': true,
        },
        {
          'login': 'support@360.org.vn',
          'database_name': 'davita_live',
          'database_url': 'https://davita.vn',
          'display_name': 'Hệ Thống Davita Dental',
          'has_v_mobile': true,
        },
      ];

      final dbList = rawList.map(DbInfo.fromJson).toList();
      expect(dbList.length, equals(2));
      expect(dbList[0].databaseName, equals('vuahethong'));
      expect(dbList[1].databaseName, equals('davita_live'));
      expect(dbList[1].databaseUrl, equals('https://davita.vn'));
    });

    test('TC-A-03: Kiểm tra Uri host resolution logic chống hardcode vuahethong', () {
      String resolveEffectiveDb(String inputUrl, String originalDb) {
        final uri = Uri.tryParse(inputUrl.toLowerCase());
        final host = uri?.host.toLowerCase() ?? '';
        if ((host == 'vuahethong.net' || host == 'www.vuahethong.net') &&
            originalDb.trim().isEmpty) {
          return 'vuahethong';
        }
        if (host == 'demo.vuahethong.com' && originalDb.trim().isEmpty) {
          return 'demo';
        }
        return originalDb.trim();
      }

      // 1. Trường hợp Davita domain riêng: phải giữ nguyên DB davita_live
      expect(
        resolveEffectiveDb('https://davita.vn', 'davita_live'),
        equals('davita_live'),
      );

      // 2. Trường hợp Subdomain riêng davita.vuahethong.net (nếu có): phải giữ nguyên DB davita
      expect(
        resolveEffectiveDb('https://davita.vuahethong.net', 'davita_tenant'),
        equals('davita_tenant'),
      );

      // 3. Trường hợp Master vuahethong.net không truyền DB: fallback về vuahethong
      expect(
        resolveEffectiveDb('https://vuahethong.net', ''),
        equals('vuahethong'),
      );

      // 4. Trường hợp Demo demo.vuahethong.com không truyền DB: fallback về demo
      expect(
        resolveEffectiveDb('https://demo.vuahethong.com', ''),
        equals('demo'),
      );
    });
  });
}
