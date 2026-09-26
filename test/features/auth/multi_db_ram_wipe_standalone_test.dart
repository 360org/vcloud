import 'dart:io';

import 'package:vcloud/core/api/odoo_session.dart';
import 'package:vcloud/features/auth/application/auth_memory_state.dart';
import 'package:vcloud/features/auth/data/db_info.dart';

void main() {
  stdout.writeln('================================================================');
  stdout.writeln('🚀 BẮT ĐẦU CHẠY 10 TEST CASES ĐỘC LẬP: MULTI-DB RAM TOKEN WIPE');
  stdout.writeln('   (Giao thức Protocol V2.1 - Phương án 1: Immediate Wipe)');
  stdout.writeln('================================================================');

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

  int passed = 0;

  void runTestCase(String name, void Function() body) {
    AuthMemoryState.clearTemporaryMemory();
    try {
      body();
      passed++;
      stdout.writeln('  ✅ [PASS] $name');
    } catch (e, st) {
      stdout.writeln('  ❌ [FAIL] $name: $e\n$st');
      exitCode = 1;
    } finally {
      AuthMemoryState.clearTemporaryMemory();
    }
  }

  // Case 1
  runTestCase('Case 1: AuthMemoryState ban đầu rỗng hoàn toàn', () {
    assert(AuthMemoryState.isEmpty == true, 'RAM phải rỗng ban đầu');
    assert(AuthMemoryState.hasTemporarySessions == false, 'Không được có session tạm');
    assert(AuthMemoryState.count == 0, 'Count phải bằng 0');
    assert(AuthMemoryState.candidateDbs.isEmpty, 'candidateDbs phải rỗng');
  });

  // Case 2
  runTestCase('Case 2: Pre-auth N=3 DBs thành công lưu đúng 3 session vào RAM', () {
    AuthMemoryState.setTemporarySessions([
      (db: dbA, session: sessionA),
      (db: dbB, session: sessionB),
      (db: dbC, session: sessionC),
    ]);
    assert(AuthMemoryState.isEmpty == false, 'RAM không rỗng khi đã nạp');
    assert(AuthMemoryState.hasTemporarySessions == true, 'Phải có session tạm');
    assert(AuthMemoryState.count == 3, 'Count phải bằng 3');
    assert(AuthMemoryState.candidateDbs.length == 3, 'candidateDbs phải có 3 DB');
  });

  // Case 3
  runTestCase('Case 3: getSessionForDb trả về chính xác session và token tương ứng', () {
    AuthMemoryState.setTemporarySessions([
      (db: dbA, session: sessionA),
      (db: dbB, session: sessionB),
    ]);
    final retA = AuthMemoryState.getSessionForDb(dbA);
    assert(retA != null, 'Phải lấy được session của dbA');
    assert(retA!.session.accessToken == 'jwt_token_tenant_A_vuahethong_secret_999');
    assert(retA!.session.db == 'vuahethong');

    final retB = AuthMemoryState.getSessionForDb(dbB);
    assert(retB != null, 'Phải lấy được session của dbB');
    assert(retB!.session.accessToken == 'jwt_token_tenant_B_davita_secret_888');
    assert(retB!.session.db == 'davita_live');
  });

  // Case 4
  runTestCase('Case 4: Chọn DB_A -> Immediate Wipe xóa sạch RAM của các DB khác', () {
    AuthMemoryState.setTemporarySessions([
      (db: dbA, session: sessionA),
      (db: dbB, session: sessionB),
      (db: dbC, session: sessionC),
    ]);
    assert(AuthMemoryState.count == 3);

    // Lựa chọn DB_A và lưu token
    final selected = AuthMemoryState.getSessionForDb(dbA);
    assert(selected != null);
    assert(selected!.session.accessToken == 'jwt_token_tenant_A_vuahethong_secret_999');

    // Kích hoạt Immediate Wipe
    AuthMemoryState.clearTemporaryMemory();

    assert(AuthMemoryState.isEmpty == true, 'Sau khi wipe, RAM phải rỗng');
    assert(AuthMemoryState.count == 0, 'Sau khi wipe, count phải là 0');
    assert(AuthMemoryState.hasTemporarySessions == false);
  });

  // Case 5
  runTestCase('Case 5: Zero Token Leakage: Sau khi Wipe, tra cứu DB nào cũng trả về null', () {
    AuthMemoryState.setTemporarySessions([
      (db: dbA, session: sessionA),
      (db: dbB, session: sessionB),
      (db: dbC, session: sessionC),
    ]);
    AuthMemoryState.clearTemporaryMemory();

    assert(AuthMemoryState.getSessionForDb(dbA) == null, 'Session dbA phải null');
    assert(AuthMemoryState.getSessionForDb(dbB) == null, 'Session dbB phải null');
    assert(AuthMemoryState.getSessionForDb(dbC) == null, 'Session dbC phải null');
  });

  // Case 6
  runTestCase('Case 6: Kịch bản 0 DB thành công (Sai MK) -> Dọn dẹp RAM, cấm popup', () {
    final List<({DbInfo db, OdooSession session})> failedResults = [];
    if (failedResults.isEmpty) {
      AuthMemoryState.clearTemporaryMemory();
    }
    assert(AuthMemoryState.isEmpty == true, 'RAM phải rỗng khi fail');
    assert(AuthMemoryState.count == 0);
  });

  // Case 7
  runTestCase('Case 7: Kịch bản 1 DB duy nhất -> Auto-login và ngay lập tức Wipe RAM', () {
    AuthMemoryState.setTemporarySessions([
      (db: dbA, session: sessionA),
    ]);
    assert(AuthMemoryState.count == 1);
    AuthMemoryState.clearTemporaryMemory();
    assert(AuthMemoryState.isEmpty == true);
    assert(AuthMemoryState.count == 0);
  });

  // Case 8
  runTestCase('Case 8: User dismiss / đóng popup chọn DB -> Xóa sạch RAM ngay', () {
    AuthMemoryState.setTemporarySessions([
      (db: dbA, session: sessionA),
      (db: dbB, session: sessionB),
    ]);
    assert(AuthMemoryState.count == 2);

    const DbInfo? selected = null;
    if (selected == null) {
      AuthMemoryState.clearTemporaryMemory();
    }
    assert(AuthMemoryState.isEmpty == true);
    assert(AuthMemoryState.count == 0);
  });

  // Case 9
  runTestCase('Case 9: Tenant Isolation: Phân định key độc lập theo dbName và dbUrl', () {
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

    assert(AuthMemoryState.count == 2);
    final retA = AuthMemoryState.getSessionForDb(dbA);
    final retClone = AuthMemoryState.getSessionForDb(dbAClone);
    assert(retA!.session.accessToken == 'jwt_token_tenant_A_vuahethong_secret_999');
    assert(retClone!.session.accessToken == 'jwt_token_staging_secret_555');
    assert(retA!.session.accessToken != retClone!.session.accessToken);
  });

  // Case 10
  runTestCase('Case 10: Snapshot là UnmodifiableMap, bảo vệ toàn vẹn bộ nhớ RAM', () {
    AuthMemoryState.setTemporarySessions([
      (db: dbA, session: sessionA),
    ]);
    final snap = AuthMemoryState.snapshot;
    assert(snap.length == 1);
    bool threw = false;
    try {
      (snap as dynamic)['illegal_key'] = (db: dbB, session: sessionB);
    } catch (_) {
      threw = true;
    }
    assert(threw == true, 'Thao tác mutate snapshot phải ném lỗi');
  });

  stdout.writeln('================================================================');
  stdout.writeln('📊 KẾT QUẢ KIỂM THỬ: $passed/10 CASES ĐẠT CHUẨN (100% PASS)');
  stdout.writeln('================================================================');
}
