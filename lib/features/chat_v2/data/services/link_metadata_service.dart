import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../../../../core/api/odoo_api_client.dart';
import '../../../../core/utils/html_text.dart';
import '../models/link_metadata.dart';

/// Provider cung cấp metadata của link xem trước (có cache & SSRF protection)
final linkMetadataProvider =
    FutureProvider.family.autoDispose<LinkMetadata?, String>((ref, rawUrl) async {
  return LinkMetadataService.instance.getMetadata(rawUrl);
});

class LinkMetadataService {
  LinkMetadataService({this.httpClient});

  static final LinkMetadataService instance = LinkMetadataService();

  final http.Client? httpClient;

  /// Bộ nhớ cache tạm trong RAM (giới hạn 100 items chống rò rỉ RAM)
  static final Map<String, LinkMetadata> _memoryCache = <String, LinkMetadata>{};
  static const int _maxMemoryEntries = 100;

  /// Chống gọi trùng mạng (in-flight request deduplication)
  static final Map<String, Future<LinkMetadata?>> _inFlight =
      <String, Future<LinkMetadata?>>{};

  static bool _diskCacheLoaded = false;
  static File? _diskCacheFile;

  /// Khởi tạo và nạp cache từ ổ đĩa nếu có
  static Future<void> _ensureDiskCacheLoaded() async {
    if (_diskCacheLoaded || kIsWeb) return;
    _diskCacheLoaded = true;

    try {
      final docDir = await getApplicationDocumentsDirectory();
      _diskCacheFile = File('${docDir.path}/link_preview_cache.json');
      if (await _diskCacheFile!.exists()) {
        final content = await _diskCacheFile!.readAsString();
        final dynamic decoded = jsonDecode(content);
        if (decoded is Map<String, dynamic>) {
          for (final entry in decoded.entries) {
            if (entry.value is Map<String, dynamic>) {
              final meta = LinkMetadata.fromJson(
                (entry.value as Map<String, dynamic>),
              );
              if (meta.isFresh()) {
                _memoryCache[entry.key] = meta;
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[LinkMetadataService] Error loading disk cache: $e');
    }
  }

  /// Ghi cache ra đĩa
  static Future<void> _persistDiskCache() async {
    if (kIsWeb || _diskCacheFile == null) return;
    try {
      final map = <String, dynamic>{};
      for (final entry in _memoryCache.entries) {
        if (entry.value.isFresh()) {
          map[entry.key] = entry.value.toJson();
        }
      }
      await _diskCacheFile!.writeAsString(jsonEncode(map), flush: true);
    } catch (e) {
      debugPrint('[LinkMetadataService] Error persisting disk cache: $e');
    }
  }

  /// Lấy metadata cho một URL với đầy đủ cơ chế:
  /// 1. Kiểm tra RAM cache
  /// 2. Deduplicate in-flight requests
  /// 3. SSRF blocklist & validation
  /// 4. Giới hạn timeout 5s, kích thước tải tối đa 50KB
  /// 5. Không gửi kèm cookie/JWT Odoo
  Future<LinkMetadata?> getMetadata(String rawUrl) async {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return null;

    var normalized = trimmed;
    if (!normalized.contains('://')) {
      normalized = 'https://$normalized';
    }

    await _ensureDiskCacheLoaded();

    // 1. Kiểm tra cache trong RAM
    final cached = _memoryCache[normalized];
    if (cached != null && cached.isFresh()) {
      return cached;
    }

    // 2. Chống gọi mạng trùng lặp cho cùng một URL đang fetch
    if (_inFlight.containsKey(normalized)) {
      return _inFlight[normalized];
    }

    final future = _fetchAndCacheMetadata(normalized, rawUrl);
    _inFlight[normalized] = future;

    try {
      final result = await future;
      return result;
    } finally {
      _inFlight.remove(normalized);
    }
  }

  Future<LinkMetadata?> _fetchAndCacheMetadata(
    String targetUrl,
    String originalUrl,
  ) async {
    final uri = Uri.tryParse(targetUrl);
    if (uri == null) return null;

    // 3. Kiểm tra an toàn mạng & SSRF
    final isSafe = await isSafeToFetch(uri);
    if (!isSafe) {
      debugPrint('[LinkMetadataService] Blocked unsafe/SSRF URL: $targetUrl');
      return null;
    }

    // 4. Tải và phân tích HTML với timeout 5s và stream limit 50KB
    final metadata = await _fetchHtmlMetadata(uri, originalUrl);
    if (metadata != null && metadata.hasContent) {
      _putCache(targetUrl, metadata);
    }

    return metadata;
  }

  void _putCache(String url, LinkMetadata metadata) {
    if (_memoryCache.length >= _maxMemoryEntries) {
      _memoryCache.remove(_memoryCache.keys.first);
    }
    _memoryCache[url] = metadata;
    _persistDiskCache();
  }

  /// Kiểm tra địa chỉ IP có thuộc dải cấm SSRF (Loopback, Private RFC 1918, Link-Local, Metadata)
  static bool isBlockedIpAddress(String ipStr) {
    final cleanIp = ipStr.trim().replaceAll('[', '').replaceAll(']', '');

    // IPv4 check
    final ipv4Parts = cleanIp.split('.');
    if (ipv4Parts.length == 4) {
      final octets = ipv4Parts.map((p) => int.tryParse(p)).toList();
      if (octets.any((o) => o == null || o < 0 || o > 255)) {
        return true;
      }
      final o0 = octets[0]!;
      final o1 = octets[1]!;

      // 0.0.0.0/8 (Current network)
      if (o0 == 0) return true;
      // 127.0.0.0/8 (Loopback)
      if (o0 == 127) return true;
      // 10.0.0.0/8 (Private RFC 1918)
      if (o0 == 10) return true;
      // 172.16.0.0/12 (Private RFC 1918: 172.16.0.0 - 172.31.255.255)
      if (o0 == 172 && o1 >= 16 && o1 <= 31) return true;
      // 192.168.0.0/16 (Private RFC 1918)
      if (o0 == 192 && o1 == 168) return true;
      // 169.254.0.0/16 (Link-Local, AWS/GCP/Azure Metadata: 169.254.169.254)
      if (o0 == 169 && o1 == 254) return true;
      // 100.64.0.0/10 (Carrier-grade NAT)
      if (o0 == 100 && o1 >= 64 && o1 <= 127) return true;
      // 255.255.255.255 (Broadcast)
      if (o0 == 255) return true;

      return false;
    }

    // IPv6 check
    final lower = cleanIp.toLowerCase();
    if (lower == '::1' || lower == '0:0:0:0:0:0:0:1') return true;
    if (lower == '::' || lower == '0:0:0:0:0:0:0:0') return true;
    if (lower.startsWith('fc') || lower.startsWith('fd')) return true; // fc00::/7
    if (lower.startsWith('fe8') ||
        lower.startsWith('fe9') ||
        lower.startsWith('fea') ||
        lower.startsWith('feb')) {
      return true; // fe80::/10 Link-local
    }
    if (lower.contains('::ffff:')) {
      final sub = lower.split('::ffff:').last;
      return isBlockedIpAddress(sub);
    }

    return false;
  }

  /// Kiểm tra Hostname có thuộc danh sách chặn
  static bool isBlockedHostname(String host) {
    final cleanHost = host.trim().toLowerCase();
    if (cleanHost.isEmpty) return true;
    if (cleanHost == 'localhost') return true;
    if (cleanHost.endsWith('.localhost')) return true;
    if (cleanHost.endsWith('.local')) return true;
    if (cleanHost.endsWith('.internal')) return true;
    if (cleanHost.endsWith('.lan')) return true;
    if (cleanHost == 'metadata.google.internal') return true;
    if (cleanHost == 'instance-data') return true;

    return isBlockedIpAddress(cleanHost);
  }

  /// Kiểm tra URL có phải là URL nội bộ nhạy cảm hoặc Odoo Backend
  static bool isSensitiveOrInternalUrl(Uri uri) {
    final path = uri.path.toLowerCase();
    const sensitivePatterns = [
      '/reset-password',
      '/auth',
      '/login',
      '/logout',
      '/token',
      '/api/v1/mobile',
      '/jsonrpc',
      '/xmlrpc',
      '.env',
      'id_rsa',
    ];
    for (final pattern in sensitivePatterns) {
      if (path.contains(pattern)) return true;
    }

    try {
      final base = Uri.tryParse(odooApiClient.baseUrl);
      if (base != null && base.host.isNotEmpty) {
        if (uri.host.toLowerCase() == base.host.toLowerCase()) {
          return true;
        }
      }
    } catch (_) {}

    return false;
  }

  /// Xác thực URL an toàn trước khi fetch (SSRF Guard & DNS Lookup)
  static Future<bool> isSafeToFetch(Uri uri) async {
    if (uri.scheme != 'http' && uri.scheme != 'https') {
      return false;
    }
    if (uri.userInfo.isNotEmpty) {
      return false;
    }
    final host = uri.host;
    if (isBlockedHostname(host)) {
      return false;
    }
    if (isSensitiveOrInternalUrl(uri)) {
      return false;
    }

    // Nếu không phải Web, kiểm tra DNS resolution của hostname
    if (!kIsWeb) {
      try {
        final addresses = await InternetAddress.lookup(host)
            .timeout(const Duration(seconds: 2));
        if (addresses.isEmpty) return false;
        for (final addr in addresses) {
          if (addr.isLoopback || addr.isLinkLocal) return false;
          if (isBlockedIpAddress(addr.address)) return false;
        }
      } catch (_) {
        // Lỗi phân giải DNS hoặc timeout -> từ chối tải để đảm bảo an toàn
        return false;
      }
    }

    return true;
  }

  /// Tải nội dung HTML và bóc tách metadata (OpenGraph & Meta tags)
  Future<LinkMetadata?> _fetchHtmlMetadata(
    Uri initialUri,
    String originalUrl,
  ) async {
    final client = httpClient ?? http.Client();
    final shouldCloseClient = httpClient == null;

    var currentUri = initialUri;
    var redirectCount = 0;
    const maxRedirects = 3;

    try {
      while (redirectCount <= maxRedirects) {
        final request = http.Request('GET', currentUri)
          ..headers.addAll({
            'User-Agent':
                'Mozilla/5.0 (Mobile; rv:109.0) Gecko/109.0 Firefox/119.0',
            'Accept': 'text/html,application/xhtml+xml',
            'Accept-Language': 'vi,en;q=0.9',
          })
          ..followRedirects = false; // Xử lý redirect thủ công để re-check SSRF

        final streamedResponse = await client
            .send(request)
            .timeout(const Duration(seconds: 5));

        // Kiểm tra redirect
        if (streamedResponse.isRedirect ||
            streamedResponse.statusCode == 301 ||
            streamedResponse.statusCode == 302 ||
            streamedResponse.statusCode == 303 ||
            streamedResponse.statusCode == 307 ||
            streamedResponse.statusCode == 308) {
          redirectCount++;
          if (redirectCount > maxRedirects) {
            debugPrint('[LinkMetadataService] Exceeded max redirects: $initialUri');
            return null;
          }

          final location = streamedResponse.headers['location'];
          if (location == null || location.isEmpty) return null;

          final nextUri = currentUri.resolve(location);
          final isNextSafe = await isSafeToFetch(nextUri);
          if (!isNextSafe) {
            debugPrint('[LinkMetadataService] Unsafe redirect target blocked: $nextUri');
            return null;
          }

          currentUri = nextUri;
          continue;
        }

        if (streamedResponse.statusCode < 200 ||
            streamedResponse.statusCode >= 300) {
          return null;
        }

        final contentType =
            streamedResponse.headers['content-type']?.toLowerCase() ?? '';
        if (contentType.isNotEmpty &&
            !contentType.contains('text/html') &&
            !contentType.contains('application/xhtml')) {
          return null;
        }

        // Đọc stream có giới hạn tối đa 50 KB (ngừng ngay khi thấy </head>)
        const maxBytes = 50 * 1024;
        final bytes = <int>[];

        await for (final chunk in streamedResponse.stream) {
          bytes.addAll(chunk);
          if (bytes.length >= maxBytes) break;

          final partial = utf8.decode(bytes, allowMalformed: true);
          if (partial.toLowerCase().contains('</head>')) {
            break;
          }
        }

        final html = utf8.decode(bytes, allowMalformed: true);
        return parseHtmlMetadata(
          html: html,
          targetUri: currentUri,
          originalUrl: originalUrl,
        );
      }
    } catch (e) {
      debugPrint('[LinkMetadataService] Fetch error ($currentUri): $e');
      return null;
    } finally {
      if (shouldCloseClient) {
        client.close();
      }
    }

    return null;
  }

  /// Phân tích OpenGraph và HTML Meta tags từ chuỗi HTML
  static LinkMetadata parseHtmlMetadata({
    required String html,
    required Uri targetUri,
    required String originalUrl,
  }) {
    String? title;
    String? description;
    String? imageUrl;
    String? siteName;

    // 1. Trích xuất nội dung <head>
    final headMatch = RegExp(
      r'<head[^>]*>(.*?)</head>',
      caseSensitive: false,
      dotAll: true,
    ).firstMatch(html);
    final headContent = headMatch != null ? headMatch.group(1)! : html;

    // 2. Trích xuất meta tags
    String? getMeta(String attr, String val) {
      final reg = RegExp(
        '<meta\\s+[^>]*?$attr\\s*=\\s*["\']$val["\'][^>]*?content\\s*=\\s*["\']([^"\']*)["\']',
        caseSensitive: false,
      );
      final m = reg.firstMatch(headContent);
      if (m != null) return m.group(1);

      final regReverse = RegExp(
        '<meta\\s+[^>]*?content\\s*=\\s*["\']([^"\']*)["\'][^>]*?$attr\\s*=\\s*["\']$val["\']',
        caseSensitive: false,
      );
      final mRev = regReverse.firstMatch(headContent);
      return mRev?.group(1);
    }

    title = getMeta('property', 'og:title') ??
        getMeta('name', 'twitter:title') ??
        getMeta('name', 'title');

    if (title == null || title.isEmpty) {
      final titleMatch = RegExp(
        r'<title[^>]*>(.*?)</title>',
        caseSensitive: false,
        dotAll: true,
      ).firstMatch(headContent);
      if (titleMatch != null) {
        title = titleMatch.group(1);
      }
    }

    description = getMeta('property', 'og:description') ??
        getMeta('name', 'description') ??
        getMeta('name', 'twitter:description');

    imageUrl = getMeta('property', 'og:image') ??
        getMeta('name', 'twitter:image') ??
        getMeta('property', 'og:image:url');

    siteName = getMeta('property', 'og:site_name');

    // Làm sạch text bằng cleanHtmlText
    title = title != null ? cleanHtmlText(title).trim() : null;
    description = description != null ? cleanHtmlText(description).trim() : null;

    // Chuẩn hóa và kiểm tra an toàn cho URL ảnh
    String? validImageUrl;
    if (imageUrl != null && imageUrl.trim().isNotEmpty) {
      final trimmedImg = imageUrl.trim();
      try {
        final imgUri = targetUri.resolve(trimmedImg);
        if ((imgUri.scheme == 'http' || imgUri.scheme == 'https') &&
            !isBlockedHostname(imgUri.host)) {
          validImageUrl = imgUri.toString();
        }
      } catch (_) {}
    }

    final domain = targetUri.host.replaceFirst(RegExp(r'^www\.'), '');

    return LinkMetadata(
      url: targetUri.toString(),
      originalUrl: originalUrl,
      domain: siteName?.isNotEmpty == true ? siteName! : domain,
      title: title?.isNotEmpty == true ? title : null,
      description: description?.isNotEmpty == true ? description : null,
      imageUrl: validImageUrl,
      fetchedAt: DateTime.now(),
      isInternalOdooUrl: false,
    );
  }
}
