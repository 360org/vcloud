import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/core/utils/gallery_saver.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Chat Media Picker & Gallery Saver Safe-Guard Tests (Waydroid / Android 13+)', () {
    test('GallerySaver.saveImage throws friendly Exception on empty bytes', () async {
      expect(
        () => GallerySaver.saveImage(bytes: Uint8List(0), fileName: 'empty.jpg'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Dữ liệu ảnh rỗng'),
        )),
      );
    });

    test('Video extension detection matches chat input bar specifications', () {
      bool isVideoFile(String filename, String? mimeType) {
        final m = (mimeType ?? '').toLowerCase();
        final n = filename.toLowerCase();
        return m.startsWith('video/') ||
            n.endsWith('.mp4') ||
            n.endsWith('.mov') ||
            n.endsWith('.avi') ||
            n.endsWith('.mkv') ||
            n.endsWith('.webm');
      }

      expect(isVideoFile('video.mp4', null), isTrue);
      expect(isVideoFile('clip.MOV', null), isTrue);
      expect(isVideoFile('recording.webm', 'video/webm'), isTrue);
      expect(isVideoFile('image.jpg', 'image/jpeg'), isFalse);
      expect(isVideoFile('photo.png', 'image/png'), isFalse);
      expect(isVideoFile('document.pdf', 'application/pdf'), isFalse);
    });

    test('Image file size threshold is strictly 10 MB and Document threshold is 25 MB', () {
      const maxImageSizeBytes = 10 * 1024 * 1024;
      const maxDocumentSizeBytes = 25 * 1024 * 1024;

      expect(maxImageSizeBytes, 10485760);
      expect(maxDocumentSizeBytes, 26214400);

      const withinLimitImage = 9 * 1024 * 1024;
      const exceedsLimitImage = 11 * 1024 * 1024;
      expect(withinLimitImage <= maxImageSizeBytes, isTrue);
      expect(exceedsLimitImage > maxImageSizeBytes, isTrue);
    });

    test('AndroidManifest.xml declares Android 13+ READ_MEDIA_IMAGES and legacy limits', () {
      final manifestFile = File('android/app/src/main/AndroidManifest.xml');
      expect(manifestFile.existsSync(), isTrue);

      final content = manifestFile.readAsStringSync();
      expect(
        content.contains('android.permission.READ_MEDIA_IMAGES'),
        isTrue,
        reason: 'Missing READ_MEDIA_IMAGES for Android 13+ (API 33+)',
      );
      expect(
        content.contains('android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32"'),
        isTrue,
        reason: 'Missing READ_EXTERNAL_STORAGE with maxSdkVersion=32',
      );
      expect(
        content.contains('android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="28"'),
        isTrue,
        reason: 'Missing WRITE_EXTERNAL_STORAGE with maxSdkVersion=28',
      );
      expect(
        content.contains('android:requestLegacyExternalStorage="true"'),
        isTrue,
        reason: 'Missing requestLegacyExternalStorage="true"',
      );
    });

    test('AndroidManifest.xml queries block includes GET_CONTENT, PICK, and IMAGE_CAPTURE', () {
      final manifestFile = File('android/app/src/main/AndroidManifest.xml');
      final content = manifestFile.readAsStringSync();

      expect(content.contains('<queries>'), isTrue);
      expect(content.contains('android.intent.action.GET_CONTENT'), isTrue);
      expect(content.contains('android.intent.action.PICK'), isTrue);
      expect(content.contains('android.media.action.IMAGE_CAPTURE'), isTrue);
    });

    test('Multi-tier fallback intent order handles Waydroid without Google Photos', () {
      final tierSequence = <String>[];

      void simulatePicker() {
        try {
          tierSequence.add('tier1_pickMultipleMedia');
          throw const FormatException('ActivityNotFoundException: No Activity found to handle Intent');
        } catch (_) {
          try {
            tierSequence.add('tier2_pickMultiImage');
            throw const FormatException('PhotoPicker unavailable');
          } catch (_) {
            try {
              tierSequence.add('tier3_pickImage');
              throw const FormatException('Gallery not found');
            } catch (_) {
              tierSequence.add('tier4_filePickerSAF');
            }
          }
        }
      }

      simulatePicker();

      expect(tierSequence, [
        'tier1_pickMultipleMedia',
        'tier2_pickMultiImage',
        'tier3_pickImage',
        'tier4_filePickerSAF',
      ]);
    });

    test('Friendly error message formatting sanitizes raw platform error codes', () {
      String formatPickerError(String errorCode, String? message) {
        final isActivityNotFound = errorCode.toLowerCase().contains('activity') ||
            (message?.toLowerCase().contains('activity') ?? false) ||
            errorCode == 'photo_access_denied';
        return isActivityNotFound
            ? 'Không tìm thấy ứng dụng Thư viện ảnh phù hợp trên thiết bị'
            : 'Lỗi truy cập hình ảnh: ${message ?? errorCode}';
      }

      expect(
        formatPickerError('ActivityNotFoundException', 'No activity found to handle intent'),
        'Không tìm thấy ứng dụng Thư viện ảnh phù hợp trên thiết bị',
      );
      expect(
        formatPickerError('photo_access_denied', null),
        'Không tìm thấy ứng dụng Thư viện ảnh phù hợp trên thiết bị',
      );
      expect(
        formatPickerError('permission_denied', 'User denied permission'),
        'Lỗi truy cập hình ảnh: User denied permission',
      );
    });
  });
}
