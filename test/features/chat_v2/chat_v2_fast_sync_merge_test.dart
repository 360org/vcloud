import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vcloud/core/api/auth_user.dart';
import 'package:vcloud/core/api/odoo_api_client.dart';
import 'package:vcloud/core/api/odoo_session.dart';
import 'package:vcloud/core/api/odoo_session_store.dart';
import 'package:vcloud/core/error/failure.dart';
import 'package:vcloud/features/auth/application/auth_controller.dart';
import 'package:vcloud/features/chat_v2/application/chat_v2_channels_controller.dart';
import 'package:vcloud/features/chat_v2/application/chat_v2_inbox_controller.dart';
import 'package:vcloud/features/chat_v2/data/chat_v2_repository.dart';
import 'package:vcloud/features/chat_v2/data/models/chat_v2_channel.dart';
import 'package:vcloud/features/chat_v2/data/odoo_bus_service.dart';
import 'package:vcloud/features/chat_v2/presentation/screens/chat_v2_list_screen.dart';

class _FakeAuthController extends AuthController {
  @override
  Future<AuthUser?> build() async => const AuthUser(
        id: '2',
        email: 'tan@360.org.vn',
        userMetadata: {
          'name': 'Anh Tân',
          'partner_id': 3,
          'has_v_mobile': true,
          'db': 'vuahethong',
        },
      );
}

class _RecordedGetChannelsCall {
  const _RecordedGetChannelsCall({
    this.limit,
    this.offset,
    this.search,
    this.filter,
    this.showArchived = false,
    this.strictLimit = false,
    this.compact = false,
    this.withMeta = false,
    this.afterMsgId,
    this.since,
  });

  final int? limit;
  final int? offset;
  final String? search;
  final String? filter;
  final bool showArchived;
  final bool strictLimit;
  final bool compact;
  final bool withMeta;
  final int? afterMsgId;
  final String? since;
}

class _FakeChatV2Repository extends Fake implements ChatV2Repository {
  _FakeChatV2Repository(this.handler);

  final Future<List<ChatV2Channel>> Function(_RecordedGetChannelsCall call) handler;
  final List<_RecordedGetChannelsCall> calls = [];
  ChatV2ChannelsMeta? metaToExpose;

  @override
  ChatV2ChannelsMeta? get lastChannelsMeta => metaToExpose;

  @override
  Future<List<ChatV2Channel>> getChannels({
    int? limit,
    int? offset,
    String? search,
    String? filter,
    bool showArchived = false,
    bool strictLimit = false,
    bool compact = false,
    bool withMeta = false,
    int? afterMsgId,
    String? since,
  }) {
    final call = _RecordedGetChannelsCall(
      limit: limit,
      offset: offset,
      search: search,
      filter: filter,
      showArchived: showArchived,
      strictLimit: strictLimit,
      compact: compact,
      withMeta: withMeta,
      afterMsgId: afterMsgId,
      since: since,
    );
    calls.add(call);
    return handler(call);
  }
}

class _MemorySessionStore implements OdooSessionStore {
  OdooSession? _session = OdooSession(
    accessToken: 'test-jwt-token',
    uid: 2,
    partnerId: 3,
    db: 'vuahethong',
    login: 'tan@360.org.vn',
    expiresAt: DateTime.utc(2099, 1, 1),
    baseUrl: 'https://vuahethong.net',
  );

  @override
  Future<void> clear() async => _session = null;

  @override
  Future<OdooSession?> read() async => _session;

  @override
  Future<void> write(OdooSession session) async => _session = session;
}

class _FakeInboxController extends ChatV2InboxController {
  @override
  ChatV2InboxState build() => const ChatV2InboxState();
}

class _WidgetFakeChannelsNotifier extends ChatV2ChannelsNotifier {
  _WidgetFakeChannelsNotifier(
    this._channels, {
    bool hasMore = true,
    ChatV2ChannelsMeta? meta,
    this._fetchedCategories,
  })  : _mockHasMore = hasMore,
        _mockMeta = meta;

  final List<ChatV2Channel> _channels;
  final bool _mockHasMore;
  final ChatV2ChannelsMeta? _mockMeta;
  final List<String>? _fetchedCategories;

  @override
  bool get hasMore => _mockHasMore;

  @override
  ChatV2ChannelsMeta? get channelsMeta => _mockMeta;

  @override
  Future<List<ChatV2Channel>> build() async => _channels;

  @override
  Future<void> fetchCategoryChannels(String category) async {
    _fetchedCategories?.add(category);
  }
}

ChatV2Channel _makeChannel(
  int index, {
  required DateTime baseTime,
  String channelType = 'chat',
  bool isGroup = false,
  int unreadCount = 0,
}) {
  return ChatV2Channel(
    id: '$index',
    name: 'Kênh #$index',
    channelType: channelType,
    isGroup: isGroup,
    memberCount: isGroup ? 5 : 2,
    lastMessage: 'Tin nhắn mới nhất tại kênh #$index',
    lastMessageDate: baseTime.subtract(Duration(minutes: index)),
    unreadCount: unreadCount,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Pha 1 Fast Sync — 5 Kịch bản Kiểm Thử Độc Lập (SPEC v2.0 Mục 7)', () {
    setUp(() {
      ChatV2ChannelLocalCache.clear();
    });

    tearDown(() {
      ChatV2ChannelLocalCache.clear();
    });

    test('Kịch bản 1: Cache có 60 kênh -> mergeTop(20) có kênh #500 mới -> tổng 61 kênh, #500 lên #1 (sau ghim), giữ nguyên #21..#60', () async {
      final now = DateTime.utc(2026, 11, 25, 10, 0);
      final all60 = List<ChatV2Channel>.generate(
        60,
        (i) => _makeChannel(i + 1, baseTime: now),
      );
      final channel500 = ChatV2Channel(
        id: '500',
        name: 'Khách Zalo VIP #500',
        channelType: 'zalo_oa',
        isGroup: false,
        isZaloOAChannel: true,
        memberCount: 2,
        lastMessage: 'Em cần tư vấn gấp ạ!',
        lastMessageDate: now.add(const Duration(seconds: 30)),
        unreadCount: 1,
      );

      // Ghim kênh #10 để xác minh #500 nhảy lên #1 ngay sau kênh ghim
      ChatV2ChannelLocalCache.set(all60, fromServerFullList: true);
      ChatV2ChannelLocalCache.toggleUserPin('10');
      expect(ChatV2ChannelLocalCache.cached.length, 60);
      expect(ChatV2ChannelLocalCache.cached.first.id, '10');

      // Polling top 20 trả về kênh #500 + top 19 kênh đầu (#1..#19)
      final top20 = <ChatV2Channel>[
        channel500,
        ...all60.take(19),
      ];

      ChatV2ChannelLocalCache.set(
        top20,
        fromServerFullList: true,
        mergeWithExisting: true,
      );

      final result = ChatV2ChannelLocalCache.cached;
      expect(result.length, 61);
      expect(result[0].id, '10'); // Kênh ghim ở đầu
      expect(result[1].id, '500'); // Kênh #500 mới nhắn nhảy lên #1 sau ghim
      for (int id = 21; id <= 60; id++) {
        expect(result.any((c) => c.id == '$id'), isTrue, reason: 'Kênh #$id phải được giữ nguyên');
      }
    });

    test('Kịch bản 2: _serverLoadedCount độc lập với _pinnedDirectChannels -> 5 ghim local + 30 trang đầu => loadMore gọi offset: 30', () async {
      final now = DateTime.utc(2026, 11, 25, 10, 0);
      final page1 = List<ChatV2Channel>.generate(
        30,
        (i) => _makeChannel(i + 1, baseTime: now),
      );
      final page2 = List<ChatV2Channel>.generate(
        30,
        (i) => _makeChannel(i + 31, baseTime: now),
      );
      final channel500 = _makeChannel(
        500,
        baseTime: now.add(const Duration(minutes: 5)),
      );

      final fakeRepo = _FakeChatV2Repository((call) async {
        if (call.offset == 0 && !call.strictLimit) {
          return page1;
        }
        if (call.offset == 0 && call.strictLimit) {
          return <ChatV2Channel>[channel500, ...page1.take(19)];
        }
        if (call.offset == 30) {
          return page2;
        }
        return const <ChatV2Channel>[];
      });

      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(_FakeAuthController.new),
          chatV2RepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authControllerProvider.future);
      await container.read(chatV2ChannelsProvider.future);

      // Bổ sung 5 kênh direct ghim cục bộ vào _pinnedDirectChannels -> tổng cache = 35
      for (int p = 901; p <= 905; p++) {
        ChatV2ChannelLocalCache.pinDirectChannel(
          _makeChannel(p, baseTime: now.subtract(const Duration(days: 5))),
        );
      }
      expect(ChatV2ChannelLocalCache.cached.length, 35);

      final notifier = container.read(chatV2ChannelsProvider.notifier);
      expect(notifier.serverLoadedCount, 30);

      // loadMore() phải gọi đúng offset: 30, limit: 30 (không nhảy cóc lên 35)
      await notifier.loadMore();
      final loadMoreCall = fakeRepo.calls.last;
      expect(loadMoreCall.limit, kLoadMoreChannelsLimit);
      expect(loadMoreCall.offset, 30);
      expect(notifier.serverLoadedCount, 60);
      expect(ChatV2ChannelLocalCache.cached.length, 65);

      // Khi polling mergeTop(20) chèn thêm 1 kênh #500 mới chưa có -> _serverLoadedCount bù +1 thành 61
      await notifier.resumeRefresh();
      final pollCall = fakeRepo.calls.last;
      expect(pollCall.limit, kPollingChannelsLimit);
      expect(pollCall.strictLimit, isTrue);
      expect(pollCall.compact, isTrue);
      expect(notifier.serverLoadedCount, 61);
      expect(ChatV2ChannelLocalCache.cached.length, 66);
    });

    test('Kịch bản 3: Bấm Ghim / Tắt chuông kênh #55 cập nhật trực tiếp từ cache, giữ nguyên kênh #31..#60 và không gọi API refresh()', () async {
      final now = DateTime.utc(2026, 11, 25, 10, 0);
      final page1 = List<ChatV2Channel>.generate(30, (i) => _makeChannel(i + 1, baseTime: now));
      final page2 = List<ChatV2Channel>.generate(30, (i) => _makeChannel(i + 31, baseTime: now));

      final fakeRepo = _FakeChatV2Repository((call) async {
        if (call.offset == 30) return page2;
        return page1;
      });

      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(_FakeAuthController.new),
          chatV2RepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authControllerProvider.future);
      await container.read(chatV2ChannelsProvider.future);
      final notifier = container.read(chatV2ChannelsProvider.notifier);
      await notifier.loadMore();

      expect(container.read(chatV2ChannelsProvider).valueOrNull?.length, 60);
      final callsBefore = fakeRepo.calls.length;

      // Ghim và Tắt chuông kênh #55 giống thao tác context menu trong ChatV2ListScreen
      ChatV2ChannelLocalCache.toggleUserPin('55');
      notifier.syncFromCache();
      ChatV2ChannelLocalCache.setUserMuted('55', true);
      notifier.syncFromCache();

      final after = container.read(chatV2ChannelsProvider).valueOrNull!;
      expect(fakeRepo.calls.length, callsBefore, reason: 'Không được gọi refresh() lên server');
      expect(after.length, 60, reason: 'Không được làm mất các kênh #31..#60 đã cuộn');
      expect(after.first.id, '55');
      expect(after.first.isMuted, isTrue);
      for (int id = 31; id <= 60; id++) {
        expect(after.any((c) => c.id == '$id'), isTrue);
      }
    });

    test('Kịch bản 4: classifySyncError phân biệt chính xác offline / serverTimeout / serverError & Silent Retry giữ cache', () async {
      // 4a. classifySyncError mapping
      expect(
        classifySyncError(const SocketException('Failed host lookup')),
        ChatV2SyncStatus.offline,
      );
      expect(
        classifySyncError(const HandshakeException('Handshake failed')),
        ChatV2SyncStatus.offline,
      );
      expect(
        classifySyncError(Exception('Network is unreachable')),
        ChatV2SyncStatus.offline,
      );
      expect(
        classifySyncError(TimeoutException('Timed out')),
        ChatV2SyncStatus.serverTimeout,
      );
      expect(
        classifySyncError(Failure('Gateway timeout', statusCode: 504)),
        ChatV2SyncStatus.serverTimeout,
      );
      expect(
        classifySyncError(Failure('Request timeout', statusCode: 408)),
        ChatV2SyncStatus.serverTimeout,
      );
      expect(
        classifySyncError(Failure('Hết thời gian chờ phản hồi từ máy chủ (25s).')),
        ChatV2SyncStatus.serverTimeout,
      );
      expect(
        classifySyncError(Failure('Internal Server Error', statusCode: 500)),
        ChatV2SyncStatus.serverError,
      );
      expect(
        classifySyncError(Failure('Bad Gateway', statusCode: 502)),
        ChatV2SyncStatus.serverError,
      );
      expect(
        classifySyncError(Failure('Service Unavailable', statusCode: 503)),
        ChatV2SyncStatus.serverError,
      );
      expect(
        classifySyncError(Exception('{"error": "server_error"}')),
        ChatV2SyncStatus.serverError,
      );

      // 4b. Graceful Silent Retry khi đã có cache: không nháy banner vàng ở lần lỗi đầu tiên
      final now = DateTime.utc(2026, 11, 25, 10, 0);
      final initial = [_makeChannel(1, baseTime: now)];
      bool shouldFail = false;

      final fakeRepo = _FakeChatV2Repository((call) async {
        if (shouldFail) {
          throw Failure('Internal Server Error', statusCode: 500);
        }
        return initial;
      });

      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(_FakeAuthController.new),
          chatV2RepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authControllerProvider.future);
      await container.read(chatV2ChannelsProvider.future);
      expect(container.read(chatV2SyncStatusProvider), ChatV2SyncStatus.synced);

      shouldFail = true;
      await container.read(chatV2ChannelsProvider.notifier).resumeRefresh();

      // Đã có cache trong RAM -> lần retry đầu giữ nguyên trạng thái synced (không bật banner giả)
      expect(container.read(chatV2SyncStatusProvider), ChatV2SyncStatus.synced);
      expect(container.read(chatV2ChannelsProvider).valueOrNull?.length, 1);
    });

    test('Kịch bản 5: OdooBusService bắt mail.record/insert (Odoo 17 Message & Odoo 19 mail.message) + Adaptive Polling 25s / 12s', () async {
      final bus = OdooBusService();
      addTearDown(bus.dispose);

      final hints = <int?>[];
      final sub = bus.onChannelActivityHint.listen(hints.add);
      addTearDown(sub.cancel);

      // Odoo 17 format: mail.record/insert chứa 'Message'
      bus.processBusNotificationForTesting({
        'type': 'mail.record/insert',
        'payload': {
          'Message': [
            {
              'id': 8801,
              'model': 'discuss.channel',
              'res_id': 500,
            }
          ],
        },
      });

      // Odoo 19 format: mail.record/insert chứa 'mail.message'
      bus.processBusNotificationForTesting({
        'type': 'mail.record/insert',
        'payload': {
          'mail.message': [
            {
              'id': 9901,
              'thread': {'id': 501, 'model': 'discuss.channel'},
            }
          ],
        },
      });

      // Odoo 17/19 format: discuss.channel/new_message
      bus.processBusNotificationForTesting({
        'type': 'discuss.channel/new_message',
        'payload': {
          'id': 502,
          'message': {'id': 9902},
        },
      });

      await Future<void>.delayed(Duration.zero);
      expect(hints, [500, 501, 502]);

      // Adaptive polling interval
      expect(
        ChatV2ChannelsNotifier.pollIntervalForBus(isConnected: true),
        const Duration(seconds: 25),
      );
      expect(
        ChatV2ChannelsNotifier.pollIntervalForBus(isConnected: false),
        const Duration(seconds: 12),
      );
    });

    test('Kịch bản mở rộng: ChatV2Repository tương thích 100% List cũ & Map mới kèm meta, truyền đúng query params Pha 2', () async {
      final capturedUris = <Uri>[];
      final mockHttp = MockClient((request) async {
        capturedUris.add(request.url);
        return http.Response(
          jsonEncode({
            'channels': [
              {
                'id': 77,
                'name': 'Zalo OA Test',
                'channel_type': 'zalo_oa',
                'category': 'zalo_oa',
                'category_label': 'Zalo OA',
                'is_zalo_oa': true,
                'last_message_date': '2026-11-25 09:00:00',
              }
            ],
            'meta': {
              'total_count': 956,
              'unread_channels_count': 14,
              'category_counts': {
                'chat': 25,
                'channel': 12,
                'zalo_oa': 890,
              },
              'max_message_id': 1284920,
              'server_time': '2026-11-25T09:00:00Z',
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final client = OdooApiClient(
        baseUrl: 'https://vuahethong.net',
        httpClient: mockHttp,
        sessionStore: _MemorySessionStore(),
      );
      await client.restoreSession();
      final repo = ChatV2Repository(client);

      final channels = await repo.getChannels(
        limit: 20,
        offset: 0,
        filter: 'zalo_oa',
        strictLimit: true,
        compact: true,
        withMeta: true,
        afterMsgId: 1284900,
        since: '2026-11-25T08:59:00Z',
      );

      expect(channels.length, 1);
      expect(channels.first.id, '77');
      expect(repo.lastChannelsMeta?.totalCount, 956);
      expect(repo.lastChannelsMeta?.unreadChannelsCount, 14);
      expect(repo.lastChannelsMeta?.categoryCounts['zalo_oa'], 890);
      expect(repo.lastChannelsMeta?.maxMessageId, 1284920);

      final qp = capturedUris.single.queryParameters;
      expect(qp['limit'], '20');
      expect(qp['offset'], '0');
      expect(qp['filter'], 'zalo_oa');
      expect(qp['strict_limit'], '1');
      expect(qp['compact'], '1');
      expect(qp['with_meta'], '1');
      expect(qp['after_msg_id'], '1284900');
      expect(qp['since'], '2026-11-25T08:59:00Z');

      // Tương thích ngược List cũ
      final legacyParsed = ChatV2Repository.parseChannelsResponse([
        {'id': 88, 'name': 'Phòng Kỹ Thuật', 'channel_type': 'channel', 'is_group': true},
      ]);
      expect(legacyParsed.channels.length, 1);
      expect(legacyParsed.meta, isNull);
    });

    testWidgets('UI Banner 3 trạng thái & Chip Tất cả 30+ / tự động nạp danh mục < 15', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final now = DateTime.utc(2026, 11, 25, 10, 0);
      final channels30 = List<ChatV2Channel>.generate(30, (i) {
        if (i == 0) {
          return ChatV2Channel(
            id: '701',
            name: 'Zalo OA Khách Hàng',
            channelType: 'zalo_oa',
            category: 'zalo_oa',
            categoryLabel: 'Zalo OA',
            isZaloOAChannel: true,
            lastMessage: 'Xin chào',
            lastMessageDate: now,
          );
        }
        return _makeChannel(i + 1, baseTime: now);
      });

      final fetchedCats = <String>[];

      Widget buildListScreen(ChatV2SyncStatus status) {
        final router = GoRouter(
          initialLocation: '/chat',
          routes: [
            GoRoute(
              path: '/chat',
              builder: (_, _) => const ChatV2ListScreen(),
            ),
          ],
        );
        return ProviderScope(
          key: ValueKey<ChatV2SyncStatus>(status),
          overrides: [
            authControllerProvider.overrideWith(_FakeAuthController.new),
            chatV2ChannelsProvider.overrideWith(
              () => _WidgetFakeChannelsNotifier(
                channels30,
                hasMore: true,
                fetchedCategories: fetchedCats,
              ),
            ),
            chatV2TotalUnreadProvider.overrideWithValue(0),
            chatV2SyncStatusProvider.overrideWith((ref) => status),
            chatV2InboxControllerProvider.overrideWith(_FakeInboxController.new),
          ],
          child: MaterialApp.router(
            theme: ThemeData(splashFactory: NoSplash.splashFactory),
            routerConfig: router,
          ),
        );
      }

      // 1. Offline banner + chip Tất cả 30+ + tap chip Zalo OA (< 15 in RAM & hasMore)
      await tester.pumpWidget(buildListScreen(ChatV2SyncStatus.offline));
      await tester.pumpAndSettle();
      expect(find.text('Đang ngoại tuyến — Chạm để thử lại'), findsOneWidget);
      expect(find.text('30+'), findsOneWidget);

      await tester.tap(find.text('Zalo OA'));
      await tester.pumpAndSettle();
      expect(fetchedCats, contains('zalo_oa'));

      // 2. ServerTimeout banner
      await tester.pumpWidget(buildListScreen(ChatV2SyncStatus.serverTimeout));
      await tester.pumpAndSettle();
      expect(find.text('Máy chủ phản hồi chậm — Chạm để thử lại'), findsOneWidget);

      // 3. ServerError banner
      await tester.pumpWidget(buildListScreen(ChatV2SyncStatus.serverError));
      await tester.pumpAndSettle();
      expect(find.text('Máy chủ tạm gián đoạn — Chạm để thử lại'), findsOneWidget);
      expect(find.text('Hộp thư hệ thống'), findsOneWidget);

      // 4. Khi có meta.totalCount (956) -> Chip Tất cả hiển thị 956 thay vì 30+
      final routerMeta = GoRouter(
        initialLocation: '/chat',
        routes: [
          GoRoute(
            path: '/chat',
            builder: (_, _) => const ChatV2ListScreen(),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          key: const ValueKey<String>('with_meta_956'),
          overrides: [
            authControllerProvider.overrideWith(_FakeAuthController.new),
            chatV2ChannelsProvider.overrideWith(
              () => _WidgetFakeChannelsNotifier(
                channels30,
                hasMore: true,
                meta: const ChatV2ChannelsMeta(
                  totalCount: 956,
                  unreadChannelsCount: 14,
                  categoryCounts: {'chat': 25, 'zalo_oa': 890},
                ),
              ),
            ),
            chatV2TotalUnreadProvider.overrideWithValue(0),
            chatV2SyncStatusProvider.overrideWith((ref) => ChatV2SyncStatus.synced),
            chatV2InboxControllerProvider.overrideWith(_FakeInboxController.new),
          ],
          child: MaterialApp.router(
            theme: ThemeData(splashFactory: NoSplash.splashFactory),
            routerConfig: routerMeta,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('956'), findsOneWidget);
      expect(find.text('890'), findsOneWidget);
      expect(find.text('30+'), findsNothing);
    });

    test('ChatV2ChannelsNotifier.build() & refresh() dùng getChannelsWithMeta(withMeta: true) cập nhật channelsMeta', () async {
      final mockHttp = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'channels': [
              {
                'id': 1,
                'name': 'Administrators',
                'channel_type': 'channel',
                'is_group': true,
                'last_message_date': '2026-11-25 09:00:00',
              },
            ],
            'meta': {
              'total_count': 123,
              'unread_channels_count': 4,
              'category_counts': {'channel': 12, 'zalo': 111},
              'max_message_id': 9999,
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final client = OdooApiClient(
        baseUrl: 'https://vuahethong.net',
        httpClient: mockHttp,
        sessionStore: _MemorySessionStore(),
      );
      await client.restoreSession();
      final repo = ChatV2Repository(client);

      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(_FakeAuthController.new),
          chatV2RepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      await container.read(authControllerProvider.future);
      await container.read(chatV2ChannelsProvider.future);

      final notifier = container.read(chatV2ChannelsProvider.notifier);
      expect(notifier.channelsMeta?.totalCount, 123);
      expect(notifier.channelsMeta?.categoryCounts['zalo'], 111);

      await notifier.refresh();
      expect(notifier.channelsMeta?.totalCount, 123);
      expect(notifier.hasMore, isTrue);
    });
  });
}
