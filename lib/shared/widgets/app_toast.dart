import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';

/// Các biến thể của Toast thông báo.
enum AppToastType {
  success,
  error,
  warning,
  info,
}

/// Hệ thống thông báo nổi trên đỉnh màn hình (Top Floating Toast Banner) chuẩn Apple HIG / Modern UI.
/// Hiển thị trượt mượt mà từ đỉnh màn hình, không che khuất thanh điều hướng hay danh sách dưới đáy.
class AppToast {
  AppToast._();

  static OverlayEntry? _currentEntry;
  static _TopToastBannerState? _currentBannerState;

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

  /// Hiển thị Toast trên đỉnh màn hình (Top Banner)
  static void show(
    BuildContext context, {
    required AppToastType type,
    required String title,
    String? message,
    Duration duration = const Duration(seconds: 3),
    VoidCallback? onAction,
    String? actionLabel,
    double bottomMargin = 20, // Giữ để tương thích chữ ký cũ nếu có gọi
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true) ??
        rootNavigatorKey.currentState?.overlay;
    if (overlay == null) {
      _fallbackShowSnackBar(
        type: type,
        title: title,
        message: message,
        duration: duration,
        onAction: onAction,
        actionLabel: actionLabel,
      );
      return;
    }
    _displayTopToast(
      overlay: overlay,
      type: type,
      title: title,
      message: message,
      duration: duration,
      onAction: onAction,
      actionLabel: actionLabel,
    );
  }

  /// Hiển thị Toast toàn cục không cần BuildContext
  static void showGlobal({
    required AppToastType type,
    required String title,
    String? message,
    Duration duration = const Duration(seconds: 3),
    VoidCallback? onAction,
    String? actionLabel,
    double bottomMargin = 20,
  }) {
    final overlay = rootNavigatorKey.currentState?.overlay;
    if (overlay == null) {
      _fallbackShowSnackBar(
        type: type,
        title: title,
        message: message,
        duration: duration,
        onAction: onAction,
        actionLabel: actionLabel,
      );
      return;
    }
    _displayTopToast(
      overlay: overlay,
      type: type,
      title: title,
      message: message,
      duration: duration,
      onAction: onAction,
      actionLabel: actionLabel,
    );
  }

  static void _displayTopToast({
    required OverlayState overlay,
    required AppToastType type,
    required String title,
    String? message,
    required Duration duration,
    VoidCallback? onAction,
    String? actionLabel,
  }) {
    // Nếu đang có toast cũ, gỡ bỏ nhanh trước khi hiện toast mới
    _dismissCurrent();

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) {
        return Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Material(
            color: Colors.transparent,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.only(top: 8, left: 16, right: 16),
                child: _TopToastBanner(
                  type: type,
                  title: title,
                  message: message,
                  duration: duration,
                  onAction: onAction,
                  actionLabel: actionLabel,
                  onRegisterState: (state) => _currentBannerState = state,
                  onDismissed: () {
                    if (_currentEntry == entry) {
                      _currentEntry = null;
                      _currentBannerState = null;
                    }
                    entry.remove();
                  },
                ),
              ),
            ),
          ),
        );
      },
    );

    _currentEntry = entry;
    overlay.insert(entry);
  }

  static void _dismissCurrent() {
    if (_currentBannerState != null) {
      _currentBannerState!.dismiss();
      _currentBannerState = null;
    } else if (_currentEntry != null) {
      _currentEntry!.remove();
      _currentEntry = null;
    }
  }

  static void _fallbackShowSnackBar({
    required AppToastType type,
    required String title,
    String? message,
    required Duration duration,
    VoidCallback? onAction,
    String? actionLabel,
  }) {
    final messenger = rootScaffoldMessengerKey.currentState;
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.only(left: 16, right: 16, bottom: 20),
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

/// Global key to access ScaffoldMessenger from anywhere
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

class _TopToastBanner extends StatefulWidget {
  const _TopToastBanner({
    required this.type,
    required this.title,
    this.message,
    required this.duration,
    this.onAction,
    this.actionLabel,
    required this.onDismissed,
    required this.onRegisterState,
  });

  final AppToastType type;
  final String title;
  final String? message;
  final Duration duration;
  final VoidCallback? onAction;
  final String? actionLabel;
  final VoidCallback onDismissed;
  final ValueChanged<_TopToastBannerState> onRegisterState;

  @override
  State<_TopToastBanner> createState() => _TopToastBannerState();
}

class _TopToastBannerState extends State<_TopToastBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;
  Timer? _dismissTimer;
  bool _isDismissing = false;

  @override
  void initState() {
    super.initState();
    widget.onRegisterState(this);

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      reverseDuration: const Duration(milliseconds: 240),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutBack,
        reverseCurve: Curves.easeInCubic,
      ),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
        reverseCurve: Curves.easeIn,
      ),
    );

    _controller.forward();

    _dismissTimer = Timer(widget.duration, () {
      dismiss();
    });
  }

  void dismiss() {
    if (_isDismissing || !mounted) return;
    _isDismissing = true;
    _dismissTimer?.cancel();
    _controller.reverse().then((_) {
      if (mounted) {
        widget.onDismissed();
      }
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: GestureDetector(
          onVerticalDragUpdate: (details) {
            // Vuốt ngược lên trên để đóng toast ngay lập tức
            if (details.primaryDelta != null && details.primaryDelta! < -4) {
              dismiss();
            }
          },
          child: _ToastCard(
            type: widget.type,
            title: widget.title,
            message: widget.message,
            onAction: widget.onAction,
            actionLabel: widget.actionLabel,
            onDismiss: dismiss,
          ),
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
