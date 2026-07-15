import 'package:flutter/material.dart';

import '../../../core/api/odoo_api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/ui_kit.dart';

/// Opens a bottom sheet listing the tenants that accept the same login/password
/// and returns the one the user picks (or `null` if dismissed). Shown after the
/// master auth resolver answers `409 multiple_tenants`; the chosen
/// [TenantChoice.tenantId] is sent back to `/api/v1/mobile/auth/login` to force
/// that tenant.
Future<TenantChoice?> showTenantSelectionSheet(
  BuildContext context,
  List<TenantChoice> tenants,
) {
  return showModalBottomSheet<TenantChoice>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => _TenantSelectionSheet(tenants: tenants),
  );
}

class _TenantSelectionSheet extends StatelessWidget {
  const _TenantSelectionSheet({required this.tenants});

  final List<TenantChoice> tenants;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: Container(
          margin: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14101828),
                blurRadius: 32,
                offset: Offset(0, 16),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 46,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Row(
                  children: [
                    Icon(
                      Icons.business_outlined,
                      color: AppColors.primary,
                      size: 22,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Chọn tổ chức',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Tài khoản thuộc nhiều tổ chức. Hãy chọn một để đăng nhập.',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: tenants.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final tenant = tenants[index];
                      return _TenantTile(
                        tenant: tenant,
                        onTap: () => Navigator.of(context).pop(tenant),
                      );
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

class _TenantTile extends StatelessWidget {
  const _TenantTile({required this.tenant, required this.onTap});

  final TenantChoice tenant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final subtitle = <String>[
      if (tenant.db != null) tenant.db!,
      if (tenant.baseUrl != null) tenant.baseUrl!,
    ].join('  ·  ');
    return PressableScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.16)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: AppColors.brand,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.business_outlined,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    tenant.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right,
              color: AppColors.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
