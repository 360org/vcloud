import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
  TestWidgetsFlutterBinding.ensureInitialized();
  FlutterSecureStorage.setMockInitialValues({});

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

    test('persists bookmarked items across instances via storage', () async {
      FlutterSecureStorage.setMockInitialValues({});
      final fakeRepo = _FakeMenuRepository();
      final controller1 = MenuController(fakeRepo);
      await controller1.loadMenu();

      // Bookmark 108
      final isAdded = await controller1.toggleBookmark(108);
      expect(isAdded, isTrue);
      expect(controller1.state.bookmarkedIds.contains(108), isTrue);

      // Create new instance of controller representing app restart
      final controller2 = MenuController(fakeRepo);
      await controller2.loadMenu();
      expect(controller2.state.bookmarkedIds.contains(108), isTrue);
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

    test('optimizes with direct URL when useDirectUrlIfAuthenticated is true and hasSsoAuthenticated is true', () {
      OdooWebViewScreen.hasSsoAuthenticated = true;
      final url = buildTargetWebViewUrl(
        rawUrl: '/web#action=210',
        session: session19,
        baseUrl: 'http://192.168.1.100:1900',
        useDirectUrlIfAuthenticated: true,
      );
      expect(url, equals('http://192.168.1.100:1900/web?db=vcloud_test_v19#action=210'));
      expect(url, isNot(contains('/api/v1/mobile/web/auth')));
      OdooWebViewScreen.hasSsoAuthenticated = false; // Reset sau test
    });

    test('requires SSO bridge when session has sessionId but WebView has NOT completed SSO yet (prevents CSRF 400)', () {
      OdooWebViewScreen.hasSsoAuthenticated = false;
      final sessionWithSid = session19.copyWith(sessionId: 'stale_session_cookie_123');
      final url = buildTargetWebViewUrl(
        rawUrl: '/web#action=210',
        session: sessionWithSid,
        baseUrl: 'http://192.168.1.100:1900',
        useDirectUrlIfAuthenticated: true,
      );
      expect(url, contains('/api/v1/mobile/web/auth'));
      expect(url, contains('token=test_token'));
      expect(url, contains('db=vcloud_test_v19'));
    });

    test('scopes SSO fast path to baseUrl|db|uid and rejects mismatch', () {
      OdooWebViewScreen.resetSso();
      OdooWebViewScreen.markSsoAuthenticated(
        session19,
        baseUrl: 'http://192.168.1.100:1900',
      );
      final sameSessionDirect = buildTargetWebViewUrl(
        rawUrl: '/web#action=210',
        session: session19,
        baseUrl: 'http://192.168.1.100:1900',
        useDirectUrlIfAuthenticated: true,
      );
      expect(sameSessionDirect, isNot(contains('/api/v1/mobile/web/auth')));

      final differentUidSession = session19.copyWith(uid: 999);
      final switchedUserUrl = buildTargetWebViewUrl(
        rawUrl: '/web#action=210',
        session: differentUidSession,
        baseUrl: 'http://192.168.1.100:1900',
        useDirectUrlIfAuthenticated: true,
      );
      expect(switchedUserUrl, contains('/api/v1/mobile/web/auth'));
      OdooWebViewScreen.resetSso();
    });

    test('buildWebViewAuthHeaders omits Cookie header to prevent iOS WKWebView CSRF collision', () {
      final sessionWithSid = session19.copyWith(sessionId: 'stale_cookie_xyz');
      final headers = buildWebViewAuthHeaders(sessionWithSid);
      expect(headers.containsKey('Cookie'), isFalse);
      expect(headers.containsKey('cookie'), isFalse);
      expect(headers['Authorization'], equals('Bearer test_token'));
      expect(headers['X-Odoo-Database'], equals('vcloud_test_v19'));
    });

    test('isOdooCsrfOrSessionErrorPage detects Vietnamese & English 400 CSRF error pages', () {
      expect(
        isOdooCsrfOrSessionErrorPage(
          '400: Yêu cầu không hợp lệ\nThông điệp lỗi:\nSession expired (invalid CSRF token)',
        ),
        isTrue,
      );
      expect(
        isOdooCsrfOrSessionErrorPage('Bad Request: Invalid CSRF token'),
        isTrue,
      );
      expect(
        isOdooCsrfOrSessionErrorPage('Knowledge - Tài liệu hướng dẫn nội bộ'),
        isFalse,
      );
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

  group('buildOdooNativeOptimizationCss (CSS Safeguard & Error Shield)', () {
    test('enforces system sans-serif font family on root and body', () {
      final css = buildOdooNativeOptimizationCss(isDark: false);
      expect(css, contains('font-family: -apple-system, BlinkMacSystemFont'));
    });

    test('completely suppresses Odoo CSS compilation error banner body::before and css_error_message', () {
      final css = buildOdooNativeOptimizationCss(isDark: true);
      expect(css, contains('body::before {'));
      expect(css, contains('display: none !important;'));
      expect(css, contains('content: "" !important;'));
      expect(css, contains('visibility: hidden !important;'));
      expect(css, contains('css_error_message {'));
      expect(css, contains('pointer-events: none !important;'));
    });

    test('generates proper dark mode variables and background rules when isDark is true', () {
      final darkCss = buildOdooNativeOptimizationCss(isDark: true);
      expect(darkCss, contains('color-scheme: dark !important;'));
      expect(darkCss, contains('--body-bg: #0F1729 !important;'));
      expect(darkCss, contains('--body-color: #F1F5F9 !important;'));
    });

    test('generates light mode rules when isDark is false', () {
      final lightCss = buildOdooNativeOptimizationCss(isDark: false);
      expect(lightCss, contains('color-scheme: light !important;'));
      expect(lightCss, contains('background-color: #FFFFFF !important;'));
      expect(lightCss, isNot(contains('--body-bg: #0F1729 !important;')));
    });

    test('enforces single scroll container and suppresses nested scroll lockup', () {
      final css = buildOdooNativeOptimizationCss(isDark: false);
      expect(css, contains('.o_action_manager {'));
      expect(css, contains('overflow: hidden !important;'));
      expect(css, contains('.o_content {'));
      expect(css, contains('overflow-y: auto !important;'));
      expect(css, contains('-webkit-overflow-scrolling: touch !important;'));
      expect(css, contains('will-change: scroll-position;'));
    });

    test('suppresses heavy animations and transitions for smooth 3G/4G rendering', () {
      final css = buildOdooNativeOptimizationCss(isDark: false);
      expect(css, contains('.fade, .collapse, .collapsing {'));
      expect(css, contains('transition: none !important;'));
      expect(css, contains('animation-duration: 0.001s !important;'));
    });

    test('hides background livechat and chatter widgets to save 3G/4G bandwidth', () {
      final css = buildOdooNativeOptimizationCss(isDark: false);
      expect(css, contains('.o_LivechatButton'));
      expect(css, contains('.o_notification_manager'));
      expect(css, contains('display: none !important;'));
    });

    test('getMinifiedOdooNativeOptimizationCss caches minified CSS without newlines', () {
      final light1 = getMinifiedOdooNativeOptimizationCss(isDark: false);
      final light2 = getMinifiedOdooNativeOptimizationCss(isDark: false);
      final dark1 = getMinifiedOdooNativeOptimizationCss(isDark: true);
      final dark2 = getMinifiedOdooNativeOptimizationCss(isDark: true);

      expect(identical(light1, light2), isTrue);
      expect(identical(dark1, dark2), isTrue);
      expect(light1.contains('\n'), isFalse);
      expect(dark1.contains('\n'), isFalse);
      expect(light1, isNot(equals(dark1)));
    });
  });

  group('parseOdooNavigationTarget (OWL Native SPA Fast-Path Odoo 17 & 19)', () {
    test('parses /mail/view activity document URL into record form target', () {
      final target = parseOdooNavigationTarget(
        '/mail/view?model=sale.order&res_id=837&db=vcloud_test_v19',
      );
      expect(target, isNotNull);
      expect(target!.isRecordForm, isTrue);
      expect(target.resModel, equals('sale.order'));
      expect(target.resId, equals(837));
      expect(target.targetHash, equals('#id=837&model=sale.order&view_type=form'));
    });

    test('parses Odoo 19 /odoo/<model>/<id> URL into record form target', () {
      final target = parseOdooNavigationTarget(
        'http://192.168.1.100:1900/odoo/purchase.order/278?menu_id=944',
      );
      expect(target, isNotNull);
      expect(target!.isRecordForm, isTrue);
      expect(target.resModel, equals('purchase.order'));
      expect(target.resId, equals(278));
      expect(target.menuId, equals(944));
    });

    test('parses AppDrawerBottomSheet /web#action=X&menu_id=Y URL', () {
      final target = parseOdooNavigationTarget(
        '/web?db=vcloud_test_v19#action=210&menu_id=105',
      );
      expect(target, isNotNull);
      expect(target!.isRecordForm, isFalse);
      expect(target.hasMenuOrAction, isTrue);
      expect(target.action, equals('210'));
      expect(target.menuId, equals(105));
      expect(target.targetHash, equals('#action=210&menu_id=105'));
    });

    test('parses XML ID action such as base.action_res_users', () {
      final target = parseOdooNavigationTarget(
        '/web?db=vcloud_test_v19#action=base.action_res_users',
      );
      expect(target, isNotNull);
      expect(target!.action, equals('base.action_res_users'));
      expect(target.menuId, isNull);
    });

    test('parses /home/action-<id> into action target', () {
      final target = parseOdooNavigationTarget('/home/action-2186?db=vcloud_test_v19');
      expect(target, isNotNull);
      expect(target!.action, equals('2186'));
      expect(target.targetHash, equals('#action=2186'));
    });

    test('returns null for non-OWL static/knowledge URLs so loadRequest fallback runs', () {
      expect(parseOdooNavigationTarget('/knowledge/article/126?db=vcloud_test_v19'), isNull);
      expect(parseOdooNavigationTarget('/help/docs'), isNull);
      expect(parseOdooNavigationTarget(''), isNull);
    });

    test('prewarm and resetSso are safe no-ops in headless test environment', () async {
      OdooWebViewScreen.hasSsoAuthenticated = true;
      await OdooWebViewScreen.prewarm(isDark: true);
      OdooWebViewScreen.resetSso();
      expect(OdooWebViewScreen.hasSsoAuthenticated, isFalse);
    });
  });

  group('AppDrawerBottomSheet raster icon cache & SVG guard', () {
    setUp(() {
      AppDrawerBottomSheet.clearIconCache();
    });

    test('caches identical Uint8List instance for valid PNG base64 across rebuilds', () {
      // 1x1 transparent PNG
      const pngDataUri =
          'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=';
      final first = AppDrawerBottomSheet.decodeSupportedRasterIcon(pngDataUri);
      final second = AppDrawerBottomSheet.decodeSupportedRasterIcon(pngDataUri);

      expect(first, isNotNull);
      expect(identical(first, second), isTrue);
      expect(AppDrawerBottomSheet.decodedIconCache.containsKey(pngDataUri), isTrue);

      AppDrawerBottomSheet.clearIconCache();
      expect(AppDrawerBottomSheet.decodedIconCache, isEmpty);
    });

    test('filters out SVG data URIs and raw <svg> base64 to prevent Android ImageDecoder crash', () {
      final svgBase64 = base64Encode(utf8.encode('<svg xmlns="http://www.w3.org/2000/svg"></svg>'));
      final svgDataUri = 'data:image/svg+xml;base64,$svgBase64';

      expect(AppDrawerBottomSheet.decodeSupportedRasterIcon(svgDataUri), isNull);
      expect(AppDrawerBottomSheet.decodeSupportedRasterIcon(svgBase64), isNull);
      expect(AppDrawerBottomSheet.decodeSupportedRasterIcon(null), isNull);
      expect(AppDrawerBottomSheet.decodeSupportedRasterIcon('   '), isNull);
    });
  });
}
