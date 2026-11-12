import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../../core/api/odoo_api_client.dart';
import '../../../core/services/biometric_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/local_attachment_cache.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/brand_logo.dart';
import '../../../shared/widgets/ui_kit.dart';
import '../../auth/application/auth_controller.dart';
import '../../chat_v2/presentation/screens/chat_v2_image_viewer_screen.dart';
import '../../chat_v2/presentation/widgets/chat_v2_avatar_action_sheet.dart';
import '../application/profile_controller.dart';
import '../application/theme_controller.dart';
import '../data/models/partner_contact_detail.dart';


class ProfileScreen extends ConsumerWidget {
  final String? partnerId;
  final String? partnerName;
  final String? partnerAvatar;
  final String? partnerRole;

  const ProfileScreen({
    super.key,
    this.partnerId,
    this.partnerName,
    this.partnerAvatar,
    this.partnerRole,
  });

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
    final isPortal = user?.isPortal ?? (meta?['is_portal'] == true || meta?['user_type'] == 'portal');
    final String role;
    final String company;
    if (isPortal) {
      final rawFunc = (meta?['function'] as String?)?.trim();
      role = (rawFunc != null && rawFunc.isNotEmpty) ? rawFunc : 'Khách hàng';
      final rawPartnerComp = (meta?['partner_company_name'] as String?)?.trim();
      company = (rawPartnerComp != null && rawPartnerComp.isNotEmpty) ? rawPartnerComp : 'Khách hàng cá nhân';
    } else {
      final rawJob = (meta?['job_title'] as String?)?.trim() ?? (meta?['role'] as String?)?.trim() ?? (meta?['function'] as String?)?.trim();
      role = (rawJob != null && rawJob.isNotEmpty) ? rawJob : 'Chưa cập nhật';
      final rawComp = (meta?['company'] as String?)?.trim() ?? (meta?['company_name'] as String?)?.trim();
      company = (rawComp != null && rawComp.isNotEmpty) ? rawComp : '360 CORP';
    }
    final rawAvatar = meta?['avatar_url'] ??
        meta?['avatar_128_url'] ??
        meta?['image_128_url'] ??
        (user != null ? '/api/v1/mobile/avatar/users/${user.id}' : null);
    final avatarUrl = rawAvatar is String && rawAvatar.isNotEmpty ? rawAvatar : null;

    final currentPartnerId = odooApiClient.session?.partnerId?.toString();
    final currentUserId = user?.id ?? odooApiClient.session?.uid.toString();
    final isViewingPartner = partnerId != null &&
        partnerId!.isNotEmpty &&
        partnerId != currentPartnerId &&
        partnerId != currentUserId;

    if (isViewingPartner) {
      return _buildPartnerProfile(context, ref);
    }

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
                  const _BiometricSettingRow(),
                  _ThemeRow(),
                  const _CacheRow(),
                  _SettingsRow(
                    icon: LucideIcons.info,
                    label: 'Thông tin ứng dụng',
                    color: AppColors.primary,
                    onTap: () => context.push('/profile/about'),
                  ),
                  _SettingsRow(
                    icon: LucideIcons.userX,
                    label: 'Yêu cầu xóa tài khoản',
                    color: AppColors.danger,
                    danger: true,
                    onTap: () => _confirmDeleteAccount(context, ref),
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

  Widget _buildPartnerProfile(BuildContext context, WidgetRef ref) {
    final pId = int.tryParse(partnerId ?? '') ?? 0;
    final contactDetailAsync = pId > 0 ? ref.watch(partnerContactDetailProvider(pId)) : null;
    final detail = contactDetailAsync?.valueOrNull;
    final isLoading = contactDetailAsync?.isLoading == true;

    final displayName = detail?.name.isNotEmpty == true
        ? detail!.name
        : (partnerName?.trim().isNotEmpty == true
            ? partnerName!.trim()
            : 'Đối tác / Khách hàng');
    final isCompany = detail?.isCompany ?? false;
    final role = detail?.subtitleInfo.isNotEmpty == true
        ? detail!.subtitleInfo
        : (partnerRole?.trim().isNotEmpty == true
            ? partnerRole!.trim()
            : (isCompany ? 'Doanh nghiệp' : 'Khách hàng cá nhân'));

    final detailAvatar = detail?.avatarUrl;
    final fallbackAvatar = partnerAvatar;
    final targetUrl = (detailAvatar != null && detailAvatar.isNotEmpty)
        ? detailAvatar
        : ((fallbackAvatar != null && fallbackAvatar.isNotEmpty)
            ? fallbackAvatar
            : '/api/v1/mobile/avatar/res.partner/$pId');
    final avatarUrl = targetUrl.startsWith('http')
        ? targetUrl
        : odooApiClient.absoluteUrl(targetUrl);

    final metrics = detail?.smartMetrics ?? const PartnerSmartMetrics();
    final companyName = detail?.effectiveCompanyName ?? '';
    final vat = detail?.vat ?? '';
    final contactAddress = detail?.contactAddress ?? '';
    final function = detail?.function ?? '';
    final email = detail?.email ?? '';
    final phone = detail?.phone ?? '';
    final website = detail?.website ?? '';
    final tags = detail?.tags ?? const <String>[];

    void copyWithFeedback(String text, String message) {
      Clipboard.setData(ClipboardData(text: text));
      HapticFeedback.lightImpact();
      AppToast.success(context, title: 'Đã sao chép', message: message);
    }

    void copyOdooWebLink() {
      if (pId <= 0) return;
      final webUrl = odooApiClient.absoluteUrl('/web#id=$pId&model=res.partner&view_type=form');
      copyWithFeedback(webUrl, 'Đã sao chép liên kết Odoo vào bộ nhớ tạm.');
    }

    return AppScaffold(
      title: displayName,
      showAppBar: false,
      wrapSafeArea: false,
      body: ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: SafeArea(
          child: Column(
            children: [
              // ── 1. Top Bar ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(LucideIcons.arrowLeft),
                      onPressed: () => context.pop(),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        isCompany
                            ? 'Hồ sơ doanh nghiệp'
                            : (partnerRole != null && partnerRole!.isNotEmpty
                                ? 'Hồ sơ đồng nghiệp'
                                : 'Hồ sơ đối tác'),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    if (pId > 0) ...[
                      IconButton(
                        icon: const Icon(LucideIcons.rotateCw, size: 19),
                        tooltip: 'Làm mới',
                        onPressed: () => ref.refresh(partnerContactDetailProvider(pId)),
                      ),
                      IconButton(
                        icon: const Icon(LucideIcons.externalLink, size: 19),
                        tooltip: 'Sao chép liên kết Odoo',
                        onPressed: copyOdooWebLink,
                      ),
                    ],
                  ],
                ),
              ),

              if (isLoading && detail == null)
                const LinearProgressIndicator(
                  minHeight: 2.5,
                  backgroundColor: Colors.transparent,
                  color: Color(0xFF0077CD),
                ),

              // ── 2. Scrollable Content ──
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
                  children: [
                    // ── Hero Profile Card ──
                    _PartnerHeroCard(
                      partnerId: pId > 0 ? pId.toString() : (partnerId ?? ''),
                      name: displayName,
                      role: role,
                      isCompany: isCompany,
                      avatarUrl: avatarUrl,
                    ),
                    const SizedBox(height: 16),

                    // ── Smart Metrics Section (Chỉ số Odoo) ──
                    _PartnerSmartMetricsSection(
                      metrics: metrics,
                      onTicketsTap: () => context.push('/tickets'),
                    ),
                    const SizedBox(height: 16),

                    // ── Enterprise & Legal Information ──
                    _EnterpriseDetailsCard(
                      companyName: companyName != displayName ? companyName : '',
                      vat: vat,
                      function: function,
                      contactAddress: contactAddress,
                      email: email,
                      phone: phone,
                      website: website,
                      tags: tags,
                      onCopy: copyWithFeedback,
                    ),
                    const SizedBox(height: 16),

                    // ── Actions Card ──
                    _SettingsCard(
                      children: [
                        _SettingsRow(
                          icon: LucideIcons.messageSquare,
                          label: 'Nhắn tin cá nhân',
                          color: const Color(0xFF00C83A),
                          onTap: () {
                            ChatV2AvatarActionSheet.openDirectChat(
                              context,
                              ref,
                              partnerId: partnerId ?? pId.toString(),
                              name: displayName,
                              avatarUrl: avatarUrl,
                            );
                          },
                        ),
                        _SettingsRow(
                          icon: LucideIcons.image,
                          label: 'Xem ảnh đại diện (phóng to)',
                          color: const Color(0xFF8B5CF6),
                          onTap: () {
                            Navigator.of(context).push(
                              ChatV2ImageViewerScreen.route(
                                imageUrl: avatarUrl,
                                title: displayName,
                              ),
                            );
                          },
                        ),
                        if (pId > 0) ...[
                          _SettingsRow(
                            icon: LucideIcons.copy,
                            label: 'Sao chép mã đối tác (#$pId)',
                            color: const Color(0xFF0077CD),
                            onTap: () => copyWithFeedback(
                              pId.toString(),
                              'Đã sao chép mã đối tác #$pId',
                            ),
                          ),
                          _SettingsRow(
                            icon: LucideIcons.externalLink,
                            label: 'Sao chép liên kết Odoo Web',
                            color: const Color(0xFF0D9488),
                            onTap: copyOdooWebLink,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteAccount(BuildContext context, WidgetRef ref) {
    final user = ref.read(authControllerProvider).value;
    final email = user?.email ?? '';

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yêu cầu xóa tài khoản'),
        content: const Text(
          'Bạn muốn gửi yêu cầu xóa tài khoản? '
          'Chúng tôi sẽ xử lý yêu cầu của bạn trong vòng 30 ngày '
          'theo quy định bảo mật dữ liệu.',
        ),
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
              final subject = Uri.encodeComponent('Yêu cầu xóa tài khoản VCloud');
              final body = Uri.encodeComponent(
                'Tôi muốn yêu cầu xóa tài khoản VCloud của tôi.\n\n'
                'Email đăng nhập: $email\n\n'
                'Vui lòng xử lý yêu cầu này theo quy định bảo mật dữ liệu.',
              );
              launchUrl(
                Uri.parse('mailto:support@360.org.vn?subject=$subject&body=$body'),
              );
            },
            child: const Text('Gửi yêu cầu'),
          ),
        ],
      ),
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

class _ProfileTopBar extends StatelessWidget {
  const _ProfileTopBar();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(LucideIcons.arrowLeft),
            tooltip: 'Quay lại',
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/home');
              }
            },
          ),
          const SizedBox(width: 4),
          Text(
            'Hồ sơ của tôi',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const Spacer(),
          const BrandLogo(height: 38),
        ],
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

  void _openAvatarZoom(BuildContext context) {
    final target = (avatarUrl != null && avatarUrl!.isNotEmpty)
        ? avatarUrl!
        : (userId.isNotEmpty ? '/api/v1/mobile/avatar/users/$userId' : null);
    if (target == null || target.isEmpty) return;
    final fullUrl = target.startsWith('http')
        ? target
        : odooApiClient.absoluteUrl(target);
    Navigator.of(context).push(
      ChatV2ImageViewerScreen.route(
        imageUrl: fullUrl,
        title: name,
      ),
    );
  }

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
                GestureDetector(
                  onTap: () => _openAvatarZoom(context),
                  behavior: HitTestBehavior.opaque,
                  child: UserAvatar(
                    userId: userId,
                    displayName: name,
                    email: email,
                    avatarUrl: avatarUrl,
                    size: 62,
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: GestureDetector(
                    onTap: () => context.push('/profile/edit'),
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
                if (email.isNotEmpty) ...[
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
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
}

class _PartnerHeroCard extends StatelessWidget {
  final String partnerId;
  final String name;
  final String role;
  final bool isCompany;
  final String avatarUrl;

  const _PartnerHeroCard({
    required this.partnerId,
    required this.name,
    required this.role,
    required this.isCompany,
    required this.avatarUrl,
  });

  void _openAvatarZoom(BuildContext context) {
    if (avatarUrl.isEmpty) return;
    Navigator.of(context).push(
      ChatV2ImageViewerScreen.route(
        imageUrl: avatarUrl,
        title: name,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: () => _openAvatarZoom(context),
            child: Stack(
              children: [
                UserAvatar(
                  userId: partnerId,
                  displayName: name,
                  email: '',
                  avatarUrl: avatarUrl,
                  size: 64,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isCompany ? const Color(0xFF0077CD) : const Color(0xFF00C83A),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? const Color(0xFF1E293B) : Colors.white,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      isCompany ? LucideIcons.building2 : LucideIcons.user,
                      color: Colors.white,
                      size: 11,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: isCompany
                            ? const Color(0xFF0077CD).withValues(alpha: 0.15)
                            : const Color(0xFF00C83A).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isCompany ? 'Doanh nghiệp' : 'Cá nhân',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: isCompany ? const Color(0xFF0077CD) : const Color(0xFF00C83A),
                        ),
                      ),
                    ),
                    if (partnerId.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '#$partnerId',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                  ],
                ),
                if (role.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    role,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      height: 1.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PartnerSmartMetricsSection extends StatelessWidget {
  final PartnerSmartMetrics metrics;
  final VoidCallback? onTicketsTap;

  const _PartnerSmartMetricsSection({
    required this.metrics,
    this.onTicketsTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFF0077CD).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  LucideIcons.gauge,
                  size: 15,
                  color: Color(0xFF0077CD),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Chỉ số hoạt động Odoo',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  icon: LucideIcons.ticket,
                  color: const Color(0xFFF59E0B),
                  count: metrics.ticketCount,
                  label: 'Phiếu hỗ trợ',
                  unit: 'vé',
                  onTap: onTicketsTap,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricTile(
                  icon: LucideIcons.briefcase,
                  color: const Color(0xFF10B981),
                  count: metrics.opportunityCount,
                  label: 'Cơ hội CRM',
                  unit: 'cơ hội',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  icon: LucideIcons.shoppingBag,
                  color: const Color(0xFF6366F1),
                  count: metrics.saleOrderCount,
                  label: 'Đơn bán hàng',
                  unit: 'đơn',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricTile(
                  icon: LucideIcons.checkSquare,
                  color: const Color(0xFF0077CD),
                  count: metrics.taskCount,
                  label: 'Nhiệm vụ',
                  unit: 'việc',
                ),
              ),
            ],
          ),
          if (metrics.meetingCount > 0) ...[
            const SizedBox(height: 10),
            _MetricTile(
              icon: LucideIcons.calendar,
              color: const Color(0xFF06B6D4),
              count: metrics.meetingCount,
              label: 'Lịch hẹn / Cuộc họp',
              unit: 'buổi',
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final int count;
  final String label;
  final String unit;
  final VoidCallback? onTap;

  const _MetricTile({
    required this.icon,
    required this.color,
    required this.count,
    required this.label,
    required this.unit,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    child: Icon(icon, color: color, size: 14),
                  ),
                  const Spacer(),
                  Text(
                    count.toString(),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: count > 0 ? color : (isDark ? Colors.white60 : const Color(0xFF64748B)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EnterpriseDetailsCard extends StatelessWidget {
  final String companyName;
  final String vat;
  final String function;
  final String contactAddress;
  final String email;
  final String phone;
  final String website;
  final List<String> tags;
  final void Function(String text, String message) onCopy;

  const _EnterpriseDetailsCard({
    required this.companyName,
    required this.vat,
    required this.function,
    required this.contactAddress,
    required this.email,
    required this.phone,
    required this.website,
    required this.tags,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final hasAnyData = companyName.isNotEmpty ||
        vat.isNotEmpty ||
        function.isNotEmpty ||
        contactAddress.isNotEmpty ||
        email.isNotEmpty ||
        phone.isNotEmpty ||
        website.isNotEmpty ||
        tags.isNotEmpty;

    return Container(
      decoration: _cardDecoration(context),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFF00C83A).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  LucideIcons.building,
                  size: 15,
                  color: Color(0xFF00C83A),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Thông tin doanh nghiệp & Pháp lý',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (!hasAnyData)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Chưa có thông tin doanh nghiệp chi tiết trong hồ sơ Odoo.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textMuted,
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          else ...[
            if (companyName.isNotEmpty)
              _DetailRowItem(
                icon: LucideIcons.building2,
                label: 'Tổ chức / Công ty',
                value: companyName,
                iconColor: const Color(0xFF0077CD),
              ),
            if (vat.isNotEmpty)
              _DetailRowItem(
                icon: LucideIcons.receipt,
                label: 'Mã số thuế',
                value: vat,
                iconColor: const Color(0xFFEA580C),
                highlightValue: true,
                onCopy: () => onCopy(vat, 'Đã sao chép mã số thuế: $vat'),
              ),
            if (function.isNotEmpty)
              _DetailRowItem(
                icon: LucideIcons.briefcase,
                label: 'Chức vụ',
                value: function,
                iconColor: const Color(0xFF8B5CF6),
              ),
            if (contactAddress.isNotEmpty)
              _DetailRowItem(
                icon: LucideIcons.mapPin,
                label: 'Địa chỉ liên hệ',
                value: contactAddress,
                iconColor: const Color(0xFFEF4444),
                onCopy: () => onCopy(contactAddress, 'Đã sao chép địa chỉ liên hệ.'),
              ),
            if (email.isNotEmpty)
              _DetailRowItem(
                icon: LucideIcons.mail,
                label: 'Email',
                value: email,
                iconColor: const Color(0xFF0D9488),
                onCopy: () => onCopy(email, 'Đã sao chép email: $email'),
              ),
            if (phone.isNotEmpty)
              _DetailRowItem(
                icon: LucideIcons.phone,
                label: 'Điện thoại',
                value: phone,
                iconColor: const Color(0xFF059669),
                onTap: () {
                  final uri = Uri.parse('tel:$phone');
                  launchUrl(uri);
                },
                onCopy: () => onCopy(phone, 'Đã sao chép số điện thoại: $phone'),
              ),
            if (website.isNotEmpty)
              _DetailRowItem(
                icon: LucideIcons.globe,
                label: 'Website',
                value: website,
                iconColor: const Color(0xFF2563EB),
                onTap: () {
                  final full = website.startsWith('http') ? website : 'https://$website';
                  launchUrl(Uri.parse(full), mode: LaunchMode.externalApplication);
                },
              ),
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF64748B).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(LucideIcons.tag, size: 15, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Nhãn / Phân loại',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final tag in tags)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0077CD).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFF0077CD).withValues(alpha: 0.25),
                                  ),
                                ),
                                child: Text(
                                  tag,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0077CD),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _DetailRowItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;
  final bool highlightValue;
  final VoidCallback? onTap;
  final VoidCallback? onCopy;

  const _DetailRowItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
    this.highlightValue = false,
    this.onTap,
    this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 15, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: highlightValue ? FontWeight.w800 : FontWeight.w600,
                      color: highlightValue
                          ? (isDark ? const Color(0xFF38BDF8) : const Color(0xFF0077CD))
                          : Theme.of(context).colorScheme.onSurface,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (onCopy != null)
            IconButton(
              icon: const Icon(LucideIcons.copy, size: 16),
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
              tooltip: 'Sao chép',
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: onCopy,
            ),
        ],
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

class _BiometricSettingRow extends ConsumerStatefulWidget {
  const _BiometricSettingRow();

  @override
  ConsumerState<_BiometricSettingRow> createState() => _BiometricSettingRowState();
}

class _BiometricSettingRowState extends ConsumerState<_BiometricSettingRow> {
  bool _available = false;
  bool _enabled = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    try {
      final bio = ref.read(biometricServiceProvider);
      final avail = await bio.isHardwareAvailable();
      final en = await bio.isBiometricEnabled();
      if (mounted) {
        setState(() {
          _available = avail;
          _enabled = en;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggle(bool value) async {
    final bio = ref.read(biometricServiceProvider);
    if (!value) {
      await bio.disableBiometrics();
      if (mounted) {
        setState(() => _enabled = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã tắt đăng nhập bằng sinh trắc học.')),
        );
      }
      return;
    }

    final authed = await bio.authenticate(
      reason: 'Xác thực vân tay hoặc Face ID để kích hoạt tính năng',
    );
    if (!authed) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Xác thực sinh trắc học không thành công hoặc đã bị hủy.')),
        );
      }
      return;
    }

    if (!mounted) return;
    final pwdController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận mật khẩu'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Nhập mật khẩu tài khoản hiện tại để lưu an toàn vào phần cứng máy (Keystore/Keychain) cho các lần mở khóa sau:',
              style: TextStyle(fontSize: 13.5),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: pwdController,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Nhập mật khẩu của bạn',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Kích hoạt'),
          ),
        ],
      ),
    );

    if (confirmed == true && pwdController.text.isNotEmpty && mounted) {
      final user = ref.read(authControllerProvider).value;
      final session = odooApiClient.session;
      final login = user?.email ?? session?.login ?? '';
      final db = session?.db ?? '';
      await bio.enableBiometrics(
        login: login,
        password: pwdController.text,
        db: db,
      );
      if (mounted) {
        setState(() => _enabled = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã kích hoạt khóa sinh trắc học thành công!')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || !_available) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.soft(const Color(0xFF0077CD)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              LucideIcons.fingerprint,
              color: Color(0xFF0077CD),
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Khóa sinh trắc học (Face ID / Vân tay)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Mở khóa ứng dụng nhanh và bảo mật',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: _enabled,
            onChanged: _toggle,
            activeTrackColor: const Color(0xFF0077CD),
          ),
        ],
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

