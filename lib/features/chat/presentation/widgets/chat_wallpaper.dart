import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:vcloud/core/theme/app_theme.dart';
import 'package:vcloud/shared/models/profile.dart';

class ChatWallpaper extends StatelessWidget {
  const ChatWallpaper({super.key});

  static const _icons = [
    LucideIcons.messageCircle,
    LucideIcons.image,
    LucideIcons.camera,
    LucideIcons.paperclip,
    LucideIcons.send,
    LucideIcons.smile,
    LucideIcons.star,
    LucideIcons.cloud,
    LucideIcons.coffee,
    LucideIcons.heart,
    LucideIcons.mapPin,
    LucideIcons.calendar,
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? const [Color(0xFF0B101E), Color(0xFF111827), Color(0xFF0B101E)]
              : const [Color(0xFFE8F5B8), Color(0xFFBFE9C9), Color(0xFF8ED8BE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = (constraints.maxWidth / 72).ceil() + 1;
          final rows = (constraints.maxHeight / 72).ceil() + 1;
          return Stack(
            children: [
              for (var row = 0; row < rows; row++)
                for (var col = 0; col < columns; col++)
                  Positioned(
                    left: col * 72.0 + (row.isEven ? 4 : 38),
                    top: row * 72.0,
                    child: Transform.rotate(
                      angle: ((row + col) % 5 - 2) * 0.14,
                      child: Icon(
                        _icons[(row * columns + col) % _icons.length],
                        size: 30 + ((row + col) % 3) * 5,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.035)
                            : AppColors.midnight.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }
}

bool isCurrentProfile(Profile profile, Set<String> currentIdentityIds) {
  final labels = currentIdentityIds
      .map((label) => label.trim().toLowerCase())
      .where((label) => label.isNotEmpty)
      .toSet();
  if (labels.isEmpty) return false;
  return labels.contains(profile.id.trim().toLowerCase()) ||
      labels.contains(profile.email.trim().toLowerCase()) ||
      labels.contains(profile.displayName.trim().toLowerCase());
}

class FrostedSurface extends StatelessWidget {
  const FrostedSurface({
    super.key,
    required this.child,
    this.height,
    this.padding,
    this.radius = 28,
    this.isFocused = false,
  });

  final Widget child;
  final double? height;
  final EdgeInsetsGeometry? padding;
  final double radius;
  final bool isFocused;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            color: isDark
                ? (isFocused
                    ? AppColors.darkSurfaceElevated.withValues(alpha: 0.92)
                    : AppColors.darkSurface.withValues(alpha: 0.78))
                : (isFocused
                    ? Colors.white.withValues(alpha: 0.76)
                    : Colors.white.withValues(alpha: 0.58)),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: isDark
                  ? (isFocused
                      ? AppColors.primary.withValues(alpha: 0.9)
                      : context.borderColor)
                  : (isFocused
                      ? AppColors.primary.withValues(alpha: 0.85)
                      : Colors.white.withValues(alpha: 0.72)),
              width: isFocused ? 1.6 : 1.1,
            ),
            boxShadow: isFocused
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      blurRadius: 14,
                      spreadRadius: 1,
                    ),
                    const BoxShadow(
                      color: Color(0x140F172A),
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ]
                : const [
                    BoxShadow(
                      color: Color(0x140F172A),
                      blurRadius: 18,
                      offset: Offset(0, 8),
                    ),
                  ],
          ),
          child: child,
        ),
      ),
    );
  }
}
