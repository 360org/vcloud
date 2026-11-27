import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/api/odoo_api_client.dart';
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
          .where((app) => bookmarkedIds.contains(app.id))
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
    return bookmarkedIds.contains(app.id);
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

  static const _legacyStorageKey = 'vcloud_pinned_apps_ids_v1';
  String? _loadedScopeKey;
  bool _hasSavedBookmarks = false;
  bool _hasLoadedMenuOnce = false;
  bool _hasServerSyncedBookmarks = false;
  bool _hasUserToggledBookmark = false;
  Future<void>? _inFlightLoad;

  String _resolveStorageKey() {
    final session = odooApiClient.session;
    if (session == null || session.db.isEmpty) {
      return _legacyStorageKey;
    }
    return 'vcloud_pinned_apps_v2_${session.db}_${session.uid}';
  }

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

  Future<Set<int>?> _readSavedBookmarks() async {
    final scopeKey = _resolveStorageKey();
    _loadedScopeKey = scopeKey;
    try {
      final raw = await _storage.read(key: scopeKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          _hasSavedBookmarks = true;
          return decoded.whereType<num>().map((e) => e.toInt()).toSet();
        }
      }
    } catch (e) {
      debugPrint('[MenuController._readSavedBookmarks] read storage error: $e');
    }
    return null;
  }

  Future<void> _writeSavedBookmarks(Set<int> bookmarks) async {
    final scopeKey = _resolveStorageKey();
    _loadedScopeKey = scopeKey;
    _hasSavedBookmarks = true;
    try {
      await _storage.write(
        key: scopeKey,
        value: jsonEncode(bookmarks.toList()),
      );
    } catch (e) {
      debugPrint('[MenuController._writeSavedBookmarks] save error: $e');
    }
  }

  Future<void> _initAndLoad() async {
    final saved = await _readSavedBookmarks();
    if (saved != null &&
        !_hasServerSyncedBookmarks &&
        !_hasUserToggledBookmark) {
      state = state.copyWith(bookmarkedIds: saved);
    }
    if (!_hasLoadedMenuOnce) {
      await loadMenu();
    }
  }

  Future<void> loadMenu() {
    if (_inFlightLoad != null) return _inFlightLoad!;
    final future = _performLoadMenu();
    _inFlightLoad = future;
    return future.whenComplete(() {
      if (identical(_inFlightLoad, future)) {
        _inFlightLoad = null;
      }
    });
  }

  Future<void> _performLoadMenu() async {
    _hasLoadedMenuOnce = true;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final result = await _repository.fetchAppsMenu();
      final serverBookmarks = await _repository.fetchServerBookmarkedIds();

      final Set<int> bookmarks;
      if (serverBookmarks != null) {
        _hasServerSyncedBookmarks = true;
        bookmarks = Set<int>.from(serverBookmarks);
        await _writeSavedBookmarks(bookmarks);
      } else {
        final currentScopeKey = _resolveStorageKey();
        Set<int>? saved;
        if (_loadedScopeKey != currentScopeKey) {
          _hasSavedBookmarks = false;
          saved = await _readSavedBookmarks();
        }
        if (saved != null) {
          bookmarks = saved;
        } else if (_hasSavedBookmarks) {
          bookmarks = Set<int>.from(state.bookmarkedIds);
        } else {
          bookmarks = Set<int>.from(state.bookmarkedIds);
          for (final app in result.apps) {
            if (app.isBookmarked) {
              bookmarks.add(app.id);
            }
          }
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

  /// Đồng bộ ngầm danh sách ghim từ server mà không bật loading spinner.
  Future<void> refreshBookmarksFromServer() async {
    try {
      final serverBookmarks = await _repository.fetchServerBookmarkedIds();
      if (serverBookmarks == null) return;
      final synced = Set<int>.from(serverBookmarks);
      state = state.copyWith(bookmarkedIds: synced);
      await _writeSavedBookmarks(synced);
    } catch (e) {
      debugPrint('[MenuController.refreshBookmarksFromServer] error: $e');
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void setActiveTab(String tab) {
    state = state.copyWith(activeTab: tab);
  }

  /// Bật/tắt ghim ứng dụng, lưu cục bộ theo DB/UID và đồng bộ lên Odoo server.
  /// Trả về `true` nếu vừa ghim, `false` nếu vừa bỏ ghim.
  Future<bool> toggleBookmark(int appId) async {
    _hasUserToggledBookmark = true;
    final updated = Set<int>.from(state.bookmarkedIds);
    final isAdded = !updated.contains(appId);
    if (isAdded) {
      updated.add(appId);
    } else {
      updated.remove(appId);
    }
    state = state.copyWith(bookmarkedIds: updated);

    await _writeSavedBookmarks(updated);
    unawaited(
      _repository
          .syncServerBookmarks(
            bookmarkedIds: updated.toList(),
            appId: appId,
            isBookmarked: isAdded,
          )
          .catchError((_) => false),
    );
    return isAdded;
  }
}

final menuControllerProvider =
    StateNotifierProvider<MenuController, MenuState>((ref) {
  final repo = ref.watch(menuRepositoryProvider);
  return MenuController(repo);
});
