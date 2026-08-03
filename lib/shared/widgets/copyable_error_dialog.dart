import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../core/theme/app_theme.dart';

/// Hiển thị AlertDialog chứa SelectableText và nút Copy Lỗi
/// cho phép người dùng sao chép toàn bộ nguyên nhân + StackTrace.
Future<void> showCopyableErrorDialog(
  BuildContext context, {
  required String title,
  required Object error,
  StackTrace? stackTrace,
}) async {
  final fullText = '$error${stackTrace != null ? '\n\n$stackTrace' : ''}';
  final isDark = Theme.of(context).brightness == Brightness.dark;

  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Icon(LucideIcons.triangleAlert, color: AppColors.danger, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: isDark ? Colors.white : AppColors.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 18,
              ),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.45,
        ),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : AppColors.border,
            ),
          ),
          child: SingleChildScrollView(
            child: SelectableText(
              fullText,
              style: TextStyle(
                fontSize: 12.5,
                fontFamily: 'monospace',
                color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                height: 1.35,
              ),
            ),
          ),
        ),
      ),
      actions: [
        ElevatedButton.icon(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: fullText));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('📋 Đã sao chép toàn bộ thông tin lỗi vào Bộ nhớ tạm!'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          icon: const Icon(LucideIcons.copy, size: 16),
          label: const Text('Copy Lỗi'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Đóng'),
        ),
      ],
    ),
  );
}
