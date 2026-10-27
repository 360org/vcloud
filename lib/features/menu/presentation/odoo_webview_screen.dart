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
import '../../../core/theme/app_theme.dart';
import 'widgets/odoo_web_frame.dart';

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

      // 1. Inject Session Cookie từ OdooApiClient nếu có
      final session = odooApiClient.session;
      if (session != null && session.accessToken.isNotEmpty) {
        try {
          final cookieManager = WebViewCookieManager();
          await cookieManager.setCookie(
            WebViewCookie(
              name: 'session_id',
              value: session.accessToken,
              domain: uri.host,
              path: '/',
            ),
          );
          debugPrint('[VCLOUD_WEBVIEW] Đã set session_id cookie vào WebView');
        } catch (e) {
          debugPrint('[VCLOUD_WEBVIEW] Set cookie error: $e');
        }
      }

      // 2. Cấu hình WebViewController cho Mobile
      final controller = WebViewController()
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
              // 3. Inject CSS ẩn thanh navbar Odoo backend để giao diện giống Native
              try {
                await _controller?.runJavaScript('''
                  (function() {
                    var css = '.o_main_navbar, .o_menu_brand, header.o_navbar { display: none !important; } body { padding-top: 0 !important; }';
                    var head = document.head || document.getElementsByTagName('head')[0];
                    var style = document.createElement('style');
                    style.type = 'text/css';
                    style.appendChild(document.createTextNode(css));
                    head.appendChild(style);
                  })();
                ''');
              } catch (cssErr) {
                debugPrint('[VCLOUD_WEBVIEW] Inject CSS error: $cssErr');
              }
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fullUrl = _buildTargetUrl();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handlePop();
      },
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: const Icon(LucideIcons.x, color: Colors.white, size: 20),
            tooltip: 'Đóng',
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/home');
              }
            },
          ),
          title: Text(
            widget.title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.2,
            ),
          ),
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
          flexibleSpace: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : null,
              gradient: isDark ? null : AppColors.brand,
              border: isDark
                  ? Border(
                      bottom: BorderSide(
                        color: Colors.white.withValues(alpha: 0.08),
                        width: 1,
                      ),
                    )
                  : null,
            ),
          ),
        ),
        body: Column(
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
