import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Kết quả xác thực trả về từ Google OAuth Sheet
class GoogleOAuthResult {
  final String accessToken;
  final String? email;
  final String? error;
  const GoogleOAuthResult({required this.accessToken, this.email, this.error});
}

/// Sheet mở In-App WebView xác thực Google OAuth2 (Luồng 2 trong Chiến Lược Kép).
/// Sử dụng trực tiếp cấu hình Google Web OAuth Provider từ vuahethong.net,
/// triệt tiêu hoàn toàn rào cản SHA-1 Keystore và ApiException: 10 trên Android.
class GoogleOAuthWebViewSheet extends StatefulWidget {
  const GoogleOAuthWebViewSheet({
    super.key,
    required this.targetUrl,
    required this.targetDb,
    this.initialEmail,
    this.clientId = '12576206090-2aucq3jt479mghm0qmnoa63f8emdekhc.apps.googleusercontent.com',
  });

  final String targetUrl;
  final String targetDb;
  final String? initialEmail;
  final String clientId;

  static Future<GoogleOAuthResult?> show(
    BuildContext context, {
    required String targetUrl,
    required String targetDb,
    String? initialEmail,
  }) {
    return showModalBottomSheet<GoogleOAuthResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => GoogleOAuthWebViewSheet(
        targetUrl: targetUrl,
        targetDb: targetDb,
        initialEmail: initialEmail,
      ),
    );
  }

  @override
  State<GoogleOAuthWebViewSheet> createState() => _GoogleOAuthWebViewSheetState();
}

class _GoogleOAuthWebViewSheetState extends State<GoogleOAuthWebViewSheet> {
  late final WebViewController _controller;
  bool _isLoading = true;
  double _progress = 0.0;
  bool _completed = false;
  Timer? _redirectPollTimer;

  static const String _officialRedirectUri = 'https://vuahethong.net/auth_oauth/signin';

  String get _redirectUri {
    final base = widget.targetUrl.trim().replaceAll(RegExp(r'/+$'), '');
    // Google OAuth 2.0 Web Client bắt buộc HTTPS domain hợp lệ đã khai báo trong Google Cloud Console.
    // Đối với môi trường LAN/IP dev (192.168.x.x, localhost), sử dụng redirect_uri chính thức của Vua Hệ Thống.
    if (!base.startsWith('https://') ||
        base.contains('192.168.') ||
        base.contains('10.') ||
        base.contains('localhost') ||
        base.contains('127.0.0.1')) {
      return _officialRedirectUri;
    }
    return '$base/auth_oauth/signin';
  }

  Uri get _authUri {
    final stateJson = jsonEncode({
      'd': widget.targetDb.isNotEmpty ? widget.targetDb : 'vuahethong',
      'p': 3,
      'r': 'https://vuahethong.net/web',
    });

    final queryParams = <String, String>{
      'response_type': 'token',
      'client_id': widget.clientId,
      'redirect_uri': _redirectUri,
      'scope': 'https://www.googleapis.com/auth/userinfo.email https://www.googleapis.com/auth/userinfo.profile',
      'state': stateJson,
      'prompt': 'select_account',
    };

    if (widget.initialEmail != null && widget.initialEmail!.trim().isNotEmpty) {
      queryParams['login_hint'] = widget.initialEmail!.trim();
    }

    return Uri.https('accounts.google.com', '/o/oauth2/auth', queryParams);
  }

  String get _platformUserAgent {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1';
    }
    return 'Mozilla/5.0 (Linux; Android 11; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Mobile Safari/537.36';
  }

  @override
  void initState() {
    super.initState();
    _initController();
  }

  @override
  void dispose() {
    _redirectPollTimer?.cancel();
    super.dispose();
  }

  void _initController() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(_platformUserAgent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (mounted) {
              setState(() {
                _progress = progress / 100.0;
                _isLoading = progress < 100;
              });
            }
          },
          onPageStarted: (String url) {
            _checkIntercept(url);
          },
          onUrlChange: (UrlChange change) {
            final url = change.url;
            if (url != null) _checkIntercept(url);
          },
          onPageFinished: (String url) {
            _handlePageFinished(url);
          },
          onNavigationRequest: (NavigationRequest request) {
            // 1. Kiểm tra ngay xem URL có chứa access_token hay không
            final token = _extractAccessToken(request.url);
            if (token != null && token.isNotEmpty) {
              _completeWithToken(token, request.url);
              return NavigationDecision.prevent;
            }

            // 2. Kiểm tra xem có lỗi OAuth trả về hay không
            final error = _extractError(request.url);
            if (error != null && error.isNotEmpty) {
              _completeWithError(error);
              return NavigationDecision.prevent;
            }

            // 3. QUAN TRỌNG: Nếu là URL redirect đích nhưng CHƯA CÓ token trong URL này (do hash fragment chưa nạp),
            // TUYỆT ĐỐI KHÔNG prevent! Cho phép navigate để WebView nạp URL và cập nhật onUrlChange/onPageFinished có kèm fragment!
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(_authUri);
  }

  bool _isTargetRedirect(String url) {
    return url.contains('/auth_oauth/signin') ||
        url.startsWith(_redirectUri) ||
        url.startsWith(_officialRedirectUri);
  }

  /// Trích xuất access_token từ URL (hỗ trợ hash fragment, query params và regex)
  static String? _extractAccessToken(String url) {
    try {
      final uri = Uri.tryParse(url);
      if (uri != null) {
        if (uri.fragment.isNotEmpty) {
          final params = Uri.splitQueryString(uri.fragment);
          final token = params['access_token'];
          if (token != null && token.isNotEmpty) return token;
        }
        final queryToken = uri.queryParameters['access_token'];
        if (queryToken != null && queryToken.isNotEmpty) return queryToken;
      }

      // Regex fallback dự phòng khi URL encoding phức tạp
      final regMatch = RegExp(r'[#?&]access_token=([^&]+)').firstMatch(url);
      if (regMatch != null && regMatch.groupCount >= 1) {
        return Uri.decodeComponent(regMatch.group(1)!);
      }
    } catch (_) {}
    return null;
  }

  /// Trích xuất lỗi OAuth từ URL nếu người dùng từ chối cấp quyền
  static String? _extractError(String url) {
    try {
      final uri = Uri.tryParse(url);
      if (uri != null) {
        if (uri.fragment.isNotEmpty) {
          final params = Uri.splitQueryString(uri.fragment);
          final err = params['error_description'] ?? params['error'];
          if (err != null && err.isNotEmpty) return err;
        }
        final queryErr = uri.queryParameters['error_description'] ?? uri.queryParameters['error'];
        if (queryErr != null && queryErr.isNotEmpty) return queryErr;
      }

      final regMatch = RegExp(r'[#?&]error=([^&]+)').firstMatch(url);
      if (regMatch != null && regMatch.groupCount >= 1) {
        return Uri.decodeComponent(regMatch.group(1)!);
      }
    } catch (_) {}
    return null;
  }

  Future<void> _checkIntercept(String url) async {
    if (_completed) return;

    final token = _extractAccessToken(url);
    if (token != null && token.isNotEmpty) {
      await _completeWithToken(token, url);
      return;
    }

    final error = _extractError(url);
    if (error != null && error.isNotEmpty) {
      _completeWithError(error);
      return;
    }

    // Nếu đang điều hướng tới URL đích hoặc trang trung gian xác thực của Google,
    // khởi chạy timer thăm dò DOM ngắn hạn để chống treo sau bước SMS 2FA
    if (_isTargetRedirect(url) || url.contains('accounts.google.com')) {
      _startRedirectPolling();
    }
  }

  /// Xử lý khi trang hoàn tất tải: thăm dò DOM window.location.href để bắt hash fragment
  Future<void> _handlePageFinished(String url) async {
    if (_completed) return;
    await _checkIntercept(url);

    if (!_completed) {
      try {
        final currentUrl = await _controller.currentUrl();
        if (currentUrl != null && currentUrl.isNotEmpty) {
          await _checkIntercept(currentUrl);
        }
      } catch (_) {}
    }

    if (!_completed && (_isTargetRedirect(url) || url.contains('auth_oauth'))) {
      try {
        final jsResult = await _controller.runJavaScriptReturningResult('window.location.href');
        final cleanUrl = jsResult.toString().replaceAll('"', '').trim();
        if (cleanUrl.isNotEmpty) {
          await _checkIntercept(cleanUrl);
        }
      } catch (_) {}
    }
  }

  /// Thăm dò liên tục URL hiện tại trong vòng 8 giây sau bước SMS OTP để chống đơ
  void _startRedirectPolling() {
    if (_redirectPollTimer != null && _redirectPollTimer!.isActive) return;
    int pollCount = 0;
    _redirectPollTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) async {
      pollCount++;
      if (_completed || !mounted || pollCount > 16) {
        timer.cancel();
        return;
      }

      try {
        final currentUrl = await _controller.currentUrl();
        if (currentUrl != null && currentUrl.isNotEmpty) {
          final token = _extractAccessToken(currentUrl);
          if (token != null && token.isNotEmpty) {
            timer.cancel();
            await _completeWithToken(token, currentUrl);
            return;
          }
        }

        // Đọc trực tiếp từ window.location.href trong trường hợp trình duyệt không kích hoạt delegate
        final jsHref = await _controller.runJavaScriptReturningResult('window.location.href');
        final cleanHref = jsHref.toString().replaceAll('"', '').trim();
        if (cleanHref.isNotEmpty) {
          final jsToken = _extractAccessToken(cleanHref);
          if (jsToken != null && jsToken.isNotEmpty) {
            timer.cancel();
            await _completeWithToken(jsToken, cleanHref);
            return;
          }
        }
      } catch (_) {}
    });
  }

  Future<void> _completeWithToken(String accessToken, String url) async {
    if (_completed) return;
    _completed = true;
    _redirectPollTimer?.cancel();

    String? resolvedEmail;
    try {
      final tokenInfoUri = Uri.parse(
        'https://www.googleapis.com/oauth2/v3/tokeninfo?access_token=$accessToken',
      );
      // Timeout 1.5 giây để đóng sheet nhanh chóng, không làm khựng màn hình người dùng
      final resp = await http.get(tokenInfoUri).timeout(const Duration(milliseconds: 1500));
      if (resp.statusCode == 200) {
        final tdata = jsonDecode(resp.body);
        resolvedEmail = tdata['email'] as String?;
      }
    } catch (e) {
      debugPrint('[GoogleOAuthWebViewSheet] tokeninfo fetch error (non-fatal): $e');
    }

    if (mounted) {
      Navigator.of(context).pop(GoogleOAuthResult(
        accessToken: accessToken,
        email: resolvedEmail ?? widget.initialEmail,
      ));
    }
  }

  void _completeWithError(String error) {
    if (_completed) return;
    _completed = true;
    _redirectPollTimer?.cancel();

    if (mounted) {
      Navigator.of(context).pop(GoogleOAuthResult(
        accessToken: '',
        error: error,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return SizedBox(
      height: size.height * 0.90,
      child: Column(
        children: [
          // Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFEEEEEE), width: 1),
              ),
            ),
            child: Row(
              children: [
                const Icon(LucideIcons.globe, size: 20, color: Color(0xFF0077cd)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Đăng nhập bằng Google',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.x, size: 22, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.of(context).pop(null),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          if (_isLoading)
            LinearProgressIndicator(
              value: _progress > 0 ? _progress : null,
              backgroundColor: const Color(0xFFE2E8F0),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0077cd)),
              minHeight: 2.5,
            ),
          // WebView Body
          Expanded(
            child: WebViewWidget(controller: _controller),
          ),
        ],
      ),
    );
  }
}
