import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

/// Popup dialog nhắc nhở người dùng bật vị trí (GPS) trên thiết bị/trình duyệt
/// khi thực hiện Check-in hoặc Check-out.
Future<void> showLocationPromptDialog(
  BuildContext context, {
  String? message,
}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) => Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFFCA5A5),
                  width: 2,
                ),
              ),
              child: const Icon(
                LucideIcons.mapPin,
                color: Color(0xFFEF4444),
                size: 34,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Yêu cầu bật vị trí (GPS)',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              (message != null && message.trim().isNotEmpty)
                  ? message
                  : 'Vui lòng bật dịch vụ vị trí (GPS) và cấp quyền vị trí trên thiết bị hoặc trình duyệt của bạn để thực hiện Check-in / Check-out.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Đóng',
                      style: TextStyle(
                        color: Color(0xFF475569),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.of(dialogContext).pop();
                      try {
                        await Geolocator.openLocationSettings();
                      } catch (_) {
                        try {
                          await Geolocator.openAppSettings();
                        } catch (_) {}
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Bật vị trí',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

/// Kiểm tra xem lỗi có phải do dịch vụ vị trí / GPS bị tắt hoặc bị từ chối không.
bool isLocationError(dynamic error) {
  if (error == null) return false;
  final msg = error.toString().toLowerCase();
  return msg.contains('location') ||
      msg.contains('vị trí') ||
      msg.contains('gps') ||
      msg.contains('permission') ||
      msg.contains('denied') ||
      msg.contains('service');
}
