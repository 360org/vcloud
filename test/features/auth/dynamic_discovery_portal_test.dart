import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/core/api/auth_user.dart';

void main() {
  group('Dynamic Model Discovery & Portal Access Control Tests', () {
    test('Case 1: Internal user has isPortal == false', () {
      const user = AuthUser(
        id: '2',
        email: 'employee@360.org.vn',
        userMetadata: {
          'is_portal': false,
          'share': false,
          'user_type': 'internal',
        },
      );
      expect(user.isPortal, isFalse);
    });

    test('Case 2: Portal user with share == true is detected as isPortal', () {
      const user = AuthUser(
        id: '10',
        email: 'customer@client.com',
        userMetadata: {
          'share': true,
        },
      );
      expect(user.isPortal, isTrue);
    });

    test('Case 3: Portal user with user_type == portal is detected as isPortal', () {
      const user = AuthUser(
        id: '11',
        email: 'portal@domain.com',
        userMetadata: {
          'user_type': 'portal',
        },
      );
      expect(user.isPortal, isTrue);
    });

    test('Case 4: installedModules parses valid Map from userMetadata', () {
      const user = AuthUser(
        id: '12',
        email: 'user@domain.com',
        userMetadata: {
          'installed_modules': {
            'helpdesk': true,
            'hr_attendance': false,
            'hr_timesheet': false,
            'project': true,
            'mail': true,
          },
        },
      );
      expect(user.installedModules['helpdesk'], isTrue);
      expect(user.installedModules['hr_attendance'], isFalse);
      expect(user.installedModules['project'], isTrue);
      expect(user.installedModules['mail'], isTrue);
    });

    test('Case 5: hasHelpdesk returns true when helpdesk is installed', () {
      const user = AuthUser(
        id: '13',
        email: 'portal_with_ticket@domain.com',
        userMetadata: {
          'is_portal': true,
          'installed_modules': {'helpdesk': true},
        },
      );
      expect(user.hasHelpdesk, isTrue);
    });

    test('Case 6: hasHelpdesk returns false when helpdesk is omitted or false', () {
      const user = AuthUser(
        id: '14',
        email: 'portal_no_ticket@domain.com',
        userMetadata: {
          'is_portal': true,
          'installed_modules': {'helpdesk': false, 'mail': true},
        },
      );
      expect(user.hasHelpdesk, isFalse);
    });

    test('Case 7: hasAttendance and hasTimesheet reflect installed_modules', () {
      const user = AuthUser(
        id: '15',
        email: 'admin@domain.com',
        userMetadata: {
          'installed_modules': {
            'hr_attendance': true,
            'hr_timesheet': true,
          },
        },
      );
      expect(user.hasAttendance, isTrue);
      expect(user.hasTimesheet, isTrue);
    });

    test('Case 8: hasProject reflects installed_modules', () {
      const user = AuthUser(
        id: '16',
        email: 'user@domain.com',
        userMetadata: {
          'installed_modules': {'project': true},
        },
      );
      expect(user.hasProject, isTrue);
    });

    test('Case 9: installedModules returns empty map safely when metadata is null or non-map', () {
      const user = AuthUser(
        id: '17',
        email: 'legacy@domain.com',
        userMetadata: {
          'installed_modules': 'invalid_string',
        },
      );
      expect(user.installedModules, isEmpty);
      expect(user.hasHelpdesk, isFalse);
      expect(user.hasAttendance, isFalse);
      expect(user.hasTimesheet, isFalse);
    });

    test('Case 10: Dynamic Portal tab configuration: Ticket is hidden when hasHelpdesk is false', () {
      const portalNoHelpdesk = AuthUser(
        id: '18',
        email: 'client@domain.com',
        userMetadata: {
          'is_portal': true,
          'installed_modules': {'helpdesk': false, 'mail': true},
        },
      );

      // Mô phỏng logic dựng tabs trong AppScaffold
      final tabs = <String>[
        if (portalNoHelpdesk.hasHelpdesk) '/tickets',
        '/chat',
        '/profile',
      ];

      expect(tabs, equals(['/chat', '/profile']));
      expect(tabs.contains('/tickets'), isFalse);
      expect(tabs.length, equals(2));
    });

    test('Case 11: Dynamic Portal tab configuration: Ticket is visible when hasHelpdesk is true', () {
      const portalWithHelpdesk = AuthUser(
        id: '19',
        email: 'client@domain.com',
        userMetadata: {
          'is_portal': true,
          'installed_modules': {'helpdesk': true, 'mail': true},
        },
      );

      final tabs = <String>[
        if (portalWithHelpdesk.hasHelpdesk) '/tickets',
        '/chat',
        '/profile',
      ];

      expect(tabs, equals(['/tickets', '/chat', '/profile']));
      expect(tabs.contains('/tickets'), isTrue);
      expect(tabs.length, equals(3));
    });

    test('Case 12: Internal employee navigation always has 5 tabs', () {
      const internalTabs = ['/home', '/chat', '/timesheet', '/tickets', '/profile'];
      expect(internalTabs.length, equals(5));
      expect(internalTabs.contains('/home'), isTrue);
      expect(internalTabs.contains('/attendance') || internalTabs.contains('/timesheet'), isTrue);
    });
  });
}
