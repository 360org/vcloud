import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/core/api/auth_user.dart';
import 'package:vcloud/shared/models/profile.dart';

void main() {
  group('Chat Role & Security Rule Test Suite', () {
    test('Case 1: Profile parses internal employee correctly', () {
      final json = <String, dynamic>{
        'id': '10',
        'email': 'staff@360.org.vn',
        'display_name': 'Nguyen Van Staff',
        'partner_id': '100',
        'role': 'employee',
        'is_portal': false,
        'user_type': 'internal',
      };
      final profile = Profile.fromMap(json);
      expect(profile.id, '10');
      expect(profile.isPortal, false);
      expect(profile.isStaff, true);
      expect(profile.isCustomer, false);
    });

    test('Case 2: Profile parses portal user with is_portal=true correctly', () {
      final json = <String, dynamic>{
        'id': '20',
        'email': 'customer@company.com',
        'display_name': 'Cong Ty Khach Hang',
        'partner_id': '200',
        'is_portal': true,
      };
      final profile = Profile.fromMap(json);
      expect(profile.id, '20');
      expect(profile.isPortal, true);
      expect(profile.isStaff, false);
      expect(profile.isCustomer, true);
    });

    test('Case 3: Profile parses portal user with user_type=portal correctly', () {
      final json = <String, dynamic>{
        'id': '21',
        'email': 'portal@test.vn',
        'display_name': 'Portal User 1',
        'partner_id': '201',
        'user_type': 'portal',
      };
      final profile = Profile.fromMap(json);
      expect(profile.isPortal, true);
      expect(profile.isStaff, false);
    });

    test('Case 4: Query normalization strips leading @ correctly', () {
      const raw1 = '@portal';
      final cleaned1 = raw1.startsWith('@') ? raw1.substring(1).trim().toLowerCase() : raw1.toLowerCase();
      expect(cleaned1, 'portal');

      const raw2 = '  @Staff  ';
      final cleaned2 = raw2.trim().startsWith('@') ? raw2.trim().substring(1).trim().toLowerCase() : raw2.trim().toLowerCase();
      expect(cleaned2, 'staff');
    });

    test('Case 5: Filtering matches portal user by @portal keyword', () {
      const portalUser = Profile(
        id: '20',
        email: 'khachhang@partner.com',
        displayName: 'Anh Nam Khách Hàng',
        role: 'portal',
      );
      const rawQ = '@portal';
      final searchQ = rawQ.startsWith('@') ? rawQ.substring(1).trim().toLowerCase() : rawQ.toLowerCase();
      final roleMatch = (portalUser.isPortal ? 'khách hàng portal' : 'nội bộ nhân viên').contains(searchQ);
      expect(roleMatch, true);
    });

    test('Case 6: Filtering matches internal user by name keyword', () {
      const staffUser = Profile(
        id: '10',
        email: 'dev@360.org.vn',
        displayName: 'Tran Van Dev',
        role: 'staff',
      );
      const searchQ = 'tran';
      final nameMatch = staffUser.displayName.toLowerCase().contains(searchQ);
      expect(nameMatch, true);
    });

    test('Case 7: Filtering matches portal user by email keyword', () {
      const portalUser = Profile(
        id: '22',
        email: 'vip_client@davita.com',
        displayName: 'Davita VIP',
        role: 'portal',
      );
      const searchQ = 'davita';
      final emailMatch = portalUser.email.toLowerCase().contains(searchQ);
      expect(emailMatch, true);
    });

    test('Case 8: AuthUser detects portal account with is_portal=true', () {
      const authUser = AuthUser(
        id: '30',
        email: 'client@portal.com',
        userMetadata: <String, dynamic>{
          'is_portal': true,
          'name': 'Client User',
        },
      );
      expect(authUser.isPortal, true);
    });

    test('Case 9: AuthUser detects portal account with share=true', () {
      const authUser = AuthUser(
        id: '31',
        email: 'share@portal.com',
        userMetadata: <String, dynamic>{
          'share': true,
          'user_type': 'portal',
        },
      );
      expect(authUser.isPortal, true);
    });

    test('Case 10: AuthUser detects internal employee with share=false', () {
      const authUser = AuthUser(
        id: '1',
        email: 'admin@vcloud.com',
        userMetadata: <String, dynamic>{
          'share': false,
          'user_type': 'internal',
        },
      );
      expect(authUser.isPortal, false);
    });
  });
}
