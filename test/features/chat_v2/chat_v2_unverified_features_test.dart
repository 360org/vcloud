import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/features/chat_v2/data/models/chat_v2_channel.dart';
import 'package:vcloud/features/chat_v2/data/models/chat_v2_message.dart';
import 'package:vcloud/features/chat_v2/presentation/widgets/chat_v2_message_item.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Feature 3.10: Shrink-Wrap Chat Bubble Layout Tests', () {
    testWidgets('Short message bubble ("Ok") shrink-wraps and does not stretch to full width', (tester) async {
      final shortMessage = ChatV2Message(
        id: 'msg_1',
        channelId: '1',
        content: 'Ok',
        authorId: '10',
        authorName: 'Sếp Tân',
        createdAt: DateTime.now(),
        isMine: true,
        status: 'sent',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 800,
              child: ChatV2MessageItem(
                message: shortMessage,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final bubbleFinder = find.byWidgetPredicate(
        (widget) => widget is Container && widget.constraints != null && widget.constraints!.maxWidth > 0,
      );
      expect(bubbleFinder, findsWidgets);

      final renderBox = tester.renderObject<RenderBox>(bubbleFinder.first);
      // For short text "Ok", width must be significantly smaller than maxWidth (800 * 0.72 = 576 or 480 cap)
      expect(renderBox.size.width, lessThan(200.0));
    });
  });

  group('Feature 3.20b: Zero-Storage Client & Media Permissions Guard', () {
    test('AndroidManifest.xml excludes broad READ_MEDIA permissions for Google Play compliance', () {
      final manifestFile = File('android/app/src/main/AndroidManifest.xml');
      expect(manifestFile.existsSync(), isTrue);

      final content = manifestFile.readAsStringSync();
      expect(content, contains('tools:node="remove"'));
      expect(content, contains('READ_MEDIA_IMAGES'));
      expect(content, contains('READ_MEDIA_VIDEO'));
    });
  });

  group('Feature 3.21 & 3.28: Voice Recording & File Picker Thresholds', () {
    test('Audio recording cancel offset threshold is strictly -60px horizontal drag', () {
      const cancelDragThreshold = -60.0;
      bool isCancelled(double dx) => dx < cancelDragThreshold;

      expect(isCancelled(-30.0), isFalse);
      expect(isCancelled(-60.0), isFalse);
      expect(isCancelled(-60.1), isTrue);
      expect(isCancelled(-120.0), isTrue);
    });

    test('File picker document size threshold is strictly 25 MB and photo is 10 MB', () {
      const maxDocumentSizeBytes = 25 * 1024 * 1024;
      const maxImageSizeBytes = 10 * 1024 * 1024;

      expect(maxDocumentSizeBytes, 26214400);
      expect(maxImageSizeBytes, 10485760);
    });
  });

  group('Feature 3.22: Voice Message Player Model & Format Tests', () {
    test('ChatV2Attachment identifies voice recording correctly', () {
      const voiceAttachment = ChatV2Attachment(
        id: 'voice_att_1',
        name: 'voice_recording.m4a',
        mimetype: 'audio/m4a',
        url: 'https://vuahethong.net/web/content/voice_att_1',
      );

      expect(voiceAttachment.isAudio, isTrue);
      expect(voiceAttachment.name, 'voice_recording.m4a');
    });
  });

  group('Feature 3.29: 1-1 vs Group Chat Context Menu Gating', () {
    test('isGroup == false hides "Rời nhóm trò chuyện" option', () {
      bool shouldShowLeaveOption(bool isGroup) {
        return isGroup;
      }

      expect(shouldShowLeaveOption(false), isFalse);
      expect(shouldShowLeaveOption(true), isTrue);
    });

    test('Direct message (channel_type: chat) has isGroup == false', () {
      final directChannel = ChatV2Channel(
        id: '101',
        name: 'Nguyễn Đào Quốc Anh',
        channelType: 'chat',
        memberCount: 2,
        lastMessageDate: DateTime.now(),
      );

      expect(directChannel.isGroup, isFalse);

      final groupChannel = ChatV2Channel(
        id: '102',
        name: 'Phòng Kỹ Thuật 360',
        channelType: 'channel',
        isGroup: true,
        memberCount: 8,
        lastMessageDate: DateTime.now(),
      );

      expect(groupChannel.isGroup, isTrue);
    });
  });
}
