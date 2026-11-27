import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:vcloud/core/api/auth_user.dart';
import 'package:vcloud/core/api/odoo_api_client.dart';
import 'package:vcloud/core/api/odoo_session.dart';
import 'package:vcloud/core/api/odoo_session_store.dart';
import 'package:vcloud/core/error/failure.dart';
import 'package:vcloud/features/auth/application/auth_controller.dart';
import 'package:vcloud/features/chat_v2/application/chat_v2_channels_controller.dart';
import 'package:vcloud/features/chat_v2/application/chat_v2_inbox_controller.dart';
import 'package:vcloud/features/chat_v2/application/chat_v2_messages_controller.dart';
import 'package:vcloud/features/chat_v2/data/chat_v2_repository.dart';
import 'package:vcloud/features/chat_v2/data/models/chat_v2_channel.dart';
import 'package:vcloud/features/chat_v2/data/models/chat_v2_message.dart';
import 'package:vcloud/features/chat_v2/presentation/screens/chat_v2_detail_screen.dart';
import 'package:vcloud/features/chat_v2/presentation/screens/chat_v2_list_screen.dart';
import 'package:vcloud/features/chat_v2/presentation/widgets/chat_v2_info_sheet.dart';
import 'package:vcloud/features/chat_v2/presentation/widgets/chat_v2_input_bar.dart';
import 'package:vcloud/features/chat_v2/presentation/widgets/chat_v2_message_item.dart';
import 'package:vcloud/shared/widgets/app_scaffold.dart';

class _MemorySessionStore extends OdooSessionStore {
  _MemorySessionStore(this._session);

  final OdooSession _session;

  @override
  Future<OdooSession?> read() async => _session;
}

class _NotFoundOdooApiClient extends OdooApiClient {
  _NotFoundOdooApiClient() : super(baseUrl: 'http://192.168.1.100:1900');

  int getCallCount = 0;

  @override
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? query,
    bool auth = true,
  }) async {
    getCallCount++;
    throw Failure('Channel 665793 not found', statusCode: 404);
  }
}

class _FakeAuthController extends AuthController {
  @override
  Future<AuthUser?> build() async => const AuthUser(
        id: '2',
        email: 'tan@360.org.vn',
        userMetadata: {
          'name': 'Nguyễn Nhật Tân',
          'partner_id': 3,
          'is_portal': false,
          'has_v_mobile': true,
          'db': 'vuahethong',
        },
      );
}

class _FakeChatRepo implements ChatV2Repository {
  final List<({String? filter, int limit, int offset})> channelCalls = [];
  final List<({int messageId, bool? star})> starCalls = [];
  List<ChatV2Channel> initialChannels = const [];
  List<ChatV2Channel> categoryChannels = const [];
  ChatV2ChannelsMeta? meta;

  @override
  ChatV2ChannelsMeta? get lastChannelsMeta => meta;

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
  }) async {
    channelCalls.add((
      filter: filter,
      limit: limit ?? 20,
      offset: offset ?? 0,
    ));
    if (filter != null && filter.isNotEmpty) {
      return categoryChannels;
    }
    return initialChannels;
  }

  @override
  Future<ChatV2ChannelsPageResult> getChannelsWithMeta({
    int? limit,
    int? offset,
    String? search,
    String? filter,
    bool showArchived = false,
    bool strictLimit = false,
    bool compact = false,
    bool withMeta = true,
    int? afterMsgId,
    String? since,
  }) async {
    channelCalls.add((
      filter: filter,
      limit: limit ?? 20,
      offset: offset ?? 0,
    ));
    return ChatV2ChannelsPageResult(
      channels: initialChannels,
      meta: meta,
    );
  }

  @override
  Future<bool> toggleStarMessage(int messageId, {bool? star}) async {
    starCalls.add((messageId: messageId, star: star));
    return star ?? true;
  }

  @override
  Future<List<ChatV2Message>> getMessages(
    String channelId, {
    int limit = 30,
    String? beforeId,
    String? currentPartnerId,
    String? currentUserId,
  }) async =>
      const [];

  @override
  Future<List<ChatV2Message>> getPinnedMessages(
    String channelId, {
    String? currentPartnerId,
    String? currentUserId,
  }) async =>
      const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeListChannelsNotifier extends ChatV2ChannelsNotifier {
  _FakeListChannelsNotifier(this._channels, this._meta);

  final List<ChatV2Channel> _channels;
  final ChatV2ChannelsMeta? _meta;
  final List<String> fetchedCategories = [];
  final Set<String> _fetchedSet = {};

  @override
  bool get hasMore => false;

  @override
  ChatV2ChannelsMeta? get channelsMeta => _meta;

  @override
  bool isCategoryFetched(String category) => _fetchedSet.contains(category);

  @override
  Future<void> fetchCategoryChannels(String category) async {
    _fetchedSet.add(category);
    fetchedCategories.add(category);
  }

  @override
  Future<List<ChatV2Channel>> build() async => _channels;
}

class _FakeDetailMessagesNotifier extends ChatV2MessagesNotifier {
  _FakeDetailMessagesNotifier(this._msgs);
  final List<ChatV2Message> _msgs;

  @override
  FutureOr<List<ChatV2Message>> build(String arg) async => _msgs;
}

class _FakeInboxNotifier extends ChatV2InboxController {
  @override
  ChatV2InboxState build() => const ChatV2InboxState(isLoading: false);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    ChatV2ChannelLocalCache.clear();
  });

  group('BUG-01 & BUG-02: Channel Classification, Hash Icon & Filter Chips', () {
    test('internal channel with "zalo" in name is NOT misclassified as Zalo', () {
      final internalGroup = ChatV2Channel.fromJson({
        'id': 501,
        'name': 'Team Zalo Nội Bộ',
        'channel_type': 'group',
        'is_group': true,
        'member_count': 4,
      });

      expect(internalGroup.isZaloChannel, isFalse);
      expect(internalGroup.isZaloOA, isFalse);
      expect(internalGroup.isZaloPersonal, isFalse);
      expect(internalGroup.effectiveCategory, 'channel');

      final zaloOA = ChatV2Channel.fromJson({
        'id': 502,
        'name': '360 CORP · Chị Hoa',
        'channel_type': 'group',
        'is_zalo_channel': true,
        'zalo_user_id': '9988',
      });
      expect(zaloOA.isZaloPersonal, isFalse);
      expect(zaloOA.isZaloOA, isTrue);
      expect(zaloOA.effectiveCategory, 'zalo_oa');

      final zaloPersonal = ChatV2Channel.fromJson({
        'id': 503,
        'name': 'Khách hàng Anh Minh',
        'channel_type': 'zalo_personal',
        'is_zalo_personal': true,
      });
      expect(zaloPersonal.isZaloPersonal, isTrue);
      expect(zaloPersonal.isZaloOA, isFalse);
      expect(zaloPersonal.effectiveCategory, 'zalo');
    });

    testWidgets(
      'ChatV2ListScreen shows # icon for channel, hides ai_chat, orders zalo before zalo_oa, and triggers fetchCategoryChannels even when hasMore==false',
      (tester) async {
        final channels = [
          const ChatV2Channel(
            id: '1',
            name: 'Administrators',
            channelType: 'channel',
            isGroup: true,
          ),
          const ChatV2Channel(
            id: '2',
            name: 'Zalo Personal',
            channelType: 'zalo_personal',
            category: 'zalo',
            isZaloPersonalChannel: true,
          ),
          const ChatV2Channel(
            id: '3',
            name: 'Zalo OA Support',
            channelType: 'zalo_oa',
            category: 'zalo_oa',
            isZaloOAChannel: true,
          ),
          const ChatV2Channel(
            id: '4',
            name: 'Ask AI Session 12',
            channelType: 'ai_chat',
            category: 'ai_chat',
          ),
        ];

        const meta = ChatV2ChannelsMeta(
          totalCount: 3,
          unreadChannelsCount: 0,
          categoryCounts: {
            'chat': 0,
            'channel': 1,
            'zalo': 1,
            'zalo_oa': 5,
            'ai_chat': 12,
          },
        );
        final notifier = _FakeListChannelsNotifier(channels, meta);
        final router = GoRouter(
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
            overrides: [
              authControllerProvider.overrideWith(_FakeAuthController.new),
              chatV2ChannelsProvider.overrideWith(() => notifier),
              chatV2TotalUnreadProvider.overrideWithValue(0),
              chatV2SyncStatusProvider
                  .overrideWith((ref) => ChatV2SyncStatus.synced),
              chatV2InboxControllerProvider.overrideWith(_FakeInboxNotifier.new),
            ],
            child: MaterialApp.router(
              theme: ThemeData(splashFactory: NoSplash.splashFactory),
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // BUG-01: Channel fallback uses # icon (size 22 in avatar) instead of letter 'A'
        expect(
          find.byWidgetPredicate(
            (w) => w is Icon && w.icon == LucideIcons.hash && w.size == 22,
          ),
          findsOneWidget,
        );
        expect(find.text('A'), findsNothing);
        expect(find.text('Administrators'), findsOneWidget);

        // BUG-02: ai_chat channel and chip are completely hidden
        expect(find.text('Ask AI Session 12'), findsNothing);
        expect(find.text('ai_chat'), findsNothing);
        expect(find.text('Ai Chat'), findsNothing);

        // BUG-02: 'Zalo' chip appears to the left of 'Zalo OA' chip
        final zaloRect = tester.getRect(find.text('Zalo'));
        final zaloOaRect = tester.getRect(find.text('Zalo OA'));
        expect(zaloRect.left, lessThan(zaloOaRect.left));

        // BUG-21: Tapping Zalo OA chip triggers fetchCategoryChannels even when hasMore == false
        // because inRamCount (1) < meta.categoryCounts['zalo_oa'] (5)
        final zaloOaChip = find.text('Zalo OA');
        await tester.ensureVisible(zaloOaChip);
        await tester.pumpAndSettle();
        await tester.tap(zaloOaChip);
        await tester.pump();
        expect(notifier.fetchedCategories, ['zalo_oa']);
      },
    );

    testWidgets(
      'UserAvatar renders without scheduling retry timers on broken URL',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: UserAvatar(
                userId: '99',
                displayName: 'Test User',
                avatarUrl: 'https://invalid.example.local/broken.png',
                size: 40,
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.byType(UserAvatar), findsOneWidget);
      },
    );
  });

  group('BUG-21: ChatV2ChannelsNotifier Category Fetch Tracking', () {
    test('fetches limit=50 once per category and resets on refresh', () async {
      final repo = _FakeChatRepo()
        ..initialChannels = [
          const ChatV2Channel(id: '1', name: 'General', channelType: 'channel'),
        ]
        ..categoryChannels = [
          const ChatV2Channel(
            id: '2',
            name: 'Zalo OA 1',
            channelType: 'zalo_oa',
            category: 'zalo_oa',
            isZaloOAChannel: true,
          ),
        ];

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

      expect(notifier.isCategoryFetched('zalo_oa'), isFalse);
      await notifier.fetchCategoryChannels('zalo_oa');
      expect(notifier.isCategoryFetched('zalo_oa'), isTrue);
      expect(
        repo.channelCalls.where((c) => c.filter == 'zalo_oa').single.limit,
        50,
      );

      // Duplicate call is suppressed
      await notifier.fetchCategoryChannels('zalo_oa');
      expect(repo.channelCalls.where((c) => c.filter == 'zalo_oa').length, 1);

      // Refresh clears _fetchedCategories
      await notifier.refresh();
      expect(notifier.isCategoryFetched('zalo_oa'), isFalse);
    });
  });

  group('BUG-17: Voice Call AppBar Button Hidden & Star Message Menu', () {
    testWidgets(
      'hides phone call icon on 1-1 chat and allows starring a message in long-press sheet',
      (tester) async {
        final fakeRepo = _FakeChatRepo();
        const directChannel = ChatV2Channel(
          id: '77',
          name: 'Lê Bá Châu',
          channelType: 'chat',
          isGroup: false,
          directPartnerId: '55',
          directPartnerName: 'Lê Bá Châu',
        );
        final msg = ChatV2Message(
          id: '4567',
          channelId: '77',
          content: 'Tin nhắn cần gắn sao',
          authorId: '55',
          authorName: 'Lê Bá Châu',
          createdAt: DateTime(2026, 11, 26, 9, 0),
          isMine: false,
        );

        final router = GoRouter(
          initialLocation: '/chat/77',
          routes: [
            GoRoute(
              path: '/chat',
              builder: (_, _) => const SizedBox.shrink(),
            ),
            GoRoute(
              path: '/chat/77',
              builder: (_, _) => const ChatV2DetailScreen(
                channelId: '77',
                title: 'Lê Bá Châu',
              ),
            ),
          ],
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authControllerProvider.overrideWith(_FakeAuthController.new),
              chatV2RepositoryProvider.overrideWithValue(fakeRepo),
              chatV2ChannelsProvider.overrideWith(
                () => _FakeListChannelsNotifier([directChannel], null),
              ),
              chatV2MessagesProvider.overrideWith(
                () => _FakeDetailMessagesNotifier([msg]),
              ),
              chatV2InboxControllerProvider.overrideWith(_FakeInboxNotifier.new),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();

        // Phone call button remains hidden in AppBar (unfinished call feature)
        expect(find.byIcon(LucideIcons.phone), findsNothing);

        // Long-press message opens sheet with Gắn sao
        await tester.longPress(find.text('Tin nhắn cần gắn sao'));
        await tester.pumpAndSettle();

        expect(find.text('Gắn sao'), findsOneWidget);
        expect(find.byIcon(LucideIcons.star), findsOneWidget);

        await tester.tap(find.text('Gắn sao'));
        await tester.pumpAndSettle();

        expect(fakeRepo.starCalls.length, 1);
        expect(fakeRepo.starCalls.single.messageId, 4567);
        expect(find.text('Đã gắn sao tin nhắn'), findsOneWidget);
      },
    );

    testWidgets('hides phone call icon on public discussion channel', (tester) async {
      const publicChannel = ChatV2Channel(
        id: '88',
        name: 'Kênh Chung',
        channelType: 'channel',
        isGroup: true,
      );

      final router = GoRouter(
        initialLocation: '/chat/88',
        routes: [
          GoRoute(
            path: '/chat/88',
            builder: (_, _) => const ChatV2DetailScreen(
              channelId: '88',
              title: 'Kênh Chung',
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(_FakeAuthController.new),
            chatV2RepositoryProvider.overrideWithValue(_FakeChatRepo()),
            chatV2ChannelsProvider.overrideWith(
              () => _FakeListChannelsNotifier([publicChannel], null),
            ),
            chatV2MessagesProvider.overrideWith(
              () => _FakeDetailMessagesNotifier(const []),
            ),
            chatV2InboxControllerProvider.overrideWith(_FakeInboxNotifier.new),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(LucideIcons.phone), findsNothing);
    });
  });

  group('BUG-18: @ticket Command Suggestion with Empty channelMembers', () {
    testWidgets('shows @ticket suggestion when typing @ even if channelMembers is empty', (tester) async {
      final controller = TextEditingController();
      final focusNode = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focusNode.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: ChatV2InputBar(
                controller: controller,
                focusNode: focusNode,
                isSending: false,
                channelId: '77',
                channelMembers: const [],
                onSend: (text, {mentionedPartners, partnerIds}) async {},
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byType(TextField));
      await tester.pump();
      await tester.enterText(find.byType(TextField), '@');
      await tester.pump();

      expect(find.text('@ticket (Tạo phiếu hỗ trợ)'), findsOneWidget);
      expect(find.text('Gõ @ticket [tiêu đề] rồi gửi để tạo ticket'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '@tic');
      await tester.pump();
      expect(find.text('@ticket (Tạo phiếu hỗ trợ)'), findsOneWidget);
    });
  });

  group('BUG-22: Avatar URL Normalization, CDN Guard & Ghost Cache Eviction', () {
    test('resolveAvatarUrl rewrites /web/image and plural aliases and protects external CDNs', () async {
      final session = OdooSession(
        accessToken: 'jwt_tok_abc',
        uid: 2,
        db: 'vcloud_test_v19',
        login: 'tan@360.org.vn',
        expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)),
        baseUrl: 'http://192.168.1.100:1900',
      );
      final client = OdooApiClient(
        baseUrl: 'http://192.168.1.100:1900',
        sessionStore: _MemorySessionStore(session),
      );
      await client.restoreSession();

      // Rewrites /web/image/<model>/<id>/<field?>
      expect(
        client.resolveAvatarUrl('/web/image/res.users/12/avatar_128'),
        'http://192.168.1.100:1900/api/v1/mobile/avatar/res.users/12?field=avatar_128&access_token=jwt_tok_abc&db=vcloud_test_v19',
      );
      expect(
        client.resolveAvatarUrl('/web/image/res.partner/3'),
        'http://192.168.1.100:1900/api/v1/mobile/avatar/res.partner/3?field=avatar_128&access_token=jwt_tok_abc&db=vcloud_test_v19',
      );
      expect(
        client.resolveAvatarUrl('/web/image/discuss.channel/99/image_128'),
        'http://192.168.1.100:1900/api/v1/mobile/avatar/discuss.channel/99?field=image_128&access_token=jwt_tok_abc&db=vcloud_test_v19',
      );
      expect(
        client.resolveAvatarUrl('/web/image/im_livechat.channel/4'),
        'http://192.168.1.100:1900/api/v1/mobile/avatar/im_livechat.channel/4?field=avatar_128&access_token=jwt_tok_abc&db=vcloud_test_v19',
      );

      // Rewrites plural aliases /api/v1/mobile/avatar/(partners|users|channels)/<id>
      expect(
        client.resolveAvatarUrl('/api/v1/mobile/avatar/partners/3/avatar_128'),
        'http://192.168.1.100:1900/api/v1/mobile/avatar/res.partner/3?field=avatar_128&access_token=jwt_tok_abc&db=vcloud_test_v19',
      );
      expect(
        client.resolveAvatarUrl('/api/v1/mobile/avatar/users/7'),
        'http://192.168.1.100:1900/api/v1/mobile/avatar/res.users/7?field=avatar_128&access_token=jwt_tok_abc&db=vcloud_test_v19',
      );
      expect(
        client.resolveAvatarUrl('/api/v1/mobile/avatar/channels/88/image_128'),
        'http://192.168.1.100:1900/api/v1/mobile/avatar/discuss.channel/88?field=image_128&access_token=jwt_tok_abc&db=vcloud_test_v19',
      );

      // External CDN (Zalo zadn.vn) never receives access_token, db, or authHeaders
      const zadnUrl = 'https://s120-ava-talk.zadn.vn/6/b/2/3/1/120/avatar.jpg';
      expect(client.authenticatedUrl(zadnUrl), zadnUrl);
      expect(client.resolveAvatarUrl(zadnUrl), zadnUrl);
      expect(client.headersForUrl(zadnUrl), isNull);

      // Relative and same-host URLs receive authHeaders
      expect(
        client.headersForUrl('/api/v1/mobile/avatar/res.partner/3?field=avatar_128'),
        isNotNull,
      );
      expect(
        client.headersForUrl('http://192.168.1.100:1900/api/v1/mobile/avatar/res.partner/3'),
        containsPair('Authorization', 'Bearer jwt_tok_abc'),
      );
    });

    test('ChatV2ChannelLocalCache scopes by baseUrl+db+uid and getMessages 404 removes ghost channel', () async {
      ChatV2ChannelLocalCache.clear();
      await ChatV2ChannelLocalCache.init(
        baseUrl: 'https://vuahethong.net',
        db: 'vuahethong',
        userId: '2',
      );
      const ghostChannel = ChatV2Channel(
        id: '665793',
        name: 'Demo User',
        channelType: 'chat',
        isGroup: false,
      );
      ChatV2ChannelLocalCache.pinDirectChannel(ghostChannel);
      ChatV2ChannelLocalCache.set([ghostChannel]);
      expect(ChatV2ChannelLocalCache.cached.map((c) => c.id), contains('665793'));

      // Switching baseUrl even with same db+uid produces a new scope and clears stale channels
      await ChatV2ChannelLocalCache.init(
        baseUrl: 'http://192.168.1.100:1900',
        db: 'vuahethong',
        userId: '2',
      );
      expect(ChatV2ChannelLocalCache.cached, isEmpty);
      expect(ChatV2ChannelLocalCache.getPinnedDirectChannel('665793'), isNull);

      // Simulating a ghost channel left in the active scope: 404 in getMessages removes it
      ChatV2ChannelLocalCache.pinDirectChannel(ghostChannel);
      ChatV2ChannelLocalCache.set([ghostChannel]);
      expect(ChatV2ChannelLocalCache.cached.map((c) => c.id), contains('665793'));

      final fake404Client = _NotFoundOdooApiClient();
      final repo = ChatV2Repository(fake404Client);
      final msgs = await repo.getMessages('665793');
      expect(msgs, isEmpty);
      expect(fake404Client.getCallCount, 1);
      expect(ChatV2ChannelLocalCache.cached.map((c) => c.id), isNot(contains('665793')));
      expect(ChatV2ChannelLocalCache.getPinnedDirectChannel('665793'), isNull);
    });

    testWidgets('ChatV2DetailScreen AppBar shows # for channel and users icon for group without voice call icon', (tester) async {
      const publicChannel = ChatV2Channel(
        id: '88',
        name: 'General',
        channelType: 'channel',
        isGroup: true,
      );
      const groupChannel = ChatV2Channel(
        id: '89',
        name: 'Dev Team',
        channelType: 'group',
        isGroup: true,
        memberCount: 4,
      );

      final router = GoRouter(
        initialLocation: '/chat/88',
        routes: [
          GoRoute(
            path: '/chat/88',
            builder: (_, _) => const ChatV2DetailScreen(
              channelId: '88',
              title: 'General',
            ),
          ),
          GoRoute(
            path: '/chat/89',
            builder: (_, _) => const ChatV2DetailScreen(
              channelId: '89',
              title: 'Dev Team',
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(_FakeAuthController.new),
            chatV2RepositoryProvider.overrideWithValue(_FakeChatRepo()),
            chatV2ChannelsProvider.overrideWith(
              () => _FakeListChannelsNotifier([publicChannel, groupChannel], null),
            ),
            chatV2MessagesProvider.overrideWith(
              () => _FakeDetailMessagesNotifier(const []),
            ),
            chatV2InboxControllerProvider.overrideWith(_FakeInboxNotifier.new),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
          (w) => w is Icon && w.icon == LucideIcons.hash && w.size == 20,
        ),
        findsOneWidget,
      );
      expect(find.byIcon(LucideIcons.phone), findsNothing);

      router.go('/chat/89');
      await tester.pumpAndSettle();

      expect(
        find.byWidgetPredicate(
          (w) => w is Icon && w.icon == LucideIcons.users && w.size == 18,
        ),
        findsOneWidget,
      );
      expect(find.byIcon(LucideIcons.phone), findsNothing);
    });
  });

  group('BUG-23: Opaque Backing on Transparent PNG Avatars', () {
    testWidgets(
      'UserAvatar and ChatV2ListScreen avatar frameBuilder wrap loaded frame in opaque ColoredBox and hide unloaded frame',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: UserAvatar(
                userId: '10',
                displayName: 'Internal',
                avatarUrl: '/api/v1/mobile/avatar/discuss.channel/4253?field=image_128',
                size: 40,
              ),
            ),
          ),
        );
        await tester.pump();

        final imgWidget = tester.widget<Image>(find.byType(Image));
        expect(imgWidget.frameBuilder, isNotNull);

        final ctx = tester.element(find.byType(UserAvatar));
        final unloaded = imgWidget.frameBuilder!(ctx, const SizedBox(), null, false);
        expect(unloaded, isA<SizedBox>());

        final loaded = imgWidget.frameBuilder!(ctx, const SizedBox(key: ValueKey('png')), 0, false);
        expect(loaded, isA<ColoredBox>());
        expect((loaded as ColoredBox).color, Colors.white);
      },
    );
  });

  group('BUG-24 & BUG-25: Media Extraction, Remote Priority & Attachment DB Params', () {
    test('extractMedia skips filename-only messages without memory bytes and never uses msg.id as attachment id', () {
      const msgNoBytes = ChatV2Message(
        id: '999001',
        channelId: '4253',
        content: 'photo_from_history.jpg',
        authorId: '3',
        authorName: 'User',
        isMine: false,
      );
      final emptyRes = ChatV2InfoSheet.extractMedia(const [msgNoBytes]);
      expect(emptyRes.images, isEmpty);

      final fakeBytes = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xE0]);
      ChatV2AttachmentImage.cacheBytes('cached_photo.jpg', fakeBytes);
      const msgWithBytes = ChatV2Message(
        id: '999002',
        channelId: '4253',
        content: 'cached_photo.jpg',
        authorId: '3',
        authorName: 'User',
        isMine: false,
      );
      final cachedRes = ChatV2InfoSheet.extractMedia(const [msgWithBytes]);
      expect(cachedRes.images.length, 1);
      expect(cachedRes.images.single.id, '');
      expect(cachedRes.images.single.messageId, '999002');
      expect(cachedRes.images.single.bytes, fakeBytes);
    });

    test('mergeRemoteAttachments puts canonical remote attachments first and preserves unsynced local bytes', () {
      final unsyncedLocal = ChatV2Attachment(
        id: '',
        name: 'pending_upload.jpg',
        mimetype: 'image/jpeg',
        bytes: Uint8List.fromList([1, 2, 3]),
        messageId: 'temp_1',
      );
      const staleFilenameOnly = ChatV2Attachment(
        id: '999001',
        name: 'broken.jpg',
        mimetype: 'image/jpeg',
      );
      const remoteValid = ChatV2Attachment(
        id: '93786',
        name: 'valid_server.png',
        mimetype: 'image/png',
        accessToken: 'tok_93786',
      );

      final merged = ChatV2InfoSheet.mergeRemoteAttachments(
        local: [staleFilenameOnly, unsyncedLocal],
        remote: [remoteValid],
      );
      expect(merged.map((a) => a.name).toList(), ['pending_upload.jpg', 'valid_server.png']);
    });

    test('ChatV2Attachment.resolveFullUrl preserves attachment access_token and appends db', () {
      const att = ChatV2Attachment(
        id: '93786',
        name: 'chart.png',
        mimetype: 'image/png',
        accessToken: 'att_secret_token',
      );
      final resolved = att.resolveFullUrl(
        'http://192.168.1.100:1900/',
        db: 'vcloud_test_v19',
      );
      expect(resolved, contains('/api/v1/mobile/attachments/93786/image'));
      expect(resolved, contains('access_token=att_secret_token'));
      expect(resolved, contains('db=vcloud_test_v19'));
    });
  });

  group('BUG-27: Dynamic Available Categories & Zero-Count Chips', () {
    test('ChatV2ChannelsMeta parses available_categories & category_labels, excludes ai_chat, and merges safely', () {
      final fullMeta = ChatV2ChannelsMeta.fromMap({
        'total_count': 1266,
        'unread_channels_count': 2,
        'category_counts': {
          'chat': 30,
          'channel': 49,
          'zalo': 0,
          'zalo_oa': 1187,
          'livechat': 0,
        },
        'available_categories': ['chat', 'channel', 'zalo', 'zalo_oa', 'livechat', 'ai_chat'],
        'category_labels': {
          'chat': 'Trò chuyện',
          'channel': 'Kênh',
          'zalo': 'Zalo',
          'zalo_oa': 'Zalo OA',
          'livechat': 'Hỗ trợ',
          'ai_chat': 'AI',
        },
      });

      expect(
        fullMeta.availableCategories,
        ['chat', 'channel', 'zalo', 'zalo_oa', 'livechat'],
      );
      expect(fullMeta.categoryLabels['zalo'], 'Zalo');
      expect(fullMeta.categoryLabels['livechat'], 'Hỗ trợ');
      expect(fullMeta.categoryLabels.containsKey('ai_chat'), isFalse);

      final compactMeta = ChatV2ChannelsMeta.fromMap({
        'total_count': 1266,
        'unread_channels_count': 3,
      });
      final merged = compactMeta.mergeFrom(fullMeta);
      expect(
        merged.availableCategories,
        ['chat', 'channel', 'zalo', 'zalo_oa', 'livechat'],
      );
      expect(merged.categoryLabels['zalo'], 'Zalo');
      expect(merged.unreadChannelsCount, 3);
    });

    testWidgets('ChatV2ListScreen renders installed zalo and livechat chips even when count == 0 without extra fetch', (tester) async {
      const channels = [
        ChatV2Channel(
          id: '1',
          name: 'Administrators',
          channelType: 'channel',
          isGroup: true,
        ),
        ChatV2Channel(
          id: '2',
          name: 'Zalo OA Support',
          channelType: 'zalo_oa',
          category: 'zalo_oa',
          isZaloOAChannel: true,
        ),
      ];
      const meta = ChatV2ChannelsMeta(
        totalCount: 2,
        unreadChannelsCount: 0,
        categoryCounts: {
          'chat': 0,
          'channel': 1,
          'zalo': 0,
          'zalo_oa': 1,
          'livechat': 0,
        },
        availableCategories: ['chat', 'channel', 'zalo', 'zalo_oa', 'livechat'],
        categoryLabels: {
          'chat': 'Trò chuyện',
          'channel': 'Kênh',
          'zalo': 'Zalo',
          'zalo_oa': 'Zalo OA',
          'livechat': 'Hỗ trợ',
        },
      );

      final notifier = _FakeListChannelsNotifier(channels, meta);
      final router = GoRouter(
        initialLocation: '/chat',
        routes: [
          GoRoute(path: '/chat', builder: (_, _) => const ChatV2ListScreen()),
          GoRoute(path: '/chat/:id', builder: (_, _) => const SizedBox.shrink()),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(_FakeAuthController.new),
            chatV2ChannelsProvider.overrideWith(() => notifier),
            chatV2TotalUnreadProvider.overrideWithValue(0),
            chatV2SyncStatusProvider.overrideWith((ref) => ChatV2SyncStatus.synced),
            chatV2InboxControllerProvider.overrideWith(_FakeInboxNotifier.new),
          ],
          child: MaterialApp.router(
            theme: ThemeData(splashFactory: NoSplash.splashFactory),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Both zero-count installed categories must appear
      expect(find.text('Zalo'), findsOneWidget);
      expect(find.text('Hỗ trợ'), findsOneWidget);
      expect(
        tester.getRect(find.text('Zalo')).left,
        lessThan(tester.getRect(find.text('Zalo OA')).left),
      );

      // Tapping Zalo (count == 0) selects filter cleanly without firing unnecessary fetchCategoryChannels
      await tester.ensureVisible(find.text('Zalo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Zalo'));
      await tester.pumpAndSettle();
      expect(notifier.fetchedCategories, isEmpty);
    });
  });
}
