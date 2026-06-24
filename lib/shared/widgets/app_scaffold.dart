import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_theme.dart';

/// Standard scaffold for top-level tabs (Home/Chat/...). Draws the
/// app bar and the bottom-nav shell. The shell auto-detects which tab is
/// active from GoRouterState, so screens only have to set [title] and
/// [body]; the bottom bar is hidden on non-tab routes (login, signup, ...).
///
/// Set [showAppBar] to false for screens that paint their own header
/// (e.g. Home's light greeting header).
class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
    this.bottomNavigationBarOverride,
    this.resizeToAvoidBottomInset,
    this.showAppBar = true,
    this.wrapSafeArea = true,
  });

  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBarOverride;
  final bool? resizeToAvoidBottomInset;
  final bool showAppBar;
  final bool wrapSafeArea;

  static const _tabs = <_TabSpec>[
    _TabSpec(label: 'Home', path: '/home', icon: LucideIcons.home),
    _TabSpec(label: 'Chat', path: '/chat', icon: LucideIcons.messageCircle),
    _TabSpec(label: 'Timesheet', path: '/timesheet', icon: LucideIcons.clock),
    _TabSpec(label: 'Ticket', path: '/tickets', icon: LucideIcons.ticket),
    _TabSpec(label: 'Tôi', path: '/profile', icon: LucideIcons.user),
  ];

  @override
  Widget build(BuildContext context) {
    // Map the current GoRouter location to one of the tab paths so the
    // shell can highlight the right tab and route user taps to the right
    // path. Any path prefixed by a tab path (e.g. `/chat/abc` → Chat) still
    // belongs to that tab; paths like `/login`, `/signup` map to no tab
    // and we hide the bar entirely.
    final loc = GoRouterState.of(context).matchedLocation;
    final activeIndex = () {
      for (var i = 0; i < _tabs.length; i++) {
        final p = _tabs[i].path;
        if (loc == p || loc.startsWith('$p/')) return i;
      }
      return null;
    }();

    final Widget? bottom = bottomNavigationBarOverride ??
        (activeIndex == null
            ? null
            : Container(
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.border)),
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x0F0F172A),
                      blurRadius: 18,
                      offset: Offset(0, -4),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        for (var i = 0; i < _tabs.length; i++)
                          _NavItem(
                            tab: _tabs[i],
                            selected: i == activeIndex,
                            onTap: () {
                              HapticFeedback.selectionClick();
                              context.go(_tabs[i].path);
                            },
                          ),
                      ],
                    ),
                  ),
                ),
              ));

    return Scaffold(
      appBar: showAppBar
          ? AppBar(
              title: Text(title),
              actions: actions,
              flexibleSpace: const DecoratedBox(
                decoration: BoxDecoration(gradient: AppColors.brand),
              ),
            )
          : null,
      body: wrapSafeArea ? SafeArea(child: body) : body,
      bottomNavigationBar: bottom,
      floatingActionButton: floatingActionButton,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
    );
  }
}

/// Animated bottom-nav item: the active icon lifts into a soft brand pill.
class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.tab,
    required this.selected,
    required this.onTap,
  });
  final _TabSpec tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.textMuted;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
              decoration: BoxDecoration(
                color: selected ? AppColors.primarySoft : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(tab.icon, size: 22, color: color),
            ),
            const SizedBox(height: 3),
            Text(
              tab.label,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabSpec {
  const _TabSpec({
    required this.label,
    required this.path,
    required this.icon,
  });
  final String label;
  final String path;
  final IconData icon;
}

/// Avatar circle with initials fallback. Used wherever a user is
/// referenced in chat/tickets/attendance.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.userId,
    required this.displayName,
    this.email,
    this.size = 40,
  });

  final String userId;
  final String displayName;
  final String? email;
  final double size;

  String get _initials {
    final cleaned = displayName.trim();
    if (cleaned.isEmpty) {
      if (email != null && email!.isNotEmpty) {
        return email![0].toUpperCase();
      }
      return userId.isEmpty ? '?' : userId[0].toUpperCase();
    }
    final parts = cleaned.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Stable color per user so the same person looks the same across screens.
    final seed = userId.hashCode;
    final color = Color.lerp(
      scheme.primary,
      scheme.tertiary,
      (seed.abs() % 100) / 100,
    )!;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        shape: BoxShape.circle,
      ),
      child: Text(
        _initials,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: size * 0.38,
        ),
      ),
    );
  }
}

/// Tiny helper that returns the current signed-in user's id (or empty).
String currentUserId() => Supabase.instance.client.auth.currentUser?.id ?? '';
