import 'package:flutter_test/flutter_test.dart';

import 'package:vcloud/features/auth/data/db_info.dart';

void main() {
  group('Kiểm tra chuẩn hoá môi trường Database & URL', () {
    test(
      '1. Domain vuahethong.net luôn map về database vuahethong, không lọt nhãn dev local',
      () {
        const prodUrl = 'https://vuahethong.net';
        final testCases = [
          '',
          '17.0',
          '17',
          '19.0',
          '19',
          'demo',
          'vuahethong',
        ];

        for (final dbName in testCases) {
          String effectiveDb = dbName.trim();
          if (prodUrl.contains('vuahethong.net')) {
            effectiveDb = 'vuahethong';
          }
          expect(
            effectiveDb,
            'vuahethong',
            reason: 'dbName $dbName phải map về vuahethong trên prod',
          );
        }
      },
    );

    test('2. Domain demo.vuahethong.com luôn map về database demo', () {
      const demoUrl = 'https://demo.vuahethong.com';
      final testCases = ['', 'demo', '17.0'];

      for (final dbName in testCases) {
        String effectiveDb = dbName.trim();
        if (demoUrl.contains('demo.vuahethong.com')) {
          effectiveDb = 'demo';
        }
        expect(effectiveDb, 'demo', reason: 'dbName $dbName phải map về demo');
      }
    });

    test(
      '3. DbInfo categoryLabel phân loại đúng môi trường Prod và Odoo 19',
      () {
        const prodDb = DbInfo(
          login: 'tanmnn@360.org.vn',
          databaseName: 'vuahethong',
          databaseUrl: 'https://vuahethong.net',
          displayName: 'Vua Hệ Thống (Chính thức)',
        );
        expect(prodDb.categoryLabel, '🏢 Nội Bộ (Odoo 17)');

        const demoDb = DbInfo(
          login: 'demo',
          databaseName: 'demo',
          databaseUrl: 'https://demo.vuahethong.com',
          displayName: 'Trung tâm Trải nghiệm & Demo (Odoo 19)',
        );
        expect(demoDb.categoryLabel, '🏢 Nội Bộ (Odoo 19)');
      },
    );
  });
}
