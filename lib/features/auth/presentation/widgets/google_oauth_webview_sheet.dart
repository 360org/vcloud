import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Kết quả xác thực trả về từ Google OAuth Sheet
class GoogleOAuthResult {
  final String accessToken;
  final String? email;
  const GoogleOAuthResult({required this.accessToken, this.email});
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

  @override
  void initState() {
    super.initState();
    _initController();
  }

  void _initController() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      // Giả lập Chrome Mobile tiêu chuẩn để vượt qua kiểm tra disallowed_useragent của Google
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 11; V2116) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Mobile Safari/537.36',
      )
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
          onNavigationRequest: (NavigationRequest request) {
            if (_isTargetRedirect(request.url)) {
              _checkIntercept(request.url);
              return NavigationDecision.prevent;
            }
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

  Future<void> _checkIntercept(String url) async {
    if (_completed) return;
    if (!_isTargetRedirect(url)) return;

    final uri = Uri.tryParse(url);
    if (uri == null) return;

    String? accessToken;
    final fragment = uri.fragment;
    if (fragment.isNotEmpty) {
      final params = Uri.splitQueryString(fragment);
      accessToken = params['access_token'];
    }
    accessToken ??= uri.queryParameters['access_token'];

    if (accessToken != null && accessToken.isNotEmpty) {
      _completed = true;
      String? resolvedEmail;
      try {
        final tokenInfoUri = Uri.parse(
          'https://www.googleapis.com/oauth2/v3/tokeninfo?access_token=$accessToken',
        );
        final resp = await http.get(tokenInfoUri).timeout(const Duration(seconds: 4));
        if (resp.statusCode == 200) {
          final tdata = jsonDecode(resp.body);
          resolvedEmail = tdata['email'] as String?;
        }
      } catch (e) {
        debugPrint('[GoogleOAuthWebViewSheet] tokeninfo fetch error: $e');
      }

      if (mounted) {
        Navigator.of(context).pop(GoogleOAuthResult(
          accessToken: accessToken,
          email: resolvedEmail,
        ));
      }
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
