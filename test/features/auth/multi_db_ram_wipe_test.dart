import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/core/api/odoo_session.dart';
import 'package:vcloud/features/auth/application/auth_memory_state.dart';
import 'package:vcloud/features/auth/data/db_info.dart';

void main() {
  group('Multi-DB Authentication & Immediate RAM Token Wipe Tests (Protocol V2.1)', () {
    final expiresAt = DateTime(2026, 12, 31).toUtc();

    const dbA = DbInfo(
      login: 'support@360.org.vn',
      databaseName: 'vuahethong',
      databaseUrl: 'https://vuahethong.net',
      displayName: '360 CORP Nội Bộ',
      hasVMobile: true,
    );

    final sessionA = OdooSession(
      accessToken: 'jwt_token_tenant_A_vuahethong_secret_999',
      refreshToken: 'refresh_tenant_A_111',
      uid: 2,
      db: 'vuahethong',
      login: 'support@360.org.vn',
      expiresAt: expiresAt,
      baseUrl: 'https://vuahethong.net',
    );

    const dbB = DbInfo(
      login: 'support@360.org.vn',
      databaseName: 'davita_live',
      databaseUrl: 'https://davita.vn',
      displayName: 'Hệ Thống Davita Dental',
      hasVMobile: true,
    );

    final sessionB = OdooSession(
      accessToken: 'jwt_token_tenant_B_davita_secret_888',
      refreshToken: 'refresh_tenant_B_222',
      uid: 104,
      db: 'davita_live',
      login: 'support@360.org.vn',
      expiresAt: expiresAt,
      baseUrl: 'https://davita.vn',
    );

    const dbC = DbInfo(
      login: 'support@360.org.vn',
      databaseName: 'ndsgroup_live',
      databaseUrl: 'https://ndsgroup.vn',
      displayName: 'Tập Đoàn NDS Group',
      hasVMobile: true,
    );

    final sessionC = OdooSession(
      accessToken: 'jwt_token_tenant_C_nds_secret_777',
      refreshToken: 'refresh_tenant_C_333',
      uid: 55,
      db: 'ndsgroup_live',
      login: 'support@360.org.vn',
      expiresAt: expiresAt,
      baseUrl: 'https://ndsgroup.vn',
    );

    setUp(() {
      // Đảm bảo RAM rỗng trước mỗi test case
      AuthMemoryState.clearTemporaryMemory();
    });

    tearDown(() {
      // Đảm bảo RAM được dọn dẹp sau mỗi test case
      AuthMemoryState.clearTemporaryMemory();
    });

    test('Case 1: AuthMemoryState ban đầu ở trạng thái rỗng hoàn toàn', () {
      expect(AuthMemoryState.isEmpty, isTrue);
      expect(AuthMemoryState.hasTemporarySessions, isFalse);
      expect(AuthMemoryState.count, equals(0));
      expect(AuthMemoryState.candidateDbs, isEmpty);
    });

    test('Case 2: Pre-auth N=3 DBs thành công lưu đúng 3 session vào RAM', () {
      AuthMemoryState.setTemporarySessions([
        (db: dbA, session: sessionA),
        (db: dbB, session: sessionB),
        (db: dbC, session: sessionC),
      ]);

      expect(AuthMemoryState.isEmpty, isFalse);
      expect(AuthMemoryState.hasTemporarySessions, isTrue);
      expect(AuthMemoryState.count, equals(3));
      expect(AuthMemoryState.candidateDbs.length, equals(3));
      expect(AuthMemoryState.candidateDbs.map((e) => e.databaseName),
          containsAll(['vuahethong', 'davita_live', 'ndsgroup_live']));
    });

    test('Case 3: getSessionForDb trả về chính xác session và token tương ứng', () {
      AuthMemoryState.setTemporarySessions([
        (db: dbA, session: sessionA),
        (db: dbB, session: sessionB),
      ]);

      final retrievedA = AuthMemoryState.getSessionForDb(dbA);
      expect(retrievedA, isNotNull);
      expect(retrievedA!.session.accessToken, equals('jwt_token_tenant_A_vuahethong_secret_999'));
      expect(retrievedA.session.db, equals('vuahethong'));

      final retrievedB = AuthMemoryState.getSessionForDb(dbB);
      expect(retrievedB, isNotNull);
      expect(retrievedB!.session.accessToken, equals('jwt_token_tenant_B_davita_secret_888'));
      expect(retrievedB.session.db, equals('davita_live'));
    });

    test('Case 4: Chọn DB_A -> Lưu session DB_A -> Immediate Wipe xóa sạch RAM', () {
      // Bước 2: Giữ tạm trong RAM khi hiện popup
      AuthMemoryState.setTemporarySessions([
        (db: dbA, session: sessionA),
        (db: dbB, session: sessionB),
        (db: dbC, session: sessionC),
      ]);
      expect(AuthMemoryState.count, equals(3));

      // Bước 3: Người dùng chọn DB_A (Token DB_A được lưu persistent xuống SecureStorage)
      final selectedSession = AuthMemoryState.getSessionForDb(dbA);
      expect(selectedSession, isNotNull);
      final persistedToken = selectedSession!.session.accessToken;
      expect(persistedToken, equals('jwt_token_tenant_A_vuahethong_secret_999'));

      // Bước 4: Immediate Memory Wipe (Phương án 1)
      AuthMemoryState.clearTemporaryMemory();

      // Verify RAM đã rỗng 100%
      expect(AuthMemoryState.isEmpty, isTrue);
      expect(AuthMemoryState.count, equals(0));
      expect(AuthMemoryState.hasTemporarySessions, isFalse);
    });

    test('Case 5: Zero Token Leakage: Sau khi Wipe, tra cứu bất kỳ DB nào đều trả về null', () {
      AuthMemoryState.setTemporarySessions([
        (db: dbA, session: sessionA),
        (db: dbB, session: sessionB),
        (db: dbC, session: sessionC),
      ]);

      AuthMemoryState.clearTemporaryMemory();

      expect(AuthMemoryState.getSessionForDb(dbA), isNull);
      expect(AuthMemoryState.getSessionForDb(dbB), isNull);
      expect(AuthMemoryState.getSessionForDb(dbC), isNull);
    });

    test('Case 6: Kịch bản 0 DB xác thực thành công (Sai MK) -> RAM sạch, cấm popup', () {
      // Khi không có DB nào pass
      final List<({DbInfo db, OdooSession session})> failedResults = [];

      if (failedResults.isEmpty) {
        AuthMemoryState.clearTemporaryMemory();
      }

      expect(AuthMemoryState.isEmpty, isTrue);
      expect(AuthMemoryState.count, equals(0));
    });

    test('Case 7: Kịch bản 1 DB duy nhất -> Auto-login và ngay lập tức Wipe RAM', () {
      // Pre-auth 1 DB duy nhất
      AuthMemoryState.setTemporarySessions([
        (db: dbA, session: sessionA),
      ]);
      expect(AuthMemoryState.count, equals(1));

      // Auto-login kích hoạt xong -> Wipe RAM
      AuthMemoryState.clearTemporaryMemory();

      expect(AuthMemoryState.isEmpty, isTrue);
      expect(AuthMemoryState.count, equals(0));
    });

    test('Case 8: User dismiss / đóng popup chọn DB -> Xóa sạch RAM ngay lập tức', () {
      // Hiện popup với 2 DB
      AuthMemoryState.setTemporarySessions([
        (db: dbA, session: sessionA),
        (db: dbB, session: sessionB),
      ]);
      expect(AuthMemoryState.count, equals(2));

      // User bấm ra ngoài vùng dialog (selected == null)
      const DbInfo? selected = null;
      if (selected == null) {
        AuthMemoryState.clearTemporaryMemory();
      }

      expect(AuthMemoryState.isEmpty, isTrue);
      expect(AuthMemoryState.count, equals(0));
    });

    test('Case 9: Tenant Isolation: Phân định key độc lập theo dbName và dbUrl', () {
      // Cùng dbName nhưng khác domain URL
      const dbAClone = DbInfo(
        login: 'support@360.org.vn',
        databaseName: 'vuahethong',
        databaseUrl: 'https://staging.vuahethong.net',
        displayName: '360 CORP Staging',
        hasVMobile: true,
      );

      final sessionAClone = OdooSession(
        accessToken: 'jwt_token_staging_secret_555',
        uid: 99,
        db: 'vuahethong',
        login: 'support@360.org.vn',
        expiresAt: expiresAt,
        baseUrl: 'https://staging.vuahethong.net',
      );

      AuthMemoryState.setTemporarySessions([
        (db: dbA, session: sessionA),
        (db: dbAClone, session: sessionAClone),
      ]);

      expect(AuthMemoryState.count, equals(2));
      final retA = AuthMemoryState.getSessionForDb(dbA);
      final retClone = AuthMemoryState.getSessionForDb(dbAClone);

      expect(retA!.session.accessToken, equals('jwt_token_tenant_A_vuahethong_secret_999'));
      expect(retClone!.session.accessToken, equals('jwt_token_staging_secret_555'));
      expect(retA.session.accessToken != retClone.session.accessToken, isTrue);
    });

    test('Case 10: Snapshot là UnmodifiableMap, bảo vệ toàn vẹn bộ nhớ RAM', () {
      AuthMemoryState.setTemporarySessions([
        (db: dbA, session: sessionA),
      ]);

      final snap = AuthMemoryState.snapshot;
      expect(snap.length, equals(1));

      // Không thể thêm hoặc xóa phần tử trực tiếp trên snapshot
      expect(
        () => (snap as dynamic)['fake_key'] = (db: dbB, session: sessionB),
        throwsA(isA<UnsupportedError>()),
      );
    });
  });
}
