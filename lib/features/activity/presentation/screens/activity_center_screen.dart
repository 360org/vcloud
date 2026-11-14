import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/app_toast.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/loading_view.dart';
import '../../../menu/presentation/app_drawer_bottom_sheet.dart';
import '../../data/models/activity_item.dart';
import '../../data/models/activity_type.dart';
import '../../data/repositories/activity_repository.dart';

/// Màn hình Native Activity Center quản lý việc cần làm (`mail.activity`)
/// kết hợp mở xem chi tiết chứng từ nguồn trong In-App WebView.
class ActivityCenterScreen extends ConsumerStatefulWidget {
  const ActivityCenterScreen({super.key});

  /// Điều hướng chi tiết hoạt động với Native Router Resolver:
  /// - Nếu là helpdesk.ticket và có resId hợp lệ (> 0): chuyển sang màn hình native TicketDetailScreen (`/tickets/:id`).
  /// - Các model khác (project.task, crm.lead, hr.leave...) hoặc thiếu resId: fallback mở In-App WebView.
  static void openActivityDetail(BuildContext context, ActivityItem item) {
    final model = item.resModel?.trim() ?? '';
    final resId = item.resId ?? 0;

    if (model == 'helpdesk.ticket' && resId > 0) {
      context.push('/tickets/$resId');
      return;
    }

    final url = buildActivityDetailWebUrl(item);
    final title = buildActivityDetailTitle(item);
    final uri = Uri(
      path: '/webview',
      queryParameters: {
        'url': url,
        'title': title,
      },
    );
    context.push(uri.toString());
  }

  /// Tạo URL Odoo chuẩn để mở thẳng Form chứng từ gốc của hoạt động trong WebView.
  /// Sử dụng route `/mail/view?model=<res_model>&res_id=<res_id>` tương thích cả Odoo 17 & 19.
  static String buildActivityDetailWebUrl(ActivityItem item) {
    final model = item.resModel?.trim() ?? '';
    final resId = item.resId ?? 0;
    if (model.isNotEmpty && resId > 0) {
      return formatAppWebUrl(
        '/mail/view?model=${Uri.encodeQueryComponent(model)}&res_id=$resId',
      );
    }
    return formatAppWebUrl('/web#action=2186');
  }

  /// Tạo tiêu đề hiển thị trên thanh AppBar của WebView khi xem chi tiết hoạt động.
  static String buildActivityDetailTitle(ActivityItem item) {
    if (item.resName?.trim().isNotEmpty == true) {
      return item.resName!.trim();
    }
    if (item.summary.trim().isNotEmpty) {
      return item.summary.trim();
    }
    return 'Hoạt động #${item.id}';
  }

  @override
  ConsumerState<ActivityCenterScreen> createState() => _ActivityCenterScreenState();
}

class _ActivityCenterScreenState extends ConsumerState<ActivityCenterScreen> {
  static const _tabFilters = <String>['all', 'overdue', 'today', 'planned'];
  static const _tabLabels = <String>[
    'Tất cả',
    '🔴 Quá hạn',
    '🟢 Hôm nay',
    '🟡 Sắp tới',
  ];

  int _selectedTabIndex = 0;
  int? _selectedTypeId;
  bool _isLoading = true;
  Object? _error;
  List<ActivityItem> _activities = const <ActivityItem>[];
  List<ActivityType> _types = const <ActivityType>[];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repo = ref.read(activityRepositoryProvider);
      final typesFuture = repo.getActivityTypes();
      final filter = _tabFilters[_selectedTabIndex];
      final activitiesFuture = repo.getActivities(
        filter: filter,
        typeId: _selectedTypeId,
      );

      final results = await Future.wait([typesFuture, activitiesFuture]);
      if (!mounted) return;

      setState(() {
        _types = results[0] as List<ActivityType>;
        _activities = results[1] as List<ActivityItem>;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadActivities() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repo = ref.read(activityRepositoryProvider);
      final filter = _tabFilters[_selectedTabIndex];
      final items = await repo.getActivities(
        filter: filter,
        typeId: _selectedTypeId,
      );
      if (!mounted) return;

      setState(() {
        _activities = items;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _isLoading = false;
      });
    }
  }

  List<ActivityItem> get _displayedActivities {
    final filter = _tabFilters[_selectedTabIndex];
    var list = _activities;

    if (_selectedTypeId != null) {
      list = list.where((a) => a.activityTypeId == _selectedTypeId).toList();
    }

    if (filter == 'overdue') {
      list = list.where((a) => a.isOverdue).toList();
    } else if (filter == 'today') {
      list = list.where((a) => a.isToday).toList();
    } else if (filter == 'planned') {
      list = list.where((a) => a.isPlanned).toList();
    }

    return list;
  }

  Future<void> _handleMarkDone(ActivityItem item) async {
    final feedbackController = TextEditingController();
    var isSubmitting = false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  const Icon(
                    LucideIcons.circleCheck,
                    color: AppColors.success,
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Hoàn tất hoạt động',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.summary.isNotEmpty ? item.summary : 'Hoạt động #${item.id}',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w600,
                        color: isDark ? const Color(0xFFE2E8F0) : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: feedbackController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: 'Nhập phản hồi / kết quả (tuỳ chọn)...',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: isDark ? const Color(0xFF64748B) : AppColors.textMuted,
                        ),
                        filled: true,
                        fillColor: isDark
                            ? const Color(0xFF0F172A)
                            : const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: isDark
                                ? const Color(0xFF334155)
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.of(ctx).pop(false),
                  child: const Text('Hủy bỏ'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: isSubmitting
                      ? null
                      : () {
                          setDialogState(() => isSubmitting = true);
                          Navigator.of(ctx).pop(true);
                        },
                  child: const Text(
                    'Xác nhận hoàn tất',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) return;

    try {
      final feedback = feedbackController.text.trim();
      await ref.read(activityRepositoryProvider).markDone(
        item.id,
        feedback: feedback.isNotEmpty ? feedback : null,
      );
      if (!mounted) return;
      AppToast.success(context, title: 'Đã hoàn tất hoạt động');
      await _loadActivities();
    } catch (e) {
      if (!mounted) return;
      AppToast.error(context, title: 'Không thể hoàn tất: $e');
    }
  }

  Future<void> _handleCancel(ActivityItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              const Icon(
                LucideIcons.triangleAlert,
                color: AppColors.danger,
                size: 24,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Hủy hoạt động',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            'Bạn có chắc chắn muốn hủy hoạt động "${item.summary.isNotEmpty ? item.summary : '#${item.id}'}" không?',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? const Color(0xFFCBD5E1) : AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Đóng'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text(
                'Xác nhận hủy',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await ref.read(activityRepositoryProvider).cancelActivity(item.id);
      if (!mounted) return;
      AppToast.success(context, title: 'Đã hủy hoạt động thành công');
      await _loadActivities();
    } catch (e) {
      if (!mounted) return;
      AppToast.error(context, title: 'Không thể hủy hoạt động: $e');
    }
  }

  void _openOnOdooWeb() {
    const rawUrl = '/web#action=2186';
    final url = formatAppWebUrl(rawUrl);
    final uri = Uri(
      path: '/webview',
      queryParameters: {
        'url': url,
        'title': 'Việc cần làm (Odoo)',
      },
    );
    context.push(uri.toString());
  }

  void _openActivityDetail(ActivityItem item) {
    ActivityCenterScreen.openActivityDetail(context, item);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppScaffold(
      title: 'Việc cần làm',
      showBackButton: true,
      actions: [
        IconButton(
          tooltip: 'Mở trên Odoo Web',
          icon: const Icon(LucideIcons.globe, size: 20),
          onPressed: _openOnOdooWeb,
        ),
      ],
      body: Column(
        children: [
          // 4 Tab hạn chót
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(_tabLabels.length, (index) {
                  final isSelected = _selectedTabIndex == index;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InkWell(
                      onTap: () {
                        if (_selectedTabIndex != index) {
                          setState(() => _selectedTabIndex = index);
                          _loadActivities();
                        }
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (isDark
                                  ? const Color(0xFF0077D9)
                                  : AppColors.primary)
                              : (isDark
                                  ? const Color(0xFF1E293B)
                                  : Colors.white),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? Colors.transparent
                                : (isDark
                                    ? const Color(0xFF334155)
                                    : const Color(0xFFE2E8F0)),
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: (isDark
                                            ? const Color(0xFF0077D9)
                                            : AppColors.primary)
                                        .withValues(alpha: 0.25),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Text(
                          _tabLabels[index],
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isSelected
                                ? Colors.white
                                : (isDark
                                    ? const Color(0xFF94A3B8)
                                    : AppColors.textSecondary),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),

          // Thanh cuộn ngang các FilterChip loại hoạt động
          if (_types.isNotEmpty)
            Container(
              padding: const EdgeInsets.only(bottom: 10, top: 2),
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    _buildTypeChip(
                      label: 'Tất cả loại',
                      isSelected: _selectedTypeId == null,
                      onTap: () {
                        if (_selectedTypeId != null) {
                          setState(() => _selectedTypeId = null);
                          _loadActivities();
                        }
                      },
                      isDark: isDark,
                    ),
                    const SizedBox(width: 8),
                    ..._types.map((type) {
                      final isSelected = _selectedTypeId == type.id;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _buildTypeChip(
                          label: type.name,
                          isSelected: isSelected,
                          onTap: () {
                            setState(() {
                              _selectedTypeId =
                                  isSelected ? null : type.id;
                            });
                            _loadActivities();
                          },
                          isDark: isDark,
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),

          const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),

          // Nội dung danh sách thẻ việc cần làm
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF334155) : const Color(0xFF0F172A))
              : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? (isDark ? const Color(0xFF64748B) : const Color(0xFF0F172A))
                : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected
                ? Colors.white
                : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569)),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: LoadingView(label: 'Đang tải việc cần làm...'));
    }

    if (_error != null) {
      return Column(
        children: [
          Expanded(
            child: ErrorView(
              error: _error!,
              onRetry: _loadData,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 24, left: 24, right: 24),
            child: OutlinedButton.icon(
              icon: const Icon(LucideIcons.globe, size: 18),
              label: const Text('Mở trên Odoo Web (/home/action-2186)'),
              onPressed: _openOnOdooWeb,
            ),
          ),
        ],
      );
    }

    final items = _displayedActivities;
    if (items.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) {
          return RefreshIndicator(
            onRefresh: _loadData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                    child: EmptyState(
                      icon: LucideIcons.calendarCheck,
                      title: 'Không có việc cần làm nào',
                      subtitle: 'Mọi việc cần làm theo tiêu chí này đã được xử lý xong.',
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (ctx, index) {
          final item = items[index];
          return _ActivityCard(
            item: item,
            onTap: () => _openActivityDetail(item),
            onDone: () => _handleMarkDone(item),
            onCancel: () => _handleCancel(item),
          );
        },
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.item,
    required this.onTap,
    required this.onDone,
    required this.onCancel,
  });

  final ActivityItem item;
  final VoidCallback onTap;
  final VoidCallback onDone;
  final VoidCallback onCancel;

  String _formatDeadline(DateTime dt) {
    final dateStr = Dates.dateVi(dt);
    if (dt.hour != 0 || dt.minute != 0) {
      return '$dateStr ${Dates.hm(dt)}';
    }
    return dateStr;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final typeVisual = _ActivityTypeVisual.resolve(item.activityTypeName);
    final stateVisual = _StateVisual.resolve(item);
    final sourceLabel = item.resName?.isNotEmpty == true
        ? item.resName!
        : (item.resModel?.isNotEmpty == true ? item.resModel! : 'Chứng từ #${item.id}');

    return Material(
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        key: ValueKey('activity_card_${item.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Badge loại hoạt động & Badge hạn chót
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                    decoration: BoxDecoration(
                      color: isDark
                          ? typeVisual.color.withValues(alpha: 0.15)
                          : typeVisual.bgColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          typeVisual.icon,
                          size: 13,
                          color: typeVisual.color,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          item.activityTypeName?.isNotEmpty == true
                              ? item.activityTypeName!
                              : 'Hoạt động',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: typeVisual.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                    decoration: BoxDecoration(
                      color: isDark
                          ? stateVisual.color.withValues(alpha: 0.15)
                          : stateVisual.bgColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          stateVisual.icon,
                          size: 13,
                          color: stateVisual.color,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          stateVisual.label,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: stateVisual.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Tiêu đề tóm tắt việc
              Text(
                item.summary.isNotEmpty ? item.summary : 'Hoạt động #${item.id}',
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                  height: 1.35,
                ),
              ),

              // Ghi chú (nếu có)
              if (item.note.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF0F172A)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        LucideIcons.fileText,
                        size: 14,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          item.note,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: isDark
                                ? const Color(0xFFCBD5E1)
                                : const Color(0xFF475569),
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 10),

              // Dòng chứng từ nguồn + nút Xem chi tiết mở WebView
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    const Icon(
                      LucideIcons.folderGit2,
                      size: 14,
                      color: Color(0xFF0077D9),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        sourceLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0077D9),
                        ),
                      ),
                    ),
                    if (item.userName?.isNotEmpty == true) ...[
                      const SizedBox(width: 8),
                      Icon(
                        LucideIcons.user,
                        size: 13,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          item.userName!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Xem chi tiết',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0077D9),
                          ),
                        ),
                        SizedBox(width: 2),
                        Icon(
                          LucideIcons.chevronRight,
                          size: 14,
                          color: Color(0xFF0077D9),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Hạn chót định dạng ngày giờ tiếng Việt
              if (item.dateDeadline != null)
                Row(
                  children: [
                    Icon(
                      LucideIcons.calendar,
                      size: 14,
                      color: stateVisual.color,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Hạn chót: ${_formatDeadline(item.dateDeadline!)}',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: stateVisual.color,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        '(${Dates.slaLabelVi(item.dateDeadline!)})',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),

              const SizedBox(height: 14),
              const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
              const SizedBox(height: 12),

              // 2 Nút thao tác nhanh: [✔ Hoàn tất] và [✖ Hủy]
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onCancel,
                      icon: const Icon(
                        LucideIcons.x,
                        size: 15,
                        color: Color(0xFFEF4444),
                      ),
                      label: const Text(
                        'Hủy',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFFCA5A5)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 9),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onDone,
                      icon: const Icon(
                        LucideIcons.check,
                        size: 15,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'Hoàn tất',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 9),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

typedef _ActivityTypeVisual = ActivityTypeVisual;
typedef _StateVisual = ActivityStateVisual;

class ActivityTypeVisual {
  const ActivityTypeVisual({
    required this.color,
    required this.bgColor,
    required this.icon,
  });

  final Color color;
  final Color bgColor;
  final IconData icon;

  static ActivityTypeVisual resolve(String? name) {
    final lower = (name ?? '').toLowerCase();
    if (lower.contains('gọi') || lower.contains('call') || lower.contains('điện')) {
      return const ActivityTypeVisual(
        color: Color(0xFF0077D9),
        bgColor: Color(0xFFEFF6FF),
        icon: LucideIcons.phoneCall,
      );
    }
    if (lower.contains('email') || lower.contains('mail') || lower.contains('thư')) {
      return const ActivityTypeVisual(
        color: Color(0xFF7C3AED),
        bgColor: Color(0xFFF5F3FF),
        icon: LucideIcons.mail,
      );
    }
    if (lower.contains('gặp') || lower.contains('họp') || lower.contains('meeting')) {
      return const ActivityTypeVisual(
        color: Color(0xFFEA580C),
        bgColor: Color(0xFFFFF7ED),
        icon: LucideIcons.calendarDays,
      );
    }
    if (lower.contains('việc') || lower.contains('todo') || lower.contains('task')) {
      return const ActivityTypeVisual(
        color: Color(0xFF16A34A),
        bgColor: Color(0xFFF0FDF4),
        icon: LucideIcons.checkSquare,
      );
    }
    return const ActivityTypeVisual(
      color: Color(0xFF475569),
      bgColor: Color(0xFFF1F5F9),
      icon: LucideIcons.clock,
    );
  }
}

class ActivityStateVisual {
  const ActivityStateVisual({
    required this.color,
    required this.bgColor,
    required this.icon,
    required this.label,
  });

  final Color color;
  final Color bgColor;
  final IconData icon;
  final String label;

  static ActivityStateVisual resolve(ActivityItem item) {
    if (item.isOverdue) {
      return const ActivityStateVisual(
        color: Color(0xFFDC2626),
        bgColor: Color(0xFFFEF2F2),
        icon: LucideIcons.alertCircle,
        label: 'Quá hạn',
      );
    }
    if (item.isToday) {
      return const ActivityStateVisual(
        color: Color(0xFF16A34A),
        bgColor: Color(0xFFF0FDF4),
        icon: LucideIcons.clock,
        label: 'Hôm nay',
      );
    }
    return const ActivityStateVisual(
      color: Color(0xFFD97706),
      bgColor: Color(0xFFFFFBEB),
      icon: LucideIcons.calendarClock,
      label: 'Sắp tới',
    );
  }
}
