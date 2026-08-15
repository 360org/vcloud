import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/features/chat_v2/application/chat_v2_messages_controller.dart';
import 'package:vcloud/features/chat_v2/data/models/chat_v2_message.dart';

void main() {
  group('ChatV2 Performance & Stress Tests', () {
    test('1. Instant Cache Switch Stress Test - 100 channels with 50 msgs each', () {
      final stopwatch = Stopwatch()..start();

      // Seed 100 channels with 50 messages each (5,000 messages total)
      for (var ch = 1; ch <= 100; ch++) {
        final messages = List<ChatV2Message>.generate(
          50,
          (i) => ChatV2Message(
            id: 'msg_${ch}_$i',
            channelId: ch.toString(),
            content: 'Tin nhắn $i trong kênh $ch',
            authorName: 'Thành viên $i',
            createdAt: DateTime.now().subtract(Duration(minutes: 50 - i)),
            isMine: i % 2 == 0,
            status: 'sent',
          ),
        );
        ChatV2MessageLocalCache.set(ch.toString(), messages, persist: false);
      }

      stopwatch.stop();
      expect(stopwatch.elapsedMilliseconds, lessThan(300),
          reason: 'Seeding 5000 messages must take less than 300ms');

      // Stress test rapid switching between channels
      final switchStopwatch = Stopwatch()..start();
      for (var i = 0; i < 500; i++) {
        final targetChannel = (i % 100 + 1).toString();
        final cached = ChatV2MessageLocalCache.get(targetChannel);
        expect(cached, isNotNull);
        expect(cached!.length, equals(50));
      }
      switchStopwatch.stop();

      // 500 switch operations must take under 50ms total (< 0.1ms per switch)
      expect(switchStopwatch.elapsedMilliseconds, lessThan(50),
          reason: 'Switching 500 times between channels must take under 50ms');
    });

    test('2. Cache Append Speed - appending real-time messages under high load', () {
      const channelId = 'stress_test_channel';
      ChatV2MessageLocalCache.set(channelId, []);

      final stopwatch = Stopwatch()..start();
      for (var i = 0; i < 1000; i++) {
        ChatV2MessageLocalCache.append(
          channelId,
          ChatV2Message(
            id: 'ws_msg_$i',
            channelId: channelId,
            content: 'WebSocket broadcast message $i',
            authorName: 'Bot $i',
            createdAt: DateTime.now(),
          ),
        );
      }
      stopwatch.stop();

      expect(ChatV2MessageLocalCache.get(channelId)!.length, equals(1000));
      expect(stopwatch.elapsedMilliseconds, lessThan(80),
          reason: 'Appending 1000 WebSocket messages must take under 80ms');
    });
  });
}
