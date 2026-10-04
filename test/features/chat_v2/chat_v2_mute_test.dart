import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/features/chat_v2/data/models/chat_v2_channel.dart';
import 'package:vcloud/features/chat_v2/application/chat_v2_channels_controller.dart';
import 'package:vcloud/features/chat_v2/presentation/widgets/chat_v2_mute_duration_sheet.dart';
import 'package:vcloud/features/chat_v2/data/odoo_bus_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ChatV2 Mute Channel Tests', () {
    test('1. ChatV2Channel default isMuted is false', () {
      const channel = ChatV2Channel(id: '1', name: 'Nhóm Dev');
      expect(channel.isMuted, isFalse);
    });

    test('2. ChatV2Channel.fromJson parse is_muted = true', () {
      final json = {
        'id': 10,
        'name': 'Kênh thông báo',
        'is_muted': true,
      };
      final channel = ChatV2Channel.fromJson(json);
      expect(channel.id, '10');
      expect(channel.name, 'Kênh thông báo');
      expect(channel.isMuted, isTrue);
    });

    test('3. ChatV2Channel.fromJson parse is_muted = false', () {
      final json = {
        'id': 11,
        'name': 'Kênh thảo luận',
        'is_muted': false,
      };
      final channel = ChatV2Channel.fromJson(json);
      expect(channel.isMuted, isFalse);
    });

    test('4. ChatV2Channel.fromJson parse is_muted = 1 as true', () {
      final json = {
        'id': 12,
        'name': 'Kênh test',
        'is_muted': 1,
      };
      final channel = ChatV2Channel.fromJson(json);
      expect(channel.isMuted, isTrue);
    });

    test('5. ChatV2Channel copyWith update isMuted correctly', () {
      const channel = ChatV2Channel(id: '1', name: 'Chat', isMuted: false);
      final mutedChannel = channel.copyWith(isMuted: true);
      expect(mutedChannel.isMuted, isTrue);
      final unmutedChannel = mutedChannel.copyWith(isMuted: false);
      expect(unmutedChannel.isMuted, isFalse);
    });

    test('6. ChatV2Channel toMap contains is_muted', () {
      const channel = ChatV2Channel(id: '1', name: 'Chat', isMuted: true);
      final map = channel.toMap();
      expect(map['is_muted'], isTrue);
    });

    test('7. ChatV2ChannelLocalCache.setUserMuted adds and removes channelId', () {
      const testChannelId = 'test_channel_999';
      expect(ChatV2ChannelLocalCache.isUserMuted(testChannelId), isFalse);

      ChatV2ChannelLocalCache.setUserMuted(testChannelId, true);
      expect(ChatV2ChannelLocalCache.isUserMuted(testChannelId), isTrue);

      ChatV2ChannelLocalCache.setUserMuted(testChannelId, false);
      expect(ChatV2ChannelLocalCache.isUserMuted(testChannelId), isFalse);
    });

    test('8. ChatV2ChannelLocalCache.toggleUserMute toggles status', () {
      const testChannelId = 'test_channel_888';
      ChatV2ChannelLocalCache.setUserMuted(testChannelId, false);
      expect(ChatV2ChannelLocalCache.isUserMuted(testChannelId), isFalse);

      ChatV2ChannelLocalCache.toggleUserMute(testChannelId);
      expect(ChatV2ChannelLocalCache.isUserMuted(testChannelId), isTrue);

      ChatV2ChannelLocalCache.toggleUserMute(testChannelId);
      expect(ChatV2ChannelLocalCache.isUserMuted(testChannelId), isFalse);
    });

    test('9. ChatV2Channel parse null is_muted falls back to false', () {
      final json = {
        'id': 20,
        'name': 'Kênh không có cờ mute',
      };
      final channel = ChatV2Channel.fromJson(json);
      expect(channel.isMuted, isFalse);
    });

    test('10. Multiple channels mute state independence', () {
      ChatV2ChannelLocalCache.setUserMuted('ch_1', true);
      ChatV2ChannelLocalCache.setUserMuted('ch_2', false);

      expect(ChatV2ChannelLocalCache.isUserMuted('ch_1'), isTrue);
      expect(ChatV2ChannelLocalCache.isUserMuted('ch_2'), isFalse);

      ChatV2ChannelLocalCache.setUserMuted('ch_1', false);
      expect(ChatV2ChannelLocalCache.isUserMuted('ch_1'), isFalse);
    });

    testWidgets('11. ChatV2MuteDurationSheet renders 4 duration options', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChatV2MuteDurationSheet(),
          ),
        ),
      );

      expect(find.text('Tắt thông báo'), findsOneWidget);
      expect(find.text('Trong 1 giờ'), findsOneWidget);
      expect(find.text('Trong 8 giờ'), findsOneWidget);
      expect(find.text('Trong 24 giờ'), findsOneWidget);
      expect(find.text('Cho đến khi tôi bật lại'), findsOneWidget);
    });

    testWidgets('12. ChatV2MuteDurationSheet tap returns selected duration', (tester) async {
      int? selectedMinutes;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            splashFactory: InkRipple.splashFactory,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) {
                return ElevatedButton(
                  onPressed: () async {
                    selectedMinutes = await showMuteDurationPickerSheet(context);
                  },
                  child: const Text('Open'),
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Trong 1 giờ'), findsOneWidget);
      await tester.tap(find.text('Trong 1 giờ'));
      await tester.pumpAndSettle();

      expect(selectedMinutes, 60);
    });

    test('13. OdooBusService handles discuss.channel.member/mute event', () async {
      final bus = OdooBusService();
      Map<String, dynamic>? received;
      final sub = bus.onMuteNotification.listen((data) {
        received = data;
      });

      bus.processBusNotificationForTesting({
        'type': 'discuss.channel.member/mute',
        'payload': {
          'channel_id': 77,
          'is_muted': true,
          'mute_until_dt': '9999-12-31 23:59:59',
        },
      });

      await Future.delayed(const Duration(milliseconds: 10));
      expect(received, isNotNull);
      expect(received!['channel_id'], 77);
      expect(received!['is_muted'], isTrue);
      expect(ChatV2ChannelLocalCache.isUserMuted('77'), isTrue);

      // Unmute event
      bus.processBusNotificationForTesting({
        'type': 'discuss.channel.member/mute',
        'payload': {
          'channel_id': 77,
          'is_muted': false,
          'mute_until_dt': null,
        },
      });

      await Future.delayed(const Duration(milliseconds: 10));
      expect(received!['channel_id'], 77);
      expect(received!['is_muted'], isFalse);
      expect(ChatV2ChannelLocalCache.isUserMuted('77'), isFalse);

      await sub.cancel();
      bus.dispose();
    });

    test('14. OdooBusService handles mail.record/insert member mute event', () async {
      final bus = OdooBusService();
      Map<String, dynamic>? received;
      final sub = bus.onMuteNotification.listen((data) {
        received = data;
      });

      bus.processBusNotificationForTesting({
        'type': 'mail.record/insert',
        'payload': {
          'discuss.channel.member': [
            {
              'id': 105,
              'channel_id': 88,
              'mute_until_dt': '2026-10-04 18:00:00',
            }
          ],
        },
      });

      await Future.delayed(const Duration(milliseconds: 10));
      expect(received, isNotNull);
      expect(received!['channel_id'], 88);
      expect(received!['is_muted'], isTrue);
      expect(ChatV2ChannelLocalCache.isUserMuted('88'), isTrue);

      await sub.cancel();
      bus.dispose();
    });
  });
}
