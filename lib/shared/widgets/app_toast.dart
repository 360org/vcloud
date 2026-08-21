import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../core/theme/app_theme.dart';

/// Các biến thể của Toast thông báo.
enum AppToastType {
  success,
  error,
  warning,
  info,
}

/// Hệ thống thông báo nổi (Floating Toast Banner) chuẩn UI/UX hiện đại.
/// Thiết kế thẻ nổi (floating pill/card), bo góc mềm mại, đổ bóng đa tầng,
/// tương thích hoàn hảo chế độ Sáng / Tối (Light / Dark mode).
class AppToast {
  AppToast._();

  /// Hiển thị thông báo Thành công (Success)
  static void success(
    BuildContext context, {
    required String title,
    String? message,
    Duration duration = const Duration(seconds: 3),
    VoidCallback? onAction,
    String? actionLabel,
  }) {
    show(
      context,
      type: AppToastType.success,
      title: title,
      message: message,
      duration: duration,
      onAction: onAction,
      actionLabel: actionLabel,
    );
  }

  /// Hiển thị thông báo Lỗi (Error / Danger)
  static void error(
    BuildContext context, {
    required String title,
    String? message,
    Duration duration = const Duration(seconds: 4),
    VoidCallback? onAction,
    String? actionLabel,
  }) {
    show(
      context,
      type: AppToastType.error,
      title: title,
      message: message,
      duration: duration,
      onAction: onAction,
      actionLabel: actionLabel,
    );
  }

  /// Hiển thị thông báo Cảnh báo (Warning)
  static void warning(
    BuildContext context, {
    required String title,
    String? message,
    Duration duration = const Duration(seconds: 3),
    VoidCallback? onAction,
    String? actionLabel,
  }) {
    show(
      context,
      type: AppToastType.warning,
      title: title,
      message: message,
      duration: duration,
      onAction: onAction,
      actionLabel: actionLabel,
    );
  }

  /// Hiển thị thông báo Thông tin (Info)
  static void info(
    BuildContext context, {
    required String title,
    String? message,
    Duration duration = const Duration(seconds: 3),
    VoidCallback? onAction,
    String? actionLabel,
  }) {
    show(
      context,
      type: AppToastType.info,
      title: title,
      message: message,
      duration: duration,
      onAction: onAction,
      actionLabel: actionLabel,
    );
  }

  /// Hiển thị Toast tổng quát với ScaffoldMessenger
  static void show(
    BuildContext context, {
    required AppToastType type,
    required String title,
    String? message,
    Duration duration = const Duration(seconds: 3),
    VoidCallback? onAction,
    String? actionLabel,
    double bottomMargin = 20,
  }) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: bottomMargin,
        ),
        padding: EdgeInsets.zero,
        duration: duration,
        content: _ToastCard(
          type: type,
          title: title,
          message: message,
          onAction: onAction,
          actionLabel: actionLabel,
          onDismiss: () => messenger.hideCurrentSnackBar(),
        ),
      ),
    );
  }
}

class _ToastCard extends StatelessWidget {
  const _ToastCard({
    required this.type,
    required this.title,
    this.message,
    this.onAction,
    this.actionLabel,
    required this.onDismiss,
  });

  final AppToastType type;
  final String title;
  final String? message;
  final VoidCallback? onAction;
  final String? actionLabel;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final (Color accentColor, IconData icon) = switch (type) {
      AppToastType.success => (const Color(0xFF00C83A), LucideIcons.checkCheck),
      AppToastType.error => (const Color(0xFFEF4444), LucideIcons.alertCircle),
      AppToastType.warning => (const Color(0xFFF59E0B), LucideIcons.alertTriangle),
      AppToastType.info => (const Color(0xFF3B82F6), LucideIcons.info),
    };

    final cardBg = isDark ? const Color(0xFF1E293B) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final descColor = isDark ? Colors.white70 : const Color(0xFF64748B);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : accentColor.withValues(alpha: 0.22),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: -2,
          ),
          BoxShadow(
            color: accentColor.withValues(alpha: isDark ? 0.2 : 0.1),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              // Icon Badge
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  icon,
                  color: accentColor,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),

              // Title & Message Content
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (message != null && message!.trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        message!.trim(),
                        style: TextStyle(
                          color: descColor,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          height: 1.25,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),

              // Action button (optional)
              if (onAction != null && actionLabel != null) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    onDismiss();
                    onAction!();
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    backgroundColor: accentColor.withValues(alpha: 0.12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text(
                    actionLabel!,
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],

              // Close / Dismiss Icon
              const SizedBox(width: 6),
              InkWell(
                onTap: onDismiss,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    LucideIcons.x,
                    size: 17,
                    color: isDark ? Colors.white38 : AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
