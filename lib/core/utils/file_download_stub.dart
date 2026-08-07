import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

bool openDownloadUrl(String url) => false;

/// Saves `bytes` to a user-chosen path via the native save dialog. Returns true
/// on success, false if the user cancelled. [FilePicker.saveFile] must be called
/// from a user gesture (the download button tap satisfies that).
Future<bool> saveBytesToFile(Uint8List bytes, String suggestedName) async {
  final path = await FilePicker.platform.saveFile(
    dialogTitle: 'Lưu tệp',
    fileName: suggestedName,
  );
  if (path == null) return false;
  // Some platforms return the bytes directly (no writable path); others return
  // a path we must write ourselves.
  await File(path).writeAsBytes(bytes);
  return true;
}

bool openPdfBlobPreview(Uint8List bytes) => false;

String? createBlobUrl(Uint8List bytes, String mimeType) => null;

void revokeBlobUrl(String url) {}
