import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';

import 'file_download.dart';

/// Tiện ích lưu ảnh & video trực tiếp vào Thư viện hệ thống (Native Gallery / Photos Album)
class GallerySaver {
  const GallerySaver._();

  /// Lưu chuỗi bytes ảnh vào Gallery
  /// - Trên Web: Fallback về hàm tải tệp mặc định của trình duyệt (`saveBytesToFile`).
  /// - Trên Mobile (iOS / Android): Sử dụng thư viện `gal` để ghi thẳng vào MediaStore / Photos Album.
  static Future<bool> saveImage({
    required Uint8List bytes,
    required String fileName,
  }) async {
    if (bytes.isEmpty) {
      throw Exception('Dữ liệu ảnh rỗng');
    }

    if (kIsWeb) {
      return await saveBytesToFile(bytes, fileName);
    }

    try {
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        final granted = await Gal.requestAccess();
        if (!granted) {
          throw Exception('Ứng dụng chưa được cấp quyền truy cập Thư viện ảnh');
        }
      }

      final nameWithoutExt = fileName.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '').trim();
      final effectiveName = nameWithoutExt.isNotEmpty ? nameWithoutExt : 'image_${DateTime.now().millisecondsSinceEpoch}';

      await Gal.putImageBytes(
        bytes,
        name: effectiveName,
      );
      return true;
    } on GalException catch (e) {
      debugPrint('[GallerySaver] GalException: ${e.type.code} - ${e.type.message}');
      if (e.type == GalExceptionType.accessDenied) {
        throw Exception('Không có quyền truy cập Thư viện ảnh');
      }

      // Fallback: Thử lưu bằng saveBytesToFile nếu Gal không ghi được MediaStore (vd trên Waydroid)
      try {
        final saved = await saveBytesToFile(bytes, fileName);
        if (saved) return true;
      } catch (_) {}

      if (e.type == GalExceptionType.notEnoughSpace) {
        throw Exception('Bộ nhớ thiết bị không đủ dung lượng');
      } else if (e.type == GalExceptionType.notSupportedFormat) {
        throw Exception('Định dạng hình ảnh không được hỗ trợ');
      } else {
        throw Exception('Lỗi lưu ảnh: ${e.type.message}');
      }
    } on PlatformException catch (e) {
      debugPrint('[GallerySaver] PlatformException: ${e.code} - ${e.message}');
      try {
        final saved = await saveBytesToFile(bytes, fileName);
        if (saved) return true;
      } catch (_) {}
      throw Exception('Không thể lưu ảnh vào thư viện: ${e.message ?? e.code}');
    } catch (e) {
      debugPrint('[GallerySaver] Error: $e');
      try {
        final saved = await saveBytesToFile(bytes, fileName);
        if (saved) return true;
      } catch (_) {}
      rethrow;
    }
  }

  /// Lưu video trực tiếp vào Thư viện hệ thống (Native Gallery / Photos Album)
  /// - Nhận vào [bytes] hoặc [filePath], kèm [fileName].
  /// - Trên Web: Fallback về hàm tải tệp mặc định của trình duyệt (`saveBytesToFile`).
  /// - Trên Mobile (iOS / Android): Sử dụng thư viện `gal` (`Gal.putVideo`) ghi vào MediaStore / Photos Album.
  static Future<bool> saveVideo({
    Uint8List? bytes,
    String? filePath,
    required String fileName,
  }) async {
    if ((bytes == null || bytes.isEmpty) && (filePath == null || filePath.isEmpty)) {
      throw Exception('Dữ liệu video rỗng');
    }

    if (kIsWeb) {
      if (bytes != null && bytes.isNotEmpty) {
        return await saveBytesToFile(bytes, fileName);
      }
      throw Exception('Không hỗ trợ lưu video từ đường dẫn tệp trên trình duyệt web');
    }

    File? tempFile;
    try {
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        final granted = await Gal.requestAccess();
        if (!granted) {
          throw Exception('Ứng dụng chưa được cấp quyền truy cập Thư viện');
        }
      }

      String targetPath;
      if (filePath != null && filePath.isNotEmpty && await File(filePath).exists()) {
        targetPath = filePath;
      } else if (bytes != null && bytes.isNotEmpty) {
        final extMatch = RegExp(r'\.([a-zA-Z0-9]+)$').firstMatch(fileName);
        final ext = (extMatch != null && extMatch.group(1) != null)
            ? '.${extMatch.group(1)}'
            : '.mp4';

        final tempDir = await getTemporaryDirectory();
        final tempFileName = 'vcloud_save_vid_${DateTime.now().millisecondsSinceEpoch}$ext';
        tempFile = File('${tempDir.path}/$tempFileName');
        await tempFile.writeAsBytes(bytes, flush: true);
        targetPath = tempFile.path;
      } else {
        throw Exception('Không tìm thấy đường dẫn hoặc dữ liệu video hợp lệ');
      }

      await Gal.putVideo(targetPath);
      return true;
    } on GalException catch (e) {
      debugPrint('[GallerySaver] GalException: ${e.type.code} - ${e.type.message}');
      if (e.type == GalExceptionType.accessDenied) {
        throw Exception('Không có quyền truy cập Thư viện ảnh');
      }

      // Fallback: Thử lưu bằng saveBytesToFile nếu Gal không ghi được MediaStore (vd trên Waydroid)
      try {
        if (bytes != null && bytes.isNotEmpty) {
          final saved = await saveBytesToFile(bytes, fileName);
          if (saved) return true;
        }
      } catch (_) {}

      if (e.type == GalExceptionType.notEnoughSpace) {
        throw Exception('Bộ nhớ thiết bị không đủ dung lượng');
      } else if (e.type == GalExceptionType.notSupportedFormat) {
        throw Exception('Định dạng video không được hỗ trợ');
      } else {
        throw Exception('Lỗi lưu video: ${e.type.message}');
      }
    } on PlatformException catch (e) {
      debugPrint('[GallerySaver] PlatformException: ${e.code} - ${e.message}');
      try {
        if (bytes != null && bytes.isNotEmpty) {
          final saved = await saveBytesToFile(bytes, fileName);
          if (saved) return true;
        }
      } catch (_) {}
      throw Exception('Không thể lưu video vào thư viện: ${e.message ?? e.code}');
    } catch (e) {
      debugPrint('[GallerySaver] Error: $e');
      try {
        if (bytes != null && bytes.isNotEmpty) {
          final saved = await saveBytesToFile(bytes, fileName);
          if (saved) return true;
        }
      } catch (_) {}
      rethrow;
    } finally {
      if (tempFile != null) {
        try {
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        } catch (delErr) {
          debugPrint('[GallerySaver] Xóa file video tạm thất bại: $delErr');
        }
      }
    }
  }
}
