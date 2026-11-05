import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../../core/api/odoo_api_client.dart';
import '../../../shared/widgets/app_toast.dart';
import '../application/menu_controller.dart';
import '../data/menu_item_model.dart';

class AppDrawerBottomSheet extends ConsumerStatefulWidget {
  const AppDrawerBottomSheet({super.key, this.currentPath});

  final String? currentPath;

  @override
  ConsumerState<AppDrawerBottomSheet> createState() =>
      _AppDrawerBottomSheetState();
}

class _AppDrawerBottomSheetState extends ConsumerState<AppDrawerBottomSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final state = ref.read(menuControllerProvider);
        if (state.searchQuery.isNotEmpty) {
          ref.read(menuControllerProvider.notifier).setSearchQuery('');
        }
        if (state.apps.isEmpty && !state.isLoading) {
          ref.read(menuControllerProvider.notifier).loadMenu();
        }
      }
    });
  }

  String _resolveCurrentPath(BuildContext context) {
    if (widget.currentPath != null && widget.currentPath!.isNotEmpty) {
      return widget.currentPath!;
    }
    try {
      return GoRouter.of(context).routerDelegate.currentConfiguration.uri.path;
    } catch (_) {
      return '';
    }
  }

  void _onAppTapped(BuildContext context, AppMenuItem app) {
    HapticFeedback.lightImpact();
    final currentPath = _resolveCurrentPath(context);
    Navigator.of(context).pop();

    if (app.isNative &&
        app.nativeRoute != null &&
        app.nativeRoute!.isNotEmpty) {
      context.go(app.nativeRoute!);
      return;
    }

    // Mở Hybrid WebView cho các module chưa có native Flutter
    final targetUrl = app.webUrl ??
        (app.actionId != null
            ? '/web#action=${app.actionId}&menu_id=${app.id}'
            : '/web#menu_id=${app.id}');

    final url = formatAppWebUrl(targetUrl);

    final uri = Uri(
      path: '/webview',
      queryParameters: {
        'url': url,
        'title': app.name,
      },
    );

    final isAlreadyWebview =
        currentPath == '/webview' || currentPath.startsWith('/webview/');
    if (isAlreadyWebview) {
      context.go(uri.toString());
    } else {
      context.push(uri.toString());
    }
  }

  void _onUtilityTapped(BuildContext context, AppUtilityItem item) {
    HapticFeedback.lightImpact();
    final currentPath = _resolveCurrentPath(context);
    Navigator.of(context).pop();

    if (item.nativeRoute != null && item.nativeRoute!.isNotEmpty) {
      context.push(item.nativeRoute!);
      return;
    }

    final targetUrl = item.webUrl ?? item.url;
    if (targetUrl != null && targetUrl.isNotEmpty) {
      final url = formatAppWebUrl(targetUrl);
      final uri = Uri(
        path: '/webview',
        queryParameters: {
          'url': url,
          'title': item.name,
        },
      );
      final isAlreadyWebview =
          currentPath == '/webview' || currentPath.startsWith('/webview/');
      if (isAlreadyWebview) {
        context.go(uri.toString());
      } else {
        context.push(uri.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final menuState = ref.watch(menuControllerProvider);
    final filteredApps = menuState.filteredApps;

    final bgColor = isDark ? const Color(0xFF0F172A) : Colors.white;
    final surfaceColor =
        isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final textColor = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final textMuted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    const brandBlue = Color(0xFF0077CD);

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isTablet = screenWidth >= 600;

    // Tính toán số cột và tỉ lệ động theo thiết bị
    final int crossAxisCount = isTablet ? 6 : 4;
    final double iconBoxSize = screenWidth < 360 ? 52.0 : 58.0;
    final double childAspectRatio =
        isTablet ? 0.82 : (screenWidth < 360 ? 0.68 : 0.72);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      expand: false,
      builder: (context, scrollController) {
        return Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 20,
                    offset: Offset(0, -4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Thanh kéo drag handle
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 10, bottom: 8),
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.2)
                            : Colors.black.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Header: Tab Selector & Nút Đóng (✕)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 6, 12, 12),
                    child: Row(
                      children: [
                        // Segmented Tabs: Bookmark & All Apps
                        Expanded(
                          child: Row(
                            children: [
                              _TabButton(
                                label: 'Đã ghim',
                                icon: LucideIcons.bookmark,
                                isSelected: menuState.activeTab == 'bookmark',
                                badgeCount: menuState.bookmarkedIds.length,
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  ref
                                      .read(menuControllerProvider.notifier)
                                      .setActiveTab('bookmark');
                                },
                              ),
                              const SizedBox(width: 8),
                              _TabButton(
                                label: 'Tất cả',
                                icon: LucideIcons.layoutGrid,
                                isSelected: menuState.activeTab == 'all',
                                badgeCount: menuState.apps.length,
                                onTap: () {
                                  HapticFeedback.selectionClick();
                                  ref
                                      .read(menuControllerProvider.notifier)
                                      .setActiveTab('all');
                                },
                              ),
                            ],
                          ),
                        ),
                        // Nút Đóng nhanh
                        IconButton(
                          icon: Icon(
                            LucideIcons.x,
                            size: 20,
                            color: textMuted,
                          ),
                          splashRadius: 20,
                          tooltip: 'Đóng',
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),

                  const Divider(height: 1, thickness: 0.5),

                  // Body: GridView các Apps & Footer Utilities
                  Expanded(
                    child: menuState.isLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(brandBlue),
                            ),
                          )
                        : RefreshIndicator(
                            color: brandBlue,
                            onRefresh: () => ref
                                .read(menuControllerProvider.notifier)
                                .loadMenu(),
                            child: CustomScrollView(
                              controller: scrollController,
                              physics: const AlwaysScrollableScrollPhysics(
                                parent: BouncingScrollPhysics(),
                              ),
                              slivers: [
                                if (filteredApps.isEmpty)
                                  SliverFillRemaining(
                                    hasScrollBody: false,
                                    child: Center(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 32),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (menuState.error != null) ...[
                                              Icon(
                                                LucideIcons.cloudOff,
                                                size: 44,
                                                color: textMuted,
                                              ),
                                              const SizedBox(height: 12),
                                              Text(
                                                'Không thể tải danh sách ứng dụng',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: textMuted,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ] else if (menuState.activeTab ==
                                                'bookmark') ...[
                                              Icon(
                                                LucideIcons.bookmarkPlus,
                                                size: 48,
                                                color: brandBlue
                                                    .withValues(alpha: 0.6),
                                              ),
                                              const SizedBox(height: 12),
                                              Text(
                                                'Chưa có ứng dụng được ghim',
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w600,
                                                  color: textColor,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                'Nhấn giữ bất kỳ ứng dụng nào ở mục Tất cả để ghim lối tắt vào đây.',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: textMuted,
                                                ),
                                              ),
                                            ] else ...[
                                              Icon(
                                                LucideIcons.layoutGrid,
                                                size: 44,
                                                color: textMuted,
                                              ),
                                              const SizedBox(height: 12),
                                              Text(
                                                'Chưa có ứng dụng nào được cấu hình',
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: textMuted,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              const SizedBox(height: 16),
                                              ElevatedButton.icon(
                                                onPressed: () {
                                                  HapticFeedback.lightImpact();
                                                  ref
                                                      .read(
                                                          menuControllerProvider
                                                              .notifier)
                                                      .loadMenu();
                                                },
                                                icon: const Icon(
                                                    LucideIcons.refreshCw,
                                                    size: 16),
                                                label: const Text('Tải lại',
                                                    style: TextStyle(
                                                        fontSize: 13,
                                                        fontWeight:
                                                            FontWeight.w600)),
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: brandBlue,
                                                  foregroundColor: Colors.white,
                                                  elevation: 0,
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                          horizontal: 18,
                                                          vertical: 10),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            12),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                  )
                                else
                                  SliverPadding(
                                    padding:
                                        const EdgeInsets.fromLTRB(16, 16, 16, 8),
                                    sliver: SliverGrid(
                                      gridDelegate:
                                          SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: crossAxisCount,
                                        mainAxisSpacing: 16,
                                        crossAxisSpacing: isTablet ? 12 : 10,
                                        childAspectRatio: childAspectRatio,
                                      ),
                                      delegate: SliverChildBuilderDelegate(
                                        (context, index) {
                                          final app = filteredApps[index];
                                          final isBookmarked =
                                              menuState.isAppBookmarked(app);
                                          return _AppCardItem(
                                            app: app,
                                            isBookmarked: isBookmarked,
                                            isDark: isDark,
                                            iconBoxSize: iconBoxSize,
                                            onTap: () =>
                                                _onAppTapped(context, app),
                                            onLongPress: () async {
                                              HapticFeedback.mediumImpact();
                                              final isAdded = await ref
                                                  .read(
                                                      menuControllerProvider
                                                          .notifier)
                                                  .toggleBookmark(app.id);
                                              if (context.mounted) {
                                                if (isAdded) {
                                                  AppToast.success(
                                                    context,
                                                    title: 'Đã ghim ứng dụng',
                                                    message:
                                                        'Đã thêm "${app.name}" vào danh sách lối tắt.',
                                                  );
                                                } else {
                                                  AppToast.info(
                                                    context,
                                                    title: 'Đã bỏ ghim',
                                                    message:
                                                        'Đã gỡ "${app.name}" khỏi danh sách lối tắt.',
                                                  );
                                                }
                                              }
                                            },
                                          );
                                        },
                                        childCount: filteredApps.length,
                                      ),
                                    ),
                                  ),

                                // Footer: Tiện ích hệ thống
                                SliverToBoxAdapter(
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        16, 12, 16, 24),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Divider(height: 24, thickness: 0.5),
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            left: 4,
                                            bottom: 8,
                                          ),
                                          child: Text(
                                            'TIỆN ÍCH HỆ THỐNG',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                              color: textMuted,
                                              letterSpacing: 0.8,
                                            ),
                                          ),
                                        ),
                                        Container(
                                          decoration: BoxDecoration(
                                            color: surfaceColor,
                                            borderRadius:
                                                BorderRadius.circular(16),
                                            border: Border.all(
                                              color: isDark
                                                  ? Colors.white.withValues(
                                                      alpha: 0.06)
                                                  : const Color(0xFFE2E8F0),
                                            ),
                                          ),
                                          child: Column(
                                            children: [
                                              for (var i = 0;
                                                  i <
                                                      menuState
                                                          .utilities.length;
                                                  i++) ...[
                                                _UtilityTile(
                                                  item: menuState.utilities[i],
                                                  isDark: isDark,
                                                  onTap: () => _onUtilityTapped(
                                                    context,
                                                    menuState.utilities[i],
                                                  ),
                                                ),
                                                if (i <
                                                    menuState.utilities.length -
                                                        1)
                                                  Divider(
                                                    height: 1,
                                                    thickness: 0.5,
                                                    indent: 48,
                                                    color: isDark
                                                        ? Colors.white
                                                            .withValues(
                                                                alpha: 0.06)
                                                        : const Color(
                                                            0xFFE2E8F0),
                                                  ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    this.badgeCount,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final int? badgeCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const brandBlue = Color(0xFF0077CD);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark
                  ? brandBlue.withValues(alpha: 0.25)
                  : brandBlue.withValues(alpha: 0.12))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? brandBlue
                : (isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : const Color(0xFFE2E8F0)),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isSelected
                  ? brandBlue
                  : (isDark
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF64748B)),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? brandBlue
                    : (isDark
                        ? const Color(0xFFF1F5F9)
                        : const Color(0xFF0F172A)),
              ),
            ),
            if (badgeCount != null && badgeCount! > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(
                  color: isSelected
                      ? brandBlue
                      : (isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : const Color(0xFFCBD5E1)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  badgeCount.toString(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : const Color(0xFF334155),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AppCardItem extends StatefulWidget {
  const _AppCardItem({
    required this.app,
    required this.isBookmarked,
    required this.isDark,
    required this.onTap,
    required this.onLongPress,
    this.iconBoxSize = 58.0,
  });

  final AppMenuItem app;
  final bool isBookmarked;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final double iconBoxSize;

  @override
  State<_AppCardItem> createState() => _AppCardItemState();
}

class _AppCardItemState extends State<_AppCardItem> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final textColor =
        widget.isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final cardBg = widget.isDark
        ? const Color(0xFF1E293B).withValues(alpha: 0.7)
        : const Color(0xFFF8FAFC);
    final borderColor = widget.isDark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE2E8F0);

    return RepaintBoundary(
      child: AnimatedScale(
        scale: _isPressed ? 0.96 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: InkWell(
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          onHighlightChanged: (highlighted) {
            if (_isPressed != highlighted) {
              setState(() => _isPressed = highlighted);
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon Box
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: widget.iconBoxSize,
                    height: widget.iconBoxSize,
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: borderColor, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: widget.isDark
                              ? const Color(0x22000000)
                              : const Color(0x080F172A),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Center(
                      child: _buildIcon(widget.app, widget.isDark),
                    ),
                  ),
                  if (widget.isBookmarked)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        padding: const EdgeInsets.all(2.5),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF59E0B),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Color(0x33F59E0B),
                              blurRadius: 4,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                        child: const Icon(
                          LucideIcons.bookmark,
                          size: 10,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),

              // Label
              SizedBox(
                width: widget.iconBoxSize > 54 ? 72 : 66,
                child: Text(
                  widget.app.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: widget.iconBoxSize < 56 ? 11.0 : 11.5,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                    height: 1.2,
                    letterSpacing: -0.1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(AppMenuItem app, bool isDark) {
    if (app.webIconData != null && app.webIconData!.trim().isNotEmpty) {
      try {
        final raw = app.webIconData!.trim();
        final base64String = raw.contains(',') ? raw.split(',').last : raw;
        final bytes = base64Decode(base64String);
        return Image.memory(
          bytes,
          width: widget.iconBoxSize < 56 ? 28 : 32,
          height: widget.iconBoxSize < 56 ? 28 : 32,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) =>
              _buildFallbackIcon(app, isDark),
        );
      } catch (_) {
        // Fallback below
      }
    }
    return _buildFallbackIcon(app, isDark);
  }

  Widget _buildFallbackIcon(AppMenuItem app, bool isDark) {
    final iconData = _resolveIconData(app.name, app.xmlid);
    return Icon(
      iconData,
      size: widget.iconBoxSize < 56 ? 24 : 26,
      color: const Color(0xFF0077CD),
    );
  }

  IconData _resolveIconData(String name, String? xmlid) {
    final lower = name.toLowerCase();
    final lowerXml = (xmlid ?? '').toLowerCase();

    if (lower.contains('chuyên cần') ||
        lower.contains('điểm danh') ||
        lowerXml.contains('attendance')) {
      return LucideIcons.clock;
    }
    if (lower.contains('kế toán') ||
        lower.contains('tài chính') ||
        lowerXml.contains('account')) {
      return LucideIcons.calculator;
    }
    if (lower.contains('thảo luận') ||
        lower.contains('chat') ||
        lowerXml.contains('mail.menu_root_chat') ||
        lowerXml.contains('discuss')) {
      return LucideIcons.messageCircle;
    }
    if (lower.contains('yêu cầu') ||
        lower.contains('ticket') ||
        lower.contains('hỗ trợ') ||
        lowerXml.contains('helpdesk')) {
      return LucideIcons.lifeBuoy;
    }
    if (lower.contains('tuyển dụng') || lowerXml.contains('recruitment')) {
      return LucideIcons.briefcase;
    }
    if (lower.contains('nhân viên') ||
        lower.contains('nhân sự') ||
        lowerXml.contains('employee')) {
      return LucideIcons.users;
    }
    if (lower.contains('chiến dịch') || lowerXml.contains('utm')) {
      return LucideIcons.megaphone;
    }
    if (lower.contains('khảo sát') || lowerXml.contains('survey')) {
      return LucideIcons.clipboardCheck;
    }
    if (lower.contains('elearning') || lower.contains('khoá học')) {
      return LucideIcons.graduationCap;
    }
    if (lower.contains('bán hàng') || lowerXml.contains('sale')) {
      return LucideIcons.shoppingBag;
    }
    if (lower.contains('mua hàng') || lowerXml.contains('purchase')) {
      return LucideIcons.shoppingCart;
    }
    if (lower.contains('kho') || lowerXml.contains('stock')) {
      return LucideIcons.package;
    }
    if (lower.contains('dự án') || lowerXml.contains('project')) {
      return LucideIcons.folderKanban;
    }
    if (lower.contains('cài đặt') || lowerXml.contains('setting')) {
      return LucideIcons.settings;
    }
    if (lower.contains('ai') || lowerXml.contains('ai_')) {
      return LucideIcons.sparkles;
    }
    if (lower.contains('email') || lowerXml.contains('mail')) {
      return LucideIcons.mail;
    }
    return LucideIcons.layoutGrid;
  }
}

class _UtilityTile extends StatelessWidget {
  const _UtilityTile({
    required this.item,
    required this.isDark,
    required this.onTap,
  });

  final AppUtilityItem item;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
    final textMuted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    const brandBlue = Color(0xFF0077CD);

    final iconData = _resolveUtilityIcon(item.id, item.icon);

    return Material(
      color: Colors.transparent,
      child: ListTile(
        dense: true,
        onTap: onTap,
        leading: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: brandBlue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            iconData,
            size: 17,
            color: brandBlue,
          ),
        ),
        title: Text(
          item.name,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        trailing: Icon(
          LucideIcons.chevronRight,
          size: 16,
          color: textMuted,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      ),
    );
  }

  IconData _resolveUtilityIcon(String id, String? icon) {
    if (id == 'docs' || icon == 'book_open') {
      return LucideIcons.bookOpen;
    }
    if (id == 'support' || icon == 'life_buoy') {
      return LucideIcons.lifeBuoy;
    }
    if (id == 'settings' || icon == 'settings') {
      return LucideIcons.settings;
    }
    return LucideIcons.wrench;
  }
}

/// Gắn `?db=<session.db>` vào URL đích trước dấu `#` nếu chưa có.
String formatAppWebUrl(String rawUrl, {String? db}) {
  final session = odooApiClient.session;
  final effectiveBase = session?.baseUrl.isNotEmpty == true ? session!.baseUrl : odooApiClient.baseUrl;
  final dbName = (db != null && db.isNotEmpty)
      ? db
      : (session?.db.isNotEmpty == true
          ? session!.db
          : OdooApiClient.resolveDefaultDbForUrl(effectiveBase));

  var url = rawUrl.trim();
  if (dbName.isNotEmpty) {
    final hashIndex = url.indexOf('#');
    if (hashIndex != -1) {
      final beforeHash = url.substring(0, hashIndex);
      final afterHash = url.substring(hashIndex + 1);
      if (!beforeHash.contains('db=')) {
        final sep = beforeHash.contains('?') ? '&' : '?';
        url = '$beforeHash${sep}db=$dbName#$afterHash';
      }
    } else if (!url.contains('db=')) {
      final sep = url.contains('?') ? '&' : '?';
      url = '$url${sep}db=$dbName';
    }
  }
  return url;
}
