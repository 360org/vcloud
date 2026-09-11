import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;
import 'magic_bytes_validator.dart';

bool openDownloadUrl(String url) {
  final clean = url.trim();
  // Chặn mở URL không phải HTTP/HTTPS (ngăn Web mở tab http://work.xlsx/ gây lỗi DNS)
  if (!clean.startsWith('http://') && !clean.startsWith('https://')) {
    return false;
  }
  return web.window.open(clean, '_blank') != null;
}

/// Saves `bytes` as a browser download named `suggestedName`. Returns true once
/// the download anchor has been clicked. (The browser owns the actual download
/// progress; we can't observe completion.)
Future<bool> saveBytesToFile(Uint8List bytes, String suggestedName) async {
  // Chặn lưu tệp nếu tài liệu văn phòng bị nhận nhầm ảnh placeholder của Odoo
  if (MagicBytesValidator.isMistakenImagePayloadForDocument(suggestedName, bytes)) {
    return false;
  }

  final ext = suggestedName.contains('.') ? suggestedName.split('.').last.toLowerCase() : '';
  final mimeType = switch (ext) {
    'pdf' => 'application/pdf',
    'txt' => 'text/plain;charset=utf-8',
    'doc' => 'application/msword',
    'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls' => 'application/vnd.ms-excel',
    'xlsx' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'ppt' => 'application/vnd.ms-powerpoint',
    'pptx' => 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'zip' => 'application/zip',
    'json' => 'application/json',
    _ => 'application/octet-stream',
  };

  final parts = <JSAny>[bytes.toJS].toJS;
  final blob = web.Blob(parts, web.BlobPropertyBag(type: mimeType));
  final url = web.URL.createObjectURL(blob);
  final anchor =
      web.document.createElement('a') as web.HTMLAnchorElement
        ..href = url
        ..download = suggestedName;
  web.document.body!.appendChild(anchor);
  anchor.click();
  anchor.remove();
  Future.delayed(const Duration(seconds: 10), () {
    web.URL.revokeObjectURL(url);
  });
  return true;
}

/// Opens PDF `bytes` in a new browser tab for inline reading.
bool openPdfBlobPreview(Uint8List bytes) {
  final parts = <JSAny>[bytes.toJS].toJS;
  final blob = web.Blob(parts, web.BlobPropertyBag(type: 'application/pdf'));
  final url = web.URL.createObjectURL(blob);
  return web.window.open(url, '_blank') != null;
}
