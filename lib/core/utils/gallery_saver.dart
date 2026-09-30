import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';

import 'file_download.dart';

/// Tiện ích lưu ảnh trực tiếp vào Thư viện ảnh hệ thống (Native Gallery / Photos Album)
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
}
