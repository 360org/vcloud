import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import 'package:vcloud/core/theme/app_theme.dart';
import 'package:vcloud/shared/models/message.dart';

String? mimetypeForName(String filename) {
  final ext = fileExtension(filename).toLowerCase();
  switch (ext) {
    case 'pdf':
      return 'application/pdf';
    case 'doc':
      return 'application/msword';
    case 'docx':
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    case 'xls':
      return 'application/vnd.ms-excel';
    case 'xlsx':
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    case 'ppt':
      return 'application/vnd.ms-powerpoint';
    case 'pptx':
      return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
    case 'txt':
      return 'text/plain';
    case 'png':
      return 'image/png';
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'gif':
      return 'image/gif';
    case 'webp':
      return 'image/webp';
    case 'zip':
      return 'application/zip';
    default:
      return null;
  }
}

String stripHtml(String htmlString) {
  final exp = RegExp(r'<[^>]*>', multiLine: true, caseSensitive: false);
  var text = htmlString.replaceAll(exp, '');
  text = text
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'");
  return text.trim();
}

String attachmentFileName(Message message) {
  final rawName = message.attachmentName?.trim();
  if (rawName != null && rawName.isNotEmpty) return rawName;

  final contentName = stripHtml(message.content).trim();
  if (contentName.isNotEmpty && contentName.contains('.')) {
    return contentName;
  }

  if (message.attachmentMimeType != null) {
    final mime = message.attachmentMimeType!.toLowerCase();
    if (mime.contains('pdf')) return 'document.pdf';
    if (mime.contains('word') || mime.contains('msword')) return 'document.docx';
    if (mime.contains('excel') || mime.contains('spreadsheet')) return 'spreadsheet.xlsx';
    if (mime.contains('presentation') || mime.contains('powerpoint')) return 'presentation.pptx';
    if (mime.contains('zip')) return 'archive.zip';
    if (mime.contains('text')) return 'document.txt';
    if (mime.contains('image')) return 'image.jpg';
  }

  return 'tep_dinh_kem';
}

String fileExtension(String fileName) {
  final dotIndex = fileName.lastIndexOf('.');
  if (dotIndex < 0 || dotIndex == fileName.length - 1) return '';
  return fileName.substring(dotIndex + 1);
}

Color fileAccentColor(String fileName) {
  final ext = fileExtension(fileName).toLowerCase();
  switch (ext) {
    case 'pdf':
      return const Color(0xFFE11D48); // Rose
    case 'doc':
    case 'docx':
      return const Color(0xFF2563EB); // Blue
    case 'xls':
    case 'xlsx':
      return const Color(0xFF16A34A); // Green
    case 'ppt':
    case 'pptx':
      return const Color(0xFFEA580C); // Orange
    case 'zip':
    case 'rar':
      return const Color(0xFF9333EA); // Purple
    case 'txt':
      return const Color(0xFF475569); // Slate
    default:
      return AppColors.primary;
  }
}

IconData fileIcon(String fileName) {
  final ext = fileExtension(fileName).toLowerCase();
  switch (ext) {
    case 'pdf':
      return LucideIcons.fileText;
    case 'doc':
    case 'docx':
      return LucideIcons.fileCode;
    case 'xls':
    case 'xlsx':
      return LucideIcons.fileSpreadsheet;
    case 'ppt':
    case 'pptx':
      return LucideIcons.presentation;
    case 'zip':
    case 'rar':
      return LucideIcons.archive;
    default:
      return LucideIcons.file;
  }
}

bool hasAttachmentOrDocument(Message message) {
  if (message.attachmentIds.isNotEmpty) return true;
  final fileName = attachmentFileName(message);
  return isImageAttachment(message, fileName) || fileExtension(fileName).isNotEmpty;
}

bool isImageAttachment(Message message, String fileName) {
  final ext = fileExtension(fileName).toLowerCase();
  if (ext == 'jpg' ||
      ext == 'jpeg' ||
      ext == 'png' ||
      ext == 'gif' ||
      ext == 'webp') {
    return true;
  }
  final mime = message.attachmentMimeType?.toLowerCase() ?? '';
  return mime.startsWith('image/');
}

String? documentThumbnailUrl(Message message) {
  if (message.attachmentIds.isNotEmpty) {
    final attachmentId = message.attachmentIds.first;
    return '/api/v1/mobile/attachments/$attachmentId/download';
  }
  return message.attachmentUrl;
}

String formatFileSize(int? bytes) {
  if (bytes == null || bytes <= 0) return '0 B';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
}
