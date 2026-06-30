import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/attendance.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/ui_kit.dart';
import '../../auth/application/auth_controller.dart';
import '../application/attendance_controller.dart';
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
    'Chủ Nhật'
  ];

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(
        const Duration(seconds: 1), (_) => setState(() => _now = DateTime.now()));
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
    final diff = DateTime.now().difference(checkInAt);
    final hours = diff.inHours;
    final minutes = diff.inMinutes.remainder(60);
    final seconds = diff.inSeconds.remainder(60);
    return '${hours.toString().padLeft(2, '0')}:'
           '${minutes.toString().padLeft(2, '0')}:'
           '${seconds.toString().padLeft(2, '0')}';
  }

  Future<void> _handle(bool checkIn) async {
    if (!checkIn) {
      // Show checkout dialog
      final result = await showDialog<CheckoutData>(
        context: context,
        builder: (_) => const CheckoutDialog(),
      );
      if (result == null) return; // User cancelled
      // TODO: Save work description and selected task
    }

    setState(() => _busy = true);
    try {
      final a = ref.read(attendanceActionsProvider);
      checkIn ? await a.checkIn() : await a.checkOut();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(e.toString().replaceFirst('Failure: ', ''))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final open = ref.watch(openSessionProvider);
    final isCheckedIn = open != null;
    final user = ref.watch(authControllerProvider).value;
    final name = (user?.userMetadata?['display_name'] as String?) ??
        user?.email?.split('@').first ??
        'Bạn';
    final clock = isCheckedIn
        ? _formatElapsed(open.checkinTime)
        : '${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}';
    final seconds = isCheckedIn
        ? ''
        : ':${_now.second.toString().padLeft(2, '0')}';

    return AppScaffold(
      title: 'Check-in',
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Avatar with gradient ring
          Center(
            child: UserAvatar(
                userId: Supabase.instance.client.auth.currentUser?.id ?? '', displayName: name, size: 84),
          ).animate().fadeIn(duration: 400.ms),
          const SizedBox(height: 24),

          // Live clock with gradient text
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(clock,
                    style: const TextStyle(
                        fontSize: 52,
                        fontWeight: FontWeight.w800,
                        height: 1,
                        letterSpacing: 1)),
                Text(seconds,
                    style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                        color: AppColors.textMuted)),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(_viDate,
                style: AppTextStyles.body
                    .copyWith(color: AppColors.textSecondary)),
          ),
          const SizedBox(height: 32),

          // Check-in status: show time if checked in, circle if not
          if (isCheckedIn)
            Center(
              child: GlassCard(
                child: Column(
                  children: [
                    const Icon(Icons.check_circle_outline,
                        color: AppColors.success, size: 40),
                    const SizedBox(height: 8),
                    const Text('ĐÃ CHECK-IN',
                        style: TextStyle(
                            color: AppColors.success,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1)),
                    const SizedBox(height: 4),
                    Text(
                      _formatCheckinTime(open.checkinTime),
                      style: AppTextStyles.body.copyWith(
                          color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms),
            )
          else
            Center(
              child: _BigCircleButton(
                enabled: !isCheckedIn && !_busy,
                busy: _busy,
                onTap: () => _handle(true),
              ),
            ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Center(
              child: Text('Hoặc',
                  style: TextStyle(color: AppColors.textMuted)),
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
                  side: const BorderSide(
                      color: AppColors.danger, width: 1.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                ),
                icon: const Icon(Icons.cancel_outlined, size: 20),
                label: const Text('CHECK-OUT',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, letterSpacing: 0.5)),
              ),
            ),
          ).animate().fadeIn(duration: 380.ms, delay: 120.ms),
          const SizedBox(height: 24),

          // Location card
          _LocationRow(open: open)
              .animate()
              .fadeIn(duration: 380.ms, delay: 180.ms),
          const SizedBox(height: 16),

          // Weekly summary
          _WeeklySummary()
              .animate()
              .fadeIn(duration: 380.ms, delay: 240.ms),
          const SizedBox(height: 16),

          // History link
          Center(
            child: TextButton(
              onPressed: () => context.push('/attendance/history'),
              child: Text('Xem lịch sử check-in',
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.primary)),
            ),
          ),
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
            colors: [AppColors.textMuted, AppColors.textMuted]);
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
                child:
                    CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(LucideIcons.mapPin,
                      color: Colors.white, size: enabled ? 34 : 28),
                  const SizedBox(height: 8),
                  Text('CHECK-IN',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: enabled ? 16 : 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1)),
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
            curve: Curves.easeInOut);
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
                  AppColors.primary, AppColors.primaryDeep),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.location_on_outlined,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('VCCI Building HCM',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                const SizedBox(height: 2),
                Text(sub,
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textSecondary)),
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
          final d = DateTime(a.checkinTime!.year, a.checkinTime!.month, a.checkinTime!.day);
          final diff = d.difference(DateTime(weekStart.year, weekStart.month, weekStart.day)).inDays;
          if (diff >= 0 && diff < 7) {
            checkinsPerDay[diff]++;
          }
        }

        final totalCheckins = checkinsPerDay.where((c) => c > 0).length;

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
                      gradient: AppColors.featureGrad(AppColors.attendance, AppColors.attendanceDeep),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(LucideIcons.calendarCheck, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Text('Tuần này', style: AppTextStyles.title.copyWith(color: AppColors.textPrimary)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(7, (i) {
                  final isToday = i == now.weekday - 1;
                  final hasCheckin = checkinsPerDay[i] > 0;
                  return Column(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          gradient: hasCheckin
                              ? AppColors.featureGrad(AppColors.attendance, AppColors.attendanceDeep)
                              : null,
                          color: hasCheckin ? null : AppColors.bg,
                          shape: BoxShape.circle,
                          border: isToday ? Border.all(color: AppColors.attendance, width: 2) : null,
                        ),
                        child: hasCheckin
                            ? const Icon(Icons.check, color: Colors.white, size: 16)
                            : Center(
                                child: Text(
                                  weekDays[i],
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                                    color: isToday ? AppColors.attendance : AppColors.textMuted,
                                  ),
                                ),
                              ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        weekDays[i],
                        style: TextStyle(
                          fontSize: 10,
                          color: isToday ? AppColors.attendance : AppColors.textMuted,
                          fontWeight: isToday ? FontWeight.w700 : FontWeight.normal,
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
                    '$totalCheckins/7 ngày đã check-in',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  GradientBadge(
                    label: totalCheckins >= 5 ? 'Đạt' : 'Cần cố gắng',
                    gradient: totalCheckins >= 5
                        ? AppColors.successGrad
                        : AppColors.featureGrad(AppColors.warning, AppColors.warning),
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
