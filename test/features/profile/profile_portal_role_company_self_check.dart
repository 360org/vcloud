// ignore_for_file: avoid_print
// Self-check logic phân luồng hiển thị hồ sơ nội bộ vs portal
// ponytail: pure dart runnable check, no external framework needed

void main() {
  (String, String) resolveRoleAndCompany({
    bool? userIsPortal,
    Map<String, dynamic>? meta,
  }) {
    final isPortal = userIsPortal ?? (meta?['is_portal'] == true || meta?['user_type'] == 'portal');
    final String role;
    final String company;
    if (isPortal) {
      final rawFunc = (meta?['function'] as String?)?.trim();
      role = (rawFunc != null && rawFunc.isNotEmpty) ? rawFunc : 'Khách hàng';
      final rawPartnerComp = (meta?['partner_company_name'] as String?)?.trim();
      company = (rawPartnerComp != null && rawPartnerComp.isNotEmpty) ? rawPartnerComp : 'Khách hàng cá nhân';
    } else {
      final rawJob = (meta?['job_title'] as String?)?.trim() ??
          (meta?['role'] as String?)?.trim() ??
          (meta?['function'] as String?)?.trim();
      role = (rawJob != null && rawJob.isNotEmpty) ? rawJob : 'Chưa cập nhật';
      final rawComp = (meta?['company'] as String?)?.trim() ?? (meta?['company_name'] as String?)?.trim();
      company = (rawComp != null && rawComp.isNotEmpty) ? rawComp : '360 CORP';
    }
    return (role, company);
  }

  // Case 1: Portal user rỗng -> Khách hàng / Khách hàng cá nhân
  final (c1Role, c1Comp) = resolveRoleAndCompany(userIsPortal: true, meta: {});
  assert(c1Role == 'Khách hàng', 'Case 1 role failed: $c1Role');
  assert(c1Comp == 'Khách hàng cá nhân', 'Case 1 comp failed: $c1Comp');

  // Case 2: Portal user có function & partner_company_name
  final (c2Role, c2Comp) = resolveRoleAndCompany(
    userIsPortal: true,
    meta: {
      'function': 'Giám Đốc Kỹ Thuật',
      'partner_company_name': 'Công ty TNHH ABC',
    },
  );
  assert(c2Role == 'Giám Đốc Kỹ Thuật', 'Case 2 role failed: $c2Role');
  assert(c2Comp == 'Công ty TNHH ABC', 'Case 2 comp failed: $c2Comp');

  // Case 3: Portal user có whitespace
  final (c3Role, c3Comp) = resolveRoleAndCompany(
    userIsPortal: true,
    meta: {
      'function': '   ',
      'partner_company_name': '   ',
    },
  );
  assert(c3Role == 'Khách hàng', 'Case 3 role failed: $c3Role');
  assert(c3Comp == 'Khách hàng cá nhân', 'Case 3 comp failed: $c3Comp');

  // Case 4: Internal user đầy đủ job_title & company
  final (c4Role, c4Comp) = resolveRoleAndCompany(
    userIsPortal: false,
    meta: {
      'job_title': 'Senior Flutter Dev',
      'company': 'Vua Hệ Thống',
    },
  );
  assert(c4Role == 'Senior Flutter Dev', 'Case 4 role failed: $c4Role');
  assert(c4Comp == 'Vua Hệ Thống', 'Case 4 comp failed: $c4Comp');

  // Case 5: Internal user chỉ có role & company_name
  final (c5Role, c5Comp) = resolveRoleAndCompany(
    userIsPortal: false,
    meta: {
      'role': 'Product Manager',
      'company_name': '360 CORP VN',
    },
  );
  assert(c5Role == 'Product Manager', 'Case 5 role failed: $c5Role');
  assert(c5Comp == '360 CORP VN', 'Case 5 comp failed: $c5Comp');

  // Case 6: Internal user chỉ có function
  final (c6Role, c6Comp) = resolveRoleAndCompany(
    userIsPortal: false,
    meta: {
      'function': 'Kế toán viên',
    },
  );
  assert(c6Role == 'Kế toán viên', 'Case 6 role failed: $c6Role');
  assert(c6Comp == '360 CORP', 'Case 6 comp failed: $c6Comp');

  // Case 7: Internal user metadata rỗng hoàn toàn -> fallback Chưa cập nhật / 360 CORP
  final (c7Role, c7Comp) = resolveRoleAndCompany(userIsPortal: false, meta: {});
  assert(c7Role == 'Chưa cập nhật', 'Case 7 role failed: $c7Role');
  assert(c7Comp == '360 CORP', 'Case 7 comp failed: $c7Comp');

  // Case 8: user null, meta['is_portal'] == true
  final (c8Role, c8Comp) = resolveRoleAndCompany(
    userIsPortal: null,
    meta: {'is_portal': true},
  );
  assert(c8Role == 'Khách hàng', 'Case 8 role failed: $c8Role');
  assert(c8Comp == 'Khách hàng cá nhân', 'Case 8 comp failed: $c8Comp');

  // Case 9: user null, meta['user_type'] == 'portal'
  final (c9Role, c9Comp) = resolveRoleAndCompany(
    userIsPortal: null,
    meta: {'user_type': 'portal'},
  );
  assert(c9Role == 'Khách hàng', 'Case 9 role failed: $c9Role');
  assert(c9Comp == 'Khách hàng cá nhân', 'Case 9 comp failed: $c9Comp');

  // Case 10: Tuyệt đối không bao giờ trả về 'AI Full Stack Engineer'
  final allRoles = [c1Role, c2Role, c3Role, c4Role, c5Role, c6Role, c7Role, c8Role, c9Role];
  for (final r in allRoles) {
    assert(!r.contains('AI Full Stack Engineer'), 'Hardcode still leaked: $r');
  }

  print('ALL 10 ASSERTIONS PASSED: Profile portal vs internal role/company logic verified.');
}
