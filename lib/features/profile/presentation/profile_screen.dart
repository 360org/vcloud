import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../auth/application/auth_controller.dart';

/// Mockup 06 — "Tôi": profile header + settings list.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value;
    final meta = user?.userMetadata;
    final name = (meta?['display_name'] as String?)?.trim();
    final displayName = (name != null && name.isNotEmpty)
        ? name
        : (user?.email?.split('@').first ?? 'Người dùng');
    final role = (meta?['role'] as String?) ?? 'Nhân viên triển khai';
    final company = (meta?['company'] as String?) ?? '360 CORP';

    return AppScaffold(
      title: 'Tôi',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ProfileHeader(name: displayName, role: '$role · $company'),
          const SizedBox(height: 16),
          Container(
            decoration: cardDecoration(),
            child: Column(
              children: [
                _Row(icon: Icons.person_outline, label: 'Hồ sơ cá nhân', onTap: () {}),
                const Divider(indent: 56, height: 1),
                _Row(icon: Icons.event_busy_outlined, label: 'Đơn nghỉ phép', onTap: () {}),
                const Divider(indent: 56, height: 1),
                _Row(
                    icon: Icons.history,
                    label: 'Lịch sử check-in',
                    onTap: () => context.go('/attendance/history')),
                const Divider(indent: 56, height: 1),
                _Row(icon: Icons.settings_outlined, label: 'Cài đặt', onTap: () {}),
                const Divider(indent: 56, height: 1),
                _Row(
                  icon: Icons.logout,
                  label: 'Đăng xuất',
                  danger: true,
                  onTap: () => ref.read(authControllerProvider.notifier).signOut(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Center(
            child: Text('VCloud v1.0.0',
                style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.name, required this.role});
  final String name;
  final String role;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: cardDecoration(),
      child: Row(
        children: [
          UserAvatar(userId: currentUserId(), displayName: name, size: 60),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(role,
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.danger : AppColors.textPrimary;
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: danger ? AppColors.danger : AppColors.primary),
      title: Text(label,
          style: TextStyle(color: color, fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
    );
  }
}
