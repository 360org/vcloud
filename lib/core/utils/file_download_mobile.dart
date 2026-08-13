import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens `url` in external application or mobile browser.
bool openDownloadUrl(String url) {
  final uri = Uri.tryParse(url.contains('://') ? url : 'https://$url');
  if (uri == null) return false;
  launchUrl(uri, mode: LaunchMode.externalApplication);
  return true;
}

/// Saves `bytes` to device storage and opens with native app viewer.
Future<bool> saveBytesToFile(Uint8List bytes, String suggestedName) async {
  try {
    // First try user-chosen path via FilePicker if supported
    String? path;
    try {
      path = await FilePicker.platform.saveFile(
        dialogTitle: 'Lưu tệp',
        fileName: suggestedName,
      );
    } catch (_) {
      path = null;
    }

    if (path == null) {
      final dir = await getApplicationDocumentsDirectory();
      path = '${dir.path}/$suggestedName';
    }

    final file = File(path);
    await file.writeAsBytes(bytes);

    // Open file using native OS registered app
    final uri = Uri.file(path);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
    return true;
  } catch (e) {
    return false;
  }
}

/// Native PDF Preview fallback using external application launcher.
bool openPdfBlobPreview(Uint8List bytes) {
  saveBytesToFile(bytes, 'preview_${DateTime.now().millisecondsSinceEpoch}.pdf');
  return true;
}

String? createBlobUrl(Uint8List bytes, String mimeType) => null;

void revokeBlobUrl(String url) {}
