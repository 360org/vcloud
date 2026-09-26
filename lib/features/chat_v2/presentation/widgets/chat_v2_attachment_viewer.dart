import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/api/mobile_attachment_repository.dart';
import '../../../../core/api/odoo_api_client.dart';
import '../../../../core/utils/magic_bytes_validator.dart';

/// Trình xử lý mở tài liệu trực tiếp trong ứng dụng (In-App Document Viewer)
/// Sử dụng open_filex để mở tài liệu (PDF, Word, Excel, TXT,...) qua native viewer.
/// 🛑 QUY TẮC AN TOÀN: Tuyệt đối KHÔNG fallback mở qua trình duyệt ngoài bằng url_launcher.
class ChatV2AttachmentViewer {
  ChatV2AttachmentViewer._();

  /// Mock opener phục vụ kiểm thử (Unit / Widget Test)
  @visibleForTesting
  static Future<OpenResult> Function(String filePath, {String? type})? customOpener;

  /// Mock fetcher phục vụ kiểm thử
  @visibleForTesting
  static Future<Uint8List> Function(String target)? customFetcher;

  /// Mock directory resolver phục vụ kiểm thử
  @visibleForTesting
  static Future<String> Function()? customDirResolver;

  /// Mở tài liệu trực tiếp in-app
  static Future<OpenResult> open({
    required BuildContext context,
    required String filename,
    int? attachmentId,
    String? downloadUrl,
    Uint8List? directBytes,
  }) async {
    final cleanName = filename.trim();
    final messenger = ScaffoldMessenger.of(context);

    // 1. Hiển thị thông báo trạng thái tải tài liệu trực quan
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Đang tải tệp tin: $cleanName...',
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
      ),
    );

    try {
      Uint8List? bytes = directBytes;

      // 2. Nạp bytes nếu chưa có sẵn
      if (bytes == null || bytes.isEmpty) {
        if (customFetcher != null) {
          bytes = await customFetcher!(cleanName);
        } else {
          // Chuẩn hóa downloadUrl
          String? targetUrl = downloadUrl;
          if (targetUrl != null &&
              !targetUrl.startsWith('http://') &&
              !targetUrl.startsWith('https://') &&
              !targetUrl.startsWith('/')) {
            targetUrl = null;
          }

          if (targetUrl == null && attachmentId != null && attachmentId > 0) {
            targetUrl = '/api/v1/mobile/attachments/$attachmentId/download';
          }

          if (targetUrl != null && targetUrl.isNotEmpty) {
            try {
              bytes = await odooApiClient.fetchBytes(targetUrl);
            } catch (err) {
              debugPrint('[ChatV2AttachmentViewer] odooApiClient.fetchBytes error: $err');
              // Fallback qua MobileAttachmentRepository
              if (attachmentId != null && attachmentId > 0) {
                try {
                  bytes = await MobileAttachmentRepository().fetchBytes(attachmentId);
                } catch (repoErr) {
                  debugPrint('[ChatV2AttachmentViewer] MobileAttachmentRepository error: $repoErr');
                }
              }
            }
          } else if (attachmentId != null && attachmentId > 0) {
            try {
              bytes = await MobileAttachmentRepository().fetchBytes(attachmentId);
            } catch (e) {
              debugPrint('[ChatV2AttachmentViewer] Fallback fetchBytes by ID error: $e');
            }
          }
        }
      }

      // 3. Kiểm tra dữ liệu nạp
      if (bytes == null || bytes.isEmpty) {
        if (context.mounted) {
          messenger.hideCurrentSnackBar();
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Không thể tải dữ liệu tệp tin hoặc tệp tin rỗng trên máy chủ.'),
              duration: Duration(seconds: 3),
              backgroundColor: Color(0xFFE11D48),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return OpenResult(type: ResultType.fileNotFound, message: 'empty_bytes');
      }

      // 4. Kiểm tra magic bytes tránh placeholder lỗi của server
      if (MagicBytesValidator.isMistakenImagePayloadForDocument(cleanName, bytes)) {
        if (context.mounted) {
          messenger.hideCurrentSnackBar();
          messenger.showSnackBar(
            const SnackBar(
              content: Text('Tệp tin gốc không tồn tại hoặc bạn không có quyền truy cập trên máy chủ.'),
              duration: Duration(seconds: 3),
              backgroundColor: Color(0xFFE11D48),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return OpenResult(type: ResultType.error, message: 'invalid_image_placeholder');
      }

      // 5. Lưu tệp tin vào thư mục lưu trữ cục bộ tạm thời của ứng dụng
      String dirPath;
      if (customDirResolver != null) {
        dirPath = await customDirResolver!();
      } else {
        try {
          final tempDir = await getTemporaryDirectory();
          dirPath = tempDir.path;
        } catch (_) {
          final docDir = await getApplicationDocumentsDirectory();
          dirPath = docDir.path;
        }
      }

      final safeName = cleanName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final filePath = '$dirPath/$safeName';
      final file = File(filePath);
      file.writeAsBytesSync(bytes, flush: true);

      // 6. Mở trực tiếp tài liệu ngay trong ứng dụng với open_filex
      final OpenResult result;
      if (customOpener != null) {
        result = await customOpener!(filePath);
      } else {
        result = await OpenFilex.open(filePath);
      }

      if (context.mounted) {
        messenger.hideCurrentSnackBar();

        switch (result.type) {
          case ResultType.done:
            // Mở thành công trực tiếp in-app
            break;
          case ResultType.noAppToOpen:
            final ext = cleanName.contains('.') ? cleanName.split('.').last.toUpperCase() : 'tài liệu';
            messenger.showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(LucideIcons.alertCircle, color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Không tìm thấy ứng dụng phù hợp để đọc tệp $ext ($cleanName). Vui lòng cài đặt ứng dụng đọc tài liệu chuyên dụng.',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
                backgroundColor: const Color(0xFFD97706),
                duration: const Duration(seconds: 4),
                behavior: SnackBarBehavior.floating,
              ),
            );
            break;
          case ResultType.fileNotFound:
            messenger.showSnackBar(
              const SnackBar(
                content: Text('Không tìm thấy tệp tin sau khi lưu tạm.'),
                backgroundColor: Color(0xFFE11D48),
                duration: Duration(seconds: 3),
                behavior: SnackBarBehavior.floating,
              ),
            );
            break;
          case ResultType.permissionDenied:
            messenger.showSnackBar(
              const SnackBar(
                content: Text('Quyền truy cập tệp tin trên thiết bị bị từ chối.'),
                backgroundColor: Color(0xFFE11D48),
                duration: Duration(seconds: 3),
                behavior: SnackBarBehavior.floating,
              ),
            );
            break;
          case ResultType.error:
            messenger.showSnackBar(
              SnackBar(
                content: Text('Lỗi khi mở tệp tin: ${result.message}'),
                backgroundColor: const Color(0xFFE11D48),
                duration: const Duration(seconds: 3),
                behavior: SnackBarBehavior.floating,
              ),
            );
            break;
        }
      }

      return result;
    } catch (e) {
      debugPrint('[ChatV2AttachmentViewer] Ngoại lệ khi mở tệp: $e');
      if (context.mounted) {
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            content: Text('Không thể mở tệp tin: $e'),
            backgroundColor: const Color(0xFFE11D48),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return OpenResult(type: ResultType.error, message: e.toString());
    }
  }
}
