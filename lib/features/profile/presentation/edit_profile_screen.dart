import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/ui_kit.dart';
import '../../auth/application/auth_controller.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _roleController;
  late final TextEditingController _companyController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final user = ref.read(authControllerProvider).value;
    final meta = user?.userMetadata;
    _nameController = TextEditingController(
      text: meta?['display_name'] as String? ?? '',
    );
    _roleController = TextEditingController(
      text: meta?['role'] as String? ?? 'Nhân viên triển khai',
    );
    _companyController = TextEditingController(
      text: meta?['company'] as String? ?? '360 CORP',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _roleController.dispose();
    _companyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Odoo API chưa hỗ trợ cập nhật hồ sơ')),
        );
        context.pop();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).value;

    return AppScaffold(
      title: 'Chỉnh sửa hồ sơ',
      actions: [
        TextButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text(
                  'Lưu',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: UserAvatar(
              userId: user?.id ?? '',
              displayName: _nameController.text.isNotEmpty
                  ? _nameController.text
                  : 'U',
              size: 80,
            ),
          ),
          const SizedBox(height: 32),
          _ProfileField(
            label: 'Họ và tên',
            controller: _nameController,
            icon: LucideIcons.user,
          ),
          const SizedBox(height: 12),
          _ProfileField(
            label: 'Chức vụ',
            controller: _roleController,
            icon: LucideIcons.briefcase,
          ),
          const SizedBox(height: 12),
          _ProfileField(
            label: 'Công ty',
            controller: _companyController,
            icon: LucideIcons.building2,
          ),
          const SizedBox(height: 12),
          _ProfileField(
            label: 'Email',
            controller: TextEditingController(text: user?.email ?? ''),
            icon: LucideIcons.mail,
            readOnly: true,
          ),
        ],
      ),
    );
  }
}

class _ProfileField extends StatelessWidget {
  const _ProfileField({
    required this.label,
    required this.controller,
    required this.icon,
    this.readOnly = false,
  });

  final String label;
  final TextEditingController controller;
  final IconData icon;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            readOnly: readOnly,
            controller: controller,
            style: TextStyle(
              color: readOnly ? AppColors.textMuted : AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, size: 18),
              filled: true,
              fillColor: AppColors.bg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
