import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/odoo_api_client.dart';
import 'menu_item_model.dart';

final menuRepositoryProvider = Provider<MenuRepository>((ref) {
  return MenuRepository();
});

class MenuRepository {
  MenuRepository({OdooApiClient? client}) : _client = client ?? odooApiClient;

  final OdooApiClient _client;

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
}
