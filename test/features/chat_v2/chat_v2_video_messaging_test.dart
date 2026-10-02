import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:open_filex/open_filex.dart';
import 'package:vcloud/core/utils/gallery_saver.dart';
import 'package:vcloud/features/chat_v2/data/models/chat_v2_message.dart';
import 'package:vcloud/features/chat_v2/presentation/screens/chat_v2_video_player_screen.dart';
import 'package:vcloud/features/chat_v2/presentation/widgets/chat_v2_attachment_viewer.dart';
import 'package:vcloud/features/chat_v2/presentation/widgets/chat_v2_message_item.dart';
import 'package:vcloud/features/chat_v2/presentation/widgets/chat_v2_video_bubble.dart';

Widget _buildTestApp({required Widget body}) {
  return MaterialApp(
    theme: ThemeData(
      useMaterial3: false,
      splashFactory: NoSplash.splashFactory,
    ),
    home: Scaffold(body: body),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Chat V2 In-App Video Sending & Player - 12 Independent Verification Tests', () {
    // -------------------------------------------------------------
    // Test Case 1: isVideo nhận diện đúng các MIME type video
    // -------------------------------------------------------------
    test('Case 1: ChatV2Attachment.isVideo identifies video mimetypes', () {
      const attMp4 = ChatV2Attachment(id: '1', name: 'clip', mimetype: 'video/mp4');
      const attMov = ChatV2Attachment(id: '2', name: 'clip', mimetype: 'video/quicktime');
      const attMkv = ChatV2Attachment(id: '3', name: 'clip', mimetype: 'video/x-matroska');
      const attWebm = ChatV2Attachment(id: '4', name: 'clip', mimetype: 'video/webm');

      expect(attMp4.isVideo, isTrue);
      expect(attMov.isVideo, isTrue);
      expect(attMkv.isVideo, isTrue);
      expect(attWebm.isVideo, isTrue);
    });

    // -------------------------------------------------------------
    // Test Case 2: isVideo nhận diện đúng qua đuôi mở rộng file
    // -------------------------------------------------------------
    test('Case 2: ChatV2Attachment.isVideo identifies video extensions without mimetype', () {
      const att1 = ChatV2Attachment(id: '1', name: 'demo.mp4', mimetype: null);
      const att2 = ChatV2Attachment(id: '2', name: 'presentation.MOV', mimetype: 'application/octet-stream');
      const att3 = ChatV2Attachment(id: '3', name: 'movie.mkv', mimetype: '');
      const att4 = ChatV2Attachment(id: '4', name: 'recording.avi', mimetype: null);
      const att5 = ChatV2Attachment(id: '5', name: 'mobile_shot.3gp', mimetype: null);

      expect(att1.isVideo, isTrue);
      expect(att2.isVideo, isTrue);
      expect(att3.isVideo, isTrue);
      expect(att4.isVideo, isTrue);
      expect(att5.isVideo, isTrue);
    });

    // -------------------------------------------------------------
    // Test Case 3: Phân định rạch ròi .webm giữa Voice message vs Video clip
    // -------------------------------------------------------------
    test('Case 3: Webm distinction: voice_*.webm is audio, other .webm is video', () {
      const voiceWebm = ChatV2Attachment(id: '1', name: 'voice_1720000000.webm', mimetype: null);
      const videoWebm = ChatV2Attachment(id: '2', name: 'intro_animation.webm', mimetype: null);

      expect(voiceWebm.isAudio, isTrue);
      expect(voiceWebm.isVideo, isFalse);

      expect(videoWebm.isVideo, isTrue);
      expect(videoWebm.isAudio, isFalse);
    });

    // -------------------------------------------------------------
    // Test Case 4: isVideo trả về false cho định dạng âm thanh (Audio)
    // -------------------------------------------------------------
    test('Case 4: ChatV2Attachment.isVideo returns false for audio files', () {
      const audioMp3 = ChatV2Attachment(id: '1', name: 'song.mp3', mimetype: 'audio/mpeg');
      const audioM4a = ChatV2Attachment(id: '2', name: 'voice.m4a', mimetype: 'audio/m4a');
      const audioWav = ChatV2Attachment(id: '3', name: 'sound.wav', mimetype: 'audio/wav');
      const audioAac = ChatV2Attachment(id: '4', name: 'track.aac', mimetype: 'audio/aac');

      expect(audioMp3.isVideo, isFalse);
      expect(audioMp3.isAudio, isTrue);
      expect(audioM4a.isVideo, isFalse);
      expect(audioM4a.isAudio, isTrue);
      expect(audioWav.isVideo, isFalse);
      expect(audioWav.isAudio, isTrue);
      expect(audioAac.isVideo, isFalse);
      expect(audioAac.isAudio, isTrue);
    });

    // -------------------------------------------------------------
    // Test Case 5: isVideo trả về false cho tài liệu và hình ảnh
    // -------------------------------------------------------------
    test('Case 5: ChatV2Attachment.isVideo returns false for documents and images', () {
      const docPdf = ChatV2Attachment(id: '1', name: 'report.pdf', mimetype: 'application/pdf');
      const docDocx = ChatV2Attachment(id: '2', name: 'contract.docx', mimetype: 'application/vnd.openxmlformats');
      const imgPng = ChatV2Attachment(id: '3', name: 'photo.png', mimetype: 'image/png');
      const imgJpg = ChatV2Attachment(id: '4', name: 'avatar.jpg', mimetype: 'image/jpeg');

      expect(docPdf.isVideo, isFalse);
      expect(docDocx.isVideo, isFalse);
      expect(imgPng.isVideo, isFalse);
      expect(imgJpg.isVideo, isFalse);
    });

    // -------------------------------------------------------------
    // Test Case 6: isAudio không bị nhầm lẫn khi file video có chữ "audio" trong tên
    // -------------------------------------------------------------
    test('Case 6: isAudio returns false for video files with audio in filename or mimetype', () {
      const videoWithAudioInName = ChatV2Attachment(
        id: '1',
        name: 'video_with_audio_track.mp4',
        mimetype: 'video/mp4',
      );
      expect(videoWithAudioInName.isVideo, isTrue);
      expect(videoWithAudioInName.isAudio, isFalse);
    });

    // -------------------------------------------------------------
    // Test Case 7: ChatV2VideoBubble widget hiển thị đúng tên file và icon Play
    // -------------------------------------------------------------
    testWidgets('Case 7: ChatV2VideoBubble renders filename and circular Play button', (tester) async {
      const videoAtt = ChatV2Attachment(
        id: '101',
        name: 'huong_dan_su_dung.mp4',
        mimetype: 'video/mp4',
        fileSize: 5 * 1024 * 1024, // 5 MB
      );

      await tester.pumpWidget(
        _buildTestApp(
          body: const ChatV2VideoBubble(
            attachment: videoAtt,
            isMine: true,
          ),
        ),
      );

      expect(find.text('huong_dan_su_dung.mp4'), findsOneWidget);
      expect(find.byIcon(LucideIcons.play), findsOneWidget);
      expect(find.byIcon(LucideIcons.video), findsOneWidget);
    });

    // -------------------------------------------------------------
    // Test Case 8: ChatV2VideoBubble định dạng dung lượng MB chính xác
    // -------------------------------------------------------------
    testWidgets('Case 8: ChatV2VideoBubble formats megabytes size badge correctly', (tester) async {
      const videoAtt = ChatV2Attachment(
        id: '102',
        name: 'clip_quang_cao.mp4',
        mimetype: 'video/mp4',
        fileSize: 15309209, // 14.6 MB
      );

      await tester.pumpWidget(
        _buildTestApp(
          body: const ChatV2VideoBubble(
            attachment: videoAtt,
            isMine: false,
          ),
        ),
      );

      expect(find.text('Video • 14.6 MB'), findsOneWidget);
    });

    // -------------------------------------------------------------
    // Test Case 9: ChatV2VideoBubble định dạng dung lượng KB chính xác
    // -------------------------------------------------------------
    testWidgets('Case 9: ChatV2VideoBubble formats kilobytes size badge correctly', (tester) async {
      const videoAtt = ChatV2Attachment(
        id: '103',
        name: 'short_teaser.mp4',
        mimetype: 'video/mp4',
        fileSize: 450 * 1024, // 450 KB
      );

      await tester.pumpWidget(
        _buildTestApp(
          body: const ChatV2VideoBubble(
            attachment: videoAtt,
            isMine: true,
          ),
        ),
      );

      expect(find.text('Video • 450.0 KB'), findsOneWidget);
    });

    // -------------------------------------------------------------
    // Test Case 10: ChatV2VideoPlayerScreen.route trả về PageRouteBuilder hợp lệ
    // -------------------------------------------------------------
    test('Case 10: ChatV2VideoPlayerScreen.route returns valid PageRouteBuilder', () {
      final route = ChatV2VideoPlayerScreen.route(
        videoUrl: 'https://vuahethong.net/web/content/105',
        title: 'Video Demo',
        bytes: Uint8List.fromList([1, 2, 3]),
      );

      expect(route, isA<PageRouteBuilder<void>>());
      final pageRoute = route as PageRouteBuilder<void>;
      expect(pageRoute.transitionDuration, const Duration(milliseconds: 250));
    });

    // -------------------------------------------------------------
    // Test Case 11: ChatV2AttachmentViewer.open chặn file video không mở qua app ngoài
    // -------------------------------------------------------------
    testWidgets('Case 11: ChatV2AttachmentViewer.open intercepts video and returns done without external opener', (tester) async {
      bool customOpenerCalled = false;
      ChatV2AttachmentViewer.customOpener = (path, {type}) async {
        customOpenerCalled = true;
        return OpenResult(type: ResultType.done);
      };

      await tester.pumpWidget(
        _buildTestApp(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                ChatV2AttachmentViewer.open(
                  context: context,
                  filename: 'demo_video.mp4',
                  downloadUrl: 'https://vuahethong.net/web/content/200',
                  directBytes: Uint8List.fromList([0, 1, 2]),
                );
              },
              child: const Text('Open Video'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Video'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // customOpener (native OpenFilex) không được gọi vì video được chặn mở In-App!
      expect(customOpenerCalled, isFalse);
    });

    // -------------------------------------------------------------
    // Test Case 12: ChatV2MessageItem hiển thị ChatV2VideoBubble khi có video attachment
    // -------------------------------------------------------------
    testWidgets('Case 12: ChatV2MessageItem renders ChatV2VideoBubble for video attachment', (tester) async {
      const msg = ChatV2Message(
        id: 'msg_video_1',
        channelId: 'ch_main',
        content: '[Video]',
        authorName: 'Nguyễn Văn A',
        isMine: false,
        attachments: [
          ChatV2Attachment(
            id: 'att_v1',
            name: 'chuc_mung_nam_moi.mp4',
            mimetype: 'video/mp4',
            fileSize: 8 * 1024 * 1024,
          ),
        ],
      );

      await tester.pumpWidget(
        _buildTestApp(
          body: const ChatV2MessageItem(
            message: msg,
          ),
        ),
      );

      expect(find.byType(ChatV2VideoBubble), findsOneWidget);
      expect(find.text('chuc_mung_nam_moi.mp4'), findsOneWidget);
      expect(find.byIcon(LucideIcons.play), findsOneWidget);
    });

    // -------------------------------------------------------------
    // Test Case 13: isVideoFilename nhận diện đúng đuôi file video
    // -------------------------------------------------------------
    test('Case 13: ChatV2Message.isVideoFilename correctly identifies video filenames', () {
      const msgMp4 = ChatV2Message(id: '1', channelId: 'c1', content: 'clip.mp4', isMine: true);
      const msgMov = ChatV2Message(id: '2', channelId: 'c1', content: 'clip.mov', isMine: true);
      const msgMkv = ChatV2Message(id: '3', channelId: 'c1', content: 'clip.mkv', isMine: true);
      const msgAvi = ChatV2Message(id: '4', channelId: 'c1', content: 'clip.avi', isMine: true);
      const msgDoc = ChatV2Message(id: '5', channelId: 'c1', content: 'report.pdf', isMine: true);
      const msgVoice = ChatV2Message(id: '6', channelId: 'c1', content: 'voice_12345.webm', isMine: true);

      expect(msgMp4.isVideoFilename, isTrue);
      expect(msgMov.isVideoFilename, isTrue);
      expect(msgMkv.isVideoFilename, isTrue);
      expect(msgAvi.isVideoFilename, isTrue);
      expect(msgDoc.isVideoFilename, isFalse);
      expect(msgVoice.isVideoFilename, isFalse);
    });

    // -------------------------------------------------------------
    // Test Case 14: ChatV2MessageItem hiển thị video khi chỉ có isVideoFilename (không bị SizedBox.shrink)
    // -------------------------------------------------------------
    testWidgets('Case 14: ChatV2MessageItem renders video from isVideoFilename content', (tester) async {
      const msg = ChatV2Message(
        id: 'msg_v_filename',
        channelId: 'ch_main',
        content: 'huong_dan_cai_dat.mp4',
        authorName: 'Admin',
        isMine: true,
      );

      await tester.pumpWidget(
        _buildTestApp(
          body: const ChatV2MessageItem(
            message: msg,
          ),
        ),
      );

      expect(find.byType(ChatV2VideoBubble), findsOneWidget);
      expect(find.text('huong_dan_cai_dat.mp4'), findsOneWidget);
    });

    // -------------------------------------------------------------
    // Test Case 15: GallerySaver.saveVideo ném ngoại lệ khi dữ liệu rỗng
    // -------------------------------------------------------------
    test('Case 15: GallerySaver.saveVideo throws on empty bytes and empty filePath', () async {
      expect(
        () => GallerySaver.saveVideo(fileName: 'test.mp4'),
        throwsA(isA<Exception>()),
      );
    });

    // -------------------------------------------------------------
    // Test Case 16: ChatV2VideoPlayerScreen chứa IconButton lưu video với tooltip 'Lưu vào máy'
    // -------------------------------------------------------------
    testWidgets('Case 16: ChatV2VideoPlayerScreen renders save video action button', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          body: const ChatV2VideoPlayerScreen(
            videoUrl: 'https://vuahethong.net/web/content/300',
            title: 'video_clip.mp4',
          ),
        ),
      );

      expect(find.byTooltip('Lưu vào máy'), findsOneWidget);
      expect(find.byIcon(LucideIcons.download), findsOneWidget);
    });
  });
}
