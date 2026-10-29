import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../../core/error/failure.dart';
import '../../../core/notifications/push_notification_controller.dart';
import '../../../core/notifications/push_notification_repository.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_format.dart';
import '../../../shared/models/task.dart';
import '../../../shared/models/timesheet.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/celebration_fireworks.dart';
import '../../../shared/widgets/ui_kit.dart';
import '../../../shared/widgets/location_prompt_dialog.dart';
import '../../attendance/application/attendance_controller.dart';
import '../../attendance/domain/shift_calculator.dart';
import '../../auth/application/auth_controller.dart';
import '../../chat_v2/application/chat_v2_channels_controller.dart';
import '../../livechat/application/livechat_controller.dart';
import '../../livechat/data/models/livechat_channel_model.dart';
import '../../livechat/presentation/widgets/livechat_selection_bottom_sheet.dart';
import '../../timesheet/application/task_controller.dart';


import '../../timesheet/application/timesheet_controller.dart';
import '../../timesheet/presentation/widgets/checklist_editor.dart';
import '../../ticket/application/ticket_controller.dart';
import '../../../shared/models/ticket.dart';
import '../application/home_summary_controller.dart';
import '../application/home_performance_diagnostics.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _statusBusy = false;
  final GlobalKey _fireworksChildKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    HomePerformanceDiagnostics.runBenchmark(ref);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // Tự động đồng bộ và nạp Push Device Token lên Odoo Backend mỗi khi mở màn hình Home
        ref.read(pushNotificationServiceProvider).registerCurrentDevice().catchError((e) {
          debugPrint('Silent push registration error on home load: $e');
          return null;
        });
      }
    });
  }

  Future<void> _showErrorDialog(dynamic error, StackTrace stackTrace) async {
    final errorMessage = error.toString();
    final fullDetails = 'Lỗi: $errorMessage\n\nStackTrace:\n$stackTrace';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Lỗi Chấm công'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(
                errorMessage,
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: fullDetails));
              if (dialogContext.mounted) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(
                    content: Text('Đã sao chép chi tiết lỗi vào Clipboard!'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            child: const Text('Copy Lỗi'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleAttendance(bool isOnline) async {
    final user = ref.read(authControllerProvider).valueOrNull;
    if (user != null && !user.hasAttendance) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tính năng yêu cầu cài đặt Module Chấm công'),
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }
    if (_statusBusy) return;
    setState(() => _statusBusy = true);
    try {
      final actions = ref.read(attendanceActionsProvider);
      if (isOnline) {
        await actions.checkOut();
      } else {
        await actions.checkIn();
        if (mounted) {
          CelebrationFireworksOverlay.trigger(_fireworksChildKey.currentContext ?? context);
        }
      }
      ref.invalidate(homeSummaryProvider);
      ref.invalidate(attendanceTodayProvider);
      ref.invalidate(openSessionProvider);
      ref.invalidate(mobileDashboardSummaryProvider);
    } catch (e, stackTrace) {
      if (mounted) {
        if (isLocationError(e)) {
          await showLocationPromptDialog(context, message: e is Failure ? e.message : e.toString());
        } else {
          await _showErrorDialog(e, stackTrace);
        }
      }
    } finally {
      if (mounted) setState(() => _statusBusy = false);
    }
  }

  Future<void> _openCskhChat() async {
    await LivechatSelectionBottomSheet.show(context);
  }

  @override
  Widget build(BuildContext context) {
    final summary = ref.watch(homeSummaryProvider);
    final todayState = ref.watch(attendanceTodayProvider);
    final dashboard = ref.watch(mobileDashboardSummaryProvider).valueOrNull;
    final notificationState = ref.watch(mobileNotificationsProvider);
    final dismissedIds = ref.watch(dismissedNotificationIdsProvider);
    final allNotifs = notificationState.valueOrNull?.items ?? const <MobileNotificationItem>[];
    final notificationCount = allNotifs
        .where((it) =>
            !dismissedIds.contains(it.id.toString()) &&
            !dismissedIds.contains('${it.eventType}_${it.id}'))
        .length;
    // DO NOT MODIFY OR REFACTOR THIS AVATAR LOADING LOGIC. IT IS THE SOURCE OF TRUTH FOR USER AVATAR DISPLAY.
    // CẤM SỬA HOẶC XÓA LOGIC TẢI AVATAR NÀY - ĐÂY LÀ NGUỒN SỰ THẬT HIỂN THỊ AVATAR DÙNG CHUNG.
    final user = ref.watch(authControllerProvider).valueOrNull;
    final meta = user?.userMetadata;
    final rawName = meta?['display_name'];
    final name = (rawName is String ? rawName : (rawName != null && rawName != false ? rawName.toString() : null))?.trim();
    final rawAvatar = meta?['avatar_url'] ??
        meta?['avatar_128_url'] ??
        meta?['image_128_url'] ??
        (user != null ? '/api/v1/mobile/avatar/users/${user.id}' : null);
    final avatarUrl = rawAvatar is String && rawAvatar.isNotEmpty ? rawAvatar : null;
    final displayName = (name != null && name.isNotEmpty)
        ? name
        : (user?.email?.split('@').first ?? 'Người dùng');
    final rawRole = meta?['role'] ?? meta?['function'] ?? meta?['job_title'];
    final jobTitle = (rawRole is String && rawRole.trim().isNotEmpty)
        ? rawRole.trim()
        : (rawRole != null && rawRole != false ? rawRole.toString().trim() : null);
    final rawCompany = meta?['company'] ?? meta?['company_name'];
    final companyName = (rawCompany is String && rawCompany.trim().isNotEmpty)
        ? rawCompany.trim()
        : (rawCompany != null && rawCompany != false ? rawCompany.toString().trim() : null);
    final allTasks = ref.watch(todayTasksProvider).valueOrNull ?? const <Task>[];
    final totalOpenTasksCount = allTasks.where((task) => !task.isCompleted).length;
    final todayTasks = allTasks
        .where((task) => !task.isCompleted)
        .take(3)
        .map(_todayTaskPreviewFromTask)
        .toList();
    // Attendance is the source of truth immediately after a toggle. The
    // dashboard is a separate cached snapshot and may be one request behind.
    final openSession = ref.watch(openSessionProvider);
    final isOnline = openSession?.isOpen ?? summary?.isCheckedIn ?? dashboard?.isCheckedIn ?? false;
    final todayAttendanceMinutes = ref.watch(todayAttendanceMinutesProvider);
    final closedMinutes = todayAttendanceMinutes > 0
        ? todayAttendanceMinutes
        : (dashboard?.todayMinutes ?? summary?.todayMinutes ?? 0);
    
    final shiftProgress = (isOnline && openSession?.checkinTime != null)
        ? ShiftCalculator.calculate(checkinTime: openSession!.checkinTime)
        : null;

    final todayMinutes = shiftProgress != null
        ? shiftProgress.workedMinutes
        : (closedMinutes + ((isOnline && openSession?.checkinTime != null)
            ? DateTime.now().difference(openSession!.checkinTime!).inMinutes
            : 0));

    final effectiveTickets = ref.watch(effectiveTicketsProvider);
    final localDoingTicketsCount = effectiveTickets.where((t) => t.status != TicketStatus.done).length;
    final openTickets = localDoingTicketsCount > 0
        ? localDoingTicketsCount
        : (dashboard?.openTickets ?? summary?.openTickets ?? 0);
    final loadedChatChannels = ref.watch(chatV2ChannelsProvider).valueOrNull;
    final serverChatCount = (dashboard?.recentConversationCount != null && dashboard!.recentConversationCount! > 0)
        ? dashboard.recentConversationCount!
        : (summary?.recentConversationCount != null && summary!.recentConversationCount > 0
            ? summary.recentConversationCount
            : null);
    final localChatCount = (loadedChatChannels != null && loadedChatChannels.isNotEmpty)
        ? loadedChatChannels.length
        : 0;
    // Ưu tiên số đếm tổng từ Server Dashboard; nếu chưa có thì fallback về số channel đã nạp trong local
    final fallbackChatCount = serverChatCount ?? localChatCount;
    final statusBusy = _statusBusy || todayState.isLoading;

    return AppScaffold(
      title: 'Home',
      showAppBar: false,
      body: CelebrationFireworksOverlay(
        autoTrigger: (user?.hasAttendance ?? true) && (shiftProgress?.isCompleted ?? (todayMinutes >= ShiftConfig.forDate(DateTime.now()).targetWorkMinutes)),
        child: RefreshIndicator(
          key: _fireworksChildKey,
          onRefresh: () async {
            ref.read(ticketOverrideProvider.notifier).set(null);
            ref.read(ticketHasMoreProvider.notifier).state = true;
            ref.invalidate(ticketsProvider);
            ref.invalidate(homeSummaryProvider);
            ref.invalidate(mobileDashboardSummaryProvider);
            ref.invalidate(attendanceTodayProvider);
            ref.invalidate(attendanceStreamProvider);
            ref.invalidate(todayTasksProvider);
            ref.invalidate(openSessionProvider);
            ref.invalidate(chatV2ChannelsProvider);
            ref.invalidate(mobileNotificationsProvider);
          },
          color: AppColors.primary,
          backgroundColor: Theme.of(context).cardColor,

          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _GreetingHeader(
                userId: user?.id ?? '',
                displayName: displayName,
                email: user?.email,
                avatarUrl: avatarUrl,
                jobTitle: jobTitle,
                companyName: companyName,
                isOnline: isOnline,
                statusBusy: statusBusy,
                isPortal: user?.isPortal ?? false,
                hasAttendance: user?.hasAttendance ?? true,
                onStatusTap: () => _toggleAttendance(isOnline),
                onOpenCskhChat: _openCskhChat,
                todayMinutes: todayMinutes,
                checkinTime: openSession?.checkinTime,
                notificationCount: notificationCount,
                notificationsLoading: notificationState.isLoading,
                onNotificationsTap: () => _openNotifications(context),
                onOpenAttendance: () => context.push('/attendance'),
              ),
              const SizedBox(height: 18),
              _QuickNavGrid(
                ticketCount: openTickets,
                chatCount: fallbackChatCount,
                unreadCount: ref.watch(chatV2TotalUnreadProvider),
                taskCount: totalOpenTasksCount,
                isPortal: user?.isPortal ?? false,
                hasHelpdesk: user?.hasHelpdesk ?? true,
                onOpenCskhChat: _openCskhChat,
              ),
              const SizedBox(height: 20),
              if (user?.isPortal == true) ...[
                if (user?.hasHelpdesk ?? true)
                  const _PortalRecentTicketsSection()
                else
                  const _PortalLivechatServicesSection(),
              ] else ...[
                _TodayWork(tasks: todayTasks),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _openNotifications(BuildContext context) {
    context.push(
      Uri(
        path: '/webview',
        queryParameters: {
          'url': '/home/action-2186',
          'title': 'Thông báo',
        },
      ).toString(),
    );
  }
}

class _GreetingHeader extends ConsumerWidget {
  const _GreetingHeader({
    required this.userId,
    required this.displayName,
    required this.email,
    required this.avatarUrl,
    this.jobTitle,
    this.companyName,
    required this.isOnline,
    required this.statusBusy,
    this.isPortal = false,
    this.hasAttendance = true,
    required this.onStatusTap,
    this.onOpenCskhChat,
    required this.todayMinutes,
    required this.checkinTime,
    required this.notificationCount,
    required this.notificationsLoading,
    required this.onNotificationsTap,
    required this.onOpenAttendance,
  });

  final String userId;
  final String displayName;
  final String? email;
  final String? avatarUrl;
  final String? jobTitle;
  final String? companyName;
  final bool isOnline;
  final bool statusBusy;
  final bool isPortal;
  final bool hasAttendance;
  final VoidCallback onStatusTap;
  final VoidCallback? onOpenCskhChat;
  final int todayMinutes;
  final DateTime? checkinTime;
  final int notificationCount;
  final bool notificationsLoading;
  final VoidCallback onNotificationsTap;
  final VoidCallback onOpenAttendance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final today = _vietnameseDateTime(DateTime.now());
    final subtitleParts = [
      if (jobTitle != null && jobTitle!.isNotEmpty) jobTitle!,
      if (companyName != null && companyName!.isNotEmpty) companyName!,
    ];
    final jobAndCompany = subtitleParts.isNotEmpty ? subtitleParts.join(' · ') : null;
    final shiftConfig = ref.watch(currentShiftConfigProvider);
    final targetMinutes = shiftConfig.targetWorkMinutes;
    final shiftProgress = (isOnline && checkinTime != null)
        ? ShiftCalculator.calculate(
            checkinTime: checkinTime!,
            config: shiftConfig,
          )
        : null;
    final displayMinutes = shiftProgress != null ? shiftProgress.workedMinutes : todayMinutes;
    final isCompleted = displayMinutes >= targetMinutes;
    final rawProgress = targetMinutes > 0 ? (displayMinutes / targetMinutes) : 0.0;
    final progress = isCompleted ? 1.0 : rawProgress.clamp(0.0, 0.985);
    final percent = isCompleted ? 100 : (rawProgress * 100).floor().clamp(0, 99);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.12)
              : AppColors.border,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PressableScale(
                onTap: () => context.push('/profile'),
                child: UserAvatar(
                  userId: userId,
                  displayName: displayName,
                  email: email,
                  avatarUrl: avatarUrl,
                  size: 48,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${greetingForHour()}, $displayName',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        height: 1.12,
                      ),
                    ),
                    if (jobAndCompany != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        jobAndCompany,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.darkTextMuted : AppColors.primary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      today,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.caption.copyWith(
                        color: isDark ? AppColors.darkTextMuted : AppColors.textSecondary,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (!isPortal) ...[
                PressableScale(
                  onTap: () {
                    if (!hasAttendance) {
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Tính năng yêu cầu cài đặt Module Chấm công'),
                          behavior: SnackBarBehavior.floating,
                          duration: Duration(seconds: 2),
                        ),
                      );
                      return;
                    }
                    onOpenAttendance();
                  },
                  child: _PresenceIndicator(
                    isOnline: isOnline,
                    hasAttendance: hasAttendance,
                  ),
                ),
                const SizedBox(width: 10),
              ],
              PressableScale(
                onTap: onNotificationsTap,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.soft(AppColors.primary),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: notificationsLoading
                          ? const Center(
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.primary,
                                ),
                              ),
                            )
                          : const Icon(
                              LucideIcons.bell,
                              color: AppColors.primary,
                              size: 20,
                            ),
                    ),
                    if (notificationCount > 0)
                      Positioned(
                        top: -5,
                        right: -6,
                        child: UnreadBadge(
                          count: notificationCount,
                          compact: true,
                          gradient: AppColors.featureGrad(
                            AppColors.danger,
                            AppColors.dangerDeep,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (isPortal)
            _PortalSupportActionCard(onTap: onOpenCskhChat)
          else
            // Work Shift Info Card - Ultra Clean & Spacious Apple HIG Design
            InkWell(
            onTap: () {
              if (!hasAttendance) {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Tính năng yêu cầu cài đặt Module Chấm công'),
                    behavior: SnackBarBehavior.floating,
                    duration: Duration(seconds: 2),
                  ),
                );
                return;
              }
              onOpenAttendance();
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: !hasAttendance
                    ? (isDark
                        ? const Color(0xFF0F172A).withValues(alpha: 0.6)
                        : const Color(0xFFF1F5F9))
                    : isDark
                        ? const Color(0xFF0F172A).withValues(alpha: 0.6)
                        : (isOnline ? AppColors.soft(AppColors.success) : AppColors.soft(AppColors.primary)).withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: !hasAttendance
                      ? (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))
                      : (isOnline ? AppColors.success : AppColors.primary).withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Status badge on left, Check in/out button on right
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: !hasAttendance
                                    ? AppColors.textMuted
                                    : (isOnline || displayMinutes >= targetMinutes)
                                        ? AppColors.success
                                        : AppColors.primary,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: (!hasAttendance
                                            ? AppColors.textMuted
                                            : (isOnline || displayMinutes >= targetMinutes)
                                                ? AppColors.success
                                                : AppColors.primary)
                                        .withValues(alpha: 0.5),
                                    blurRadius: 6,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                !hasAttendance
                                    ? 'Chấm công (Đã khóa 🔒)'
                                    : (shiftProgress != null
                                        ? shiftProgress.badgeLabel
                                        : (displayMinutes >= targetMinutes
                                            ? 'Đã hoàn thành ca 🎉'
                                            : (isOnline ? 'Đã vào ca' : 'Chưa vào ca làm'))),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: !hasAttendance
                                      ? AppColors.textMuted
                                      : (isOnline || displayMinutes >= targetMinutes)
                                          ? AppColors.success
                                          : AppColors.primary,
                                ),
                              ),
                            ),
                            if (checkinTime != null && hasAttendance) ...[
                              const SizedBox(width: 6),
                              Text(
                                '• ${Dates.hm(checkinTime!)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _CheckInStatusButton(
                        isOnline: isOnline,
                        busy: statusBusy,
                        hasAttendance: hasAttendance,
                        onTap: () {
                          if (!hasAttendance) {
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Tính năng yêu cầu cài đặt Module Chấm công'),
                                behavior: SnackBarBehavior.floating,
                                duration: Duration(seconds: 2),
                              ),
                            );
                            return;
                          }
                          onStatusTap();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Main Metric Headline Row: 7h 23m / 8h  |  92%
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            _durationVi(Duration(minutes: displayMinutes)),
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: Theme.of(context).colorScheme.onSurface,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '/ ${shiftConfig.targetHoursFormatted} ca làm',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        '$percent%',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: (isOnline || isCompleted) ? AppColors.success : AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Sleek Progress Bar with 50% Lunch Break Divider
                  Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      Container(
                        height: 7,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppColors.border.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: progress,
                        child: Container(
                          height: 7,
                          decoration: BoxDecoration(
                            gradient: AppColors.featureGrad(
                              (isOnline || isCompleted) ? AppColors.success : AppColors.primary,
                              (isOnline || isCompleted) ? const Color(0xFF10B981) : AppColors.success,
                            ),
                            borderRadius: BorderRadius.circular(99),
                            boxShadow: [
                              BoxShadow(
                                color: ((isOnline || isCompleted) ? AppColors.success : AppColors.primary).withValues(alpha: 0.35),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // 50% Lunch Break Divider Tick Mark
                      Positioned(
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            width: 2,
                            height: 9,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : Colors.white,
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Single Clear Footer Line (Zero text redundancy!)
                  Row(
                    children: [
                      Icon(
                        !hasAttendance ? LucideIcons.lock : LucideIcons.mapPin,
                        size: 12,
                        color: !hasAttendance ? AppColors.textMuted : AppColors.success,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        !hasAttendance ? 'Chưa kích hoạt' : 'GPS hợp lệ',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: !hasAttendance ? AppColors.textMuted : AppColors.success,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        '•',
                        style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          !hasAttendance
                              ? 'Chức năng chấm công tạm khóa (cần cài đặt Module hr_attendance)'
                              : (shiftProgress != null
                                  ? (shiftProgress.remainingMinutes > 0
                                      ? 'Còn ${_durationVi(Duration(minutes: shiftProgress.remainingMinutes))} đến mốc ${shiftConfig.shiftEndHour.toString().padLeft(2, '0')}:${shiftConfig.shiftEndMinute.toString().padLeft(2, '0')}'
                                      : '🎉 Đã hoàn thành xuất sắc ${shiftConfig.targetHoursFormatted} làm việc!')
                                  : (displayMinutes >= targetMinutes
                                      ? '🎉 Đã hoàn thành xuất sắc ca làm việc hôm nay (${_durationVi(Duration(minutes: displayMinutes))})'
                                      : (displayMinutes > 0
                                          ? 'Đã tích lũy ${_durationVi(Duration(minutes: displayMinutes))} • Chưa vào ca mới'
                                          : 'Chưa bắt đầu ca làm việc'))),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: !hasAttendance
                                ? AppColors.textMuted
                                : (displayMinutes >= targetMinutes)
                                    ? AppColors.success
                                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.65),
                          ),
                        ),
                      ),
                      const Icon(LucideIcons.chevronRight, size: 14, color: AppColors.textMuted),
                    ],
                  ),
                  if (hasAttendance && (shiftProgress?.isCompleted ?? (displayMinutes >= 480))) ...[
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: () {
                        HapticFeedback.heavyImpact();
                        CelebrationFireworksOverlay.trigger(context);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: AppColors.featureGrad(
                            const Color(0xFFFFD700),
                            AppColors.success,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x33FFD700),
                              blurRadius: 8,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Text('🎉', style: TextStyle(fontSize: 14)),
                            const SizedBox(width: 6),
                            const Expanded(
                              child: Text(
                                'CHÚC MỪNG! ĐÃ HOÀN THÀNH 8H LÀM VIỆC XUẤT SẮC!',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 10,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(LucideIcons.sparkles, color: Colors.white, size: 11),
                                  SizedBox(width: 3),
                                  Text(
                                    'Bắn pháo',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PortalSupportActionCard extends StatelessWidget {
  const _PortalSupportActionCard({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? const [Color(0xFF1E3A8A), Color(0xFF1E293B)]
                  : const [Color(0xFFEFF6FF), Color(0xFFDBEAFE)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFF0077CD).withValues(alpha: isDark ? 0.45 : 0.25),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0077CD).withValues(alpha: isDark ? 0.25 : 0.08),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0077CD), Color(0xFF00A3FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0077CD).withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  LucideIcons.headphones,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Hỗ Trợ Trực Tuyến',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00CE2C).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFF00CE2C).withValues(alpha: 0.4),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF00CE2C),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                'Trực ca',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF059669),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Chạm để kết nối chuyên viên CSKH hoặc Kỹ thuật',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? const Color(0xFF94A3B8)
                            : const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFF0077CD).withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  LucideIcons.arrowRight,
                  color: Color(0xFF0077CD),
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickNavGrid extends ConsumerWidget {
  const _QuickNavGrid({
    required this.ticketCount,
    required this.chatCount,
    required this.unreadCount,
    required this.taskCount,
    this.isPortal = false,
    this.hasHelpdesk = true,
    this.onOpenCskhChat,
  });

  final int ticketCount;
  final int chatCount;
  final int unreadCount;
  final int taskCount;
  final bool isPortal;
  final bool hasHelpdesk;
  final VoidCallback? onOpenCskhChat;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboard = ref.watch(mobileDashboardSummaryProvider).valueOrNull;
    final serverUnread = dashboard?.unreadMessageCount;
    final localUnreadCount = ref.watch(chatV2TotalUnreadProvider);
    final channelCount = ref.watch(chatV2ChannelsProvider.select((c) => c.valueOrNull?.length ?? 0));
    final effectiveTickets = ref.watch(effectiveTicketsProvider);
    final localDoingTicketsCount = effectiveTickets.where((t) => t.status != TicketStatus.done).length;
    final liveTicketCount = localDoingTicketsCount > 0
        ? localDoingTicketsCount
        : (ticketCount > 0 ? ticketCount : 0);

    // Nguồn chân lý đếm tổng: Ưu tiên local unread, nếu 0 thì đọc trực tiếp từ Server Dashboard Summary
    final liveChatCount = chatCount > 0 ? chatCount : (channelCount > 0 ? channelCount : 0);
    final liveUnreadCount = localUnreadCount > 0 ? localUnreadCount : (serverUnread ?? localUnreadCount);

    final livechatChannels = ref.watch(livechatChannelsProvider).valueOrNull ?? const <LivechatChannelModel>[];
    final availableLivechatCount = livechatChannels.where((c) => c.isAvailable).length;

    // --- CASE 2: Portal KHÔNG có module Helpdesk (isPortal && !hasHelpdesk) ---
    // Hiển thị 3 thẻ: 1 thẻ ngang nổi bật trên đầu + 2 thẻ 'Chưa đọc' và 'Hội thoại' ở dưới. Ẩn nút Tạo ticket.
    if (isPortal && !hasHelpdesk) {
      return Column(
        children: [
          const SectionHeader(
            title: 'Tổng quan hôm nay',
          ),
          const SizedBox(height: 10),
          _PortalSupportBannerPill(
            onlineCount: availableLivechatCount > 0 ? availableLivechatCount : livechatChannels.length,
            onTap: onOpenCskhChat ?? () => LivechatSelectionBottomSheet.show(context),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 138,
                  child: _MetricPill(
                    icon: LucideIcons.mailOpen,
                    label: 'Chưa đọc',
                    value: liveUnreadCount.toString(),
                    caption: 'Cuộc trò chuyện',
                    gradient: AppColors.chatGrad,
                    onTap: () => context.go('/chat?filter=unread'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 138,
                  child: _MetricPill(
                    icon: LucideIcons.messagesSquare,
                    label: 'Hội thoại',
                    value: liveChatCount.toString(),
                    caption: 'Cuộc trò chuyện',
                    gradient: AppColors.brandWide,
                    onTap: () => context.go('/chat'),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    // --- CASE 1: Portal CÓ module Helpdesk (isPortal && hasHelpdesk) ---
    // Hiển thị Lưới 4 ô (2x2): Ticket, Chưa đọc, Hội thoại, Hỗ trợ (Livechat)
    if (isPortal && hasHelpdesk) {
      return Column(
        children: [
          SectionHeader(
            title: 'Tổng quan hôm nay',
            trailing: 'Tạo ticket',
            onTrailingTap: () => context.push('/tickets/new'),
          ),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.12,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _MetricPill(
                icon: LucideIcons.ticket,
                label: 'Ticket',
                value: liveTicketCount.toString(),
                caption: 'Cần xử lý',
                gradient: AppColors.ticketGrad,
                onTap: () => context.go('/tickets'),
              ),
              _MetricPill(
                icon: LucideIcons.mailOpen,
                label: 'Chưa đọc',
                value: liveUnreadCount.toString(),
                caption: 'Cuộc trò chuyện',
                gradient: AppColors.chatGrad,
                onTap: () => context.go('/chat?filter=unread'),
              ),
              _MetricPill(
                icon: LucideIcons.messagesSquare,
                label: 'Hội thoại',
                value: liveChatCount.toString(),
                caption: 'Cuộc trò chuyện',
                gradient: AppColors.brandWide,
                onTap: () => context.go('/chat'),
              ),
              _MetricPill(
                icon: LucideIcons.headphones,
                label: 'Hỗ trợ',
                value: availableLivechatCount > 0
                    ? availableLivechatCount.toString()
                    : (livechatChannels.isNotEmpty ? livechatChannels.length.toString() : '24/7'),
                caption: 'Trực ca 🟢',
                gradient: const LinearGradient(
                  colors: [Color(0xFF00C83A), Color(0xFF059669)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                onTap: onOpenCskhChat ?? () => LivechatSelectionBottomSheet.show(context),
              ),
            ],
          ),
        ],
      );
    }

    // --- CASE 0: Nhân viên nội bộ (!isPortal) ---
    return Column(
      children: [
        SectionHeader(
          title: 'Tổng quan hôm nay',
          trailing: 'Tạo ticket',
          onTrailingTap: () => context.push('/tickets/new'),
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.12,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _MetricPill(
              icon: LucideIcons.ticket,
              label: 'Ticket',
              value: liveTicketCount.toString(),
              caption: 'Cần xử lý',
              gradient: AppColors.ticketGrad,
              onTap: () => context.go('/tickets'),
            ),
            _MetricPill(
              icon: LucideIcons.mailOpen,
              label: 'Chưa đọc',
              value: liveUnreadCount.toString(),
              caption: 'Cuộc trò chuyện',
              gradient: AppColors.chatGrad,
              onTap: () => context.go('/chat?filter=unread'),
            ),
            _MetricPill(
              icon: LucideIcons.messagesSquare,
              label: 'Chats',
              value: liveChatCount.toString(),
              caption: 'Cuộc trò chuyện',
              gradient: AppColors.brandWide,
              onTap: () => context.go('/chat'),
            ),
            _MetricPill(
              icon: LucideIcons.listTodo,
              label: 'Công việc hôm nay',
              value: taskCount.toString(),
              caption: 'Đang mở',
              gradient: AppColors.timesheetGrad,
              onTap: () => context.go('/timesheet'),
            ),
          ],
        ),
      ],
    );
  }
}

class _PortalSupportBannerPill extends StatelessWidget {
  const _PortalSupportBannerPill({
    required this.onTap,
    this.onlineCount = 0,
  });

  final VoidCallback onTap;
  final int onlineCount;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0077CD), Color(0xFF00CE2C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x220077CD),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
                child: const Icon(
                  LucideIcons.headphones,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Flexible(
                          child: Text(
                            'Hỗ Trợ Trực Tuyến',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.circle, color: Color(0xFF86EFAC), size: 6),
                              SizedBox(width: 3),
                              Text(
                                'Online',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      onlineCount > 0
                          ? '$onlineCount kênh trực tuyến · CSKH & Kỹ thuật'
                          : 'Sẵn sàng hỗ trợ trực tuyến 24/7',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.92),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                LucideIcons.chevronRight,
                color: Colors.white70,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PortalRecentTicketsSection extends ConsumerWidget {
  const _PortalRecentTicketsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tickets = ref.watch(effectiveTicketsProvider);
    final recentTickets = tickets.take(2).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Phiếu hỗ trợ của bạn',
          trailing: 'Xem tất cả',
          onTrailingTap: () => context.go('/tickets'),
        ),
        const SizedBox(height: 10),
        if (recentTickets.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Column(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.soft(AppColors.primary),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    LucideIcons.ticket,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Bạn chưa có phiếu hỗ trợ nào',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Cần hỗ trợ về sản phẩm hoặc sự cố phần mềm?',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  onPressed: () => context.push('/tickets/new'),
                  icon: const Icon(LucideIcons.plus, size: 16),
                  label: const Text('Gửi yêu cầu hỗ trợ'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  ),
                ),
              ],
            ),
          )
        else
          GlassCard(
            padding: EdgeInsets.zero,
            radius: 18,
            child: Column(
              children: [
                for (var i = 0; i < recentTickets.length; i++) ...[
                  _PortalTicketRow(ticket: recentTickets[i]),
                  if (i != recentTickets.length - 1)
                    const Divider(height: 1, indent: 54),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _PortalTicketRow extends StatelessWidget {
  const _PortalTicketRow({required this.ticket});

  final Ticket ticket;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (ticket.status) {
      TicketStatus.todo => const Color(0xFF3B82F6),
      TicketStatus.doing => const Color(0xFFF59E0B),
      TicketStatus.done => AppColors.success,
    };
    final statusLabel = switch (ticket.status) {
      TicketStatus.todo => 'Mới',
      TicketStatus.doing => 'Đang xử lý',
      TicketStatus.done => 'Đã đóng',
    };

    return PressableScale(
      onTap: () => context.push('/tickets/${ticket.id}'),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.soft(statusColor),
                shape: BoxShape.circle,
              ),
              child: Icon(LucideIcons.ticket, color: statusColor, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ticket.title.isNotEmpty ? ticket.title : 'Ticket #${ticket.id}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '#${ticket.id} · ${_formatTicketDate(ticket.createdAt)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            StatusPill(label: statusLabel, color: statusColor),
          ],
        ),
      ),
    );
  }
}

String _formatTicketDate(DateTime dt) {
  return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
}

class _PortalLivechatServicesSection extends ConsumerWidget {
  const _PortalLivechatServicesSection();

  Future<void> _connectChannel(BuildContext context, WidgetRef ref, String keyword) async {
    try {
      final channels = await ref.read(livechatChannelsProvider.future);
      final match = channels.firstWhere(
        (c) => c.name.toLowerCase().contains(keyword.toLowerCase()),
        orElse: () => channels.isNotEmpty ? channels.first : throw Exception('Không tìm thấy kênh hỗ trợ'),
      );
      final session = await ref.read(livechatControllerProvider).openSession(channelId: match.id);
      ref.invalidate(chatV2ChannelsProvider);
      final encodedName = Uri.encodeComponent(session.channelName);
      final encodedAvatar = Uri.encodeComponent(session.avatarUrl ?? '');
      if (context.mounted) {
        context.push('/chat/${session.channelId}?name=$encodedName&avatar=$encodedAvatar');
      }
    } catch (_) {
      if (context.mounted) {
        await LivechatSelectionBottomSheet.show(context);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(
          title: 'Dịch vụ hỗ trợ trực tuyến',
        ),
        const SizedBox(height: 10),
        _LivechatServiceCard(
          icon: LucideIcons.headphones,
          accentColor: const Color(0xFF0077CD),
          title: 'Chăm Sóc Khách Hàng (Customer Care)',
          description: 'Tư vấn sản phẩm, báo giá, chính sách hợp đồng',
          onTap: () => _connectChannel(context, ref, 'Customer Care'),
        ),
        const SizedBox(height: 10),
        _LivechatServiceCard(
          icon: LucideIcons.wrench,
          accentColor: const Color(0xFF00CE2C),
          title: 'Hỗ Trợ Kỹ Thuật (Technical Support)',
          description: 'Xử lý sự cố, hướng dẫn sử dụng phần mềm',
          onTap: () => _connectChannel(context, ref, 'Technical Support'),
        ),
      ],
    );
  }
}

class _LivechatServiceCard extends StatelessWidget {
  const _LivechatServiceCard({
    required this.icon,
    required this.accentColor,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final Color accentColor;
  final String title;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A0F172A),
                blurRadius: 16,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.soft(accentColor),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: accentColor.withValues(alpha: 0.25),
                  ),
                ),
                child: Icon(icon, color: accentColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF00CE2C).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.circle, color: Color(0xFF00CE2C), size: 6),
                              SizedBox(width: 3),
                              Text(
                                'Trực ca',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF059669),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.soft(accentColor),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Nhắn tin',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: accentColor,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(LucideIcons.arrowRight, size: 12, color: accentColor),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricPill extends StatelessWidget {
  const _MetricPill({
    required this.icon,
    required this.label,
    required this.value,
    required this.caption,
    required this.gradient,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final String caption;
  final Gradient gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A0F172A),
                blurRadius: 22,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Stack(
          children: [
            Positioned(
              right: -18,
              bottom: -22,
              child: Icon(
                icon,
                color: Colors.white.withValues(alpha: 0.12),
                size: 92,
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Icon(icon, color: Colors.white, size: 20),
                    ),
                    const Spacer(),
                    const Icon(
                      LucideIcons.chevronRight,
                      color: Colors.white70,
                      size: 18,
                    ),
                  ],
                ),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        value,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
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

class _CheckInStatusButton extends StatelessWidget {
  const _CheckInStatusButton({
    required this.isOnline,
    required this.busy,
    required this.onTap,
    this.hasAttendance = true,
  });

  final bool isOnline;
  final bool busy;
  final VoidCallback onTap;
  final bool hasAttendance;

  @override
  Widget build(BuildContext context) {
    if (!hasAttendance) {
      return PressableScale(
        onTap: onTap,
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF334155).withValues(alpha: 0.5)
                : const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF475569)
                  : const Color(0xFFCBD5E1),
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.lock,
                color: AppColors.textMuted,
                size: 15,
              ),
              SizedBox(width: 7),
              Text(
                'Khóa 🔒',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      );
    }
    final color = busy
        ? AppColors.warning
        : isOnline
        ? AppColors.danger
        : AppColors.success;
    return PressableScale(
      onTap: busy ? null : onTap,
      child: Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: AppColors.soft(color),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isOnline ? LucideIcons.logOut : LucideIcons.logIn,
              color: color,
              size: 16,
            ),
            const SizedBox(width: 7),
            Text(
              busy
                  ? '...'
                  : isOnline
                  ? 'Check out'
                  : 'Check in',
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PresenceIndicator extends StatelessWidget {
  const _PresenceIndicator({
    required this.isOnline,
    this.hasAttendance = true,
  });

  final bool isOnline;
  final bool hasAttendance;

  @override
  Widget build(BuildContext context) {
    if (!hasAttendance) {
      return Container(
        width: 42,
        height: 42,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.soft(AppColors.textMuted),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.textMuted.withValues(alpha: 0.2)),
        ),
        child: const Center(
          child: Icon(
            LucideIcons.lock,
            color: AppColors.textMuted,
            size: 16,
          ),
        ),
      );
    }
    final color = isOnline ? AppColors.success : AppColors.danger;
    return Container(
      width: 42,
      height: 42,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.soft(color),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Center(
        child: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

_TodayTaskPreview _todayTaskPreviewFromTask(Task task) {
  final statusInfo = _taskStatusInfo(task);
  return _TodayTaskPreview(
    id: task.id,
    title: task.title,
    tag: statusInfo.label,
    accent: statusInfo.color,
    icon: _taskCategoryIcon(task.category),
    note: null,
    logged: null,
    subtasks: task.subtasks,
  );
}

({String label, Color color}) _taskStatusInfo(Task task) {
  if (task.isCompleted) {
    return (label: 'Hoàn thành', color: AppColors.success);
  }
  final raw = '${task.state ?? ''} ${task.stageName ?? ''}'.toLowerCase();
  if (raw.contains('change') || raw.contains('thay đổi')) {
    return (label: task.stageName ?? 'Thay đổi yêu cầu', color: const Color(0xFFF59E0B));
  }
  if (raw.contains('cancel') || raw.contains('hủy') || raw.contains('huỷ')) {
    return (label: task.stageName ?? 'Hủy', color: AppColors.danger);
  }
  if (raw.contains('approved') || raw.contains('chấp thuận') || raw.contains('duyệt')) {
    return (label: task.stageName ?? 'Được chấp thuận', color: AppColors.primary);
  }
  if (task.stageName != null && task.stageName!.trim().isNotEmpty) {
    return (label: task.stageName!, color: const Color(0xFF8B5CF6));
  }
  return (label: 'Đang làm', color: const Color(0xFF8B5CF6));
}

IconData _taskCategoryIcon(TimesheetCategory category) {
  return switch (category) {
    TimesheetCategory.erp => LucideIcons.database,
    TimesheetCategory.crm => LucideIcons.users,
    TimesheetCategory.meeting => LucideIcons.calendarClock,
    TimesheetCategory.support => LucideIcons.headphones,
    TimesheetCategory.other => LucideIcons.circleDot,
  };
}



class _TodayTaskPreview {
  const _TodayTaskPreview({
    required this.id,
    required this.title,
    required this.tag,
    required this.accent,
    required this.icon,
    this.note,
    this.logged,
    this.subtasks = const <TaskChecklistItem>[],
  });

  /// Odoo task id — needed so the quick-edit popup can route saves
  /// back to [TaskActions.log] without round-tripping the full sheet.
  final String id;
  final String title;
  final String tag;
  final Color accent;
  final IconData icon;

  /// Last logged "what I did" summary, if any. Used to pre-fill the
  /// editor when re-opening a task that already has a log entry.
  final String? note;

  /// Last logged duration, if any. Same purpose — defaults the
  /// duration picker to a sensible bucket when re-opening.
  final Duration? logged;

  final List<TaskChecklistItem> subtasks;
}

class _TodayWork extends StatelessWidget {
  const _TodayWork({required this.tasks});

  final List<_TodayTaskPreview> tasks;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SectionHeader(
          title: "Công việc hôm nay",
          trailing: 'Mở Timesheet',
          onTrailingTap: () => context.go('/timesheet'),
        ),
        const SizedBox(height: 10),
        GlassCard(
          padding: EdgeInsets.zero,
          radius: 18,
          child: tasks.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(18),
                  child: Text(
                    'Chưa có công việc hôm nay.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                )
              : Column(
                  children: [
                    for (var i = 0; i < tasks.length; i++) ...[
                      _TimesheetRow(task: tasks[i]),
                      if (i != tasks.length - 1)
                        const Divider(height: 1, indent: 54),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _TimesheetRow extends ConsumerWidget {
  const _TimesheetRow({required this.task});

  final _TodayTaskPreview task;

  Future<void> _openQuickEdit(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TaskQuickEditSheet(task: task),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PressableScale(
      onTap: () {
        // Tap a task → popup that lets the user record work-time / note
        // without bouncing them over to the full timesheet screen.
        // They can still get there via the "Mở Timesheet" trailing link.
        _openQuickEdit(context, ref);
      },
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: AppColors.soft(task.accent),
                shape: BoxShape.circle,
              ),
              child: Icon(task.icon, color: task.accent, size: 15),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                task.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),

            StatusPill(label: task.tag, color: task.accent),
          ],
        ),
      ),
    );
  }
}

/// Bottom-sheet that lets the user edit a task's `note` (nội dung công
/// việc đã làm) and re-log `duration` (thời gian làm việc) inline
/// from the home dashboard. Save always routes through
/// [TaskActions.log] — these cards only show open tasks, so we never
/// flip workflow status.
///
/// The widget is `ConsumerStatefulWidget` so its actions run on its
/// own `ref` (the parent's `WidgetRef` is short-lived and must not be
/// captured into the sheet's lifetime).
class _TaskQuickEditSheet extends ConsumerStatefulWidget {
  const _TaskQuickEditSheet({required this.task});

  final _TodayTaskPreview task;

  @override
  ConsumerState<_TaskQuickEditSheet> createState() =>
      _TaskQuickEditSheetState();
}

class _TaskQuickEditSheetState extends ConsumerState<_TaskQuickEditSheet> {
  late final TextEditingController _noteController;
  late TimesheetDuration _duration;
  bool _saving = false;
  bool _hasError = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(text: widget.task.note ?? '');
    _noteController.addListener(_onNoteChanged);
    _duration = widget.task.logged == null
        ? TimesheetDuration.thirty
        : durationBucketForElapsed(widget.task.logged!);
  }

  void _onNoteChanged() {
    if (_hasError && _noteController.text.trim().isNotEmpty) {
      setState(() {
        _hasError = false;
        _errorMessage = null;
      });
    }
  }

  @override
  void dispose() {
    _noteController.removeListener(_onNoteChanged);
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final note = _noteController.text.trim();
    if (note.isEmpty) {
      HapticFeedback.mediumImpact();
      setState(() {
        _hasError = true;
        _errorMessage = 'Vui lòng nhập nội dung công việc đã làm trước khi lưu.';
      });
      showTopNotification(
        context,
        message: 'Vui lòng nhập nội dung công việc đã làm.',
        isError: true,
      );
      return;
    }
    setState(() {
      _hasError = false;
      _errorMessage = null;
      _saving = true;
    });
    try {
      await ref
          .read(taskActionsProvider)
          .log(taskId: widget.task.id, summary: note, duration: _duration);
      ref.invalidate(timesheetStreamProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Lưu log thất bại: ${describeError(e)}';
        });
        showTopNotification(
          context,
          message: 'Lưu log thất bại: ${describeError(e)}',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          left: 12,
          right: 12,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 10,
        ),
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(28),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.soft(widget.task.accent),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        widget.task.icon,
                        color: widget.task.accent,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.task.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),

                    StatusPill(
                      label: widget.task.tag,
                      color: widget.task.accent,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Cập nhật nội dung & thời gian làm việc.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 14),
                TaskChecklistEditor(
                  noteController: _noteController,
                  duration: _duration,
                  saving: _saving,
                  hasError: _hasError,
                  errorMessage: _errorMessage,
                  initialSubtasks: widget.task.subtasks,
                  onDurationChanged: _saving
                      ? null
                      : (dur) => setState(() => _duration = dur),
                  onSave: _saving ? null : _save,
                  saveLabel: 'Lưu cập nhật',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _vietnameseDateTime(DateTime dt) {
  const weekdays = [
    'Thứ hai',
    'Thứ ba',
    'Thứ tư',
    'Thứ năm',
    'Thứ sáu',
    'Thứ bảy',
    'Chủ nhật',
  ];
  final weekday = weekdays[dt.weekday - 1];
  final day = dt.day.toString().padLeft(2, '0');
  final month = dt.month.toString().padLeft(2, '0');
  final hour = dt.hour.toString().padLeft(2, '0');
  final minute = dt.minute.toString().padLeft(2, '0');
  return '$weekday, $day/$month/${dt.year} · $hour:$minute';
}

String _durationVi(Duration duration) {
  final minutes = duration.inMinutes;
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (h == 0) return '$m phút';
  if (m == 0) return '$h giờ';
  return '$h giờ $m phút';
}

@visibleForTesting
String greetingForHour([DateTime? time]) {
  final hour = (time ?? DateTime.now()).hour;
  if (hour >= 5 && hour < 12) {
    return 'Chào buổi sáng';
  } else if (hour >= 12 && hour < 18) {
    return 'Chào buổi chiều';
  } else {
    return 'Chào buổi tối';
  }
}
