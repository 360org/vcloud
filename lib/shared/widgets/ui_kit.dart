import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../core/theme/app_theme.dart';

/// Wraps a child so it springs down slightly on touch (with a light haptic),
/// giving every tappable surface a premium, tactile feel.
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.scale = 0.97,
    this.haptic = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final bool haptic;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null ? null : (_) => _set(true),
      onTapCancel: () => _set(false),
      onTapUp: widget.onTap == null ? null : (_) => _set(false),
      onTap: widget.onTap == null
          ? null
          : () {
              if (widget.haptic) HapticFeedback.lightImpact();
              widget.onTap!();
            },
      child: Semantics(
        button: widget.onTap != null,
        child: AnimatedScale(
          scale: _down ? widget.scale : 1.0,
          duration: const Duration(milliseconds: 110),
          curve: Curves.easeOut,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Full-width gradient CTA with colored glow + press feedback + haptics.
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.gradient = AppColors.brand,
    this.glowColor = AppColors.primary,
    this.icon,
    this.loading = false,
    this.height = 54,
  });

  final String label;
  final VoidCallback? onPressed;
  final Gradient gradient;
  final Color glowColor;
  final IconData? icon;
  final bool loading;
  final double height;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: PressableScale(
        onTap: enabled ? onPressed : null,
        child: Opacity(
          opacity: enabled ? 1 : 0.55,
          child: Container(
            height: height,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: enabled ? gradient : null,
              color: enabled
                  ? null
                  : AppColors.textMuted.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(16),
              boxShadow: enabled
                  ? AppColors.glow(glowColor, opacity: 0.4)
                  : null,
            ),
            child: loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, color: Colors.white, size: 20),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Counts up from 0 to [value] when first shown — used on dashboard stat
/// tiles so numbers feel alive instead of static.
class AnimatedCount extends StatelessWidget {
  const AnimatedCount({
    super.key,
    required this.value,
    required this.style,
    this.decimals = 0,
  });

  final double value;
  final TextStyle style;
  final int decimals;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: const Duration(milliseconds: 750),
      curve: Curves.easeOutCubic,
      builder: (_, v, _) {
        final text = decimals == 0
            ? v.round().toString()
            : v.toStringAsFixed(decimals);
        return Text(text, style: style);
      },
    );
  }
}

/// Glassmorphism card — frosted glass effect with subtle border and glow.
/// Use this as the primary card container for a premium feel.
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 20,
    this.glowColor,
    this.borderOpacity,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? glowColor;
  final double? borderOpacity;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E293B) : AppColors.surface;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : AppColors.border.withValues(alpha: 0.6);
    return Container(
      padding: padding,
      decoration: glassDecoration(color: cardBg, radius: radius).copyWith(
        border: Border.all(color: borderColor, width: 0.5),
        boxShadow: glowColor != null
            ? AppColors.glassGlow(glowColor!)
            : glassDecoration(color: cardBg, radius: radius).boxShadow,
      ),
      child: child,
    );
  }

}

/// Gradient background header — animated gradient that shifts subtly.
class GradientHeader extends StatelessWidget {
  const GradientHeader({
    super.key,
    required this.child,
    this.gradient,
    this.height,
    this.padding,
  });

  final Widget child;
  final Gradient? gradient;
  final double? height;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: height,
      padding: padding,
      decoration: BoxDecoration(gradient: gradient ?? AppColors.midnightGrad),
      child: child,
    );
  }
}

/// Pill badge with gradient fill — used for status indicators.
class GradientBadge extends StatelessWidget {
  const GradientBadge({
    super.key,
    required this.label,
    required this.gradient,
    this.textColor = Colors.white,
    this.fontSize = 11,
  });

  final String label;
  final Gradient gradient;
  final Color textColor;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontSize: fontSize,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

/// Stat tile with animated count and gradient icon chip — used on dashboard.
/// Compact semantic status pill with a colored dot.
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.color,
    this.onTap,
    this.icon,
    this.fontSize = 13,
  });

  final String label;
  final Color color;
  final VoidCallback? onTap;
  final IconData? icon;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.soft(color),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: color, size: 14),
            const SizedBox(width: 5),
          ] else ...[
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return content;
    return PressableScale(onTap: onTap, child: content);
  }
}

/// Compact section header with an optional trailing action.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.onTrailingTap,
  });

  final String title;
  final String? trailing;
  final VoidCallback? onTrailingTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: AppTextStyles.title.copyWith(color: AppColors.textPrimary),
          ),
        ),
        if (trailing != null)
          TextButton(
            onPressed: onTrailingTap,
            style: TextButton.styleFrom(
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: Text(trailing!),
          ),
      ],
    );
  }
}

/// Small command tile for Home quick actions.
class CompactActionTile extends StatelessWidget {
  const CompactActionTile({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.badgeCount = 0,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxHeight < 96;
          final padding = compact ? 12.0 : 14.0;
          final iconSize = compact ? 32.0 : 36.0;
          final iconRadius = compact ? 10.0 : 12.0;
          final labelFontSize = compact ? 12.0 : 13.0;

          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Container(
            padding: EdgeInsets.all(padding),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : AppColors.border,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x080F172A),
                  blurRadius: 14,
                  offset: Offset(0, 6),
                ),
              ],
            ),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: iconSize,
                      height: iconSize,
                      decoration: BoxDecoration(
                        color: AppColors.soft(color),
                        borderRadius: BorderRadius.circular(iconRadius),
                      ),
                      child: Icon(icon, color: color, size: compact ? 17 : 19),
                    ),
                    const Spacer(),
                    UnreadBadge(count: badgeCount, compact: true),
                  ],
                ),
                SizedBox(height: compact ? 8 : 12),
                Expanded(
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: labelFontSize,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Two-option segmented control for compact filters.
class SegmentedTabs extends StatelessWidget {
  const SegmentedTabs({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onChanged,
  }) : assert(labels.length == 2, 'SegmentedTabs supports exactly 2 labels.');

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF2F7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: PressableScale(
                onTap: () => onChanged(i),
                haptic: selectedIndex != i,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: selectedIndex == i
                        ? AppColors.midnight
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(13),
                    boxShadow: selectedIndex == i
                        ? const [
                            BoxShadow(
                              color: Color(0x160F172A),
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      color: selectedIndex == i
                          ? Colors.white
                          : AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class QuickAttachmentAction {
  const QuickAttachmentAction({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;
}

/// Shared placeholder attachment sheet. V1 deliberately does not upload files.
class QuickAttachmentSheet extends StatelessWidget {
  const QuickAttachmentSheet({
    super.key,
    required this.onSelected,
    this.title = 'Dinh kem',
  });

  final ValueChanged<QuickAttachmentAction> onSelected;
  final String title;

  static const actions = <QuickAttachmentAction>[
    QuickAttachmentAction(
      label: 'Anh',
      icon: LucideIcons.image,
      color: AppColors.chat,
    ),
    QuickAttachmentAction(
      label: 'Camera',
      icon: LucideIcons.camera,
      color: AppColors.timesheet,
    ),
    QuickAttachmentAction(
      label: 'Tai lieu',
      icon: LucideIcons.fileText,
      color: AppColors.primary,
    ),
    QuickAttachmentAction(
      label: 'Tep',
      icon: LucideIcons.file,
      color: AppColors.ticket,
    ),
    QuickAttachmentAction(
      label: 'Vi tri',
      icon: LucideIcons.mapPin,
      color: AppColors.danger,
    ),
    QuickAttachmentAction(
      label: 'Lien he',
      icon: LucideIcons.user,
      color: AppColors.attendance,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),

      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 16),
            SectionHeader(title: title),
            const SizedBox(height: 8),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.1,
              children: [
                for (final action in actions)
                  PressableScale(
                    onTap: () => onSelected(action),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.soft(action.color),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: action.color.withValues(alpha: 0.14),
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(action.icon, color: action.color, size: 24),
                          const SizedBox(height: 8),
                          Text(
                            action.label,
                            style: TextStyle(
                              color: action.color,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.icon,
    required this.color,
    required this.deepColor,
    required this.label,
    required this.value,
    required this.sub,
    this.decimals = 0,
    this.onTap,
  });

  final IconData icon;
  final Color color;
  final Color deepColor;
  final String label;
  final double value;
  final String sub;
  final int decimals;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: ${value.round()} $sub',
      button: onTap != null,
      child: PressableScale(
        onTap: onTap,
        child: GlassCard(
          padding: const EdgeInsets.all(16),
          radius: 16,
          glowColor: color,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: AppColors.featureGrad(color, deepColor),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: AppColors.glow(color, opacity: 0.25),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(height: 14),
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 6),
              AnimatedCount(
                value: value,
                decimals: decimals,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sub,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Unread count badge — gradient pill for conversation list items.
/// Requires backend support for unread_count field on conversations.
class UnreadBadge extends StatelessWidget {
  const UnreadBadge({
    super.key,
    required this.count,
    this.gradient = AppColors.brand,
    this.compact = false,
  });

  final int count;
  final Gradient gradient;
  final bool compact;

  static String format(int count) {
    if (count > 99) return '99+';
    if (count > 9) return '10+';
    return count.toString();
  }

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final displayText = format(count);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 3 : 4,
      ),
      constraints: BoxConstraints(
        minWidth: compact ? 18 : 22,
        minHeight: compact ? 18 : 22,
      ),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(999),
        boxShadow: compact
            ? null
            : AppColors.glow(AppColors.primary, opacity: 0.18),
      ),
      child: Text(
        displayText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// Message status indicator — single check (sent), double check (delivered/read).
/// Requires backend support for status field on messages.
class MessageStatusIcon extends StatelessWidget {
  const MessageStatusIcon({
    super.key,
    required this.status,
    this.size = 14,
    this.color,
  });

  final String status;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? AppColors.textMuted;
    switch (status) {
      case 'sent':
        return Icon(Icons.check, size: size, color: iconColor);
      case 'delivered':
      case 'read':
        return Icon(
          Icons.done_all,
          size: size,
          color: status == 'read' ? AppColors.primary : iconColor,
        );
      default:
        return Icon(Icons.access_time, size: size, color: iconColor);
    }
  }
}

/// Glass-styled search field with clear button — reusable across screens.
class GlassSearchField extends StatelessWidget {
  const GlassSearchField({
    super.key,
    required this.onChanged,
    this.hintText = 'Tìm kiếm...',
    this.controller,
    this.autofocus = false,
  });

  final ValueChanged<String> onChanged;
  final String hintText;
  final TextEditingController? controller;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: glassDecoration(radius: 14),
      child: TextField(
        controller: controller,
        autofocus: autofocus,
        onChanged: onChanged,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: const TextStyle(color: AppColors.textMuted),
          prefixIcon: const Icon(
            Icons.search,
            color: AppColors.textMuted,
            size: 20,
          ),
          filled: true,
          fillColor: AppColors.surface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

/// Glass-styled text field with label, hint, and optional prefix/suffix icons.
/// Reusable across forms for consistent styling.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.prefixIcon,
    this.suffixIcon,
    this.onChanged,
    this.onTap,
    this.readOnly = false,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.maxLines = 1,
    this.radius = 14,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final bool readOnly;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final int maxLines;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label ?? hint,
      textField: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (label != null) ...[
            Text(
              label!,
              style: AppTextStyles.label.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Container(
            decoration: glassDecoration(radius: radius),
            child: TextFormField(
              controller: controller,
              onChanged: onChanged,
              onTap: onTap,
              readOnly: readOnly,
              obscureText: obscureText,
              keyboardType: keyboardType,
              validator: validator,
              maxLines: maxLines,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
              ),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: const TextStyle(color: AppColors.textMuted),
                prefixIcon: prefixIcon != null
                    ? Icon(prefixIcon, color: AppColors.textMuted, size: 20)
                    : null,
                suffixIcon: suffixIcon,
                filled: true,
                fillColor: AppColors.surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(radius),
                  borderSide: BorderSide.none,
                ),
                errorBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(radius),
                  borderSide: const BorderSide(
                    color: AppColors.danger,
                    width: 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(radius),
                  borderSide: const BorderSide(
                    color: AppColors.primary,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Status badge with semantic colors — for ticket status, priority, etc.
class AppBadge extends StatelessWidget {
  const AppBadge({
    super.key,
    required this.label,
    this.color = AppColors.primary,
    this.textColor,
    this.size = AppBadgeSize.small,
    this.icon,
  });

  final String label;
  final Color color;
  final Color? textColor;
  final AppBadgeSize size;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final padding = size == AppBadgeSize.small
        ? const EdgeInsets.symmetric(horizontal: 8, vertical: 3)
        : const EdgeInsets.symmetric(horizontal: 12, vertical: 5);
    final fontSize = size == AppBadgeSize.small ? 11.0 : 13.0;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.soft(color),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: fontSize + 2, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

enum AppBadgeSize { small, medium }

/// Loading skeleton placeholder — animated shimmer effect for content loading.
class AppSkeleton extends StatefulWidget {
  const AppSkeleton({
    super.key,
    this.width,
    this.height = 16,
    this.radius = 8,
    this.lines = 1,
    this.spacing = 8,
  });

  final double? width;
  final double height;
  final double radius;
  final int lines;
  final double spacing;

  @override
  State<AppSkeleton> createState() => _AppSkeletonState();
}

class _AppSkeletonState extends State<AppSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _animation = Tween<double>(
      begin: 0.3,
      end: 0.7,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: List.generate(widget.lines, (index) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: index < widget.lines - 1 ? widget.spacing : 0,
              ),
              child: Container(
                width: widget.width,
                height: widget.height,
                decoration: BoxDecoration(
                  color: AppColors.border.withValues(alpha: _animation.value),
                  borderRadius: BorderRadius.circular(widget.radius),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

/// Wraps multiple children to animate them in sequence with staggered delays.
/// Use this for list items, grid tiles, or any collection of widgets.
class StaggeredEntrance extends StatefulWidget {
  const StaggeredEntrance({
    super.key,
    required this.children,
    this.delay = 50,
    this.duration = 300,
    this.offset = 12,
    this.direction = Axis.vertical,
  });

  final List<Widget> children;
  final int delay;
  final int duration;
  final double offset;
  final Axis direction;

  @override
  State<StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<StaggeredEntrance> {
  final List<bool> _visible = [];

  @override
  void initState() {
    super.initState();
    _animateItems();
  }

  Future<void> _animateItems() async {
    for (int i = 0; i < widget.children.length; i++) {
      await Future.delayed(Duration(milliseconds: widget.delay));
      if (mounted) {
        setState(() {
          _visible.add(true);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(widget.children.length, (index) {
        final isVisible = index < _visible.length && _visible[index];
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: isVisible ? 1 : 0),
          duration: Duration(milliseconds: widget.duration),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(
                  widget.direction == Axis.vertical
                      ? 0
                      : widget.offset * (1 - value),
                  widget.direction == Axis.vertical
                      ? widget.offset * (1 - value)
                      : 0,
                ),
                child: child,
              ),
            );
          },
          child: widget.children[index],
        );
      }),
    );
  }
}

/// Wraps a child to shake horizontally when [error] is non-null.
/// Useful for form validation feedback.
class ShakeOnError extends StatefulWidget {
  const ShakeOnError({super.key, required this.child, this.error});

  final Widget child;
  final Object? error;

  @override
  State<ShakeOnError> createState() => _ShakeOnErrorState();
}

class _ShakeOnErrorState extends State<ShakeOnError>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _animation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));
  }

  @override
  void didUpdateWidget(ShakeOnError oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.error != null && oldWidget.error == null) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final shake = _animation.value * 8 * (1 - _animation.value);
        return Transform.translate(offset: Offset(shake, 0), child: child);
      },
      child: widget.child,
    );
  }
}

/// Displays a high-priority floating notification banner at the TOP of the viewport,
/// ensuring it is never submerged behind Modal Bottom Sheets or Navigation Bars.
void showTopNotification(
  BuildContext context, {
  required String message,
  bool isError = false,
  Duration duration = const Duration(seconds: 3),
}) {
  final overlay = Overlay.maybeOf(context);
  if (overlay == null) return;

  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => _TopNotificationOverlay(
      message: message,
      isError: isError,
      onDismiss: () {
        if (entry.mounted) entry.remove();
      },
    ),
  );

  overlay.insert(entry);
  Future.delayed(duration, () {
    if (entry.mounted) entry.remove();
  });
}

class _TopNotificationOverlay extends StatefulWidget {
  const _TopNotificationOverlay({
    required this.message,
    required this.isError,
    required this.onDismiss,
  });

  final String message;
  final bool isError;
  final VoidCallback onDismiss;

  @override
  State<_TopNotificationOverlay> createState() => _TopNotificationOverlayState();
}

class _TopNotificationOverlayState extends State<_TopNotificationOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _offsetAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, -0.8),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.paddingOf(context).top + 12;
    final bgColor = widget.isError ? const Color(0xFFE53935) : const Color(0xFF1E293B);
    final icon = widget.isError ? LucideIcons.triangleAlert : LucideIcons.circleCheck;

    return Positioned(
      top: topPadding,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _offsetAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: widget.onDismiss,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 16,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(icon, color: Colors.white, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
