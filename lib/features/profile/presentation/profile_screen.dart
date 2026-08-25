import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import 'package:flutter/services.dart';
import '../../../core/notifications/push_notification_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/local_attachment_cache.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/brand_logo.dart';
import '../../../shared/widgets/ui_kit.dart';
import '../../../shared/widgets/whats_new_sheet.dart';
import '../../auth/application/auth_controller.dart';
import '../application/theme_controller.dart';


class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // DO NOT MODIFY OR REFACTOR THIS AVATAR LOADING LOGIC. IT IS THE SOURCE OF TRUTH FOR USER AVATAR DISPLAY.
    // CẤM SỬA HOẶC XÓA LOGIC TẢI AVATAR NÀY - ĐÂY LÀ NGUỒN SỰ THẬT HIỂN THỊ AVATAR DÙNG CHUNG.
    final user = ref.watch(authControllerProvider).value;
    final meta = user?.userMetadata;
    final name = (meta?['display_name'] as String?)?.trim();
    final displayName = name?.isNotEmpty == true
        ? name!
        : (user?.email?.split('@').first ?? 'Người dùng');
    final role = (meta?['role'] as String?) ?? (meta?['function'] as String?) ?? 'AI Full Stack Engineer (Agentic AI Platform)';
    final company = (meta?['company'] as String?) ?? (meta?['company_name'] as String?) ?? '360 CORP';
    final rawAvatar = meta?['avatar_url'] ??
        meta?['avatar_128_url'] ??
        meta?['image_128_url'] ??
        (user != null ? '/web/image/res.users/${user.id}/avatar_128' : null);
    final avatarUrl = rawAvatar is String && rawAvatar.isNotEmpty ? rawAvatar : null;

    return AppScaffold(
      title: 'Tôi',
      showAppBar: false,
      wrapSafeArea: false,
      body: ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 112),
            children: [
              const _ProfileTopBar(),
              const SizedBox(height: 14),
              _ProfileHero(
                userId: user?.id ?? '',
                name: displayName,
                role: '$role · $company',
                email: user?.email ?? '',
                avatarUrl: avatarUrl,
              ),
              const SizedBox(height: 16),
              _SettingsCard(
                children: [
                  _SettingsRow(
                    icon: LucideIcons.user,
                    label: 'Hồ sơ cá nhân',
                    color: AppColors.primary,
                    onTap: () => context.push('/profile/edit'),
                  ),
                  _ThemeRow(),
                  const _CacheRow(),
                  _SettingsRow(
                    icon: LucideIcons.sparkles,
                    label: 'Có gì mới trong v2.5.0 (Build 91)',
                    color: const Color(0xFF00C83A),
                    onTap: () => WhatsNewSheet.show(context),
                  ),
                  _SettingsRow(
                    icon: LucideIcons.bellRing,
                    label: 'Thông báo đẩy & FCM Token',
                    color: const Color(0xFF3B82F6),
                    onTap: () => _showPushTokenDialog(context, ref),
                  ),
                  _SettingsRow(
                    icon: LucideIcons.info,
                    label: 'Thông tin ứng dụng',
                    color: AppColors.primary,
                    onTap: () => context.push('/profile/about'),
                  ),
                  _SettingsRow(
                    icon: LucideIcons.logOut,
                    label: 'Đăng xuất',
                    color: AppColors.danger,
                    danger: true,
                    onTap: () => _confirmLogout(context, ref),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPushTokenDialog(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PushTokenSheet(ref: ref),
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đăng xuất?'),
        content: const Text('Bạn có chắc chắn muốn đăng xuất tài khoản?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authControllerProvider.notifier).signOut();
            },
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );
  }
}

class _PushTokenSheet extends StatefulWidget {
  const _PushTokenSheet({required this.ref});
  final WidgetRef ref;

  @override
  State<_PushTokenSheet> createState() => _PushTokenSheetState();
}

class _PushTokenSheetState extends State<_PushTokenSheet> {
  bool _loading = false;
  String? _status;
  Map<String, String>? _deviceInfo;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAndRegister();
  }

  Future<void> _loadAndRegister() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final service = widget.ref.read(pushNotificationServiceProvider);
      await service.registerCurrentDevice();
      final info = await service.getDeviceInfo();
      if (mounted) {
        setState(() {
          _loading = false;
          _deviceInfo = info;
          _status = 'Đã đăng ký thành công lên Odoo Server!';
        });
      }
    } catch (e) {
      if (mounted) {
        final service = widget.ref.read(pushNotificationServiceProvider);
        final info = await service.getDeviceInfo();
        setState(() {
          _loading = false;
          _deviceInfo = info;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final token = _deviceInfo?['token'] ?? '';

    return Container(
      padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E2024) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(LucideIcons.bellRing, color: Color(0xFF3B82F6), size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Thông Báo Đẩy (FCM Token)',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      'Trạng thái thiết bị & Token nhận thông báo',
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(strokeWidth: 2.5),
                    SizedBox(height: 12),
                    Text('Đang đồng bộ thiết bị lên Odoo Server...'),
                  ],
                ),
              ),
            )
          else ...[
            if (_errorMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.alertTriangle, color: Colors.red, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(fontSize: 13, color: Colors.red),
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF00C83A).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF00C83A).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(LucideIcons.checkCircle, color: Color(0xFF00C83A), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _status ?? 'Thiết bị đã kết nối',
                        style: const TextStyle(fontSize: 13, color: Color(0xFF00C83A), fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  _infoRow('Nền tảng (Platform)', _deviceInfo?['platform'] ?? ''),
                  _infoRow('Tên thiết bị', _deviceInfo?['deviceName'] ?? ''),
                  _infoRow('Installation ID', _deviceInfo?['installationId'] ?? ''),
                  _infoRow('Phiên bản App', _deviceInfo?['appVersion'] ?? ''),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'FCM Registration Token (Dùng để test Firebase Console):',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark ? Colors.black38 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
              ),
              child: SelectableText(
                token,
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                maxLines: 4,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _loadAndRegister,
                    icon: const Icon(LucideIcons.refreshCw, size: 16),
                    label: const Text('Đăng Ký Lại'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: token.isNotEmpty && token != 'Chưa tạo token'
                        ? () {
                            Clipboard.setData(ClipboardData(text: token));
                            AppToast.showGlobal(
                              type: AppToastType.success,
                              title: 'Đã sao chép FCM Token',
                              message: 'Đã sao chép token vào bộ nhớ tạm!',
                            );
                          }
                        : null,
                    icon: const Icon(LucideIcons.copy, size: 16),
                    label: const Text('Sao Chép Token'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileTopBar extends StatelessWidget {
  const _ProfileTopBar();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: BrandLogo(height: 90),
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.userId,
    required this.name,
    required this.role,
    required this.email,
    this.avatarUrl,
  });

  final String userId;
  final String name;
  final String role;
  final String email;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/profile/edit'),
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: _cardDecoration(context),
        child: Row(
          children: [
            Stack(
              children: [
                UserAvatar(
                  userId: userId,
                  displayName: name,
                  email: email,
                  avatarUrl: avatarUrl,
                  size: 62,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      LucideIcons.camera,
                      color: Colors.white,
                      size: 11,
                    ),
                  ),
                ),
              ],
            ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  role,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(context),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1)
              const Divider(height: 1, indent: 64, color: AppColors.border),
          ],
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final textColor = danger
        ? AppColors.danger
        : Theme.of(context).colorScheme.onSurface;
    return PressableScale(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.soft(color),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 19),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: textColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const Icon(
              LucideIcons.chevronRight,
              color: AppColors.textMuted,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeRow extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeAsync = ref.watch(themeControllerProvider);
    final currentTheme = themeAsync.valueOrNull ?? AppThemeMode.light;

    return PressableScale(
      onTap: () => _showThemePicker(context, ref, currentTheme),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.soft(AppColors.primary),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                LucideIcons.palette,
                color: AppColors.primary,
                size: 19,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Giao diện',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    currentTheme.displayName,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              LucideIcons.chevronRight,
              color: AppColors.textMuted,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  void _showThemePicker(
    BuildContext context,
    WidgetRef ref,
    AppThemeMode current,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final isDark = theme.brightness == Brightness.dark;
        final sheetBg = isDark ? const Color(0xFF1E293B) : Colors.white;
        final textColor = isDark ? Colors.white : AppColors.textPrimary;

        return Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: BorderRadius.circular(26),
            boxShadow: const [
              BoxShadow(
                color: Color(0x220F172A),
                blurRadius: 22,
                offset: Offset(0, -8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF475569) : AppColors.border,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Chọn giao diện',
                style: TextStyle(
                  color: textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              for (final mode in AppThemeMode.values)
                Material(
                  color: Colors.transparent,
                  child: ListTile(
                    title: Text(
                      mode.displayName,
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    trailing: mode == current
                        ? const Icon(Icons.check_circle, color: AppColors.primary)
                        : null,
                    onTap: () {
                      ref.read(themeControllerProvider.notifier).setTheme(mode);
                      Navigator.pop(ctx);
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _CacheRow extends StatefulWidget {
  const _CacheRow();

  @override
  State<_CacheRow> createState() => _CacheRowState();
}

class _CacheRowState extends State<_CacheRow> {
  double _cacheSizeMB = 0.0;
  bool _loading = false;
  bool _clearing = false;

  @override
  void initState() {
    super.initState();
    _loadCacheSize();
  }

  Future<void> _loadCacheSize() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final size = await LocalAttachmentCache.getCacheSizeInMB();
      if (mounted) {
        setState(() {
          _cacheSizeMB = size;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _confirmClearCache() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dọn dẹp bộ nhớ đệm?'),
        content: Text(
          'Bạn có chắc chắn muốn dọn dẹp ${_cacheSizeMB.toStringAsFixed(1)} MB bộ nhớ đệm đính kèm? Dữ liệu đính kèm sẽ được tải lại từ máy chủ khi cần.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Dọn dẹp'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    setState(() => _clearing = true);
    try {
      await LocalAttachmentCache.clearAllCache();
      final newSize = await LocalAttachmentCache.getCacheSizeInMB();
      if (!mounted) return;
      setState(() {
        _cacheSizeMB = newSize;
        _clearing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã dọn dẹp bộ nhớ đệm thành công!'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _clearing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dọn dẹp bộ nhớ đệm thất bại: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: _clearing ? null : _confirmClearCache,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.soft(AppColors.primary),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                LucideIcons.hardDrive,
                color: AppColors.primary,
                size: 19,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bộ nhớ đệm & Dữ liệu',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    _loading || _clearing
                        ? 'Đang tính toán...'
                        : 'Dung lượng: ${_cacheSizeMB.toStringAsFixed(1)} MB',
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (_clearing)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              )
            else
              TextButton(
                onPressed: _confirmClearCache,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'Dọn dẹp',
                  style: TextStyle(
                    color: AppColors.danger,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}


BoxDecoration _cardDecoration(BuildContext context, {double radius = 22}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return BoxDecoration(
    color: Theme.of(context).cardColor,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(
      color: isDark
          ? const Color(0xFF334155)
          : AppColors.border.withValues(alpha: 0.7),
    ),
    boxShadow: const [
      BoxShadow(color: Color(0x0A0F172A), blurRadius: 16, offset: Offset(0, 8)),
    ],
  );
}

