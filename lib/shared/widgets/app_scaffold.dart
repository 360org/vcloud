import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../core/api/odoo_api_client.dart';
import '../../core/theme/app_theme.dart';
import '../../features/chat/application/conversations_controller.dart';
import 'ui_kit.dart';

/// Standard scaffold for top-level tabs (Home/Chat/...). Draws the
/// app bar and the bottom-nav shell. The shell auto-detects which tab is
/// active from GoRouterState, so screens only have to set [title] and
/// [body]; the bottom bar is hidden on non-tab routes (login, signup, ...).
///
/// Set [showAppBar] to false for screens that paint their own header
/// (e.g. Home's light greeting header).
class AppScaffold extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = GoRouterState.of(context).matchedLocation;
    final activeIndex = () {
      for (var i = 0; i < _tabs.length; i++) {
        final p = _tabs[i].path;
        if (loc == p || loc.startsWith('$p/')) return i;
      }
      return null;
    }();

    // Get badge counts
    final chatUnread = ref.watch(totalUnreadCountProvider);

    final Widget? bottom =
        bottomNavigationBarOverride ??
        (activeIndex == null
            ? null
            : _FloatingTabBar(
                tabs: _tabs,
                activeIndex: activeIndex,
                chatUnread: chatUnread,
              ));

    return Scaffold(
      appBar: showAppBar
          ? AppBar(
              centerTitle: true,
              elevation: 0,
              title: Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  letterSpacing: -0.2,
                ),
              ),
              actions: actions,
              flexibleSpace: Container(
                decoration: const BoxDecoration(gradient: AppColors.brand),
              ),
            )
          : null,
      body: wrapSafeArea ? SafeArea(child: body) : body,
      extendBody: bottom != null,
      bottomNavigationBar: bottom,
      floatingActionButton: floatingActionButton,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
    );
  }
}

class _FloatingTabBar extends StatelessWidget {
  const _FloatingTabBar({
    required this.tabs,
    required this.activeIndex,
    required this.chatUnread,
  });

  final List<_TabSpec> tabs;
  final int activeIndex;
  final int chatUnread;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(34, 0, 34, 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkSurface.withValues(alpha: 0.88)
                  : Colors.white.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.14)
                    : Colors.white.withValues(alpha: 0.78),
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x120F172A),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                for (var i = 0; i < tabs.length; i++)
                  Expanded(
                    child: _NavItem(
                      tab: tabs[i],
                      selected: i == activeIndex,
                      badgeCount: _getBadgeCount(tabs[i].path, chatUnread),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        context.go(tabs[i].path);
                      },
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

/// Animated bottom-nav item: the active icon lifts into a soft gradient pill.
int _getBadgeCount(String path, int chatUnread) {
  if (path == '/chat') return chatUnread;
  return 0;
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.tab,
    required this.selected,
    required this.onTap,
    this.badgeCount = 0,
  });
  final _TabSpec tab;
  final bool selected;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = selected
        ? AppColors.primary
        : (isDark ? AppColors.darkTextMuted : AppColors.textPrimary);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Semantics(
        label: '${tab.label}${badgeCount > 0 ? ", $badgeCount unread" : ""}',
        button: true,
        selected: selected,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.textMuted.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Icon(
                      tab.icon,
                      size: selected ? 24 : 22,
                      color: color,
                    ),
                  ),
                  if (badgeCount > 0)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: UnreadBadge(
                        count: badgeCount,
                        compact: true,
                        gradient: AppColors.featureGrad(
                          AppColors.danger,
                          AppColors.dangerDeep,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 1),
              SizedBox(
                width: double.infinity,
                child: Text(
                  tab.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    color: color,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    height: 1.1,
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

class _TabSpec {
  const _TabSpec({required this.label, required this.path, required this.icon});
  final String label;
  final String path;
  final IconData icon;
}

/// Avatar circle with initials fallback and per-user gradient ring.
/// Used wherever a user is referenced in chat/tickets/attendance.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.userId,
    required this.displayName,
    this.email,
    this.avatarUrl,
    this.size = 40,
  });

  final String userId;
  final String displayName;
  final String? email;
  final String? avatarUrl;
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
    if (parts.length == 1) {
      return parts.first.substring(0, parts.length.clamp(0, 1)).toUpperCase();
    }
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  /// Stable hue from 0..1 based on user id so each person gets a
  /// consistent colour across the app.
  Color get _userColor {
    final h = (userId.hashCode & 0x7FFFFFFF) % 360;
    return HSLColor.fromAHSL(1, h.toDouble(), 0.55, 0.55).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final fallback = Center(
      child: Text(
        _initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.36,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    return Container(
      width: size + 4,
      height: size + 4,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [_userColor, _userColor.withValues(alpha: 0.6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppColors.accent(_userColor),
          border: Border.all(color: AppColors.surface, width: 2),
        ),
        child: ClipOval(
          child: Stack(
            fit: StackFit.expand,
            children: [
              fallback,
              _avatarContent(fallback),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatarContent(Widget fallback) {
    final value = avatarUrl?.trim();
    if (value == null || value.isEmpty || value == 'false' || value == 'null') {
      return fallback;
    }
    final memoryImage = value.startsWith('data:image')
        ? _safeDataImage(value)
        : !value.contains('/') && value.length > 80
        ? _safeMemoryImage(value)
        : null;
    if (memoryImage != null) {
      return Image(
        image: memoryImage,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => fallback,
      );
    }

    final networkUrl = _networkAvatarUrl(value);
    if (networkUrl == null) return fallback;

    return _AvatarNetworkImage(
      url: networkUrl,
      fallback: fallback,
    );
  }

  MemoryImage? _safeMemoryImage(String value) {
    try {
      return MemoryImage(base64Decode(value));
    } on FormatException {
      return null;
    }
  }

  MemoryImage? _safeDataImage(String value) {
    final comma = value.indexOf(',');
    if (comma == -1) return null;
    return _safeMemoryImage(value.substring(comma + 1));
  }


  String? _networkAvatarUrl(String value) {
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    if (!value.startsWith('/')) return null;
    try {
      return odooApiClient.absoluteUrl(value);
    } on FormatException {
      return null;
    }
  }
}

final Map<String, Uint8List> _avatarBytesCache = {};

class _AvatarNetworkImage extends StatefulWidget {
  const _AvatarNetworkImage({
    required this.url,
    required this.fallback,
  });

  final String url;
  final Widget fallback;

  @override
  State<_AvatarNetworkImage> createState() => _AvatarNetworkImageState();
}

class _AvatarNetworkImageState extends State<_AvatarNetworkImage> {
  Uint8List? _bytes;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(_AvatarNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    final cached = _avatarBytesCache[widget.url];
    if (cached != null) {
      if (mounted) {
        setState(() {
          _bytes = cached;
          _hasError = false;
        });
      }
      return;
    }

    try {
      final res = await http.get(
        Uri.parse(widget.url),
        headers: const {'User-Agent': 'Mozilla/5.0'},
      );
      if (res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
        _avatarBytesCache[widget.url] = res.bodyBytes;
        if (mounted) {
          setState(() {
            _bytes = res.bodyBytes;
            _hasError = false;
          });
        }
      } else {
        if (mounted) setState(() => _hasError = true);
      }
    } catch (_) {
      if (mounted) setState(() => _hasError = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError || _bytes == null) return widget.fallback;
    return Image.memory(
      _bytes!,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => widget.fallback,
    );
  }
}
