import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/api/odoo_api_client.dart';
import '../../../core/api/odoo_session.dart';
import '../../../core/config/env.dart';
import '../../../shared/widgets/app_scaffold.dart';
import 'widgets/odoo_web_frame.dart';

/// CSS tối ưu hóa Native UX và triệt tiêu giật lag cho Odoo WebView (Pha 1)
const String _kOdooNativeOptimizationCss = '''
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

/* 3. Tối ưu vùng nội dung Odoo Action Manager chiếm trọn khung nhìn */
.o_action_manager {
  top: 0 !important;
  height: 100vh !important;
  overflow-y: auto !important;
  -webkit-overflow-scrolling: touch !important;
}

/* 4. Tăng tốc phần cứng GPU cho các phần tử cuộn */
.o_content, .o_kanban_view, .o_list_view, .o_form_view {
  transform: translateZ(0);
  -webkit-transform: translateZ(0);
  backface-visibility: hidden;
  -webkit-backface-visibility: hidden;
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
* {
  -webkit-font-smoothing: antialiased !important;
}
''';

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

class OdooWebViewScreen extends ConsumerStatefulWidget {
  const OdooWebViewScreen({
    super.key,
    required this.url,
    this.title = 'Vcloud Web',
  });

  final String url;
  final String title;

  @override
  ConsumerState<OdooWebViewScreen> createState() => _OdooWebViewScreenState();
}

class _OdooWebViewScreenState extends ConsumerState<OdooWebViewScreen> {
  WebViewController? _controller;
  bool _isLoading = true;
  double _progress = 0.0;
  bool _hasError = false;
  String? _errorMessage;
  int _webFrameKey = 0;
  Timer? _webTimeoutTimer;

  @override
  void initState() {
    super.initState();
    debugPrint('[VCLOUD_WEBVIEW] initState: rawUrl=${widget.url}, title=${widget.title}');
    _startLoadingWorkflow();
  }

  @override
  void didUpdateWidget(covariant OdooWebViewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      debugPrint('[VCLOUD_WEBVIEW] didUpdateWidget: đổi url từ ${oldWidget.url} sang ${widget.url}');
      if (kIsWeb) {
        setState(() {
          _webFrameKey++;
          _isLoading = true;
          _hasError = false;
          _errorMessage = null;
        });
        _startLoadingWorkflow();
      } else {
        _transitionToNewUrl(widget.url);
      }
    }
  }

  /// Tối ưu Pha 1: Chuyển module tức thì qua SPA Hash Routing trên cùng Odoo Web Client.
  /// Không reload lại HTML/JS/CSS, không chớp trắng, duy trì session & cache runtime.
  Future<void> _transitionToNewUrl(String newRawUrl) async {
    final controller = _controller;
    if (controller != null) {
      try {
        final currentUrl = await controller.currentUrl();
        debugPrint('[VCLOUD_WEBVIEW] _transitionToNewUrl: currentUrl=$currentUrl, target=$newRawUrl');

        final isCurrentOnOdoo = currentUrl != null &&
            (currentUrl.contains('/web') ||
                currentUrl.contains('/odoo') ||
                currentUrl.contains('/home/'));

        if (isCurrentOnOdoo) {
          final targetHash = extractOdooTargetHash(newRawUrl);

          if (targetHash != null && targetHash.isNotEmpty) {
            debugPrint('[VCLOUD_WEBVIEW] Pha 1 SPA Hash Switch: targetHash=$targetHash');

            // Hiển thị thanh tiến trình mỏng nhẹ, KHÔNG che màn hình bằng spinner trắng
            if (mounted) {
              setState(() {
                _progress = 0.35;
                _hasError = false;
                _errorMessage = null;
              });
            }

            final jsResult = await controller.runJavaScriptReturningResult('''
              (function() {
                try {
                  var target = '$targetHash';
                  var path = window.location.pathname;
                  if (path.startsWith('/web') || path.startsWith('/odoo')) {
                    if (window.location.hash !== target) {
                      window.location.hash = target;
                    } else {
                      window.dispatchEvent(new HashChangeEvent('hashchange'));
                    }
                    return 'hash_applied';
                  } else {
                    var basePath = path.includes('/odoo') ? '/odoo' : '/web';
                    window.location.href = basePath + target;
                    return 'href_navigated';
                  }
                } catch (e) {
                  return 'err: ' + e;
                }
              })();
            ''');

            debugPrint('[VCLOUD_WEBVIEW] SPA Hash result: $jsResult');

            // Tái tiêm CSS tối ưu hóa Native UX để duy trì layout chuẩn
            await _injectNativeOptimizationCss();

            // Kết thúc hiệu ứng chuyển trang sau 300ms
            Future.delayed(const Duration(milliseconds: 300), () {
              if (mounted) {
                setState(() {
                  _progress = 1.0;
                  _isLoading = false;
                });
              }
            });
            return;
          }
        }
      } catch (e) {
        debugPrint('[VCLOUD_WEBVIEW] Lỗi SPA transition: $e -> Fallback loadRequest');
      }
    }

    // Fallback chuẩn: loadRequest toàn bộ nếu chưa vào Odoo web hoặc không xác định được hash
    if (mounted) {
      setState(() {
        _isLoading = true;
        _hasError = false;
        _errorMessage = null;
      });
    }
    final newUrl = _buildTargetUrl();
    await controller?.loadRequest(Uri.parse(newUrl));
  }

  @override
  void dispose() {
    _webTimeoutTimer?.cancel();
    super.dispose();
  }

  void _startLoadingWorkflow() {
    try {
      final targetUrl = _buildTargetUrl();
      debugPrint('[VCLOUD_WEBVIEW] Bắt đầu nạp targetUrl=$targetUrl');

      if (kIsWeb) {
        // Trên Web: Khởi tạo iframe và theo dõi trạng thái
        _webTimeoutTimer?.cancel();
        // Fallback tự động tắt loading sau 2.5s nếu iframe đã nạp ngầm
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
      final resolved = buildTargetWebViewUrl(
        rawUrl: widget.url,
        session: odooApiClient.session,
        baseUrl: odooApiClient.baseUrl,
      );
      debugPrint('[VCLOUD_WEBVIEW] buildTargetWebViewUrl resolved: $resolved');
      return resolved;
    } catch (e, stack) {
      debugPrint('[VCLOUD_WEBVIEW] Lỗi buildTargetWebViewUrl: $e\n$stack');
      return widget.url;
    }
  }

  Future<void> _initializeWebView() async {
    try {
      final fullUrl = _buildTargetUrl();
      final uri = Uri.parse(fullUrl);
      debugPrint('[VCLOUD_WEBVIEW] Khởi tạo WebViewController cho mobile với uri=$uri');

      // Cấu hình WebViewController cho Mobile
      // ponytail: Không inject session.accessToken vào cookie 'session_id' vì accessToken là JWT Bearer,
      // không phải Odoo session_id. SSO bridge (/api/v1/mobile/web/auth) tự sinh và gán Odoo session_id chuẩn.
      final controller = WebViewController();
      controller
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.white)
        ..setNavigationDelegate(
          NavigationDelegate(
            onProgress: (int progress) {
              if (mounted) {
                setState(() {
                  _progress = progress / 100.0;
                });
              }
            },
            onPageStarted: (String url) {
              debugPrint('[VCLOUD_WEBVIEW] Mobile onPageStarted: $url');
              if (mounted) {
                setState(() {
                  _isLoading = true;
                  _hasError = false;
                });
              }
            },
            onPageFinished: (String url) async {
              debugPrint('[VCLOUD_WEBVIEW] Mobile onPageFinished: $url');
              if (mounted) {
                setState(() {
                  _isLoading = false;
                });
              }
              // 3. Inject CSS tối ưu hóa Native UX và triệt tiêu giật lag (Pha 1)
              await _injectNativeOptimizationCss(controller);
            },
            onWebResourceError: (WebResourceError error) {
              debugPrint('[VCLOUD_WEBVIEW] WebResourceError: ${error.errorCode} - ${error.description}');
              if (mounted && error.isForMainFrame == true) {
                setState(() {
                  _hasError = true;
                  _errorMessage = '${error.errorCode}: ${error.description}';
                  _isLoading = false;
                });
              }
            },
          ),
        );

      if (!kIsWeb) {
        try {
          await controller.setOverScrollMode(WebViewOverScrollMode.never);
        } catch (e) {
          debugPrint('[VCLOUD_WEBVIEW] setOverScrollMode error: $e');
        }
      }

      final headers = odooApiClient.authHeaders ?? <String, String>{};
      await controller.loadRequest(uri, headers: headers);

      if (mounted) {
        setState(() {
          _controller = controller;
        });
      }
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

  /// Tiêm CSS tối ưu hóa Native UX và triệt tiêu giật lag (Pha 1)
  Future<void> _injectNativeOptimizationCss([WebViewController? targetController]) async {
    try {
      final ctrl = targetController ?? _controller;
      final minifiedCss = _kOdooNativeOptimizationCss
          .replaceAll('\n', ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .replaceAll("'", r"\'");

      await ctrl?.runJavaScript('''
        (function() {
          var styleId = 'vcloud-native-optimization-style';
          var existing = document.getElementById(styleId);
          if (!existing) {
            existing = document.createElement('style');
            existing.id = styleId;
            existing.type = 'text/css';
            (document.head || document.documentElement).appendChild(existing);
          }
          existing.textContent = '$minifiedCss';
        })();
      ''');
    } catch (cssErr) {
      debugPrint('[VCLOUD_WEBVIEW] Inject CSS error: $cssErr');
    }
  }

  Future<void> _handlePop() async {
    try {
      final controller = _controller;
      if (controller != null && await controller.canGoBack()) {
        await controller.goBack();
      } else {
        if (mounted) {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/home');
          }
        }
      }
    } catch (e) {
      debugPrint('[VCLOUD_WEBVIEW] _handlePop error: $e');
      if (mounted) {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/home');
        }
      }
    }
  }

  Future<void> _openInExternalBrowser() async {
    try {
      final fullUrl = _buildTargetUrl();
      debugPrint('[VCLOUD_WEBVIEW] Mở trình duyệt ngoài: $fullUrl');
      final uri = Uri.parse(fullUrl);
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        debugPrint('[VCLOUD_WEBVIEW] launchUrl trả về false cho uri=$uri');
      }
    } catch (e, stack) {
      debugPrint('[VCLOUD_WEBVIEW] _openInExternalBrowser error: $e\n$stack');
    }
  }

  void _handleReload() {
    try {
      debugPrint('[VCLOUD_WEBVIEW] Người dùng bấm Tải lại (Reload)');
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
        setState(() {
          _isLoading = true;
          _hasError = false;
          _errorMessage = null;
        });
        _controller?.reload();
      }
    } catch (e) {
      debugPrint('[VCLOUD_WEBVIEW] _handleReload error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final fullUrl = _buildTargetUrl();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handlePop();
      },
      child: AppScaffold(
        title: widget.title,
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
              LinearProgressIndicator(
                value: _progress > 0 ? _progress : null,
                minHeight: 2.5,
                backgroundColor: Colors.transparent,
                valueColor: const AlwaysStoppedAnimation<Color>(
                  Color(0xFF00C83A),
                ),
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
                                url: fullUrl,
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

/// Chuẩn hoá URL mở In-App WebView:
/// 1. Luôn chèn `?db=database` vào trước dấu # để đảm bảo ngữ cảnh Database.
/// 2. Sử dụng SSO bridge (/api/v1/mobile/web/auth) khi có accessToken để tự động nạp phiên Odoo,
///    thiết lập cookie session_id và đăng nhập thẳng vào ứng dụng (cả Native và Web),
///    triệt tiêu hoàn toàn màn hình /web/database/selector và /web/login.
String buildTargetWebViewUrl({
  required String rawUrl,
  OdooSession? session,
  String baseUrl = '',
}) {
  try {
    var target = rawUrl.trim();
    if (target.isEmpty) {
      target = '/web';
    }

    final db = (session != null && session.db.isNotEmpty)
        ? session.db
        : (Env.odooDb.isNotEmpty ? Env.odooDb : 'vcloud_test_v19');

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

    final base = baseUrl.isNotEmpty
        ? baseUrl
        : (session?.baseUrl.isNotEmpty == true
            ? session!.baseUrl
            : odooApiClient.baseUrl);

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

    // Sử dụng SSO bridge khi có accessToken (cả Native và Web) để tự động nạp session Odoo,
    // thiết lập cookie session_id và điều hướng thẳng vào ứng dụng được chỉ định
    if (session != null && session.accessToken.isNotEmpty) {
      final ssoUri = Uri(
        path: '/api/v1/mobile/web/auth',
        queryParameters: {
          'token': session.accessToken,
          if (db.isNotEmpty) 'db': db,
          'redirect': target,
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
