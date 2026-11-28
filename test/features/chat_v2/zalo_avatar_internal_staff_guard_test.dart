import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:vcloud/core/api/auth_user.dart';
import 'package:vcloud/features/auth/application/auth_controller.dart';
import 'package:vcloud/features/chat_v2/application/chat_v2_channels_controller.dart';
import 'package:vcloud/features/chat_v2/application/chat_v2_inbox_controller.dart';
import 'package:vcloud/features/chat_v2/data/chat_v2_repository.dart';
import 'package:vcloud/features/chat_v2/data/models/chat_v2_channel.dart';
import 'package:vcloud/features/chat_v2/presentation/screens/chat_v2_list_screen.dart';

class _FakeAuthController extends AuthController {
  @override
  Future<AuthUser?> build() async => const AuthUser(
        id: '3514',
        email: 'tanmnn@360.org.vn',
        userMetadata: {
          'name': 'Ma Nguyễn Nhật Tân',
          'partner_id': 6713,
          'is_portal': false,
          'has_v_mobile': true,
          'db': 'vuahethong',
        },
      );
}

class _FakeChannelsNotifier extends ChatV2ChannelsNotifier {
  _FakeChannelsNotifier(this._channels);

  final List<ChatV2Channel> _channels;

  @override
  bool get hasMore => false;

  @override
  ChatV2ChannelsMeta? get channelsMeta => null;

  @override
  bool isCategoryFetched(String category) => true;

  @override
  Future<void> fetchCategoryChannels(String category) async {}

  @override
  Future<List<ChatV2Channel>> build() async => _channels;
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

  group('Zalo OA Avatar Internal Staff Guard (BUG-28)', () {
    test('does NOT resolve internal staff partner_id=3 (Chau, Le Ba) on Zalo OA channels', () {
      final payloads = <Map<String, dynamic>>[
        {
          'id': 739110,
          'name': '360 CORP (+84 836 360 360) · Anh Khang Vitamin House',
          'channel_type': 'group',
          'avatar_url': null,
          'direct_partner': null,
          'partner_id': 3,
          'is_zalo_channel': false,
          'members': [
            {
              'id': 3,
              'name': 'Chau, Le Ba',
              'email': 'admin@vuahethong.net',
              'avatar_url': '/api/v1/mobile/avatar/res.partner/3?field=avatar_128',
              'is_me': false,
            },
            {
              'id': 6387,
              'name': 'Nguyen Thi Thu Thao',
              'email': 'thaontt@360.org.vn',
              'avatar_url': '/api/v1/mobile/avatar/res.partner/6387?field=avatar_128',
              'is_me': false,
            },
            {
              'id': 6691,
              'name': 'Morpheus',
              'email': 'morpheus@360.org.vn',
              'avatar_url': '/api/v1/mobile/avatar/res.partner/6691?field=avatar_128',
              'is_me': false,
            },
          ],
        },
        {
          'id': 739064,
          'name': '360 CORP (+84 836 360 360) · ĐÀN SẾU KHỞI NGHIỆP',
          'channel_type': 'group',
          'avatar_url': null,
          'direct_partner': null,
          'partner_id': 3,
          'is_zalo_channel': false,
          'members': [
            {
              'id': 3,
              'name': 'Chau, Le Ba',
              'email': 'admin@vuahethong.net',
              'avatar_url': '/api/v1/mobile/avatar/res.partner/3?field=avatar_128',
              'is_me': false,
            },
          ],
        },
        {
          'id': 739066,
          'name': '360 CORP (+84 836 360 360) · Nguyễn Khánh Linh',
          'channel_type': 'group',
          'avatar_url': null,
          'direct_partner': null,
          'partner_id': 3,
          'is_zalo_channel': false,
          'members': [
            {
              'id': 3,
              'name': 'Chau, Le Ba',
              'email': 'admin@vuahethong.net',
              'avatar_url': '/api/v1/mobile/avatar/res.partner/3?field=avatar_128',
              'is_me': false,
            },
          ],
        },
        {
          'id': 739082,
          'name': '360 CORP (+84 836 360 360) · Triển lãm Startup Connection Day Vũng Tàu 28.11',
          'channel_type': 'group',
          'avatar_url': null,
          'direct_partner': null,
          'partner_id': 3,
          'is_zalo_channel': false,
          'members': [
            {
              'id': 3,
              'name': 'Chau, Le Ba',
              'email': 'admin@vuahethong.net',
              'avatar_url': '/api/v1/mobile/avatar/res.partner/3?field=avatar_128',
              'is_me': false,
            },
          ],
        },
      ];

      for (final raw in payloads) {
        final ch = ChatV2Channel.fromJson(raw);
        expect(ch.isZaloOA, isTrue);
        expect(ch.isGroup, isFalse);
        expect(ch.avatarUrl, isNull, reason: 'Channel ${ch.id} should not inherit staff avatar');
        expect(ch.directPartnerAvatar, isNull);
        expect(ch.directPartnerId, isNull);
        expect(ch.partnerId, isNull);
        expect(ch.resolveZaloAvatarUrl(), isNull);
      }
    });

    test('preserves channel avatar and external customer member for 1579 and 4087', () {
      final ch1579 = ChatV2Channel.fromJson({
        'id': 1579,
        'name': 'Cao Thị Hồng',
        'channel_type': 'group',
        'is_zalo_channel': true,
        'avatar_url': '/api/v1/mobile/avatar/discuss.channel/1579?field=avatar_128',
        'partner_id': 3130,
        'members': [
          {
            'id': 3,
            'name': 'Chau, Le Ba',
            'email': 'admin@vuahethong.net',
            'avatar_url': '/api/v1/mobile/avatar/res.partner/3?field=avatar_128',
            'is_me': false,
          },
          {
            'id': 3130,
            'name': 'Cao Thị Hồng',
            'email': '838934979158813668',
            'avatar_url': '/api/v1/mobile/avatar/res.partner/3130?field=avatar_128',
            'is_me': false,
          },
        ],
      });
      expect(ch1579.avatarUrl, contains('/api/v1/mobile/avatar/discuss.channel/1579'));
      expect(ch1579.directPartnerId, '3130');

      final ch4087 = ChatV2Channel.fromJson({
        'id': 4087,
        'name': 'Esog - Hương Lê',
        'channel_type': 'group',
        'is_zalo_channel': true,
        'avatar_url': '/api/v1/mobile/avatar/discuss.channel/4087?field=avatar_128',
        'partner_id': 5449,
        'members': [
          {
            'id': 2,
            'name': 'Bot',
            'email': 'bot@vuahethong.net',
            'avatar_url': '/api/v1/mobile/avatar/res.partner/2?field=avatar_128',
            'is_me': false,
          },
          {
            'id': 961,
            'name': 'Supper Admin',
            'email': 'admin@w360s.com',
            'avatar_url': '/api/v1/mobile/avatar/res.partner/961?field=avatar_128',
            'is_me': false,
          },
          {
            'id': 5449,
            'name': 'ESOG Huong Le',
            'email': 'huong.le@esog.com.vn',
            'avatar_url': '/api/v1/mobile/avatar/res.partner/5449?field=avatar_128',
            'is_me': false,
          },
        ],
      });
      expect(ch4087.avatarUrl, contains('/api/v1/mobile/avatar/discuss.channel/4087'));
      expect(ch4087.directPartnerId, '5449');
    });

    testWidgets('ChatV2ListScreen renders initials instead of Chau Le Ba avatar for Zalo channels with internal-only members', (tester) async {
      final channels = [
        ChatV2Channel.fromJson({
          'id': 739110,
          'name': '360 CORP (+84 836 360 360) · Anh Khang Vitamin House',
          'channel_type': 'group',
          'partner_id': 3,
          'last_message': 'nhờ em chuyển lại quyền quản trị OA',
          'members': [
            {
              'id': 3,
              'name': 'Chau, Le Ba',
              'email': 'admin@vuahethong.net',
              'avatar_url': '/api/v1/mobile/avatar/res.partner/3?field=avatar_128',
              'is_me': false,
            },
          ],
        }),
        ChatV2Channel.fromJson({
          'id': 739064,
          'name': '360 CORP (+84 836 360 360) · ĐÀN SẾU KHỞI NGHIỆP',
          'channel_type': 'group',
          'partner_id': 3,
          'last_message': '[Đính kèm]',
          'members': [
            {
              'id': 3,
              'name': 'Chau, Le Ba',
              'email': 'admin@vuahethong.net',
              'avatar_url': '/api/v1/mobile/avatar/res.partner/3?field=avatar_128',
              'is_me': false,
            },
          ],
        }),
      ];

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
            chatV2ChannelsProvider.overrideWith(() => _FakeChannelsNotifier(channels)),
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

      expect(find.text('Anh Khang Vitamin House'), findsOneWidget);
      expect(find.text('ĐÀN SẾU KHỞI NGHIỆP'), findsOneWidget);

      final netImages = tester
          .widgetList<Image>(find.byType(Image))
          .where((img) => img.image is NetworkImage)
          .map((img) => (img.image as NetworkImage).url)
          .toList();
      expect(
        netImages.where((url) => url.contains('res.partner/3')),
        isEmpty,
        reason: 'Must never load Chau, Le Ba avatar (res.partner/3) for Zalo channels',
      );
    });
  });
}
