import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../../core/error/failure.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/attendance.dart';
import '../../../shared/models/timesheet.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/ui_kit.dart';
import '../../auth/application/auth_controller.dart';
import '../../timesheet/application/task_controller.dart';
import '../../timesheet/application/timesheet_controller.dart';
import '../../../shared/widgets/location_prompt_dialog.dart';
import '../application/attendance_controller.dart';
import '../domain/shift_calculator.dart';
import 'widgets/checkout_dialog.dart';

/// Check-in screen — live clock, big check-in/out circle, location, history.
class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});

  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  Timer? _ticker;
  DateTime _now = DateTime.now();
  bool _busy = false;

  static const _weekdays = [
    'Thứ Hai',
    'Thứ Ba',
    'Thứ Tư',
    'Thứ Năm',
    'Thứ Sáu',
    'Thứ Bảy',
    'Chủ Nhật',
  ];

  Future<void> _showErrorDialog(dynamic error, StackTrace stackTrace) async {
    final errorMessage = error.toString();
    final fullDetails = 'Lỗi: $errorMessage\n\nStackTrace:\n$stackTrace';

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Lỗi Check-in (Chấm công)'),
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

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() => _now = DateTime.now()),
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String get _viDate {
    final wd = _weekdays[_now.weekday - 1];
    final d = _now.day.toString().padLeft(2, '0');
    final m = _now.month.toString().padLeft(2, '0');
    return '$wd, $d/$m/${_now.year}';
  }

  String _formatCheckinTime(DateTime? time) {
    if (time == null) return '';
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    final s = time.second.toString().padLeft(2, '0');
    final d = time.day.toString().padLeft(2, '0');
    final mo = time.month.toString().padLeft(2, '0');
    return '$h:$m:$s · $d/$mo/${time.year}';
  }

  String _formatElapsed(DateTime? checkInAt) {
    if (checkInAt == null) return '00:00:00';
    final result = ShiftCalculator.calculate(checkinTime: checkInAt);
    final workedMins = result.workedMinutes;
    final hours = workedMins ~/ 60;
    final minutes = workedMins % 60;
    final seconds = DateTime.now().second;
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _handle(bool checkIn) async {
    CheckoutData? checkoutData;
    if (!checkIn) {
      // Show checkout dialog
      checkoutData = await showDialog<CheckoutData>(
        context: context,
        builder: (_) => const CheckoutDialog(),
      );
      if (checkoutData == null) return; // User cancelled
    }

    setState(() => _busy = true);
    try {
      final a = ref.read(attendanceActionsProvider);
      if (checkIn) {
        await a.checkIn();
      } else {
        await a.checkOut();
        if (checkoutData != null && checkoutData.workDescription.isNotEmpty) {
          try {
            await ref.read(taskActionsProvider).log(
              taskId: checkoutData.selectedTaskId ?? '',
              summary: checkoutData.workDescription,
              duration: TimesheetDuration.thirty,
            );
            ref.invalidate(timesheetStreamProvider);
          } catch (_) {
            // Best effort timesheet log on checkout
          }
        }
      }
    } catch (e, stackTrace) {
      if (mounted) {
        if (isLocationError(e)) {
          await showLocationPromptDialog(context, message: e is Failure ? e.message : e.toString());
        } else {
          await _showErrorDialog(e, stackTrace);
        }
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final todayState = ref.watch(attendanceTodayProvider);
    final open = ref.watch(openSessionProvider);
    final statusLoading = todayState.isLoading && open == null;
    final isCheckedIn = open != null;
    // DO NOT MODIFY OR REFACTOR THIS AVATAR LOADING LOGIC. IT IS THE SOURCE OF TRUTH FOR USER AVATAR DISPLAY.
    // CẤM SỬA HOẶC XÓA LOGIC TẢI AVATAR NÀY - ĐÂY LÀ NGUỒN SỰ THẬT HIỂN THỊ AVATAR DÙNG CHUNG.
    final user = ref.watch(authControllerProvider).valueOrNull;
    final meta = user?.userMetadata;
    final rawName = meta?['display_name'];
    final name = (rawName is String ? rawName : (rawName != null && rawName != false ? rawName.toString() : null))?.trim();
    final rawAvatar = meta?['avatar_url'] ??
        meta?['avatar_128_url'] ??
        meta?['image_128_url'] ??
        (user != null ? '/web/image/res.users/${user.id}/avatar_128' : null);
    final avatarUrl = rawAvatar is String && rawAvatar.isNotEmpty ? rawAvatar : null;
    final displayName = (name != null && name.isNotEmpty)
        ? name
        : (user?.email?.split('@').first ?? 'Bạn');
    final clock = isCheckedIn
        ? _formatElapsed(open.checkinTime)
        : '${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}';
    final seconds = isCheckedIn
        ? ''
        : ':${_now.second.toString().padLeft(2, '0')}';

    return AppScaffold(
      title: 'Check-in',
      actions: [
        IconButton(
          onPressed: () => context.push('/attendance/history'),
          icon: const Icon(LucideIcons.history, size: 20),
          tooltip: 'Lịch sử chấm công',
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // Avatar with gradient ring
          Center(
            child: UserAvatar(
              userId: user?.id ?? '',
              displayName: displayName,
              email: user?.email,
              avatarUrl: avatarUrl,
              size: 84,
            ),
          ).animate().fadeIn(duration: 400.ms),
          const SizedBox(height: 24),

          // Live clock with gradient text
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  clock,
                  style: const TextStyle(
                    fontSize: 52,
                    fontWeight: FontWeight.w800,
                    height: 1,
                    letterSpacing: 1,
                  ),
                ),
                Text(
                  seconds,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              _viDate,
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Check-in status: show time if checked in, circle if not
          if (isCheckedIn)
            Center(
              child: GlassCard(
                child: Column(
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      color: AppColors.success,
                      size: 40,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'ĐÃ CHECK-IN',
                      style: TextStyle(
                        color: AppColors.success,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatCheckinTime(open.checkinTime),
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms),
            )
          else
            Center(
              child: _BigCircleButton(
                enabled: !statusLoading && !isCheckedIn && !_busy,
                busy: _busy || statusLoading,
                onTap: () => _handle(true),
              ),
            ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Center(
              child: Text('Hoặc', style: TextStyle(color: AppColors.textMuted)),
            ),
          ),

          // Check-out button
          GlassCard(
            padding: EdgeInsets.zero,
            child: SizedBox(
              height: 54,
              child: OutlinedButton.icon(
                onPressed: isCheckedIn && !_busy ? () => _handle(false) : null,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: const BorderSide(color: AppColors.danger, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                icon: const Icon(Icons.cancel_outlined, size: 20),
                label: const Text(
                  'CHECK-OUT',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ).animate().fadeIn(duration: 380.ms, delay: 120.ms),
          const SizedBox(height: 16),

          // 3-Segment Shift Progress & Time Breakdown Card
          _DetailedShiftBreakdownCard(open: open)
              .animate().fadeIn(duration: 380.ms, delay: 150.ms),
          const SizedBox(height: 16),

          // Location card
          _LocationRow(
            open: open,
          ).animate().fadeIn(duration: 380.ms, delay: 180.ms),
          const SizedBox(height: 16),

          // Weekly summary
          _WeeklySummary().animate().fadeIn(duration: 380.ms, delay: 240.ms),
          const SizedBox(height: 16),

          // Company Shift Policy (Quy định khung giờ làm việc công ty)
          const _CompanyShiftPolicyCard()
              .animate().fadeIn(duration: 380.ms, delay: 280.ms),
        ],
      ),
    );
  }
}

class _BigCircleButton extends StatelessWidget {
  const _BigCircleButton({
    required this.enabled,
    required this.busy,
    required this.onTap,
  });
  final bool enabled;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final gradient = enabled
        ? AppColors.featureGrad(AppColors.attendance, AppColors.attendanceDeep)
        : const LinearGradient(
            colors: [AppColors.textMuted, AppColors.textMuted],
          );
    final glow = enabled ? AppColors.attendance : AppColors.textMuted;
    final circle = GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 160,
        height: 160,
        decoration: BoxDecoration(
          gradient: gradient,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: glow.withValues(alpha: enabled ? 0.4 : 0.15),
              blurRadius: 32,
              offset: const Offset(0, 12),
            ),
            BoxShadow(
              color: glow.withValues(alpha: enabled ? 0.2 : 0.05),
              blurRadius: 64,
              offset: const Offset(0, 24),
            ),
          ],
        ),
        child: busy
            ? const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    LucideIcons.mapPin,
                    color: Colors.white,
                    size: enabled ? 34 : 28,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'CHECK-IN',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: enabled ? 16 : 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
      ),
    );
    if (!enabled) return circle;
    return circle
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scaleXY(
          begin: 1.0,
          end: 1.05,
          duration: 1200.ms,
          curve: Curves.easeInOut,
        );
  }
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({required this.open});
  final Attendance? open;

  @override
  Widget build(BuildContext context) {
    final hasCoords = open?.checkinLat != null && open?.checkinLng != null;
    final sub = hasCoords
        ? '${open!.checkinLat!.toStringAsFixed(5)}, ${open!.checkinLng!.toStringAsFixed(5)}'
        : '155 Nguyễn Thái Học, P. Tam Thắng, TP. HCM';
    return GlassCard(
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: AppColors.featureGrad(
                AppColors.primary,
                AppColors.primaryDeep,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.location_on_outlined,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'VCCI Building HCM',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  sub,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
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

/// Weekly attendance summary card.
class _WeeklySummary extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(attendanceStreamProvider);

    return historyAsync.when(
      data: (list) {
        final now = DateTime.now();
        final weekStart = now.subtract(Duration(days: now.weekday - 1));
        final weekDays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

        // Count check-ins per day this week
        final checkinsPerDay = List.filled(7, 0);
        for (final a in list) {
          if (a.checkinTime == null) continue;
          final d = DateTime(
            a.checkinTime!.year,
            a.checkinTime!.month,
            a.checkinTime!.day,
          );
          final diff = d
              .difference(
                DateTime(weekStart.year, weekStart.month, weekStart.day),
              )
              .inDays;
          if (diff >= 0 && diff < 7) {
            checkinsPerDay[diff]++;
          }
        }

        // Standard working days: 6 days (Monday to Saturday, T2 - T7). Sunday (CN) is a rest day.
        final workDaysCheckins = checkinsPerDay.sublist(0, 6).where((c) => c > 0).length;
        final hasSundayCheckin = checkinsPerDay[6] > 0;

        return GlassCard(
          glowColor: AppColors.attendance,
          radius: 20,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: AppColors.featureGrad(
                        AppColors.attendance,
                        AppColors.attendanceDeep,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      LucideIcons.calendarCheck,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Tuần này',
                    style: AppTextStyles.title.copyWith(
                      color: context.textColor,
                    ),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: () => context.push('/attendance/history'),
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      child: Row(
                        children: [
                          Text(
                            'Lịch sử',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                          SizedBox(width: 3),
                          Icon(LucideIcons.chevronRight, size: 14, color: AppColors.primary),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(7, (i) {
                  final isToday = i == now.weekday - 1;
                  final hasCheckin = checkinsPerDay[i] > 0;
                  final isSunday = i == 6;

                  return Column(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          gradient: hasCheckin
                              ? AppColors.featureGrad(
                                  AppColors.attendance,
                                  AppColors.attendanceDeep,
                                )
                              : null,
                          color: hasCheckin
                              ? null
                              : (isSunday
                                  ? (Theme.of(context).brightness == Brightness.dark
                                      ? const Color(0xFF334155).withValues(alpha: 0.4)
                                      : const Color(0xFFF1F5F9))
                                  : AppColors.bg),
                          shape: BoxShape.circle,
                          border: isToday
                              ? Border.all(
                                  color: AppColors.attendance,
                                  width: 2,
                                )
                              : null,
                        ),
                        child: hasCheckin
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 16,
                              )
                            : Center(
                                child: Text(
                                  isSunday ? 'Nghỉ' : weekDays[i],
                                  style: TextStyle(
                                    fontSize: isSunday ? 9 : 10,
                                    fontWeight: isToday
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isToday
                                        ? AppColors.attendance
                                        : (isSunday ? AppColors.textMuted : AppColors.textMuted),
                                  ),
                                ),
                              ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        weekDays[i],
                        style: TextStyle(
                          fontSize: 10,
                          color: isToday
                              ? AppColors.attendance
                              : (isSunday ? AppColors.textMuted : AppColors.textMuted),
                          fontWeight: isToday
                              ? FontWeight.w700
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  );
                }),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    hasSundayCheckin
                        ? '$workDaysCheckins/6 ngày (+1 CN)'
                        : '$workDaysCheckins/6 ngày đã check-in',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: context.textColor,
                    ),
                  ),
                  GradientBadge(
                    label: workDaysCheckins >= 5 ? 'Đạt' : 'Cần cố gắng',
                    gradient: workDaysCheckins >= 5
                        ? AppColors.successGrad
                        : AppColors.featureGrad(
                            AppColors.warning,
                            AppColors.warning,
                          ),
                    fontSize: 11,
                  ),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

class _DetailedShiftBreakdownCard extends StatelessWidget {
  const _DetailedShiftBreakdownCard({required this.open});
  final Attendance? open;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final checkin = open?.checkinTime;
    final shiftProgress = ShiftCalculator.calculate(checkinTime: checkin);
    final config = shiftProgress.config;

    final now = DateTime.now();
    final date = (checkin ?? now).toLocal();
    final lunchStart = DateTime(date.year, date.month, date.day, config.lunchStartHour, config.lunchStartMinute);
    final lunchEnd = DateTime(date.year, date.month, date.day, config.lunchEndHour, config.lunchEndMinute);

    final morningWorked = shiftProgress.morningWorkedMinutes;
    final afternoonWorked = shiftProgress.afternoonWorkedMinutes;
    final morningProgress = shiftProgress.morningProgress;
    final afternoonProgress = shiftProgress.afternoonProgress;

    final dayStr = date.day.toString().padLeft(2, '0');
    final monthStr = date.month.toString().padLeft(2, '0');
    final formattedDateVi = '${config.dayName}, $dayStr/$monthStr/${date.year}';

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
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title & Badge Row (Hiển thị rõ Thứ, Ngày và Mục tiêu giờ làm)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.soft(AppColors.primary),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(LucideIcons.clock, size: 18, color: AppColors.primary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Chi tiết ca ${config.dayName} (${config.targetHoursFormatted})',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$formattedDateVi • Tiêu chuẩn ${config.targetHoursFormatted}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (shiftProgress.stage == ShiftStage.lunchBreak)
                      ? const Color(0xFFF59E0B).withValues(alpha: 0.15)
                      : AppColors.soft(AppColors.success),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  shiftProgress.badgeLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: (shiftProgress.stage == ShiftStage.lunchBreak)
                        ? const Color(0xFFD97706)
                        : AppColors.success,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 3-Segment Shift Progress Bar (Ca sáng - Nghỉ trưa - Ca chiều)
          Row(
            children: [
              // Ca sáng segment
              Expanded(
                flex: config.morningTargetMinutes,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Ca sáng',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          '${morningWorked ~/ 60}h${morningWorked % 60 > 0 ? ' ${morningWorked % 60}m' : ''}/${config.morningHoursFormatted}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Stack(
                      children: [
                        Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: AppColors.border,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: morningProgress,
                          child: Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppColors.success,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),

              // Nghỉ trưa segment (1h = 60m)
              Expanded(
                flex: 60,
                child: Column(
                  children: [
                    const Text(
                      '🍱 Nghỉ trưa',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFFD97706)),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.5)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),

              // Ca chiều segment
              Expanded(
                flex: config.afternoonTargetMinutes,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Ca chiều',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                        ),
                        Text(
                          '${afternoonWorked ~/ 60}h${afternoonWorked % 60 > 0 ? ' ${afternoonWorked % 60}m' : ''}/${config.afternoonHoursFormatted}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Stack(
                      children: [
                        Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: AppColors.border,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: afternoonProgress,
                          child: Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(4),
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
          const SizedBox(height: 16),

          // 3 Detailed Stage Rows
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : AppColors.bg,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _ShiftStageRow(
                  icon: LucideIcons.sun,
                  iconColor: const Color(0xFFF59E0B),
                  title: 'Ca sáng (${config.morningTimeRange})',
                  subtitle: morningWorked >= config.morningTargetMinutes
                      ? 'Hoàn thành ${config.morningHoursFormatted} ca sáng 🟢'
                      : (now.isBefore(lunchStart) ? 'Đang thực hiện ($morningWorked / ${config.morningTargetMinutes} phút)' : 'Chưa đủ giờ ca sáng'),
                  isCompleted: morningWorked >= config.morningTargetMinutes,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 1, thickness: 0.5),
                ),
                _ShiftStageRow(
                  icon: LucideIcons.utensils,
                  iconColor: const Color(0xFFD97706),
                  title: 'Giờ nghỉ trưa (${config.lunchTimeRange})',
                  subtitle: '1 tiếng nghỉ ngơi • Tự động đóng băng công',
                  isCompleted: now.isAfter(lunchEnd),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 1, thickness: 0.5),
                ),
                _ShiftStageRow(
                  icon: LucideIcons.sunset,
                  iconColor: AppColors.primary,
                  title: 'Ca chiều (${config.afternoonTimeRange})',
                  subtitle: afternoonWorked >= config.afternoonTargetMinutes
                      ? 'Hoàn thành ${config.afternoonHoursFormatted} ca chiều 🟢'
                      : (now.isAfter(lunchEnd)
                          ? 'Đang thực hiện (${shiftProgress.remainingMinutes}m nữa đến ${config.shiftEndHour.toString().padLeft(2, '0')}:${config.shiftEndMinute.toString().padLeft(2, '0')})'
                          : 'Chờ đến ca chiều (${config.lunchEndHour.toString().padLeft(2, '0')}:${config.lunchEndMinute.toString().padLeft(2, '0')})'),
                  isCompleted: afternoonWorked >= config.afternoonTargetMinutes,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShiftStageRow extends StatelessWidget {
  const _ShiftStageRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.isCompleted,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isCompleted ? AppColors.success : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        if (isCompleted)
          const Icon(LucideIcons.checkCircle2, size: 16, color: AppColors.success),
      ],
    );
  }
}

class _CompanyShiftPolicyCard extends StatelessWidget {
  const _CompanyShiftPolicyCard();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final todayWeekday = now.weekday;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.12) : AppColors.border,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A0F172A),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.soft(AppColors.attendance),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(LucideIcons.calendarClock, size: 18, color: AppColors.attendanceDeep),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Quy định khung giờ làm việc',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Chính sách thời gian chuẩn công ty',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.soft(AppColors.primary),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Quy chuẩn',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 4 Rule Cards
          _PolicyItemRow(
            dayLabel: 'Thứ Hai (T2)',
            timeRange: '07:30 – 17:00',
            lunchBreak: 'Nghỉ trưa 12:00 – 13:00',
            breakdown: 'Ca sáng: 07:30 - 12:00 (4h30) • Ca chiều: 13:00 - 17:00 (4h)',
            totalHoursBadge: '8h30 (510p)',
            isToday: todayWeekday == DateTime.monday,
            badgeColor: const Color(0xFF10B981),
            isDark: isDark,
          ),
          const SizedBox(height: 10),
          _PolicyItemRow(
            dayLabel: 'Thứ Ba – Thứ Sáu (T3 - T6)',
            timeRange: '08:00 – 17:00',
            lunchBreak: 'Nghỉ trưa 12:00 – 13:00',
            breakdown: 'Ca sáng: 08:00 - 12:00 (4h) • Ca chiều: 13:00 - 17:00 (4h)',
            totalHoursBadge: '8h00 (480p)',
            isToday: todayWeekday >= 2 && todayWeekday <= 5,
            badgeColor: const Color(0xFF2563EB),
            isDark: isDark,
          ),
          const SizedBox(height: 10),
          _PolicyItemRow(
            dayLabel: 'Thứ Bảy (T7)',
            timeRange: '08:00 – 16:30',
            lunchBreak: 'Nghỉ trưa 12:00 – 13:00',
            breakdown: 'Ca sáng: 08:00 - 12:00 (4h) • Ca chiều: 13:00 - 16:30 (3h30)',
            totalHoursBadge: '7h30 (450p)',
            isToday: todayWeekday == DateTime.saturday,
            badgeColor: const Color(0xFFF59E0B),
            isDark: isDark,
          ),
          const SizedBox(height: 10),
          _PolicyItemRow(
            dayLabel: 'Chủ Nhật (CN)',
            timeRange: 'Ngày nghỉ cuối tuần',
            lunchBreak: 'Nghỉ ngơi theo chế độ công ty',
            breakdown: 'Không tính định mức ca làm việc',
            totalHoursBadge: 'Nghỉ lễ/tuần',
            isToday: todayWeekday == DateTime.sunday,
            badgeColor: const Color(0xFF94A3B8),
            isDark: isDark,
          ),
        ],
      ),
    );
  }
}

class _PolicyItemRow extends StatelessWidget {
  const _PolicyItemRow({
    required this.dayLabel,
    required this.timeRange,
    required this.lunchBreak,
    required this.breakdown,
    required this.totalHoursBadge,
    required this.isToday,
    required this.badgeColor,
    required this.isDark,
  });

  final String dayLabel;
  final String timeRange;
  final String lunchBreak;
  final String breakdown;
  final String totalHoursBadge;
  final bool isToday;
  final Color badgeColor;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isToday
            ? badgeColor.withValues(alpha: isDark ? 0.15 : 0.08)
            : (isDark ? const Color(0xFF0F172A) : AppColors.bg),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isToday
              ? badgeColor.withValues(alpha: 0.5)
              : (isDark ? Colors.white.withValues(alpha: 0.06) : AppColors.border.withValues(alpha: 0.5)),
          width: isToday ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: badgeColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Text(
                      dayLabel,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: isToday ? badgeColor : (isDark ? Colors.white : AppColors.textPrimary),
                      ),
                    ),
                    if (isToday)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: badgeColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Hôm nay',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: badgeColor,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  totalHoursBadge,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(LucideIcons.clock, size: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  '$timeRange ($lunchBreak)',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            breakdown,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white54 : AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
