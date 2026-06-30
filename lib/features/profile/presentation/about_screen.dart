import 'package:flutter/material.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/ui_kit.dart';

/// About screen — app info, version, credits.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Thông tin',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // App icon and name
          Center(
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: AppColors.brand,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: AppColors.glow(AppColors.primary, opacity: 0.3),
                  ),
                  child: const Icon(LucideIcons.cloud, color: Colors.white, size: 40),
                ),
                const SizedBox(height: 16),
                const Text(
                  'VCloud',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'v1.1.0+2',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textMuted,
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
                  'Ứng dụng quản lý nhân viên',
                  style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(
                  'VCloud giúp nhân viên quản lý công việc hàng ngày: chấm công, timesheet, ticket hỗ trợ, và nhắn tin nội bộ.',
                  style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
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
                Text('Tính năng', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                const _FeatureItem(icon: LucideIcons.clock, title: 'Chấm công', subtitle: 'Check-in/check-out với vị trí'),
                const _FeatureItem(icon: LucideIcons.timer, title: 'Timesheet', subtitle: 'Ghi nhận thời gian làm việc'),
                const _FeatureItem(icon: LucideIcons.ticket, title: 'Ticket', subtitle: 'Quản lý yêu cầu hỗ trợ'),
                const _FeatureItem(icon: LucideIcons.messageCircle, title: 'Tin nhắn', subtitle: 'Nhắn tin nội bộ nhóm'),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Tech stack
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Công nghệ', style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                const _TechItem(label: 'Flutter', value: '3.x'),
                const _TechItem(label: 'Dart', value: '3.12+'),
                const _TechItem(label: 'Backend', value: 'Supabase'),
                const _TechItem(label: 'State', value: 'Riverpod'),
                const _TechItem(label: 'Routing', value: 'GoRouter'),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Credits
          Center(
            child: Text(
              '© 2026 360 CORP',
              style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Built with ❤️ by Crush',
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
              gradient: AppColors.featureGrad(AppColors.primary, AppColors.primaryDeep),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TechItem extends StatelessWidget {
  const _TechItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
