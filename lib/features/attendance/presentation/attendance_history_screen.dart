import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_format.dart';
import '../../../shared/models/attendance.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../application/attendance_controller.dart';

class AttendanceHistoryScreen extends ConsumerWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(attendanceStreamProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppScaffold(
      title: 'Lịch sử chấm công',
      body: rows.when(
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              icon: LucideIcons.calendarOff,
              title: 'Chưa có dữ liệu chấm công',
              subtitle: 'Lịch sử vào/ra ca của bạn sẽ hiển thị chi tiết tại đây.',
            );
          }

          // Group by date
          final byDate = <String, List<Attendance>>{};
          for (final a in list) {
            final targetDate = a.checkinTime ?? a.createdAt;
            final key = Dates.isoDate(targetDate);
            byDate.putIfAbsent(key, () => <Attendance>[]).add(a);
          }
          final groups = byDate.entries.toList()
            ..sort((a, b) => b.key.compareTo(a.key));

          final totalSessions = list.length;
          final totalMins = _totalMinutes(list);
          final openCount = list.where((a) => a.isOpen).length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              // Summary Overview Header Card
              _SummaryBannerCard(
                totalSessions: totalSessions,
                totalMinutes: totalMins,
                openCount: openCount,
                isDark: isDark,
              ).animate().fadeIn(duration: 350.ms).slideY(begin: -0.08, end: 0),

              const SizedBox(height: 18),

              // Grouped History Cards
              for (int gi = 0; gi < groups.length; gi++) ...[
                _DateGroupHeader(
                  dateStr: groups[gi].key,
                  sessionCount: groups[gi].value.length,
                  isDark: isDark,
                ).animate().fadeIn(delay: (60 * gi).ms),
                const SizedBox(height: 8),
                for (final a in groups[gi].value)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _AttendanceSessionCard(
                      attendance: a,
                      isDark: isDark,
                    ),
                  ).animate().fadeIn(delay: (80 * gi).ms).slideX(begin: 0.04, end: 0),
                const SizedBox(height: 6),
              ],
            ],
          );
        },
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(error: e),
      ),
    );
  }

  int _totalMinutes(List<Attendance> list) {
    int total = 0;
    for (final a in list) {
      if (a.elapsed != null) {
        total += a.elapsed!.inMinutes;
      }
    }
    return total;
  }
}

class _SummaryBannerCard extends StatelessWidget {
  const _SummaryBannerCard({
    required this.totalSessions,
    required this.totalMinutes,
    required this.openCount,
    required this.isDark,
  });

  final int totalSessions;
  final int totalMinutes;
  final int openCount;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final humanTime = Dates.humanDuration(Duration(minutes: totalMinutes));

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF064E3B), const Color(0xFF065F46)]
              : [const Color(0xFF10B981), const Color(0xFF047857)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: (isDark ? const Color(0xFF064E3B) : const Color(0xFF10B981))
                .withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  LucideIcons.history,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Tổng quan chấm công',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: openCount > 0 ? const Color(0xFF34D399) : Colors.white70,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      openCount > 0 ? 'Đang trong ca' : 'Đã ra ca',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatColumn(
                  label: 'Tổng ca làm',
                  value: '$totalSessions',
                  icon: LucideIcons.calendarCheck,
                ),
              ),
              Container(
                width: 1,
                height: 36,
                color: Colors.white.withValues(alpha: 0.15),
              ),
              Expanded(
                child: _StatColumn(
                  label: 'Tổng thời lượng',
                  value: humanTime.isNotEmpty ? humanTime : '0m',
                  icon: LucideIcons.clock,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white70, size: 14),
            const SizedBox(width: 5),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _DateGroupHeader extends StatelessWidget {
  const _DateGroupHeader({
    required this.dateStr,
    required this.sessionCount,
    required this.isDark,
  });

  final String dateStr;
  final int sessionCount;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final formattedDate = _formatDateVi(dateStr);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: Row(
        children: [
          const Icon(
            LucideIcons.calendarDays,
            size: 16,
            color: AppColors.attendance,
          ),
          const SizedBox(width: 8),
          Text(
            formattedDate,
            style: TextStyle(
              color: isDark ? Colors.white : AppColors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.soft(AppColors.attendance),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$sessionCount ca',
              style: const TextStyle(
                color: AppColors.attendanceDeep,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateVi(String isoDateStr) {
    try {
      final parts = isoDateStr.split('-');
      if (parts.length != 3) return isoDateStr;
      final year = int.parse(parts[0]);
      final month = int.parse(parts[1]);
      final day = int.parse(parts[2]);
      final dt = DateTime(year, month, day);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final diff = today.difference(dt).inDays;

      const weekdays = [
        'Thứ Hai',
        'Thứ Ba',
        'Thứ Tư',
        'Thứ Năm',
        'Thứ Sáu',
        'Thứ Bảy',
        'Chủ Nhật',
      ];
      final wd = weekdays[dt.weekday - 1];
      final dayStr = day.toString().padLeft(2, '0');
      final monthStr = month.toString().padLeft(2, '0');

      if (diff == 0) return 'Hôm nay · $wd, $dayStr/$monthStr/$year';
      if (diff == 1) return 'Hôm qua · $wd, $dayStr/$monthStr/$year';
      return '$wd, $dayStr/$monthStr/$year';
    } catch (_) {
      return isoDateStr;
    }
  }
}

class _AttendanceSessionCard extends StatelessWidget {
  const _AttendanceSessionCard({
    required this.attendance,
    required this.isDark,
  });

  final Attendance attendance;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final a = attendance;
    final isOpen = a.isOpen;
    final inTimeStr = a.checkinTime != null ? Dates.time(a.checkinTime!) : 'Chưa vào';
    final outTimeStr = a.checkoutTime != null ? Dates.time(a.checkoutTime!) : (isOpen ? 'Đang làm việc' : 'Chưa ra');
    final durationStr = a.elapsed != null ? Dates.humanDuration(a.elapsed!) : null;
    final hasGps = a.checkinLat != null && a.checkinLng != null;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOpen
              ? AppColors.attendance.withValues(alpha: 0.5)
              : (isDark ? Colors.white.withValues(alpha: 0.08) : AppColors.border),
          width: isOpen ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isOpen
                ? AppColors.attendance.withValues(alpha: 0.08)
                : const Color(0x050F172A),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Status Bar inside card
            Row(
              children: [
                // Status pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isOpen
                        ? AppColors.soft(AppColors.attendance)
                        : (isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFF1F5F9)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isOpen ? LucideIcons.circleDot : LucideIcons.checkCircle2,
                        size: 13,
                        color: isOpen ? AppColors.attendanceDeep : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isOpen ? 'Đang trong ca' : 'Hoàn thành ca',
                        style: TextStyle(
                          color: isOpen ? AppColors.attendanceDeep : AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Elapsed duration pill
                if (durationStr != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.soft(AppColors.primary),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          LucideIcons.timer,
                          size: 13,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          durationStr,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 14),

            // Time flow row: In → Out
            Row(
              children: [
                // Check-in Column
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.soft(AppColors.attendance).withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.attendance.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.attendance.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            LucideIcons.logIn,
                            size: 16,
                            color: AppColors.attendanceDeep,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Vào ca',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                inTimeStr,
                                style: TextStyle(
                                  color: isDark ? Colors.white : AppColors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(
                    LucideIcons.arrowRight,
                    size: 18,
                    color: AppColors.textMuted,
                  ),
                ),

                // Check-out Column
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isOpen
                          ? AppColors.soft(AppColors.warning).withValues(alpha: 0.4)
                          : AppColors.soft(AppColors.primary).withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isOpen
                            ? AppColors.warning.withValues(alpha: 0.2)
                            : AppColors.primary.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isOpen
                                ? AppColors.warning.withValues(alpha: 0.2)
                                : AppColors.primary.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            isOpen ? LucideIcons.clock : LucideIcons.logOut,
                            size: 16,
                            color: isOpen ? AppColors.warning : AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isOpen ? 'Trạng thái' : 'Ra ca',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                outTimeStr,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isOpen
                                      ? AppColors.warning
                                      : (isDark ? Colors.white : AppColors.textPrimary),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
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
            ),

            // GPS location info if available
            if (hasGps) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(
                      LucideIcons.mapPin,
                      size: 13,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Tọa độ GPS: (${a.checkinLat!.toStringAsFixed(4)}, ${a.checkinLng!.toStringAsFixed(4)})',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
