import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/odoo_api_client.dart';
import '../../../core/error/failure.dart';
import 'menu_item_model.dart';

final menuRepositoryProvider = Provider<MenuRepository>((ref) {
  return MenuRepository();
});

class MenuRepository {
  MenuRepository({OdooApiClient? client}) : _client = client ?? odooApiClient;

  final OdooApiClient _client;

  Set<int>? _lastFetchedBookmarkedIds;
  bool _lastBookmarkSyncSupported = false;
  int? _cachedUserSettingsId;

  Future<({List<AppMenuItem> apps, List<AppUtilityItem> utilities})>
      fetchAppsMenu() async {
    try {
      final res = await _client.get('/api/v1/mobile/menu/apps');
      Map<String, dynamic> dataMap = {};
      if (res is Map) {
        if (res['data'] is Map) {
          dataMap = Map<String, dynamic>.from(res['data'] as Map);
        } else if (res['result'] is Map) {
          final inner = res['result'] as Map;
          if (inner['data'] is Map) {
            dataMap = Map<String, dynamic>.from(inner['data'] as Map);
          } else {
            dataMap = Map<String, dynamic>.from(inner);
          }
        } else {
          dataMap = Map<String, dynamic>.from(res);
        }
      }

      final explicitUnsupported = dataMap['bookmark_sync_supported'] == false;
      if (!explicitUnsupported &&
          (dataMap['bookmark_sync_supported'] == true ||
              dataMap['bookmarked_ids'] is List)) {
        _lastBookmarkSyncSupported = true;
        _lastFetchedBookmarkedIds = _parseBookmarkedIdSet(
          dataMap['bookmarked_ids'],
        );
      } else {
        _lastBookmarkSyncSupported = false;
        _lastFetchedBookmarkedIds = null;
      }

      final appsRaw =
          dataMap['apps'] ?? (res is Map ? res['apps'] : null);
      final utilsRaw = dataMap['utilities'] ??
          (res is Map
              ? (res['utilities'] ?? res['system_utilities'])
              : null);

      final List<AppMenuItem> apps = (appsRaw is List)
          ? appsRaw
              .whereType<Map>()
              .map((e) => AppMenuItem.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : <AppMenuItem>[];

      final List<AppUtilityItem> utilities = (utilsRaw is List)
          ? utilsRaw
              .whereType<Map>()
              .map((e) => AppUtilityItem.fromJson(Map<String, dynamic>.from(e)))
              .toList()
          : <AppUtilityItem>[];

      debugPrint(
          '📱 [MenuRepository] Loaded ${apps.length} apps, ${utilities.length} utilities');
      return (apps: apps, utilities: utilities);
    } catch (e, st) {
      debugPrint('🚨 [MenuRepository.fetchAppsMenu] Error fetching apps: $e\n$st');
      rethrow;
    }
  }

  /// Lấy danh sách ID ứng dụng đã ghim từ server (ưu tiên Tier 1 `v_mobile`,
  /// fallback sang Tier 2 `/web/session/get_session_info` của Odoo Web).
  Future<Set<int>?> fetchServerBookmarkedIds() async {
    if (_lastBookmarkSyncSupported) {
      if (_lastFetchedBookmarkedIds != null) {
        final cached = Set<int>.from(_lastFetchedBookmarkedIds!);
        _lastFetchedBookmarkedIds = null;
        return cached;
      }
      try {
        await fetchAppsMenu();
        if (_lastFetchedBookmarkedIds != null) {
          final refreshed = Set<int>.from(_lastFetchedBookmarkedIds!);
          _lastFetchedBookmarkedIds = null;
          return refreshed;
        }
      } catch (_) {}
    }

    return _fetchBookmarkedIdsFromWebSession();
  }

  Future<Set<int>?> _fetchBookmarkedIdsFromWebSession() async {
    final session = _client.session;
    if (session == null || session.accessToken.isEmpty) return null;

    try {
      final res = await _client.post(
        '/web/session/get_session_info',
        body: const {
          'jsonrpc': '2.0',
          'method': 'call',
          'params': <String, dynamic>{},
        },
      );
      if (res is Map && res['result'] is Map) {
        final result = res['result'] as Map;
        final userSettings = result['user_settings'];
        if (userSettings is Map && userSettings.containsKey('apps_bookmarked')) {
          _cachedUserSettingsId = (userSettings['id'] as num?)?.toInt();
          return _parseBookmarkedIdSet(userSettings['apps_bookmarked']);
        }
      }
    } catch (e) {
      debugPrint('[MenuRepository._fetchBookmarkedIdsFromWebSession] error: $e');
    }
    return null;
  }

  /// Đồng bộ thay đổi ghim ứng dụng lên server (Tier 1 REST, fallback Tier 2 Web RPC).
  Future<bool> syncServerBookmarks({
    required List<int> bookmarkedIds,
    required int appId,
    required bool isBookmarked,
  }) async {
    var shouldFallbackTier2 = false;
    try {
      final res = await _client.post(
        '/api/v1/mobile/menu/bookmark',
        body: {
          'menu_id': appId,
          'bookmarked': isBookmarked,
          'bookmarked_ids': bookmarkedIds,
        },
      );
      if (res is Map && res['error'] != null) {
        return false;
      }
      return true;
    } on Failure catch (e) {
      if (e.statusCode == 404 || e.statusCode == 405) {
        shouldFallbackTier2 = true;
      } else {
        return false;
      }
    } catch (_) {
      shouldFallbackTier2 = true;
    }

    if (!shouldFallbackTier2 || _client.session == null) {
      return false;
    }

    try {
      if (_cachedUserSettingsId == null) {
        await _fetchBookmarkedIdsFromWebSession();
      }
      if (_cachedUserSettingsId == null) return false;

      final res = await _client.post(
        '/web/dataset/call_kw/res.users.settings/set_res_users_settings',
        body: {
          'jsonrpc': '2.0',
          'method': 'call',
          'params': {
            'model': 'res.users.settings',
            'method': 'set_res_users_settings',
            'args': [
              [_cachedUserSettingsId],
            ],
            'kwargs': {
              'new_settings': {'apps_bookmarked': bookmarkedIds},
            },
          },
        },
      );
      return res is Map && res['error'] == null;
    } catch (e) {
      debugPrint('[MenuRepository.syncServerBookmarks] Tier 2 error: $e');
      return false;
    }
  }

  Set<int> _parseBookmarkedIdSet(Object? raw) {
    Object? target = raw;
    if (target is String && target.trim().startsWith('[')) {
      try {
        target = jsonDecode(target);
      } catch (_) {}
    }
    if (target is! List) return <int>{};
    return target
        .map((e) => e is num ? e.toInt() : int.tryParse(e.toString()))
        .whereType<int>()
        .toSet();
  }
}
