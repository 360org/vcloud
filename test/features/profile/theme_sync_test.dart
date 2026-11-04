import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/features/profile/application/theme_controller.dart';
import 'package:vcloud/features/menu/presentation/odoo_webview_screen.dart';
import 'package:vcloud/core/api/odoo_session.dart';

void main() {
  group('Theme Synchronization Unit Tests (prompt_theme_sync)', () {
    test('Case 1: AppThemeMode.system trả về ThemeMode.system của hệ điều hành', () {
      expect(AppThemeMode.system.themeMode, equals(ThemeMode.system));
    });

    test('Case 2: AppThemeMode.dark trả về ThemeMode.dark', () {
      expect(AppThemeMode.dark.themeMode, equals(ThemeMode.dark));
    });

    test('Case 3: AppThemeMode.light trả về ThemeMode.light', () {
      expect(AppThemeMode.light.themeMode, equals(ThemeMode.light));
    });

    test('Case 4: buildTargetWebViewUrl truyền color_scheme=dark vào SSO bridge URL', () {
      final session = OdooSession(
        uid: 1,
        login: 'admin',
        db: 'vcloud_test_v19',
        accessToken: 'dummy.jwt.token',
        expiresAt: DateTime.now().add(const Duration(days: 1)),
        baseUrl: 'http://192.168.1.100:1900',
      );

      final url = buildTargetWebViewUrl(
        rawUrl: '/odoo/action-123',
        session: session,
        colorScheme: 'dark',
      );

      final uri = Uri.parse(url);
      expect(uri.queryParameters['token'], equals('dummy.jwt.token'));
      expect(uri.queryParameters['color_scheme'], equals('dark'));
      expect(uri.queryParameters['db'], equals('vcloud_test_v19'));
    });

    test('Case 5: buildTargetWebViewUrl truyền color_scheme=light vào SSO bridge URL', () {
      final session = OdooSession(
        uid: 1,
        login: 'admin',
        db: 'vcloud_test_v19',
        accessToken: 'dummy.jwt.token',
        expiresAt: DateTime.now().add(const Duration(days: 1)),
        baseUrl: 'http://192.168.1.100:1900',
      );

      final url = buildTargetWebViewUrl(
        rawUrl: '/odoo/action-123',
        session: session,
        colorScheme: 'light',
      );

      final uri = Uri.parse(url);
      expect(uri.queryParameters['color_scheme'], equals('light'));
    });

    test('Case 6: buildTargetWebViewUrl khi colorScheme rỗng hoặc null không gắn color_scheme thừa', () {
      final session = OdooSession(
        uid: 1,
        login: 'admin',
        db: 'vcloud_test_v19',
        accessToken: 'dummy.jwt.token',
        expiresAt: DateTime.now().add(const Duration(days: 1)),
        baseUrl: 'http://192.168.1.100:1900',
      );

      final urlNull = buildTargetWebViewUrl(
        rawUrl: '/odoo/action-123',
        session: session,
        colorScheme: null,
      );
      expect(Uri.parse(urlNull).queryParameters.containsKey('color_scheme'), isFalse);

      final urlEmpty = buildTargetWebViewUrl(
        rawUrl: '/odoo/action-123',
        session: session,
        colorScheme: '',
      );
      expect(Uri.parse(urlEmpty).queryParameters.containsKey('color_scheme'), isFalse);
    });

    test('Case 7: buildTargetWebViewUrl khi session null thì resolve URL an toàn không lỗi', () {
      final url = buildTargetWebViewUrl(
        rawUrl: '/web#action=321',
        session: null,
        baseUrl: 'http://192.168.1.100:1900',
        colorScheme: 'dark',
      );
      expect(url, equals('http://192.168.1.100:1900/web?db=vcloud_test_v19#action=321'));
    });

    test('Case 8: buildTargetWebViewUrl bảo toàn redirect parameter chứa URI gốc', () {
      final session = OdooSession(
        uid: 2,
        login: 'demo',
        db: 'vcloud_test_v19',
        accessToken: 'valid.token',
        expiresAt: DateTime.now().add(const Duration(hours: 2)),
        baseUrl: 'http://192.168.1.100:1900',
      );

      final url = buildTargetWebViewUrl(
        rawUrl: '/odoo/project/10?view_type=form#cids=1',
        session: session,
        colorScheme: 'dark',
      );

      final uri = Uri.parse(url);
      expect(uri.queryParameters['redirect'], equals('/odoo/project/10?view_type=form&db=vcloud_test_v19#cids=1'));
      expect(uri.queryParameters['color_scheme'], equals('dark'));
    });

    test('Case 9: buildOdooNativeOptimizationCss sinh CSS Dark Mode đúng màu nền #0F1729 và color-scheme: dark', () {
      final css = buildOdooNativeOptimizationCss(isDark: true);
      expect(css, contains('color-scheme: dark !important;'));
      expect(css, contains('background-color: #0F1729 !important;'));
      expect(css, contains('color: #F1F5F9 !important;'));
      expect(css, contains('.o_action_manager'));
    });

    test('Case 10: buildOdooNativeOptimizationCss sinh CSS Light Mode đúng màu nền #FFFFFF và color-scheme: light', () {
      final css = buildOdooNativeOptimizationCss(isDark: false);
      expect(css, contains('color-scheme: light !important;'));
      expect(css, contains('background-color: #FFFFFF !important;'));
      expect(css, contains('color: #0F172A !important;'));
      expect(css, contains('.o_action_manager'));
    });

    test('Case 11: buildOdooNativeOptimizationCss sinh CSS Dark Mode đầy đủ cho các thành phần Odoo (.o_kanban_record, .o_control_panel, .o_form_sheet)', () {
      final css = buildOdooNativeOptimizationCss(isDark: true);
      expect(css, contains('.o_control_panel'));
      expect(css, contains('.o_kanban_record'));
      expect(css, contains('.o_list_table'));
      expect(css, contains('.o_form_sheet'));
      expect(css, contains('--KanbanRecord-background: #1E293B !important;'));
      expect(css, contains('--ControlPanel-background: #0F1729 !important;'));
    });

    test('Case 12: buildOdooNativeOptimizationCss sinh CSS Light Mode không chứa rules ghi đè dark mode của Odoo', () {
      final css = buildOdooNativeOptimizationCss(isDark: false);
      expect(css, isNot(contains('--KanbanRecord-background')));
      expect(css, isNot(contains('--ControlPanel-background')));
      expect(css, isNot(contains('.o_kanban_renderer')));
    });
  });
}
