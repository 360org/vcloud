import 'package:flutter/material.dart' hide MenuController;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/core/api/odoo_api_client.dart';
import 'package:vcloud/core/api/odoo_session.dart';
import 'package:vcloud/core/error/failure.dart';
import 'package:vcloud/core/services/global_state_reset_service.dart';
import 'package:vcloud/features/chat_v2/application/chat_v2_inbox_controller.dart';
import 'package:vcloud/features/chat_v2/data/chat_v2_repository.dart';
import 'package:vcloud/features/chat_v2/domain/models/chat_v2_inbox_item.dart';
import 'package:vcloud/features/chat_v2/presentation/widgets/chat_v2_inbox_tab.dart';
import 'package:vcloud/features/menu/application/menu_controller.dart';
import 'package:vcloud/features/menu/data/menu_item_model.dart';
import 'package:vcloud/features/menu/data/menu_repository.dart';

class _FakeChatV2Repository implements ChatV2Repository {
  int inboxFetchCount = 0;
  bool throw405 = false;
  List<ChatV2InboxItem> itemsToReturn = const [];

  @override
  Future<List<ChatV2InboxItem>> fetchInboxMessages({
    int limit = 40,
    int offset = 0,
  }) async {
    inboxFetchCount++;
    if (throw405) {
      throw Failure('Method Not Allowed', statusCode: 405);
    }
    return itemsToReturn;
  }

  @override
  Future<List<ChatV2InboxItem>> fetchStarredMessages({
    int limit = 40,
    int offset = 0,
  }) async {
    if (throw405) {
      throw Failure('Method Not Allowed', statusCode: 405);
    }
    return const [];
  }

  @override
  Future<List<ChatV2InboxItem>> fetchHistoryMessages({
    int limit = 40,
    int offset = 0,
  }) async {
    if (throw405) {
      throw Failure('Method Not Allowed', statusCode: 405);
    }
    return const [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeOdooApiClient implements OdooApiClient {
  _FakeOdooApiClient({this.mockSession});

  OdooSession? mockSession;
  final Map<String, dynamic Function()> getHandlers = {};
  final Map<String, dynamic Function(Object? body)> postHandlers = {};
  final List<String> getCalls = [];
  final List<({String path, Object? body})> postCalls = [];

  @override
  OdooSession? get session => mockSession;

  @override
  Future<dynamic> get(
    String path, {
    Map<String, Object?> query = const <String, Object?>{},
    bool auth = true,
  }) async {
    getCalls.add(path);
    final handler = getHandlers[path];
    if (handler != null) return handler();
    throw Failure('Unhandled GET $path', statusCode: 404);
  }

  @override
  Future<dynamic> post(
    String path, {
    Object? body,
    Map<String, Object?> query = const <String, Object?>{},
    bool auth = true,
  }) async {
    postCalls.add((path: path, body: body));
    final handler = postHandlers[path];
    if (handler != null) return handler(body);
    throw Failure('Unhandled POST $path', statusCode: 404);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeSyncMenuRepository extends MenuRepository {
  _FakeSyncMenuRepository({this.initialApps = const []});

  final List<AppMenuItem> initialApps;
  Set<int>? serverBookmarks;
  final List<({List<int> bookmarkedIds, int appId, bool isBookmarked})>
      syncCalls = [];

  @override
  Future<({List<AppMenuItem> apps, List<AppUtilityItem> utilities})>
      fetchAppsMenu() async {
    return (apps: initialApps, utilities: const <AppUtilityItem>[]);
  }

  @override
  Future<Set<int>?> fetchServerBookmarkedIds() async {
    return serverBookmarks == null ? null : Set<int>.from(serverBookmarks!);
  }

  @override
  Future<bool> syncServerBookmarks({
    required List<int> bookmarkedIds,
    required int appId,
    required bool isBookmarked,
  }) async {
    syncCalls.add((
      bookmarkedIds: bookmarkedIds,
      appId: appId,
      isBookmarked: isBookmarked,
    ));
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('Inbox Stale Error Reset & [HTTP 405] Classification', () {
    test(
      'preserves Failure.statusCode as [HTTP 405] and GlobalStateResetService clears stale Inbox state',
      () async {
        final fakeChatRepo = _FakeChatV2Repository()..throw405 = true;
        final container = ProviderContainer(
          overrides: [
            chatV2RepositoryProvider.overrideWithValue(fakeChatRepo),
          ],
        );
        addTearDown(container.dispose);

        await container
            .read(chatV2InboxControllerProvider.notifier)
            .loadInbox(refresh: true);

        final errorState = container.read(chatV2InboxControllerProvider);
        expect(errorState.error, contains('[HTTP 405]'));
        expect(errorState.isLoading, isFalse);

        // Simulate DB switch / logout reset via GlobalStateResetService
        fakeChatRepo.throw405 = false;
        fakeChatRepo.itemsToReturn = const [
          ChatV2InboxItem(
            id: 901,
            subject: 'Hộp thư sau khi đổi DB',
            recordName: 'Ticket #901',
            model: 'helpdesk.ticket',
            resId: 901,
            body: '<p>Dữ liệu mới</p>',
            authorName: 'Hệ thống',
          ),
        ];

        await GlobalStateResetService.clearAllUserDataOnLogout(
          container: container,
        );

        // Trigger rebuild of invalidated provider and allow its build() microtask to finish
        container.read(chatV2InboxControllerProvider);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        final resetState = container.read(chatV2InboxControllerProvider);
        expect(resetState.error, isNull);
        expect(resetState.inboxItems.length, 1);
        expect(resetState.inboxItems.first.id, 901);
      },
    );

    testWidgets(
      'ChatV2InboxTab renders 405 unsupported message and retries once on entry',
      (tester) async {
        final fakeChatRepo = _FakeChatV2Repository()..throw405 = true;
        final container = ProviderContainer(
          overrides: [
            chatV2RepositoryProvider.overrideWithValue(fakeChatRepo),
          ],
        );
        addTearDown(container.dispose);

        // Pre-populate error state before mounting ChatV2InboxTab
        await container
            .read(chatV2InboxControllerProvider.notifier)
            .loadInbox(refresh: true);
        final countBeforeMount = fakeChatRepo.inboxFetchCount;

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              home: Scaffold(
                body: ChatV2InboxTab(tabType: ChatV2InboxTabType.inbox),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          fakeChatRepo.inboxFetchCount,
          greaterThan(countBeforeMount),
          reason: 'Should auto-retry once on tab entry when stale error exists',
        );
        expect(find.text('Máy chủ chưa nâng cấp tính năng'), findsOneWidget);
        expect(
          find.text(
            'Máy chủ hiện tại chưa hỗ trợ Hộp thư đến Discuss (cần nâng cấp module v_mobile).',
          ),
          findsOneWidget,
        );
      },
    );
  });

  group('MenuState Unpin Fix', () {
    test('isAppBookmarked and filteredApps allow unpinning even if app.isBookmarked is true', () async {
      const appFromServer = AppMenuItem(
        id: 307,
        name: 'Tài chính',
        isBookmarked: true,
      );
      const stateWithPin = MenuState(
        apps: [appFromServer],
        activeTab: 'bookmark',
        bookmarkedIds: {307},
      );
      expect(stateWithPin.isAppBookmarked(appFromServer), isTrue);
      expect(stateWithPin.filteredApps.map((a) => a.id), [307]);

      const stateAfterUnpin = MenuState(
        apps: [appFromServer],
        activeTab: 'bookmark',
        bookmarkedIds: {},
      );
      expect(stateAfterUnpin.isAppBookmarked(appFromServer), isFalse);
      expect(stateAfterUnpin.filteredApps, isEmpty);

      // Verify MenuController persists unpinning an initially bookmarked app
      final fakeRepo = _FakeSyncMenuRepository(initialApps: const [appFromServer]);
      final controller = MenuController(fakeRepo);
      await controller.loadMenu();
      expect(controller.state.isAppBookmarked(appFromServer), isTrue);

      final isAdded = await controller.toggleBookmark(307);
      expect(isAdded, isFalse);
      expect(controller.state.isAppBookmarked(appFromServer), isFalse);

      // Reload offline (serverBookmarks == null) -> must stay unpinned
      await controller.loadMenu();
      expect(controller.state.isAppBookmarked(appFromServer), isFalse);
    });
  });

  group('MenuRepository Tier 1 & Tier 2 Web Sync', () {
    test('Tier 1 parses bookmark_sync_supported + bookmarked_ids and posts to /api/v1/mobile/menu/bookmark', () async {
      final client = _FakeOdooApiClient(
        mockSession: OdooSession(
          accessToken: 'tok_1',
          uid: 2,
          db: 'vuahethong',
          login: 'admin',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
          baseUrl: 'https://vuahethong.net',
        ),
      );
      client.getHandlers['/api/v1/mobile/menu/apps'] = () => {
            'status': 'success',
            'data': {
              'bookmark_sync_supported': true,
              'bookmarked_ids': [307, 1062],
              'apps': [
                {'id': 307, 'name': 'Tài chính', 'is_bookmarked': true},
                {'id': 1062, 'name': 'Kiến thức', 'is_bookmarked': true},
              ],
              'utilities': <dynamic>[],
            },
          };
      client.postHandlers['/api/v1/mobile/menu/bookmark'] = (body) => {
            'status': 'success',
            'data': {
              'bookmarked_ids': [307, 1062, 87],
              'bookmark_sync_supported': true,
            },
          };

      final repo = MenuRepository(client: client);
      final menu = await repo.fetchAppsMenu();
      expect(menu.apps.length, 2);

      final ids = await repo.fetchServerBookmarkedIds();
      expect(ids, {307, 1062});
      expect(client.postCalls, isEmpty);

      final ok = await repo.syncServerBookmarks(
        bookmarkedIds: [307, 1062, 87],
        appId: 87,
        isBookmarked: true,
      );
      expect(ok, isTrue);
      expect(client.postCalls.length, 1);
      expect(client.postCalls.single.path, '/api/v1/mobile/menu/bookmark');
    });

    test('Tier 2 falls back to /web/session/get_session_info and set_res_users_settings on 404/405', () async {
      final client = _FakeOdooApiClient(
        mockSession: OdooSession(
          accessToken: 'tok_2',
          uid: 5,
          db: 'vuahethong',
          login: 'user',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
          baseUrl: 'https://vuahethong.net',
        ),
      );
      client.getHandlers['/api/v1/mobile/menu/apps'] = () => {
            'status': 'success',
            'data': {
              'apps': [
                {'id': 1062, 'name': 'Kiến thức'},
              ],
              'utilities': <dynamic>[],
            },
          };
      client.postHandlers['/api/v1/mobile/menu/bookmark'] = (_) {
        throw Failure('Not Found', statusCode: 404);
      };
      client.postHandlers['/web/session/get_session_info'] = (_) => {
            'jsonrpc': '2.0',
            'result': {
              'uid': 5,
              'user_settings': {
                'id': 77,
                'apps_bookmarked': [1062, 87],
              },
            },
          };
      client.postHandlers['/web/dataset/call_kw/res.users.settings/set_res_users_settings'] =
          (body) => {
                'jsonrpc': '2.0',
                'result': {'apps_bookmarked': [1062, 87, 307]},
              };

      final repo = MenuRepository(client: client);
      await repo.fetchAppsMenu();

      final ids = await repo.fetchServerBookmarkedIds();
      expect(ids, {1062, 87});

      final synced = await repo.syncServerBookmarks(
        bookmarkedIds: [1062, 87, 307],
        appId: 307,
        isBookmarked: true,
      );
      expect(synced, isTrue);
      expect(client.postCalls.last.path,
          '/web/dataset/call_kw/res.users.settings/set_res_users_settings');
      final rpcBody = client.postCalls.last.body as Map<String, dynamic>;
      final params = rpcBody['params'] as Map<String, dynamic>;
      expect(params['args'], [
        [77],
      ]);
      expect(params['kwargs'], {
        'new_settings': {
          'apps_bookmarked': [1062, 87, 307],
        },
      });
    });
  });

  group('MenuController.refreshBookmarksFromServer', () {
    test('silently syncs Web pins (1062 Knowledge) without toggling isLoading', () async {
      final repo = _FakeSyncMenuRepository(
        initialApps: const [
          AppMenuItem(id: 87, name: 'Thảo luận'),
          AppMenuItem(id: 1062, name: 'Kiến thức'),
        ],
      )..serverBookmarks = {87};

      final controller = MenuController(repo);
      await controller.loadMenu();
      expect(controller.state.bookmarkedIds, {87});

      // Simulate user pinning Knowledge (1062) on Odoo Web
      repo.serverBookmarks = {87, 1062};
      final loadingStates = <bool>[];
      final sub = controller.addListener(
        (state) => loadingStates.add(state.isLoading),
        fireImmediately: false,
      );
      addTearDown(sub);

      await controller.refreshBookmarksFromServer();

      expect(controller.state.bookmarkedIds, {87, 1062});
      expect(loadingStates, everyElement(isFalse));

      // Verify toggling pin calls syncServerBookmarks
      final added = await controller.toggleBookmark(1062);
      expect(added, isFalse);
      expect(controller.state.bookmarkedIds, {87});
      await Future<void>.delayed(Duration.zero);
      expect(repo.syncCalls.length, 1);
      expect(repo.syncCalls.single.appId, 1062);
      expect(repo.syncCalls.single.isBookmarked, isFalse);
      expect(repo.syncCalls.single.bookmarkedIds, [87]);
    });
  });
}
