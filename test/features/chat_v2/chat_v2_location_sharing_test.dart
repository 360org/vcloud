import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/features/chat_v2/data/models/chat_v2_message.dart';
import 'package:vcloud/features/chat_v2/presentation/widgets/chat_v2_location_card.dart';

void main() {
  group('Chat V2 Location Sharing - Model & Parser Tests', () {
    test('1. Accurately detects Google Maps location message and parses coordinates', () {
      const msg = ChatV2Message(
        id: 'msg_loc_1',
        channelId: 'ch_1',
        content: '📍 Vị trí: https://maps.google.com/?q=10.762622,106.660172',
      );

      expect(msg.isLocationMessage, isTrue);
      final coords = msg.locationCoordinates;
      expect(coords, isNotNull);
      expect(coords!.lat, closeTo(10.762622, 0.000001));
      expect(coords.lng, closeTo(106.660172, 0.000001));
      expect(coords.mapUrl, contains('https://maps.google.com/?q=10.762622,106.660172'));
    });

    test('2. Accurately detects Apple Maps location URL and parses negative coordinates', () {
      const msg = ChatV2Message(
        id: 'msg_loc_2',
        channelId: 'ch_1',
        content: 'Ghé đây nhé https://maps.apple.com/?q=-33.8688,151.2093',
      );

      expect(msg.isLocationMessage, isTrue);
      final coords = msg.locationCoordinates;
      expect(coords, isNotNull);
      expect(coords!.lat, closeTo(-33.8688, 0.0001));
      expect(coords.lng, closeTo(151.2093, 0.0001));
    });

    test('3. Accurately detects OpenStreetMap location URL', () {
      const msg = ChatV2Message(
        id: 'msg_loc_3',
        channelId: 'ch_1',
        content: 'Vị trí kho hàng: https://www.openstreetmap.org/?mlat=21.028511&mlon=105.854444',
      );

      expect(msg.isLocationMessage, isTrue);
    });

    test('4. Standard text messages are NOT identified as location messages', () {
      const msgNormal = ChatV2Message(
        id: 'msg_normal',
        channelId: 'ch_1',
        content: 'Xin chào anh em, hôm nay họp lúc 14:00 nhé!',
      );

      expect(msgNormal.isLocationMessage, isFalse);
      expect(msgNormal.locationCoordinates, isNull);
    });

    test('5. Image and document messages are NOT identified as location messages', () {
      const msgImg = ChatV2Message(
        id: 'msg_img',
        channelId: 'ch_1',
        content: 'image_picker_123.jpg',
      );
      expect(msgImg.isLocationMessage, isFalse);

      const msgDoc = ChatV2Message(
        id: 'msg_doc',
        channelId: 'ch_1',
        content: 'Báo cáo tài chính.pdf',
      );
      expect(msgDoc.isLocationMessage, isFalse);
    });
  });

  group('Chat V2 Location Sharing - UI Widget Tests', () {
    testWidgets('6. ChatV2LocationCard renders coordinates and action button properly', (tester) async {
      const msg = ChatV2Message(
        id: 'msg_loc_widget',
        channelId: 'ch_1',
        content: '📍 Vị trí: https://maps.google.com/?q=10.762622,106.660172',
        authorName: 'Nguyễn Văn A',
        isMine: false,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ChatV2LocationCard(
              message: msg,
              isMine: false,
            ),
          ),
        ),
      );

      expect(find.text('Vị trí được chia sẻ'), findsOneWidget);
      expect(find.text('10.762622, 106.660172'), findsOneWidget);
      expect(find.text('Mở trên Google Maps'), findsOneWidget);
    });
  });
}
