import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/core/api/odoo_session.dart';
import 'package:vcloud/features/chat_v2/application/chat_v2_channels_controller.dart';
import 'package:vcloud/features/chat_v2/data/models/chat_v2_channel.dart';
import 'package:vcloud/features/menu/presentation/odoo_webview_screen.dart';

void main() {
  group('Fix 1: Push Notification Cold-Start Cache Full-List Guard', () {
    setUp(() {
      ChatV2ChannelLocalCache.clear();
    });

    test('updateChannelLastMessage(addIfMissing: true) không đánh dấu hasFullServerList', () {
      expect(ChatV2ChannelLocalCache.hasFullServerList, isFalse);

      ChatV2ChannelLocalCache.updateChannelLastMessage(
        '999',
        lastMessage: 'Vt: Về rồi. Có gì thắc mắc mai làm việc',
        lastMessageDate: DateTime.now(),
        authorName: '360 CORP (+84 836 360 360) · Khách A',
        unreadCount: 1,
        addIfMissing: true,
      );

      expect(ChatV2ChannelLocalCache.cached.length, 1);
      expect(ChatV2ChannelLocalCache.hasFullServerList, isFalse);
    });

    test('set(channels, fromServerFullList: true) đánh dấu hasFullServerList = true', () {
      ChatV2ChannelLocalCache.set(
        [
          const ChatV2Channel(id: '1', name: 'Administrators', channelType: 'channel', isGroup: true),
          const ChatV2Channel(id: '2', name: 'Demo User', channelType: 'chat', isGroup: false),
        ],
        fromServerFullList: true,
      );

      expect(ChatV2ChannelLocalCache.cached.length, 2);
      expect(ChatV2ChannelLocalCache.hasFullServerList, isTrue);

      ChatV2ChannelLocalCache.clear();
      expect(ChatV2ChannelLocalCache.hasFullServerList, isFalse);
    });
  });

  group('Fix 2: WebView /web/login Redirect Detection & SSO Recovery URL', () {
    test('isOdooLoginRedirectUrl nhận diện chính xác /web/login và /web/database/selector', () {
      expect(isOdooLoginRedirectUrl('https://vuahethong.net/web/login?redirect=%2Fodoo%2Fcommissions'), isTrue);
      expect(isOdooLoginRedirectUrl('https://vuahethong.net/web/database/selector'), isTrue);
      expect(isOdooLoginRedirectUrl('https://vuahethong.net/api/v1/mobile/web/auth?token=abc&redirect=/odoo/commissions'), isFalse);
      expect(isOdooLoginRedirectUrl('https://vuahethong.net/odoo/commissions'), isFalse);
      expect(isOdooLoginRedirectUrl(''), isFalse);
    });

    test('buildTargetWebViewUrl(useDirectUrlIfAuthenticated: false) ép đi qua cầu SSO /api/v1/mobile/web/auth', () {
      final session = OdooSession(
        uid: 2,
        login: 'tanmnn@360.org.vn',
        db: 'vuahethong',
        baseUrl: 'https://vuahethong.net',
        accessToken: 'jwt-valid-token',
        sessionId: 'stale-cookie-id',
        expiresAt: DateTime.now().add(const Duration(hours: 2)),
      );

      final ssoUrl = buildTargetWebViewUrl(
        rawUrl: '/odoo/commissions',
        session: session,
        baseUrl: 'https://vuahethong.net',
        useDirectUrlIfAuthenticated: false,
      );

      expect(ssoUrl, contains('/api/v1/mobile/web/auth'));
      expect(ssoUrl, contains('token=jwt-valid-token'));
      expect(ssoUrl, contains('db=vuahethong'));
    });
  });

  group('Fix 4: Zalo Cá Nhân (isZaloPersonal) Name, Group & Avatar', () {
    test('is_zalo_personal = true không xếp thành nhóm, bóc tên sạch và lấy avatar khách hàng', () {
      final ch = ChatV2Channel.fromJson({
        'id': 4201,
        'name': '[Zalo] Nguyễn Văn A',
        'channel_type': 'group',
        'is_group': true,
        'is_zalo_personal': true,
        'category': 'zalo',
        'members': [
          {'id': 2, 'name': 'Admin', 'is_me': true, 'avatar_url': '/web/image/res.partner/2/avatar_128'},
          {'id': 99, 'name': 'Nguyễn Văn A', 'is_me': false, 'avatar_url': '/web/image/res.partner/99/avatar_128'},
        ],
      });

      expect(ch.isZaloPersonal, isTrue);
      expect(ch.getActualIsGroup('Admin'), isFalse);
      expect(ch.getCleanName('Admin'), 'Nguyễn Văn A');
      expect(
        ch.avatarUrl,
        contains('/api/v1/mobile/avatar/res.partner/99?field=avatar_128'),
      );
    });
  });

  group('Fix 3: AppBar Subtitle Ellipsis không tràn trên màn hình hẹp 320px', () {
    testWidgets('Row chứa icon + Flexible Text không ném lỗi RenderFlex overflow', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 140,
              child: Row(
                children: [
                  Icon(Icons.tag, size: 13),
                  SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      'Kênh thảo luận • 6 thành viên',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
