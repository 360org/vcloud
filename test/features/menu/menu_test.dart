import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/core/api/auth_user.dart';
import 'package:vcloud/core/api/odoo_session.dart';
import 'package:vcloud/features/menu/application/menu_controller.dart';
import 'package:vcloud/features/menu/data/menu_item_model.dart';
import 'package:vcloud/features/menu/data/menu_repository.dart';
import 'package:vcloud/features/menu/presentation/app_drawer_bottom_sheet.dart';
import 'package:vcloud/features/menu/presentation/odoo_webview_screen.dart';
import 'package:vcloud/shared/widgets/app_scaffold.dart';

class _FakeMenuRepository extends MenuRepository {
  _FakeMenuRepository({this.shouldThrow = false});

  final bool shouldThrow;

  @override
  Future<({List<AppMenuItem> apps, List<AppUtilityItem> utilities})>
      fetchAppsMenu() async {
    if (shouldThrow) {
      throw Exception('Network error');
    }
    return (
      apps: const [
        AppMenuItem(
          id: 102,
          name: 'Chuyên cần',
          nativeRoute: '/timesheet',
          isNative: true,
          isBookmarked: true,
        ),
        AppMenuItem(
          id: 105,
          name: 'Kế toán',
          webUrl: '/web#action=210&menu_id=105',
          isNative: false,
          isBookmarked: false,
        ),
        AppMenuItem(
          id: 108,
          name: 'Tuyển dụng',
          webUrl: '/web#action=300&menu_id=108',
          isNative: false,
          isBookmarked: false,
        ),
      ],
      utilities: const [
        AppUtilityItem(
          id: 'support',
          name: 'Yêu cầu hỗ trợ',
          nativeRoute: '/tickets',
        ),
      ],
    );
  }
}

void main() {
  group('AppMenuItem & AppUtilityItem model', () {
    test('fromJson and toJson roundtrip correctly', () {
      final json = {
        'id': 102,
        'name': 'Chuyên cần',
        'xmlid': 'hr_attendance.menu_hr_attendance_root',
        'action_id': 145,
        'web_icon': 'hr_attendance,static/description/icon.png',
        'web_icon_data': 'data:image/png;base64,abc123==',
        'native_route': '/timesheet',
        'is_native': true,
        'is_bookmarked': true,
      };

      final item = AppMenuItem.fromJson(json);
      expect(item.id, 102);
      expect(item.name, 'Chuyên cần');
      expect(item.xmlid, 'hr_attendance.menu_hr_attendance_root');
      expect(item.actionId, 145);
      expect(item.webIcon, 'hr_attendance,static/description/icon.png');
      expect(item.webIconData, 'data:image/png;base64,abc123==');
      expect(item.nativeRoute, '/timesheet');
      expect(item.isNative, isTrue);
      expect(item.isBookmarked, isTrue);

      final exported = item.toJson();
      expect(exported['id'], 102);
      expect(exported['is_native'], isTrue);
      expect(exported['is_bookmarked'], isTrue);
    });

    test('copyWith works as expected', () {
      const item = AppMenuItem(id: 1, name: 'Test', isNative: false);
      final updated = item.copyWith(isNative: true, name: 'Updated');
      expect(updated.id, 1);
      expect(updated.name, 'Updated');
      expect(updated.isNative, isTrue);
    });

    test('AppUtilityItem parses fromJson correctly', () {
      final json = {
        'id': 'docs',
        'name': 'Tài liệu hướng dẫn',
        'icon': 'book_open',
        'url': '/help/docs',
      };
      final item = AppUtilityItem.fromJson(json);
      expect(item.id, 'docs');
      expect(item.name, 'Tài liệu hướng dẫn');
      expect(item.icon, 'book_open');
      expect(item.url, '/help/docs');
    });
  });

  group('MenuController', () {
    test('loads menu and filters by search query and tabs', () async {
      final fakeRepo = _FakeMenuRepository();
      final controller = MenuController(fakeRepo);

      await controller.loadMenu();
      expect(controller.state.apps.length, 3);
      expect(controller.state.utilities.length, 1);
      expect(controller.state.bookmarkedIds.contains(102), isTrue);

      // Search query filter
      controller.setSearchQuery('kế toán');
      expect(controller.state.filteredApps.length, 1);
      expect(controller.state.filteredApps.first.id, 105);

      // Reset query
      controller.setSearchQuery('');
      expect(controller.state.filteredApps.length, 3);

      // Bookmark tab filter
      controller.setActiveTab('bookmark');
      expect(controller.state.filteredApps.length, 1);
      expect(controller.state.filteredApps.first.id, 102);

      // Toggle bookmark for Kế toán (105)
      controller.toggleBookmark(105);
      expect(controller.state.filteredApps.length, 2);

      // Untoggle bookmark for Kế toán
      controller.toggleBookmark(105);
      expect(controller.state.filteredApps.length, 1);
    });

    test('falls back to default utilities if repository returns empty',
        () async {
      final fakeRepo = _FakeMenuRepository(shouldThrow: true);
      final controller = MenuController(fakeRepo);

      await controller.loadMenu();
      expect(controller.state.apps, isEmpty);
      expect(controller.state.utilities.length, 3); // default utilities
    });
  });

  group('buildTargetWebViewUrl', () {
    final session19 = OdooSession(
      accessToken: 'test_token',
      uid: 2,
      db: 'vcloud_test_v19',
      login: 'admin',
      expiresAt: DateTime.now().add(const Duration(days: 1)),
      baseUrl: 'http://192.168.1.100:1900',
    );

    test('uses SSO bridge with token and db when session is present', () {
      final url = buildTargetWebViewUrl(
        rawUrl: '/web#action=base.action_res_users',
        session: session19,
        baseUrl: 'http://192.168.1.100:1900',
      );
      expect(url, contains('/api/v1/mobile/web/auth'));
      expect(url, contains('token=test_token'));
      expect(url, contains('db=vcloud_test_v19'));
      expect(url, contains('redirect='));
      expect(url, isNot(contains('/web/database/selector')));
    });

    test('injects db into query parameter before fragment when session is null', () {
      final url = buildTargetWebViewUrl(
        rawUrl: '/web#action=210&menu_id=105',
        session: null,
        baseUrl: 'http://192.168.1.100:8069',
      );
      expect(url, contains('/web?db='));
      expect(url, contains('#action=210&menu_id=105'));
      expect(url, isNot(contains('/web/database/selector')));
    });

    test('preserves existing query parameters and does not duplicate db', () {
      final url = buildTargetWebViewUrl(
        rawUrl: '/web?cids=1#action=123',
        session: null,
        baseUrl: 'http://192.168.1.100:1900',
      );
      expect(url, contains('cids=1'));
      expect(url, contains('db='));
      expect(url, contains('#action=123'));
    });

    test('preserves /web and appends ?db= before fragment', () {
      final url = buildTargetWebViewUrl(
        rawUrl: '/web#action=210&menu_id=105',
        session: null,
        baseUrl: 'http://192.168.1.100:1900',
      );
      expect(url, contains('/web?db='));
      expect(url, contains('#action=210&menu_id=105'));
      expect(url, isNot(contains('/odoo')));
      expect(url, isNot(contains('/web/database/selector')));
    });

    test('falls back to /web with SSO when rawUrl is empty', () {
      final url = buildTargetWebViewUrl(
        rawUrl: '',
        session: session19,
        baseUrl: 'http://192.168.1.100:1900',
      );
      expect(url, contains('/api/v1/mobile/web/auth'));
      expect(url, contains('token=test_token'));
      expect(url, contains('db=vcloud_test_v19'));
      expect(url, contains('redirect='));
    });
  });

  group('formatAppWebUrl', () {
    test('appends ?db=<db> before # fragment', () {
      final formatted = formatAppWebUrl(
        '/web#action=210&menu_id=105',
        db: 'custom_db',
      );
      expect(formatted, equals('/web?db=custom_db#action=210&menu_id=105'));
    });

    test('appends &db=<db> before # fragment when query params already exist', () {
      final formatted = formatAppWebUrl(
        '/web?cids=1#action=210&menu_id=105',
        db: 'custom_db',
      );
      expect(formatted, equals('/web?cids=1&db=custom_db#action=210&menu_id=105'));
    });

    test('does not duplicate db if db= is already present before #', () {
      final formatted = formatAppWebUrl(
        '/web?db=existing_db#action=210',
        db: 'custom_db',
      );
      expect(formatted, equals('/web?db=existing_db#action=210'));
    });

    test('appends ?db=<db> to URL without fragment', () {
      final formatted = formatAppWebUrl(
        '/help/docs',
        db: 'custom_db',
      );
      expect(formatted, equals('/help/docs?db=custom_db'));
    });
  });

  group('AppScaffold showAppsDrawer logic', () {
    test('shouldShowAppsDrawer returns false when user is null', () {
      expect(
        AppScaffold.shouldShowAppsDrawer(user: null),
        isFalse,
      );
    });

    test('shouldShowAppsDrawer returns false for Portal user with is_portal=true', () {
      const portalUser = AuthUser(
        id: '101',
        email: 'customer@example.com',
        userMetadata: {'is_portal': true},
      );
      expect(
        AppScaffold.shouldShowAppsDrawer(user: portalUser),
        isFalse,
      );
    });

    test('shouldShowAppsDrawer returns false for Portal user with user_type=portal', () {
      const portalUser = AuthUser(
        id: '102',
        email: 'portal@example.com',
        userMetadata: {'user_type': 'portal'},
      );
      expect(
        AppScaffold.shouldShowAppsDrawer(user: portalUser),
        isFalse,
      );
    });

    test('shouldShowAppsDrawer returns false when sessionScope is portal', () {
      const employeeUser = AuthUser(
        id: '2',
        email: 'emp@example.com',
        userMetadata: {'is_portal': false},
      );
      expect(
        AppScaffold.shouldShowAppsDrawer(
          user: employeeUser,
          sessionScope: 'portal',
        ),
        isFalse,
      );
    });

    test('shouldShowAppsDrawer returns true for internal employee with non-portal scope', () {
      const employeeUser = AuthUser(
        id: '2',
        email: 'employee@360.org.vn',
        userMetadata: {'is_portal': false, 'user_type': 'internal'},
      );
      expect(
        AppScaffold.shouldShowAppsDrawer(
          user: employeeUser,
          sessionScope: null,
        ),
        isTrue,
      );
    });
  });

  group('extractOdooTargetHash (Pha 1 SPA Routing)', () {
    test('extracts hash fragment from standard module URL', () {
      final hash = extractOdooTargetHash('/web#action=72&cids=1&menu_id=214');
      expect(hash, equals('#action=72&cids=1&menu_id=214'));
    });

    test('extracts hash fragment from URL with db query param', () {
      final hash = extractOdooTargetHash('/web?db=vcloud_test_v19#action=120&menu_id=50');
      expect(hash, equals('#action=120&menu_id=50'));
    });

    test('converts /home/action-2186 into #action=2186', () {
      final hash = extractOdooTargetHash('/home/action-2186');
      expect(hash, equals('#action=2186'));
    });

    test('converts /home/action-2186?db=xyz into #action=2186', () {
      final hash = extractOdooTargetHash('/home/action-2186?db=vcloud_test_v19');
      expect(hash, equals('#action=2186'));
    });

    test('returns null for URLs without hash or action pattern', () {
      final hash = extractOdooTargetHash('/help/docs');
      expect(hash, isNull);
    });
  });
}
