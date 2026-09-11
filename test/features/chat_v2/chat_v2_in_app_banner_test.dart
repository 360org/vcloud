import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/features/chat_v2/presentation/widgets/chat_v2_in_app_banner.dart';

void main() {
  group('Kiểm thử InAppNotificationNotifier & Payload', () {
    test('1. Khởi tạo notifier ban đầu mang giá trị null', () {
      final notifier = InAppNotificationNotifier();
      expect(notifier.state, isNull);
    });

    test(
      '2. Gọi show với tin nhắn thường tạo payload chuẩn (isMention = false)',
      () {
        final notifier = InAppNotificationNotifier();
        notifier.show(
          title: 'Nguyễn Văn A',
          body: 'Alo bạn ơi kiểm tra giúp mình',
          channelId: '10',
          isMention: false,
        );

        expect(notifier.state, isNotNull);
        expect(notifier.state!.title, 'Nguyễn Văn A');
        expect(notifier.state!.body, 'Alo bạn ơi kiểm tra giúp mình');
        expect(notifier.state!.channelId, '10');
        expect(notifier.state!.isMention, isFalse);
      },
    );

    test(
      '3. Gọi show với tin nhắn có tag tạo payload nhắc tên (isMention = true)',
      () {
        final notifier = InAppNotificationNotifier();
        notifier.show(
          title: 'Nguyễn Văn A (Phòng Kỹ Thuật)',
          body: '@Tân kiểm tra giúp em báo cáo gấp!',
          channelId: '25',
          isMention: true,
        );

        expect(notifier.state, isNotNull);
        expect(notifier.state!.title, 'Nguyễn Văn A (Phòng Kỹ Thuật)');
        expect(notifier.state!.body, '@Tân kiểm tra giúp em báo cáo gấp!');
        expect(notifier.state!.channelId, '25');
        expect(notifier.state!.isMention, isTrue);
      },
    );

    test('4. Gọi dismiss xoá payload khỏi màn hình', () {
      final notifier = InAppNotificationNotifier();
      notifier.show(title: 'Test', body: 'Test body', channelId: '99');
      expect(notifier.state, isNotNull);

      notifier.dismiss();
      expect(notifier.state, isNull);
    });
  });
}
