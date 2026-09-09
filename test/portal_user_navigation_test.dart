import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/core/api/auth_user.dart';

void main() {
  group('Portal User Model & Role Verification', () {
    test('AuthUser isPortal returns true when userMetadata has is_portal=true', () {
      const portalUser = AuthUser(
        id: '101',
        email: 'customer@example.com',
        userMetadata: {
          'is_portal': true,
          'user_type': 'portal',
          'share': true,
        },
      );

      expect(portalUser.isPortal, isTrue);
    });

    test('AuthUser isPortal returns false for internal employee', () {
      const internalUser = AuthUser(
        id: '2',
        email: 'employee@360.org.vn',
        userMetadata: {
          'is_portal': false,
          'user_type': 'internal',
          'share': false,
        },
      );

      expect(internalUser.isPortal, isFalse);
    });

    test('AuthUser isPortal defaults to false when metadata is empty', () {
      const defaultUser = AuthUser(
        id: '3',
        email: 'user@example.com',
      );

      expect(defaultUser.isPortal, isFalse);
    });
  });
}
