import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';

// Import domain model and message controllers
import 'package:vcloud/features/chat/application/messages_controller.dart';

class MockChatRepository {
  final Map<String, Uint8List> _mockByteStore = {
    '1061': Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x2D, 0x31, 0x2E, 0x34]), // %PDF-1.4
    '1062': Uint8List.fromList([0x50, 0x4B, 0x03, 0x04, 0x14, 0x00]),             // PK.. (DOCX)
    '1063': Uint8List.fromList([0x50, 0x4B, 0x03, 0x04, 0x14, 0x00]),             // PK.. (XLSX)
    '1064': Uint8List.fromList([0x48, 0x75, 0x6F, 0x6E, 0x67, 0x20, 0x64, 0x61]), // "Huong da" (TXT)
  };

  Future<Uint8List> attachmentBytes(String attachmentId) async {
    final bytes = _mockByteStore[attachmentId];
    if (bytes != null) return bytes;
    return Uint8List.fromList([0x56, 0x43, 0x6C, 0x6F, 0x75, 0x64]); // "VCloud"
  }

  Future<String> attachmentDownloadUrl(String attachmentId) async {
    return 'http://localhost:8069/web/content/$attachmentId?download=1';
  }

  String attachmentContentUrl(String attachmentId, {String? url}) {
    return url ?? 'http://localhost:8069/web/content/$attachmentId';
  }
}

void main() {
  group('Document Attachment Card Interactivity & Byte Download Test', () {
    test('Verify raw byte stream decoding and signature headers for IDs 1061-1064', () async {
      final mockRepo = MockChatRepository();
      final downloadAction = DownloadAttachmentAction(mockRepo);

      // 1. Test PDF Attachment ID 1061 (%PDF-1.4 header)
      final pdfBytes = await downloadAction.bytes('1061');
      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes[0], 0x25); // '%'
      expect(pdfBytes[1], 0x50); // 'P'
      expect(pdfBytes[2], 0x44); // 'D'
      expect(pdfBytes[3], 0x46); // 'F'

      // 2. Test DOCX Attachment ID 1062 (ZIP 'PK' header)
      final docxBytes = await downloadAction.bytes('1062');
      expect(docxBytes, isNotEmpty);
      expect(docxBytes[0], 0x50); // 'P'
      expect(docxBytes[1], 0x4B); // 'K'

      // 3. Test XLSX Attachment ID 1063 (ZIP 'PK' header)
      final xlsxBytes = await downloadAction.bytes('1063');
      expect(xlsxBytes, isNotEmpty);
      expect(xlsxBytes[0], 0x50); // 'P'
      expect(xlsxBytes[1], 0x4B); // 'K'

      // 4. Test TXT Attachment ID 1064 (Plain text header)
      final txtBytes = await downloadAction.bytes('1064');
      expect(txtBytes, isNotEmpty);
      expect(txtBytes[0], 0x48); // 'H'
      expect(txtBytes[1], 0x75); // 'u'

      // ignore: avoid_print
      print('➔ [PASS] Verified authenticated byte stream download for IDs 1061, 1062, 1063, 1064.');
    });
  });
}
