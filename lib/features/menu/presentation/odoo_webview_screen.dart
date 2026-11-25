import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
// ignore: depend_on_referenced_packages
import 'package:webview_flutter_android/webview_flutter_android.dart';
// ignore: depend_on_referenced_packages
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

import '../../../core/api/odoo_api_client.dart';
import '../../../core/api/odoo_session.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../profile/application/theme_controller.dart';
import 'widgets/odoo_web_frame.dart';

/// Enum điều khiển Force Dark trên Android WebView
enum ForceDark { off, on, auto }

/// Extension bổ sung setForceDark cho [AndroidWebViewController]
extension AndroidWebViewControllerForceDark on AndroidWebViewController {
  /// ponytail: webview_flutter_android chưa bind API setForceDark trực tiếp từ Pigeon;
  /// method này giữ API contract chuẩn và kết hợp cùng CSS :root { color-scheme: light/dark }
  /// để điều khiển hiển thị trên WebView Android.
  Future<void> setForceDark(ForceDark mode) async {
    try {
      final color = mode == ForceDark.on ? const Color(0xFF0F1729) : Colors.white;
      await setBackgroundColor(color);
    } catch (_) {}
  }
}

/// Sinh CSS tối ưu hóa Native UX và thích ứng chính xác theo Theme Sáng / Tối
@visibleForTesting
String buildOdooNativeOptimizationCss({required bool isDark}) {
  final colorScheme = isDark ? 'dark' : 'light';
  final bgColor = isDark ? '#0F1729' : '#FFFFFF';
  final textColor = isDark ? '#F1F5F9' : '#0F172A';

  final darkModeRules = isDark
      ? '''
/* 7. Dark Mode Styling toàn diện cho Odoo Web Client khi App ở chế độ Tối */
:root {
  --body-bg: #0F1729 !important;
  --body-color: #F1F5F9 !important;
  --bs-body-bg: #0F1729 !important;
  --bs-body-color: #F1F5F9 !important;
  --bs-card-bg: #1E293B !important;
  --bs-card-border-color: #334155 !important;
  --bs-border-color: #334155 !important;
  --bs-tertiary-bg: #1E293B !important;
  --KanbanRecord-background: #1E293B !important;
  --KanbanRecord-color: #F1F5F9 !important;
  --ControlPanel-background: #0F1729 !important;
  --o-view-background-color: #0F1729 !important;
  --o-webclient-background-color: #0F1729 !important;
  --o-form-lightsecondary: #1E293B !important;
  --o-searchview-background: #0F1729 !important;
}

/* Background & Text vùng nội dung */
.o_content,
.o_view_controller,
.o_form_sheet_bg,
.o_kanban_view,
.o_list_view,
.o_calendar_view,
.o_activity_view,
.o_pivot_view,
.o_graph_view {
  background-color: #0F1729 !important;
  color: #F1F5F9 !important;
}

/* Control Panel, Search Bar & Breadcrumbs */
.o_control_panel,
.o_cp_top,
.o_cp_bottom,
.o_cp_searchview,
.o_searchview,
.o_searchview_input_container {
  background-color: #0F1729 !important;
  color: #F1F5F9 !important;
  border-color: #334155 !important;
}
.o_control_panel .breadcrumb,
.o_control_panel .breadcrumb-item,
.o_control_panel .breadcrumb-item a {
  color: #F1F5F9 !important;
}

/* Kanban Cards, Records & Columns */
.o_kanban_renderer,
.o_kanban_view .o_kanban_record,
.o_kanban_record,
.o_kanban_group,
.o_kanban_header,
.o_kanban_quick_create,
.card {
  background-color: #1E293B !important;
  color: #F1F5F9 !important;
  border-color: #334155 !important;
}
.o_kanban_record * {
  color: inherit;
}
.o_kanban_record strong,
.o_kanban_record h1,
.o_kanban_record h2,
.o_kanban_record h3,
.o_kanban_record h4,
.o_kanban_record h5,
.o_kanban_record b {
  color: #F1F5F9 !important;
}
.o_kanban_record .text-muted,
.o_kanban_record small,
.o_kanban_record .o_field_widget {
  color: #94A3B8 !important;
}
.o_kanban_counter_side {
  color: #94A3B8 !important;
}

/* List View & Tables */
.o_list_table,
.table,
thead,
tbody,
tr,
th,
td {
  background-color: #1E293B !important;
  color: #F1F5F9 !important;
  border-color: #334155 !important;
}
.table-striped > tbody > tr:nth-of-type(odd) > * {
  background-color: #0F1729 !important;
  color: #F1F5F9 !important;
}
.table-striped > tbody > tr:nth-of-type(even) > * {
  background-color: #1E293B !important;
  color: #F1F5F9 !important;
}
.table-hover > tbody > tr:hover > * {
  background-color: #334155 !important;
}

/* Form View, Sheet & Group */
.o_form_sheet,
.o_form_view .o_form_sheet,
.o_form_statusbar,
.o_statusbar_status,
.o_group {
  background-color: #1E293B !important;
  color: #F1F5F9 !important;
  border-color: #334155 !important;
  box-shadow: none !important;
}

/* Input Fields & Selects */
.o_input,
input,
select,
textarea,
.form-control,
.form-select {
  background-color: #0F1729 !important;
  color: #F1F5F9 !important;
  border-color: #334155 !important;
}
input::placeholder,
textarea::placeholder {
  color: #64748B !important;
}

/* Secondary Buttons & Pagination */
.btn-secondary,
.btn-light,
.btn-default,
.btn-outline-secondary,
.o_pager_buttons .btn {
  background-color: #334155 !important;
  color: #F1F5F9 !important;
  border-color: #475569 !important;
}
.btn-link {
  color: #38BDF8 !important;
}

/* Dropdowns & Popovers */
.dropdown-menu,
.modal-content,
.popover,
.o_popover {
  background-color: #1E293B !important;
  color: #F1F5F9 !important;
  border-color: #334155 !important;
}
.dropdown-item {
  color: #F1F5F9 !important;
}
.dropdown-item:hover,
.dropdown-item:focus {
  background-color: #334155 !important;
  color: #F1F5F9 !important;
}
'''
      : '';

  return '''
:root, html, body {
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif !important;
  color-scheme: $colorScheme !important;
  background-color: $bgColor !important;
  color: $textColor !important;
}

/* 1. Ẩn triệt để toàn bộ navbar web Odoo để tránh 2 tầng menu */
.o_main_navbar,
.o_menu_brand,
header.o_navbar,
.o_navbar_apps_menu,
.o_menu_toggle,
.o_mobile_navbar {
  display: none !important;
}

/* 2. Loại bỏ khoảng trống thừa ở đỉnh trang và hiệu ứng tap mờ */
html, body {
  padding-top: 0 !important;
  margin-top: 0 !important;
  -webkit-font-smoothing: antialiased !important;
  -webkit-tap-highlight-color: transparent !important;
  touch-action: pan-x pan-y !important;
  overscroll-behavior-y: none !important;
}

/* 3. Tối ưu phân cấp cuộn mượt mà: Triệt tiêu xung đột nested scroll giữa action_manager và content */
.o_action_manager {
  top: 0 !important;
  height: 100% !important;
  overflow: hidden !important;
  background-color: $bgColor !important;
}

.o_content {
  overflow-y: auto !important;
  -webkit-overflow-scrolling: touch !important;
  overscroll-behavior-y: contain !important;
  will-change: scroll-position;
}

/* 4. Tối ưu hóa GPU & Rasterization: Giảm tiêu thụ VRAM chống tụt khung hình trên mobile */
.o_kanban_view, .o_list_view, .o_form_view {
  contain: content;
}

/* 5. Cải thiện độ nhạy và triệt tiêu độ trễ 300ms khi chạm trên mobile */
button, a, .o_dropdown_button, .o_kanban_record, .o_data_row, [role="button"] {
  touch-action: manipulation !important;
}

/* 6. Responsive CSS Media Queries cho Odoo Web */
@media (max-width: 359.98px) {
  html { font-size: 12px !important; }
}
@media (min-width: 360px) and (max-width: 599.98px) {
  html { font-size: 13px !important; }
}
.o_calendar_sync_buttons button, .o_cp_buttons .btn {
  padding: 4px 8px !important;
  font-size: 12px !important;
}

/* 7. Triệt tiêu hoàn toàn banner lỗi CSS nội bộ của Odoo (body::before) và thẻ css_error_message */
body::before {
  display: none !important;
  content: "" !important;
  visibility: hidden !important;
  height: 0 !important;
  width: 0 !important;
  opacity: 0 !important;
  pointer-events: none !important;
}
css_error_message {
  display: none !important;
}

/* 8. Fallback typography & form control styling khi asset compilation gặp sự cố */
a {
  text-decoration: none;
  color: #38BDF8;
}
.o_setting_box, .o_form_view {
  font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif !important;
}

/* 9. Triệt tiêu animation & transition nặng nề gây giật lag khi tải trên mạng 3G/4G */
.fade, .collapse, .collapsing {
  transition: none !important;
}
@media (max-width: 768px) {
  * {
    animation-duration: 0.001s !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.05s !important;
  }
}

/* 10. Ẩn các widget livechat & chatter nền của web để giảm tải kết nối websocket/longpolling trên 3G/4G */
.o_LivechatButton,
.o-livechat-LivechatButton,
.o_notification_manager,
.o_chat_window {
  display: none !important;
}

/* 11. Chống nghẽn hiển thị phông chữ (FOIT) khi mạng 3G/4G chập chờn */
* {
  font-display: swap !important;
}

$darkModeRules
''';
}

String? _cachedLightMinifiedCss;
String? _cachedDarkMinifiedCss;

/// Trả về chuỗi CSS tối ưu Native UX đã được minify và cache sẵn theo chế độ Sáng/Tối
/// nhằm loại bỏ hoàn toàn chi phí chạy RegExp lặp lại trên UI thread khi tải trang.
@visibleForTesting
String getMinifiedOdooNativeOptimizationCss({required bool isDark}) {
  if (isDark) {
    return _cachedDarkMinifiedCss ??= buildOdooNativeOptimizationCss(isDark: true)
        .replaceAll('\n', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll("'", r"\'");
  }
  return _cachedLightMinifiedCss ??= buildOdooNativeOptimizationCss(isDark: false)
      .replaceAll('\n', ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll("'", r"\'");
}

/// Trích xuất hash fragment của Odoo từ URL thô (dùng cho SPA Hash Routing tức thì)
String? extractOdooTargetHash(String rawUrl) {
  final trimmed = rawUrl.trim();
  if (trimmed.contains('#')) {
    return trimmed.substring(trimmed.indexOf('#'));
  }
  if (trimmed.contains('/home/action-')) {
    final after = trimmed.split('/home/action-').last;
    final actionId = after.split('?').first.split('#').first;
    if (actionId.isNotEmpty) {
      return '#action=$actionId';
    }
  }
  return null;
}

/// Đích điều hướng Odoo trích xuất từ URL để chuyển trang tức thì qua OWL Services (Odoo 17 & 19).
@visibleForTesting
class OdooNavigationTarget {
  const OdooNavigationTarget({
    this.resModel,
    this.resId,
    this.menuId,
    this.action,
    this.targetHash,
  });

  final String? resModel;
  final int? resId;
  final int? menuId;
  final String? action;
  final String? targetHash;

  bool get isRecordForm =>
      resModel != null && resModel!.isNotEmpty && resId != null && resId! > 0;

  bool get hasMenuOrAction =>
      (menuId != null && menuId! > 0) || (action != null && action!.isNotEmpty);
}

/// Phân tích URL Odoo (`/mail/view`, `/web#action=...&menu_id=...`, `/home/action-...`, `/odoo/<model>/<id>`)
/// thành [OdooNavigationTarget] phục vụ điều hướng SPA tức thì không cần tải lại HTML/JS.
@visibleForTesting
OdooNavigationTarget? parseOdooNavigationTarget(String rawUrl) {
  final trimmed = rawUrl.trim();
  if (trimmed.isEmpty) return null;

  final targetHash = extractOdooTargetHash(trimmed);
  final uri = Uri.tryParse(trimmed);

  if (uri != null) {
    // 1. Chứng từ từ Activity Center: /mail/view?model=sale.order&res_id=837
    if (uri.path.endsWith('/mail/view')) {
      final model = uri.queryParameters['model']?.trim();
      final resId = int.tryParse(uri.queryParameters['res_id'] ?? '');
      if (model != null && model.isNotEmpty && resId != null && resId > 0) {
        return OdooNavigationTarget(
          resModel: model,
          resId: resId,
          targetHash: '#id=$resId&model=$model&view_type=form',
        );
      }
    }

    // 2. Đường dẫn chuẩn Odoo 19: /odoo/<model>/<id>
    final segments = uri.pathSegments;
    if (segments.length >= 3 && segments[0] == 'odoo') {
      final candidateModel = segments[1].trim();
      final candidateId = int.tryParse(segments[2]);
      if (candidateModel.contains('.') && candidateId != null && candidateId > 0) {
        return OdooNavigationTarget(
          resModel: candidateModel,
          resId: candidateId,
          menuId: int.tryParse(uri.queryParameters['menu_id'] ?? ''),
          targetHash: '#id=$candidateId&model=$candidateModel&view_type=form',
        );
      }
    }
  }

  // 3. Hash fragment chuẩn của App Drawer / Odoo 17 & 19: #action=210&menu_id=105
  if (targetHash != null && targetHash.length > 1) {
    final fragBody = targetHash.substring(1);
    final params = <String, String>{};
    for (final part in fragBody.split('&')) {
      final eqIdx = part.indexOf('=');
      if (eqIdx > 0) {
        final k = Uri.decodeQueryComponent(part.substring(0, eqIdx).trim());
        final v = Uri.decodeQueryComponent(part.substring(eqIdx + 1).trim());
        params[k] = v;
      }
    }
    final action = params['action']?.trim();
    final menuId = int.tryParse(params['menu_id'] ?? '');
    final model = params['model']?.trim();
    final id = int.tryParse(params['id'] ?? '');

    if ((model != null && model.isNotEmpty && id != null && id > 0) ||
        (menuId != null && menuId > 0) ||
        (action != null && action.isNotEmpty)) {
      return OdooNavigationTarget(
        resModel: (model != null && model.isNotEmpty) ? model : null,
        resId: (id != null && id > 0) ? id : null,
        menuId: (menuId != null && menuId > 0) ? menuId : null,
        action: (action != null && action.isNotEmpty) ? action : null,
        targetHash: targetHash,
      );
    }
  }

  return null;
}

String _escapeJsSingleQuoted(String input) {
  return input
      .replaceAll(r'\', r'\\')
      .replaceAll("'", r"\'")
      .replaceAll('\n', '')
      .replaceAll('\r', '');
}

Future<void> _injectOptimizationCssIntoController(
  WebViewController ctrl, {
  required bool isDark,
}) async {
  try {
    final minifiedCss = getMinifiedOdooNativeOptimizationCss(isDark: isDark);
    await ctrl.runJavaScript('''
      (function() {
        // 1. Inject Clipboard Polyfill cho môi trường HTTP Non-Secure Context (Local Server IP)
        // Tránh lỗi RPCErrorDialog crash: Cannot read properties of undefined (reading 'writeText')
        if (typeof window !== 'undefined' && (!window.navigator || !window.navigator.clipboard)) {
          if (!window.navigator) { window.navigator = {}; }
          window.navigator.clipboard = {
            writeText: function(text) {
              return new Promise(function(resolve, reject) {
                try {
                  var ta = document.createElement('textarea');
                  ta.value = text || '';
                  ta.style.position = 'fixed';
                  ta.style.opacity = '0';
                  ta.style.pointerEvents = 'none';
                  document.body.appendChild(ta);
                  ta.focus();
                  ta.select();
                  var ok = document.execCommand('copy');
                  document.body.removeChild(ta);
                  if (ok) { resolve(); } else { reject(new Error('execCommand copy failed')); }
                } catch (e) {
                  reject(e);
                }
              });
            }
          };
        }

        // 2. Inject Native Styling
        var styleId = 'vcloud-native-optimization-style';
        var existing = document.getElementById(styleId);
        var root = document.head || document.documentElement;
        if (!existing) {
          existing = document.createElement('style');
          existing.id = styleId;
          existing.type = 'text/css';
          if (root) root.appendChild(existing);
        } else if (existing.parentNode !== root && root) {
          root.appendChild(existing);
        }
        if (existing) {
          existing.textContent = '$minifiedCss';
        }
      })();
    ''');
  } catch (cssErr) {
    debugPrint('[VCLOUD_WEBVIEW] Inject CSS error: $cssErr');
  }
}

/// Quản lý Warm WebView Engine duy nhất theo phiên đăng nhập `(baseUrl|db|uid)`.
/// Giúp làm ấm trước OWL WebClient (10MB JS/CSS) và giữ nguyên engine giữa các lần đóng/mở màn hình,
/// giảm thời gian mở ứng dụng/chứng từ từ ~3.2s–8.8s xuống ~100ms–300ms.
class _OdooWarmWebViewPool {
  _OdooWarmWebViewPool._();

  static final _OdooWarmWebViewPool instance = _OdooWarmWebViewPool._();

  WebViewController? _controller;
  String? _sessionSignature;
  bool _isLeased = false;
  bool _isOwlReady = false;
  bool _hasInjectedEagerCss = false;
  bool _hasAutoClearedCacheOnCssError = false;
  bool _lastIsDark = false;
  _OdooWebViewScreenState? _activeOwner;

  bool get isPlatformSupported {
    if (kIsWeb) return false;
    try {
      return WebViewPlatform.instance != null;
    } catch (_) {
      return false;
    }
  }

  String _computeSignature(OdooSession session, String baseUrl) {
    final effectiveBase = baseUrl.isNotEmpty ? baseUrl : session.baseUrl;
    return '$effectiveBase|${session.db}|${session.uid}';
  }

  _OdooWebViewScreenState? get activeOwner => _activeOwner;

  bool _isMainOdooClientUrl(String url) {
    return !url.contains('/api/v1/mobile/web/auth') &&
        !url.contains('/web/login') &&
        (url.contains('/web') || url.contains('/odoo') || url.contains('/home/'));
  }

  /// Làm ấm ngầm WebView Engine ngay khi người dùng mở ngăn kéo "Ứng dụng" hoặc "Hoạt động".
  Future<void> prewarm({bool isDark = false}) async {
    if (!isPlatformSupported) return;
    final session = odooApiClient.session;
    if (session == null || session.isExpired || session.scope == 'portal') {
      return;
    }

    final sig = _computeSignature(session, odooApiClient.baseUrl);
    if (_controller != null && _sessionSignature == sig) {
      return;
    }

    if (_sessionSignature != null && _sessionSignature != sig) {
      disposeAll();
    }

    try {
      _lastIsDark = isDark;
      final warmUrl = buildTargetWebViewUrl(
        rawUrl: '/web',
        session: session,
        baseUrl: odooApiClient.baseUrl,
        colorScheme: isDark ? 'dark' : 'light',
        useDirectUrlIfAuthenticated: true,
      );
      final uri = Uri.parse(warmUrl);
      debugPrint('[VCLOUD_WEBVIEW] 🔥 Prewarming WebView Engine ngầm: $uri');

      final ctrl = await _createConfiguredController(
        isDark: isDark,
        uriForCookie: uri,
        session: session,
        bindToPoolCallbacks: true,
      );
      _controller = ctrl;
      _sessionSignature = sig;
      _isOwlReady = false;
      _isLeased = false;

      final headers = _buildAuthHeaders(session);
      await ctrl.loadRequest(uri, headers: headers);
    } catch (e) {
      debugPrint('[VCLOUD_WEBVIEW] Prewarm bỏ qua (không ảnh hưởng UI): $e');
    }
  }

  /// Cấp phát controller cho màn hình `OdooWebViewScreen` mới mở.
  /// Áp dụng cơ chế Lease 1-1 để tránh xung đột `PlatformView` khi màn hình cũ đang chạy animation đóng.
  Future<({WebViewController controller, bool ownsLease, bool wasOwlReady})>
      acquire({
    required _OdooWebViewScreenState owner,
    required bool isDark,
    required Uri targetUri,
    required OdooSession? session,
  }) async {
    _lastIsDark = isDark;

    if (session != null && !session.isExpired) {
      final sig = _computeSignature(session, odooApiClient.baseUrl);
      if (_sessionSignature != null && _sessionSignature != sig) {
        disposeAll();
      }

      // Trường hợp 1: Đã có sẵn Warm Controller rảnh (không bị màn hình khác giữ lease)
      if (_controller != null && !_isLeased && _sessionSignature == sig) {
        _isLeased = true;
        _activeOwner = owner;
        final ready = _isOwlReady;
        final ctrl = _controller!;
        unawaited(_applyThemeBackground(ctrl, isDark: isDark));
        return (controller: ctrl, ownsLease: true, wasOwlReady: ready);
      }

      // Trường hợp 2: Chưa có Warm Controller nào trong Pool -> khởi tạo và đăng ký vào Pool
      if (_controller == null) {
        final ctrl = await _createConfiguredController(
          isDark: isDark,
          uriForCookie: targetUri,
          session: session,
          bindToPoolCallbacks: true,
        );
        _controller = ctrl;
        _sessionSignature = sig;
        _isLeased = true;
        _isOwlReady = false;
        _activeOwner = owner;
        return (controller: ctrl, ownsLease: true, wasOwlReady: false);
      }
    }

    // Trường hợp 3: Warm Controller đang bận (ví dụ route trước đang chạy reverse transition 240ms)
    // -> Khởi tạo controller độc lập an toàn, tuyệt đối không gắn 1 native view vào 2 WebViewWidget
    final standalone = await _createConfiguredController(
      isDark: isDark,
      uriForCookie: targetUri,
      session: session,
      bindToPoolCallbacks: false,
      standaloneOwner: owner,
    );
    return (controller: standalone, ownsLease: false, wasOwlReady: false);
  }

  void releaseLease(_OdooWebViewScreenState owner) {
    if (_activeOwner == owner) {
      _activeOwner = null;
    }
    _isLeased = false;
  }

  void disposeAll() {
    _controller = null;
    _sessionSignature = null;
    _isLeased = false;
    _isOwlReady = false;
    _hasInjectedEagerCss = false;
    _hasAutoClearedCacheOnCssError = false;
    _activeOwner = null;
    if (isPlatformSupported) {
      try {
        unawaited(WebViewCookieManager().clearCookies().catchError((_) => false));
      } catch (_) {}
    }
  }

  Map<String, String> _buildAuthHeaders(OdooSession? session) {
    final headers =
        Map<String, String>.from(odooApiClient.authHeaders ?? <String, String>{});
    if (session?.sessionId != null && session!.sessionId!.isNotEmpty) {
      headers['Cookie'] = 'session_id=${session.sessionId}';
    }
    return headers;
  }

  Future<void> _applyThemeBackground(
    WebViewController ctrl, {
    required bool isDark,
  }) async {
    try {
      final bg = isDark ? const Color(0xFF0F1729) : Colors.white;
      await ctrl.setBackgroundColor(bg);
      final platform = ctrl.platform;
      if (platform is AndroidWebViewController) {
        await platform.setForceDark(isDark ? ForceDark.on : ForceDark.off);
      }
    } catch (_) {}
  }

  Future<WebViewController> _createConfiguredController({
    required bool isDark,
    required Uri uriForCookie,
    required OdooSession? session,
    required bool bindToPoolCallbacks,
    _OdooWebViewScreenState? standaloneOwner,
  }) async {
    final themeBgColor = isDark ? const Color(0xFF0F1729) : Colors.white;
    final controller = WebViewController();

    late final NavigationDelegate delegate;
    delegate = NavigationDelegate(
      onProgress: (int progress) {
        final owner = bindToPoolCallbacks ? _activeOwner : standaloneOwner;
        owner?._onControllerProgress(progress);

        final eagerInjected = bindToPoolCallbacks
            ? _hasInjectedEagerCss
            : (standaloneOwner?._standaloneEagerCss ?? false);
        if (progress >= 20 && !eagerInjected) {
          if (bindToPoolCallbacks) {
            _hasInjectedEagerCss = true;
          } else {
            standaloneOwner?._standaloneEagerCss = true;
          }
          final dark = owner != null ? owner._isDarkTheme : _lastIsDark;
          unawaited(_injectOptimizationCssIntoController(controller, isDark: dark));
        }
      },
      onPageStarted: (String url) {
        debugPrint('[VCLOUD_WEBVIEW] Mobile onPageStarted: $url');
        if (bindToPoolCallbacks) {
          _hasInjectedEagerCss = false;
        } else {
          standaloneOwner?._standaloneEagerCss = false;
        }
        final owner = bindToPoolCallbacks ? _activeOwner : standaloneOwner;
        owner?._onControllerPageStarted(url);
      },
      onPageFinished: (String url) async {
        debugPrint('[VCLOUD_WEBVIEW] Mobile onPageFinished: $url');
        if (_isMainOdooClientUrl(url)) {
          OdooWebViewScreen.hasSsoAuthenticated = true;
          if (bindToPoolCallbacks) {
            _isOwlReady = true;
          }
        }

        final owner = bindToPoolCallbacks ? _activeOwner : standaloneOwner;
        owner?._onControllerPageFinished(url);

        final dark = owner != null ? owner._isDarkTheme : _lastIsDark;
        await _injectOptimizationCssIntoController(controller, isDark: dark);

        // Tự phục hồi bộ nhớ đệm nếu phát hiện lỗi biên dịch CSS bundle của Odoo
        final checkedCss = bindToPoolCallbacks
            ? _hasAutoClearedCacheOnCssError
            : (standaloneOwner?._standaloneCheckedCssError ?? false);
        if (!checkedCss) {
          try {
            final dynamic hasError = await controller.runJavaScriptReturningResult('''
              (function() {
                var computed = window.getComputedStyle(document.body, '::before');
                var text = (computed && computed.content) ? computed.content : '';
                var errEl = document.querySelector('css_error_message');
                return (text.indexOf('A css error') !== -1 || errEl !== null);
              })()
            ''');
            final errorDetected =
                hasError == true || hasError.toString().contains('true');
            if (errorDetected) {
              debugPrint('[VCLOUD_WEBVIEW] Phát hiện Odoo CSS Error -> Tự động xoá cache và tải lại sạch');
              if (bindToPoolCallbacks) {
                _hasAutoClearedCacheOnCssError = true;
              } else {
                standaloneOwner?._standaloneCheckedCssError = true;
              }
              await controller.clearCache();
              await controller.reload();
            }
          } catch (_) {}
        }
      },
      onWebResourceError: (WebResourceError error) {
        debugPrint('[VCLOUD_WEBVIEW] WebResourceError: ${error.errorCode} - ${error.description}');
        final owner = bindToPoolCallbacks ? _activeOwner : standaloneOwner;
        owner?._onControllerWebResourceError(error);
      },
    );

    // Chạy song song toàn bộ cấu hình Platform Channel & đồng bộ Cookie nhằm triệt tiêu độ trễ tuần tự ~90ms
    final setupTasks = <Future<void>>[
      controller.setJavaScriptMode(JavaScriptMode.unrestricted),
      controller.setBackgroundColor(themeBgColor),
      controller.setNavigationDelegate(delegate),
      controller.setOverScrollMode(WebViewOverScrollMode.never).catchError((_) {}),
    ];

    if (session?.sessionId != null &&
        session!.sessionId!.isNotEmpty &&
        uriForCookie.host.isNotEmpty) {
      setupTasks.add(
        WebViewCookieManager()
            .setCookie(
              WebViewCookie(
                name: 'session_id',
                value: session.sessionId!,
                domain: uriForCookie.host,
                path: '/',
              ),
            )
            .catchError((Object cookieErr) {
          debugPrint('[VCLOUD_WEBVIEW] Lỗi đồng bộ cookie: $cookieErr');
        }),
      );
    }

    try {
      final platform = controller.platform;
      if (platform is AndroidWebViewController) {
        setupTasks.addAll([
          platform.setForceDark(isDark ? ForceDark.on : ForceDark.off).catchError((_) {}),
          platform.setAllowFileAccess(true).catchError((_) {}),
          platform.setAllowContentAccess(true).catchError((_) {}),
        ]);
      } else if (platform is WebKitWebViewController) {
        setupTasks.addAll([
          platform.setAllowsBackForwardNavigationGestures(true).catchError((_) {}),
          platform.setAllowsLinkPreview(false).catchError((_) {}),
        ]);
      }
    } catch (e) {
      debugPrint('[VCLOUD_WEBVIEW] controller platform config error: $e');
    }

    await Future.wait(setupTasks);
    return controller;
  }
}

class OdooWebViewScreen extends ConsumerStatefulWidget {
  const OdooWebViewScreen({
    super.key,
    required this.url,
    this.title = 'Vcloud Web',
  });

  final String url;
  final String title;

  /// Biến cờ tĩnh ghi nhận WebView đã được xác thực SSO thành công trong phiên làm việc.
  /// Khi đã có session cookie, các lần tải trang sau không cần redirect qua SSO bridge, giúp tiết kiệm round-trip mạng.
  static bool hasSsoAuthenticated = false;

  /// Làm ấm trước WebView Engine ngầm để khi người dùng chạm vào ứng dụng / chứng từ sẽ mở tức thì.
  static Future<void> prewarm({bool isDark = false}) {
    return _OdooWarmWebViewPool.instance.prewarm(isDark: isDark);
  }

  /// Điều hướng trực tiếp ngay trên `OdooWebViewScreen` đang hiển thị (khi mở ngăn kéo "Ứng dụng" từ trong WebView).
  /// Giữ nguyên ngăn xếp Back về màn hình gốc và chuyển app qua OWL SPA chỉ trong ~70–150ms.
  static bool navigateActiveIfMounted({
    required String url,
    required String title,
  }) {
    final active = _OdooWarmWebViewPool.instance.activeOwner;
    if (active != null && active.mounted) {
      active._navigateInPlace(url: url, title: title);
      return true;
    }
    return false;
  }

  /// Reset trạng thái SSO và giải phóng toàn bộ Warm WebView + Cookie khi người dùng đăng xuất hoặc phiên hết hạn.
  static void resetSso() {
    hasSsoAuthenticated = false;
    _OdooWarmWebViewPool.instance.disposeAll();
  }

  @override
  ConsumerState<OdooWebViewScreen> createState() => _OdooWebViewScreenState();
}

class _OdooWebViewScreenState extends ConsumerState<OdooWebViewScreen> {
  WebViewController? _controller;
  late String _activeRawUrl;
  late String _activeTitle;
  bool _ownsWarmLease = false;
  bool _didInitWorkflow = false;
  bool _isLoading = true;
  final ValueNotifier<double> _progressNotifier = ValueNotifier<double>(0.0);
  bool _hasError = false;
  String? _errorMessage;
  int _webFrameKey = 0;
  Timer? _webTimeoutTimer;
  Timer? _fastSpaSettleTimer;
  Stopwatch? _loadStopwatch;
  String? _sessionEntryUrl;
  int _navGeneration = 0;
  int _ssoRecoveryAttempts = 0;
  bool _standaloneEagerCss = false;
  bool _standaloneCheckedCssError = false;

  bool get _isDarkTheme {
    try {
      final themeMode = ref.read(themeControllerProvider).valueOrNull;
      if (themeMode == AppThemeMode.dark) return true;
      if (themeMode == AppThemeMode.light) return false;
      if (mounted) {
        return Theme.of(context).brightness == Brightness.dark;
      }
    } catch (_) {}
    return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
        Brightness.dark;
  }

  @override
  void initState() {
    super.initState();
    _activeRawUrl = widget.url;
    _activeTitle = widget.title;
    debugPrint('[VCLOUD_WEBVIEW] initState: rawUrl=$_activeRawUrl, title=$_activeTitle');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInitWorkflow) {
      _didInitWorkflow = true;
      _startLoadingWorkflow();
    }
  }

  void _navigateInPlace({required String url, required String title}) {
    debugPrint('[VCLOUD_WEBVIEW] navigateInPlace: đổi sang url=$url, title=$title');
    setState(() {
      _activeRawUrl = url;
      _activeTitle = title;
      _hasError = false;
      _errorMessage = null;
      _ssoRecoveryAttempts = 0;
    });
    if (kIsWeb) {
      setState(() {
        _webFrameKey++;
        _isLoading = true;
      });
      _startLoadingWorkflow();
    } else {
      _transitionToNewUrl(url);
    }
  }

  @override
  void didUpdateWidget(covariant OdooWebViewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url || oldWidget.title != widget.title) {
      _navigateInPlace(url: widget.url, title: widget.title);
    }
  }

  String? _normalizeUrlForBackCheck(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    var s = raw.trim();
    if (s.endsWith('/')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }

  void _onControllerProgress(int progress) {
    if (!mounted) return;
    _progressNotifier.value = progress / 100.0;
  }

  void _onControllerPageStarted(String url) {
    if (!mounted) return;
    _progressNotifier.value = 0.1;
    if (!_isLoading || _hasError) {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
    }
  }

  void _onControllerPageFinished(String url) {
    final elapsed = _loadStopwatch?.elapsedMilliseconds;
    _loadStopwatch?.stop();
    if (elapsed != null) {
      debugPrint('[VCLOUD_WEBVIEW] ⏱️ Tải xong trang sau ${elapsed}ms: ${sanitizeUrlForLog(url)}');
    }
    final session = odooApiClient.session;
    if (isOdooLoginRedirectUrl(url) &&
        _ssoRecoveryAttempts < 1 &&
        session != null &&
        session.accessToken.isNotEmpty &&
        _controller != null) {
      _ssoRecoveryAttempts++;
      OdooWebViewScreen.hasSsoAuthenticated = false;
      _OdooWarmWebViewPool.instance._isOwlReady = false;
      final ssoUrl = buildTargetWebViewUrl(
        rawUrl: _activeRawUrl,
        session: session,
        baseUrl: odooApiClient.baseUrl,
        colorScheme: _isDarkTheme ? 'dark' : 'light',
        useDirectUrlIfAuthenticated: false,
      );
      debugPrint('[VCLOUD_WEBVIEW] 🔄 Phát hiện redirect về /web/login -> Tự động SSO lại: ${sanitizeUrlForLog(ssoUrl)}');
      final headers = _OdooWarmWebViewPool.instance._buildAuthHeaders(session);
      unawaited(_controller!.loadRequest(Uri.parse(ssoUrl), headers: headers));
      return;
    }
    if (!url.contains('/api/v1/mobile/web/auth') && !isOdooLoginRedirectUrl(url)) {
      _ssoRecoveryAttempts = 0;
      _sessionEntryUrl ??= _normalizeUrlForBackCheck(url);
    }
    if (mounted) {
      _progressNotifier.value = 1.0;
      if (_isLoading) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onControllerWebResourceError(WebResourceError error) {
    if (mounted && error.isForMainFrame == true) {
      setState(() {
        _hasError = true;
        _errorMessage = '${error.errorCode}: ${error.description}';
        _isLoading = false;
      });
    }
  }

  /// Điều hướng tức thì (~100–250ms) thông qua dịch vụ OWL (`services.menu` / `services.action`)
  /// tương thích đồng thời cả Odoo 17 (`/web#...`) và Odoo 19 (`/odoo/...`).
  Future<bool> _tryNavigateViaOwlSpa(
    WebViewController controller,
    String rawUrl,
  ) async {
    final target = parseOdooNavigationTarget(rawUrl);
    if (target == null) return false;

    try {
      final currentUrl = await controller.currentUrl();
      final isOnOdooClient = currentUrl != null &&
          !currentUrl.contains('/web/login') &&
          (currentUrl.contains('/web') ||
              currentUrl.contains('/odoo') ||
              currentUrl.contains('/home/'));
      if (!isOnOdooClient) return false;

      final modelEsc = _escapeJsSingleQuoted(target.resModel ?? '');
      final resId = target.resId ?? 0;
      final menuId = target.menuId ?? 0;
      final actionEsc = _escapeJsSingleQuoted(target.action ?? '');
      final hashEsc = _escapeJsSingleQuoted(target.targetHash ?? '');

      final rawResult = await controller.runJavaScriptReturningResult('''
        (function() {
          try {
            // Đóng hộp thoại lỗi hoặc popup cũ (nếu chứng từ trước đó gặp OwlError)
            var closeBtns = document.querySelectorAll('.o_dialog .btn-close, .modal .btn-close');
            for (var i = 0; i < closeBtns.length; i++) {
              try { closeBtns[i].click(); } catch (_) {}
            }

            var owlRoot = window.odoo && window.odoo.__WOWL_DEBUG__ && window.odoo.__WOWL_DEBUG__.root;
            var services = owlRoot && owlRoot.env && owlRoot.env.services;
            if (services && services.action) {
              var model = '$modelEsc';
              var resId = $resId;
              var menuId = $menuId;
              var actionParam = '$actionEsc';

              if (model && resId > 0) {
                services.action.doAction({
                  type: 'ir.actions.act_window',
                  res_model: model,
                  res_id: resId,
                  views: [[false, 'form']],
                  view_mode: 'form',
                  target: 'current'
                }, { clearBreadcrumbs: true });
                return 'owl_record_dispatched';
              }

              if (menuId > 0 && services.menu) {
                var menuObj = services.menu.getMenu(menuId);
                if (menuObj && menuObj.actionID) {
                  services.menu.selectMenu(menuObj);
                  return 'owl_menu_dispatched';
                }
              }

              if (actionParam) {
                var parsedAction = /^\\d+\$/.test(actionParam) ? parseInt(actionParam, 10) : actionParam;
                services.action.doAction(parsedAction, { clearBreadcrumbs: true });
                return 'owl_action_dispatched';
              }
            }

            // Fallback Hash Routing cho Odoo 17 khi đang ở đường dẫn /web
            var hashTarget = '$hashEsc';
            var path = window.location.pathname || '';
            if (hashTarget && path.indexOf('/web') === 0) {
              if (window.location.hash !== hashTarget) {
                window.location.hash = hashTarget;
              } else {
                window.dispatchEvent(new HashChangeEvent('hashchange'));
              }
              return 'hash_applied';
            }

            return 'unsupported';
          } catch (e) {
            return 'err:' + (e && e.message ? e.message : String(e));
          }
        })();
      ''');

      final resStr = rawResult.toString().replaceAll('"', '');
      final succeeded = resStr == 'owl_record_dispatched' ||
          resStr == 'owl_menu_dispatched' ||
          resStr == 'owl_action_dispatched' ||
          resStr == 'hash_applied';

      debugPrint('[VCLOUD_WEBVIEW] SPA Navigation result=$resStr cho rawUrl=$rawUrl');
      return succeeded;
    } catch (e) {
      debugPrint('[VCLOUD_WEBVIEW] _tryNavigateViaOwlSpa error: $e');
      return false;
    }
  }

  /// Chuyển module / chứng từ tức thì trên cùng Odoo Web Client.
  /// Không reload lại HTML/JS/CSS, không chớp trắng, duy trì session & cache runtime.
  Future<void> _transitionToNewUrl(String newRawUrl) async {
    final gen = ++_navGeneration;
    _sessionEntryUrl = null;
    _loadStopwatch = Stopwatch()..start();

    final controller = _controller;
    if (controller != null) {
      _progressNotifier.value = 0.35;
      if (mounted) {
        setState(() {
          _isLoading = true;
          _hasError = false;
          _errorMessage = null;
        });
      }

      final spaOk = await _tryNavigateViaOwlSpa(controller, newRawUrl);
      if (spaOk) {
        final elapsed = _loadStopwatch?.elapsedMilliseconds ?? 0;
        _loadStopwatch?.stop();
        debugPrint('[VCLOUD_WEBVIEW] ⚡ Chuyển trang SPA tức thì hoàn tất sau ${elapsed}ms');
        unawaited(_injectNativeOptimizationCss(controller));
        _scheduleFastSpaCompletion(controller, gen);
        return;
      }
    }

    // Fallback chuẩn: loadRequest toàn bộ nếu chưa boot OWL hoặc trang tĩnh (VD: /knowledge/...)
    if (mounted) {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _errorMessage = null;
      });
    }
    final newUrl = _buildTargetUrl();
    final headers = _OdooWarmWebViewPool.instance._buildAuthHeaders(odooApiClient.session);
    await controller?.loadRequest(Uri.parse(newUrl), headers: headers);
  }

  void _scheduleFastSpaCompletion(WebViewController controller, int generation) {
    _fastSpaSettleTimer?.cancel();
    _fastSpaSettleTimer = Timer(const Duration(milliseconds: 220), () async {
      if (!mounted || generation != _navGeneration) return;
      _progressNotifier.value = 1.0;
      setState(() {
        _isLoading = false;
      });
      try {
        final cur = await controller.currentUrl();
        if (mounted && generation == _navGeneration) {
          _sessionEntryUrl = _normalizeUrlForBackCheck(cur);
        }
      } catch (_) {}
    });
  }

  @override
  void dispose() {
    _webTimeoutTimer?.cancel();
    _fastSpaSettleTimer?.cancel();
    _progressNotifier.dispose();
    super.dispose();
    if (_ownsWarmLease) {
      _OdooWarmWebViewPool.instance.releaseLease(this);
      _ownsWarmLease = false;
    }
  }

  void _startLoadingWorkflow() {
    try {
      _loadStopwatch = Stopwatch()..start();
      if (kIsWeb) {
        final targetUrl = _buildTargetUrl();
        debugPrint('[VCLOUD_WEBVIEW] Bắt đầu nạp Web iframe targetUrl=$targetUrl');
        _webTimeoutTimer?.cancel();
        _webTimeoutTimer = Timer(const Duration(milliseconds: 2500), () {
          if (mounted && _isLoading && !_hasError) {
            debugPrint('[VCLOUD_WEBVIEW] Web iframe timeout watcher: chuyển _isLoading sang false');
            setState(() {
              _isLoading = false;
            });
          }
        });
      } else {
        _initializeWebView();
      }
    } catch (e, stack) {
      debugPrint('[VCLOUD_WEBVIEW] Lỗi trong _startLoadingWorkflow: $e\n$stack');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  String _buildTargetUrl() {
    try {
      final isDark = _isDarkTheme;
      final resolved = buildTargetWebViewUrl(
        rawUrl: _activeRawUrl,
        session: odooApiClient.session,
        baseUrl: odooApiClient.baseUrl,
        colorScheme: isDark ? 'dark' : 'light',
        useDirectUrlIfAuthenticated: true,
      );
      debugPrint('[VCLOUD_WEBVIEW] buildTargetWebViewUrl resolved: ${sanitizeUrlForLog(resolved)}');
      return resolved;
    } catch (e, stack) {
      debugPrint('[VCLOUD_WEBVIEW] Lỗi buildTargetWebViewUrl: $e\n$stack');
      return _activeRawUrl;
    }
  }

  Future<void> _initializeWebView() async {
    try {
      final gen = ++_navGeneration;
      _sessionEntryUrl = null;
      _ssoRecoveryAttempts = 0;
      final fullUrl = _buildTargetUrl();
      final uri = Uri.parse(fullUrl);
      debugPrint('[VCLOUD_WEBVIEW] Khởi tạo WebViewController cho mobile với uri=${sanitizeUrlForLog(uri.toString())}');
      final isDark = _isDarkTheme;
      final currentSession = odooApiClient.session;

      final acquired = await _OdooWarmWebViewPool.instance.acquire(
        owner: this,
        isDark: isDark,
        targetUri: uri,
        session: currentSession,
      );

      final controller = acquired.controller;
      _ownsWarmLease = acquired.ownsLease;

      // Gắn controller vào cây Widget ngay lập tức để tránh chặn hiển thị bởi các bước mạng phía sau
      if (mounted) {
        setState(() {
          _controller = controller;
        });
      }

      // Fast-Path: Nếu Warm Engine đã boot sẵn OWL WebClient -> Điều hướng SPA tức thì (~100–250ms)
      if (acquired.wasOwlReady) {
        _progressNotifier.value = 0.4;
        final spaOk = await _tryNavigateViaOwlSpa(controller, _activeRawUrl);
        if (spaOk) {
          final elapsed = _loadStopwatch?.elapsedMilliseconds ?? 0;
          _loadStopwatch?.stop();
          debugPrint('[VCLOUD_WEBVIEW] ⚡ Mở nhanh từ Warm Engine (SPA) chỉ mất ${elapsed}ms');
          unawaited(_injectNativeOptimizationCss(controller));
          _scheduleFastSpaCompletion(controller, gen);
          return;
        }
      }

      debugPrint('[VCLOUD_WEBVIEW] Nạp trang qua loadRequest: uri=$uri');
      final headers = _OdooWarmWebViewPool.instance._buildAuthHeaders(currentSession);
      await controller.loadRequest(uri, headers: headers);
    } catch (e, stack) {
      debugPrint('[VCLOUD_WEBVIEW] Error initializing webview: $e\n$stack');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  /// Tiêm CSS tối ưu hóa Native UX từ bộ nhớ đệm đã minify sẵn
  Future<void> _injectNativeOptimizationCss([WebViewController? targetController]) async {
    final ctrl = targetController ?? _controller;
    if (ctrl == null) return;
    await _injectOptimizationCssIntoController(ctrl, isDark: _isDarkTheme);
  }

  void _popWebViewRoute() {
    if (!mounted) return;
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  Future<void> _handlePop() async {
    try {
      final controller = _controller;
      if (controller != null && !kIsWeb) {
        final currentUrl = await controller.currentUrl();
        final normalizedCurrent = _normalizeUrlForBackCheck(currentUrl);
        final atEntryUrl =
            _sessionEntryUrl == null || normalizedCurrent == _sessionEntryUrl;

        bool hasSubBreadcrumb = false;
        if (atEntryUrl) {
          try {
            final bcRes = await controller.runJavaScriptReturningResult(
              "document.querySelectorAll('.o_control_panel .breadcrumb-item').length > 1",
            );
            hasSubBreadcrumb = bcRes == true || bcRes.toString() == 'true';
          } catch (_) {}
        }

        if ((!atEntryUrl || hasSubBreadcrumb) && await controller.canGoBack()) {
          await controller.goBack();
          return;
        }
      }
      _popWebViewRoute();
    } catch (e) {
      debugPrint('[VCLOUD_WEBVIEW] _handlePop error: $e');
      _popWebViewRoute();
    }
  }

  Future<void> _openInExternalBrowser() async {
    try {
      final fullUrl = _buildTargetUrl();
      debugPrint('[VCLOUD_WEBVIEW] Mở trình duyệt ngoài: ${sanitizeUrlForLog(fullUrl)}');
      final uri = Uri.parse(fullUrl);
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        debugPrint('[VCLOUD_WEBVIEW] launchUrl trả về false cho uri=${sanitizeUrlForLog(uri.toString())}');
      }
    } catch (e, stack) {
      debugPrint('[VCLOUD_WEBVIEW] _openInExternalBrowser error: $e\n$stack');
    }
  }

  Future<void> _handleReload() async {
    try {
      debugPrint('[VCLOUD_WEBVIEW] Người dùng bấm Tải lại (Reload)');
      _loadStopwatch = Stopwatch()..start();
      if (kIsWeb) {
        setState(() {
          _isLoading = true;
          _hasError = false;
          _errorMessage = null;
          _webFrameKey++;
        });
        _webTimeoutTimer?.cancel();
        _webTimeoutTimer = Timer(const Duration(milliseconds: 2000), () {
          if (mounted && _isLoading && !_hasError) {
            setState(() {
              _isLoading = false;
            });
          }
        });
      } else {
        _progressNotifier.value = 0.15;
        setState(() {
          _isLoading = true;
          _hasError = false;
          _errorMessage = null;
        });
        // Giữ nguyên HTTP Disk Cache của gói 10MB JS/CSS immutable để tải lại nhanh (~1s thay vì ~8.8s).
        // Nếu có lỗi CSS hỏng, cơ chế Self-Healing trong onPageFinished vẫn tự động clearCache() riêng.
        await _controller?.reload();
      }
    } catch (e) {
      debugPrint('[VCLOUD_WEBVIEW] _handleReload error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<AppThemeMode>>(themeControllerProvider, (prev, next) {
      if (next.hasValue && prev?.value != next.value) {
        debugPrint('[VCLOUD_WEBVIEW] Theme đổi sang: ${next.value} -> Cập nhật CSS');
        final isDark = _isDarkTheme;
        if (_controller != null) {
          unawaited(_OdooWarmWebViewPool.instance._applyThemeBackground(_controller!, isDark: isDark));
        }
        _injectNativeOptimizationCss();
      }
    });

    // Chỉ tính toán fullUrl trên nền tảng Flutter Web (iframe); tránh tính toán thừa mỗi lần rebuild trên Mobile
    final webIframeUrl = kIsWeb ? _buildTargetUrl() : '';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handlePop();
      },
      child: AppScaffold(
        title: _activeTitle,
        showBackButton: true,
        onBack: _handlePop,
        wrapSafeArea: false,
        actions: [
          IconButton(
            icon: const Icon(
              LucideIcons.rotateCw,
              color: Colors.white,
              size: 18,
            ),
            tooltip: 'Tải lại',
            onPressed: _handleReload,
          ),
          IconButton(
            icon: const Icon(
              LucideIcons.externalLink,
              color: Colors.white,
              size: 18,
            ),
            tooltip: 'Mở bằng trình duyệt',
            onPressed: _openInExternalBrowser,
          ),
        ],
        body: Padding(
          padding: const EdgeInsets.only(bottom: 74),
          child: Column(
            children: [
              if (_isLoading)
                ValueListenableBuilder<double>(
                  valueListenable: _progressNotifier,
                  builder: (context, progress, _) {
                    return LinearProgressIndicator(
                      value: progress > 0 ? progress : null,
                      minHeight: 2.5,
                      backgroundColor: Colors.transparent,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        Color(0xFF00C83A),
                      ),
                    );
                  },
                ),
              Expanded(
                child: _hasError
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                LucideIcons.wifiOff,
                                size: 48,
                                color: Color(0xFF94A3B8),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Không thể kết nối đến máy chủ',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (_errorMessage != null) ...[
                                const SizedBox(height: 8),
                                Text(
                                  _errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 20),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      setState(() {
                                        _hasError = false;
                                        _isLoading = true;
                                      });
                                      _startLoadingWorkflow();
                                    },
                                    icon: const Icon(LucideIcons.rotateCw, size: 16),
                                    label: const Text('Thử lại'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF0077CD),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  OutlinedButton.icon(
                                    onPressed: _openInExternalBrowser,
                                    icon: const Icon(LucideIcons.externalLink, size: 16),
                                    label: const Text('Mở trình duyệt'),
                                    style: OutlinedButton.styleFrom(
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      )
                    : (kIsWeb
                        ? KeyedSubtree(
                            key: ValueKey('web-frame-$_webFrameKey'),
                            child: buildHtmlIframe(
                                  url: webIframeUrl,
                                  isDark: Theme.of(context).brightness == Brightness.dark,
                                  onLoaded: () {
                                    debugPrint('[VCLOUD_WEBVIEW] Flutter Web: Iframe onLoaded triggered');
                                    if (mounted) {
                                      setState(() => _isLoading = false);
                                    }
                                  },
                                  onError: (err) {
                                    debugPrint('[VCLOUD_WEBVIEW] Flutter Web: Iframe onError: $err');
                                    if (mounted) {
                                      setState(() {
                                        _hasError = true;
                                        _errorMessage = err;
                                        _isLoading = false;
                                      });
                                    }
                                  },
                                ) ??
                                const SizedBox.shrink(),
                          )
                        : (_controller == null
                            ? const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Color(0xFF0077CD),
                                  ),
                                ),
                              )
                            : WebViewWidget(controller: _controller!))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ponytail: Lọc bỏ token nhạy cảm khỏi URL trước khi ghi ra console log
String sanitizeUrlForLog(String url) {
  try {
    final uri = Uri.parse(url);
    if (uri.queryParameters.containsKey('token')) {
      final qp = Map<String, String>.from(uri.queryParameters);
      qp['token'] = '***REDACTED***';
      return uri.replace(queryParameters: qp).toString();
    }
    return url;
  } catch (_) {
    return url.replaceAll(RegExp(r'token=[^&]+'), 'token=***REDACTED***');
  }
}

/// Nhận diện URL trang đăng nhập / chọn DB của hệ thống (không tính cầu SSO /api/v1/mobile/web/auth)
bool isOdooLoginRedirectUrl(String url) {
  if (url.isEmpty) return false;
  final lower = url.toLowerCase();
  if (lower.contains('/api/v1/mobile/web/auth')) return false;
  return lower.contains('/web/login') || lower.contains('/web/database/selector');
}

/// Chuẩn hoá URL mở In-App WebView:
/// 1. Luôn chèn `?db=database` vào trước dấu # để đảm bảo ngữ cảnh Database.
/// 2. Sử dụng SSO bridge (/api/v1/mobile/web/auth) khi có accessToken để tự động nạp phiên Odoo,
///    thiết lập cookie session_id và đăng nhập thẳng vào ứng dụng (cả Native và Web),
///    triệt tiêu hoàn toàn màn hình /web/database/selector và /web/login.
String buildTargetWebViewUrl({
  required String rawUrl,
  OdooSession? session,
  String baseUrl = '',
  String? colorScheme,
  bool useDirectUrlIfAuthenticated = false,
}) {
  try {
    var target = rawUrl.trim();
    if (target.isEmpty) {
      target = '/web';
    }

    final base = baseUrl.isNotEmpty
        ? baseUrl
        : (session?.baseUrl.isNotEmpty == true
            ? session!.baseUrl
            : odooApiClient.baseUrl);

    final db = (session != null && session.db.isNotEmpty)
        ? session.db
        : OdooApiClient.resolveDefaultDbForUrl(base);

    // Luôn gắn ?db=<database> vào trước dấu # nếu chưa có
    if (db.isNotEmpty) {
      final hashIndex = target.indexOf('#');
      if (hashIndex != -1) {
        final beforeHash = target.substring(0, hashIndex);
        final afterHash = target.substring(hashIndex + 1);
        if (!beforeHash.contains('db=')) {
          final sep = beforeHash.contains('?') ? '&' : '?';
          target = '$beforeHash${sep}db=$db#$afterHash';
        }
      } else if (!target.contains('db=')) {
        final sep = target.contains('?') ? '&' : '?';
        target = '$target${sep}db=$db';
      }
    }

    String resolveAbsolute(String path) {
      try {
        if (path.startsWith('http://') || path.startsWith('https://')) return path;
        if (base.isNotEmpty) {
          final normalized = path.startsWith('/') ? path : '/$path';
          return '$base$normalized';
        }
        return odooApiClient.absoluteUrl(path);
      } catch (e) {
        debugPrint('[VCLOUD_WEBVIEW] resolveAbsolute error: $e');
        return path;
      }
    }

    // Tối ưu Cache Fast-Path (Đặc biệt cho mạng 3G/4G): Nếu WebView đã xác thực SSO
    // HOẶC đã có sẵn Odoo session_id cookie hợp lệ từ phiên đăng nhập,
    // đi thẳng tới URL đích (đã có ?db=...), triệt tiêu hoàn toàn round-trip 303 Redirect qua SSO bridge.
    final hasValidSessionCookie = session != null &&
        session.sessionId != null &&
        session.sessionId!.isNotEmpty;
    if (useDirectUrlIfAuthenticated &&
        (OdooWebViewScreen.hasSsoAuthenticated || hasValidSessionCookie) &&
        session != null &&
        !session.isExpired) {
      return resolveAbsolute(target);
    }

    // Sử dụng SSO bridge khi có accessToken (cả Native và Web) để tự động nạp session Odoo,
    // thiết lập cookie session_id và điều hướng thẳng vào ứng dụng được chỉ định
    if (session != null && session.accessToken.isNotEmpty) {
      final ssoUri = Uri(
        path: '/api/v1/mobile/web/auth',
        queryParameters: {
          'token': session.accessToken,
          if (db.isNotEmpty) 'db': db,
          'redirect': target,
          if (colorScheme != null && colorScheme.isNotEmpty) 'color_scheme': colorScheme,
        },
      );
      return resolveAbsolute(ssoUri.toString());
    }

    return resolveAbsolute(target);
  } catch (e, stack) {
    debugPrint('[VCLOUD_WEBVIEW] Fatal error in buildTargetWebViewUrl: $e\n$stack');
    return rawUrl;
  }
}
