import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:vcloud/core/api/auth_user.dart';
import 'package:vcloud/features/auth/application/auth_controller.dart';
import 'package:vcloud/features/chat_v2/application/chat_v2_channels_controller.dart';
import 'package:vcloud/features/chat_v2/application/chat_v2_inbox_controller.dart';
import 'package:vcloud/features/chat_v2/application/chat_v2_messages_controller.dart';
import 'package:vcloud/features/chat_v2/data/chat_v2_repository.dart';
import 'package:vcloud/features/chat_v2/data/models/chat_v2_channel.dart';
import 'package:vcloud/features/chat_v2/data/models/chat_v2_message.dart';
import 'package:vcloud/features/chat_v2/presentation/screens/chat_v2_detail_screen.dart';
import 'package:vcloud/features/chat_v2/presentation/screens/chat_v2_list_screen.dart';
import 'package:vcloud/features/chat_v2/presentation/widgets/chat_v2_input_bar.dart';
import 'package:vcloud/shared/widgets/app_scaffold.dart';

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

  group('BUG-17: Voice Call AppBar Button & Star Message Menu', () {
    testWidgets(
      'shows phone call icon on 1-1 chat and allows starring a message in long-press sheet',
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

        // Phone call button visible in AppBar
        expect(find.byIcon(LucideIcons.phone), findsOneWidget);

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
}
