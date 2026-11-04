import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../data/menu_item_model.dart';
import '../data/menu_repository.dart';

class MenuState {
  const MenuState({
    this.apps = const [],
    this.utilities = const [],
    this.searchQuery = '',
    this.activeTab = 'all',
    this.bookmarkedIds = const {},
    this.isLoading = false,
    this.error,
  });

  final List<AppMenuItem> apps;
  final List<AppUtilityItem> utilities;
  final String searchQuery;
  final String activeTab; // 'all' | 'bookmark'
  final Set<int> bookmarkedIds;
  final bool isLoading;
  final String? error;

  List<AppMenuItem> get filteredApps {
    var result = apps;
    if (activeTab == 'bookmark') {
      result = result
          .where((app) => bookmarkedIds.contains(app.id) || app.isBookmarked)
          .toList();
    }
    final q = searchQuery.trim().toLowerCase();
    if (q.isNotEmpty) {
      result = result
          .where((app) => app.name.toLowerCase().contains(q))
          .toList();
    }
    return result;
  }

  bool isAppBookmarked(AppMenuItem app) {
    return bookmarkedIds.contains(app.id) || app.isBookmarked;
  }

  MenuState copyWith({
    List<AppMenuItem>? apps,
    List<AppUtilityItem>? utilities,
    String? searchQuery,
    String? activeTab,
    Set<int>? bookmarkedIds,
    bool? isLoading,
    String? error,
  }) {
    return MenuState(
      apps: apps ?? this.apps,
      utilities: utilities ?? this.utilities,
      searchQuery: searchQuery ?? this.searchQuery,
      activeTab: activeTab ?? this.activeTab,
      bookmarkedIds: bookmarkedIds ?? this.bookmarkedIds,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

class MenuController extends StateNotifier<MenuState> {
  MenuController(this._repository, [FlutterSecureStorage? storage])
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                encryptedSharedPreferences: true,
                resetOnError: false,
              ),
            ),
        super(const MenuState()) {
    _initAndLoad();
  }

  final MenuRepository _repository;
  final FlutterSecureStorage _storage;

  static const _storageKey = 'vcloud_pinned_apps_ids_v1';

  static const List<AppUtilityItem> defaultUtilities = [
    AppUtilityItem(
      id: 'docs',
      name: 'Tài liệu hướng dẫn',
      icon: 'book_open',
      url: '/knowledge/article/126',
    ),
    AppUtilityItem(
      id: 'support',
      name: 'Yêu cầu hỗ trợ',
      icon: 'life_buoy',
      nativeRoute: '/tickets',
    ),
    AppUtilityItem(
      id: 'settings',
      name: 'Cài đặt hệ thống',
      icon: 'settings',
      webUrl: '/web#action=base.action_res_users',
    ),
  ];

  Future<void> _initAndLoad() async {
    try {
      final raw = await _storage.read(key: _storageKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          final saved = decoded.whereType<num>().map((e) => e.toInt()).toSet();
          if (saved.isNotEmpty) {
            state = state.copyWith(bookmarkedIds: saved);
          }
        }
      }
    } catch (e) {
      debugPrint('[MenuController._initAndLoad] read storage error: $e');
    }
    await loadMenu();
  }

  Future<void> loadMenu() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _repository.fetchAppsMenu();
      final bookmarks = Set<int>.from(state.bookmarkedIds);
      for (final app in result.apps) {
        if (app.isBookmarked) {
          bookmarks.add(app.id);
        }
      }

      final utils =
          result.utilities.isNotEmpty ? result.utilities : defaultUtilities;

      state = state.copyWith(
        apps: result.apps,
        utilities: utils,
        bookmarkedIds: bookmarks,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        utilities: defaultUtilities,
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setActiveTab(String tab) {
    state = state.copyWith(activeTab: tab);
  }

  /// Bật/tắt ghim ứng dụng và lưu bền vững vào FlutterSecureStorage.
  /// Trả về `true` nếu vừa ghim, `false` nếu vừa bỏ ghim.
  Future<bool> toggleBookmark(int appId) async {
    final updated = Set<int>.from(state.bookmarkedIds);
    final isAdded = !updated.contains(appId);
    if (isAdded) {
      updated.add(appId);
    } else {
      updated.remove(appId);
    }
    state = state.copyWith(bookmarkedIds: updated);

    try {
      await _storage.write(
        key: _storageKey,
        value: jsonEncode(updated.toList()),
      );
    } catch (e) {
      debugPrint('[MenuController.toggleBookmark] save error: $e');
    }
    return isAdded;
  }
}

final menuControllerProvider =
    StateNotifierProvider<MenuController, MenuState>((ref) {
  final repo = ref.watch(menuRepositoryProvider);
  return MenuController(repo);
});
