import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/brand_logo.dart';
import '../../../shared/widgets/ui_kit.dart';

final appVersionProvider = FutureProvider<String>((ref) async {
  try {
    final info = await PackageInfo.fromPlatform();
    final version = info.version.isNotEmpty ? info.version : '2.5.0';
    final build = info.buildNumber.isNotEmpty ? info.buildNumber : '80';
    return 'v$version+$build';
  } catch (_) {
    return 'v2.5.0+80';
  }
});

/// About screen — app info, version, credits.
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final versionAsync = ref.watch(appVersionProvider);
    final versionText = versionAsync.maybeWhen(
      data: (v) => 'Phiên bản $v',
      orElse: () => 'Phiên bản v2.5.0+80',
    );

    return AppScaffold(
      title: 'Thông tin',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // App icon and version
          Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 18,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.border),
                    boxShadow: AppColors.glow(AppColors.primary, opacity: 0.18),
                  ),
                  child: const BrandLogo(height: 72),
                ),
                const SizedBox(height: 14),
                Text(
                  versionText,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Description
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ứng dụng quản lý công việc',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'VCloud giúp nhân viên quản lý công việc hàng ngày: chấm công, timesheet, ticket hỗ trợ, và nhắn tin nội bộ.',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Features
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tính năng',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                const _FeatureItem(
                  icon: LucideIcons.clock,
                  title: 'Chấm công',
                  subtitle: 'Check-in/check-out với vị trí',
                ),
                const _FeatureItem(
                  icon: LucideIcons.timer,
                  title: 'Timesheet',
                  subtitle: 'Ghi nhận thời gian làm việc',
                ),
                const _FeatureItem(
                  icon: LucideIcons.ticket,
                  title: 'Ticket',
                  subtitle: 'Quản lý yêu cầu hỗ trợ',
                ),
                const _FeatureItem(
                  icon: LucideIcons.messageCircle,
                  title: 'Tin nhắn',
                  subtitle: 'Nhắn tin nội bộ nhóm',
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Copyright
          Center(
            child: Text(
              '© 2026 360 CORP',
              style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  const _FeatureItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: AppColors.featureGrad(
                AppColors.primary,
                AppColors.primaryDeep,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
