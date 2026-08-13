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
import '../../../core/utils/vn_holidays.dart';
import '../application/attendance_controller.dart';
import '../domain/shift_calculator.dart';

class AttendanceHistoryScreen extends ConsumerStatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  ConsumerState<AttendanceHistoryScreen> createState() => _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends ConsumerState<AttendanceHistoryScreen> {
  bool _isCalendarView = false;
  late DateTime _selectedMonth;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month, 1);
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  @override
  Widget build(BuildContext context) {
    final rows = ref.watch(attendanceStreamProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppScaffold(
      title: 'Lịch sử chấm công',
      actions: [
        IconButton(
          onPressed: () {
            setState(() {
              _isCalendarView = !_isCalendarView;
            });
          },
          icon: Icon(
            _isCalendarView ? LucideIcons.list : LucideIcons.calendarDays,
            size: 20,
          ),
          tooltip: _isCalendarView ? 'Xem dạng danh sách' : 'Xem dạng lịch',
        ),
      ],
      body: rows.when(
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              icon: LucideIcons.calendarOff,
              title: 'Chưa có dữ liệu chấm công',
              subtitle: 'Lịch sử vào/ra ca của bạn sẽ hiển thị chi tiết tại đây.',
            );
          }

          final totalSessions = list.length;
          final totalMins = _totalMinutes(list);
          final openCount = list.where((a) => a.isOpen).length;

          if (_isCalendarView) {
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
                _AttendanceCalendarView(
                  attendances: list,
                  selectedMonth: _selectedMonth,
                  selectedDate: _selectedDate,
                  isDark: isDark,
                  onMonthChanged: (newMonth) {
                    setState(() => _selectedMonth = newMonth);
                  },
                  onDateSelected: (newDate) {
                    setState(() => _selectedDate = newDate);
                  },
                ).animate().fadeIn(duration: 350.ms),
              ],
            );
          }

          // Group by date for List View
          final byDate = <String, List<Attendance>>{};
          for (final a in list) {
            final targetDate = a.checkinTime ?? a.createdAt;
            final key = Dates.isoDate(targetDate);
            byDate.putIfAbsent(key, () => <Attendance>[]).add(a);
          }
          final groups = byDate.entries.toList()
            ..sort((a, b) => b.key.compareTo(a.key));

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
      if (a.checkinTime != null) {
        final calc = ShiftCalculator.calculate(
          checkinTime: a.checkinTime,
          now: a.checkoutTime,
        );
        total += calc.workedMinutes;
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
    final shiftCalc = a.checkinTime != null
        ? ShiftCalculator.calculate(
            checkinTime: a.checkinTime,
            now: a.checkoutTime,
          )
        : null;
    final durationStr = shiftCalc != null
        ? Dates.humanDuration(Duration(minutes: shiftCalc.workedMinutes))
        : null;
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

class _AttendanceCalendarView extends StatelessWidget {
  const _AttendanceCalendarView({
    required this.attendances,
    required this.selectedMonth,
    required this.selectedDate,
    required this.isDark,
    required this.onMonthChanged,
    required this.onDateSelected,
  });

  final List<Attendance> attendances;
  final DateTime selectedMonth;
  final DateTime? selectedDate;
  final bool isDark;
  final ValueChanged<DateTime> onMonthChanged;
  final ValueChanged<DateTime> onDateSelected;

  @override
  Widget build(BuildContext context) {
    final daysInMonth = DateTime(selectedMonth.year, selectedMonth.month + 1, 0).day;
    final firstWeekday = DateTime(selectedMonth.year, selectedMonth.month, 1).weekday; // 1=Mon, 7=Sun
    final leadingEmpty = firstWeekday - 1;

    final weekLabels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    final now = DateTime.now();

    // Map date key "YYYY-MM-DD" to list of attendances
    final attendanceByDay = <String, List<Attendance>>{};
    for (final a in attendances) {
      final t = a.checkinTime ?? a.createdAt;
      final key = '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
      attendanceByDay.putIfAbsent(key, () => []).add(a);
    }

    // Sessions for currently selected date
    List<Attendance> selectedDaySessions = [];
    if (selectedDate != null) {
      final key = '${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}';
      selectedDaySessions = attendanceByDay[key] ?? [];
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Calendar Surface Card
        Container(
          padding: const EdgeInsets.all(16),
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
            children: [
              // Month Header Controls (Tháng X, YYYY ◄ ►)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Tháng ${selectedMonth.month}, ${selectedMonth.year}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(LucideIcons.chevronLeft, size: 20),
                        onPressed: () {
                          onMonthChanged(DateTime(selectedMonth.year, selectedMonth.month - 1, 1));
                        },
                      ),
                      IconButton(
                        icon: const Icon(LucideIcons.chevronRight, size: 20),
                        onPressed: () {
                          onMonthChanged(DateTime(selectedMonth.year, selectedMonth.month + 1, 1));
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Weekday Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(7, (i) {
                  final label = weekLabels[i];
                  final isSun = i == 6;
                  final isSat = i == 5;
                  final color = isSun
                      ? AppColors.danger
                      : (isSat
                          ? const Color(0xFF2563EB)
                          : (isDark ? Colors.white60 : AppColors.textMuted));

                  return Expanded(
                    child: Center(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 10),
              const Divider(height: 1, thickness: 0.5),
              const SizedBox(height: 10),

              // Calendar Days Grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: leadingEmpty + daysInMonth,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  childAspectRatio: 0.85,
                  crossAxisSpacing: 4,
                  mainAxisSpacing: 6,
                ),
                itemBuilder: (context, index) {
                  if (index < leadingEmpty) {
                    return const SizedBox.shrink();
                  }

                  final dayNum = index - leadingEmpty + 1;
                  final dayDate = DateTime(selectedMonth.year, selectedMonth.month, dayNum);
                  final dayKey = '${dayDate.year}-${dayDate.month.toString().padLeft(2, '0')}-${dayDate.day.toString().padLeft(2, '0')}';
                  final dayAttendances = attendanceByDay[dayKey] ?? [];

                  // Calculate worked minutes for this day
                  int dayWorkedMins = 0;
                  for (final a in dayAttendances) {
                    if (a.checkinTime != null) {
                      final calc = ShiftCalculator.calculate(
                        checkinTime: a.checkinTime,
                        now: a.checkoutTime,
                      );
                      dayWorkedMins += calc.workedMinutes;
                    }
                  }

                  final isToday = now.year == dayDate.year && now.month == dayDate.month && now.day == dayDate.day;
                  final isSelected = selectedDate != null &&
                      selectedDate!.year == dayDate.year &&
                      selectedDate!.month == dayDate.month &&
                      selectedDate!.day == dayDate.day;

                  final isSunday = dayDate.weekday == DateTime.sunday;
                  final isSaturday = dayDate.weekday == DateTime.saturday;
                  final holiday = VnHolidays.getHoliday(dayDate);
                  final hasCheckin = dayAttendances.isNotEmpty;
                  final workedHoursStr = dayWorkedMins > 0 ? _formatShortDuration(dayWorkedMins) : (hasCheckin ? '0m' : null);

                  // Cell background color
                  final cellBg = isSelected
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : (holiday != null
                          ? (isDark ? const Color(0xFF450A0A) : const Color(0xFFFEF2F2))
                          : (isSunday
                              ? (isDark ? const Color(0xFF450A0A).withValues(alpha: 0.3) : const Color(0xFFFEF2F2).withValues(alpha: 0.5))
                              : (isToday ? AppColors.soft(AppColors.primary) : Colors.transparent)));

                  // Cell border color
                  final cellBorder = isSelected
                      ? AppColors.primary
                      : (holiday != null
                          ? const Color(0xFFFCA5A5)
                          : (isToday ? AppColors.primary.withValues(alpha: 0.4) : Colors.transparent));

                  // Day text color
                  final dayTextColor = isSelected
                      ? AppColors.primary
                      : (holiday != null
                          ? const Color(0xFFDC2626)
                          : (isSunday
                              ? AppColors.danger
                              : (isSaturday
                                  ? const Color(0xFF2563EB)
                                  : (isToday
                                      ? AppColors.primary
                                      : (isDark ? Colors.white : AppColors.textPrimary)))));

                  return InkWell(
                    onTap: () => onDateSelected(dayDate),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: cellBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: cellBorder,
                          width: isSelected ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$dayNum',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: (isToday || isSelected || hasCheckin || holiday != null || isSunday)
                                  ? FontWeight.w900
                                  : FontWeight.w500,
                              color: dayTextColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          if (holiday != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDC2626).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                holiday.shortLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFFDC2626),
                                ),
                              ),
                            )
                          else if (workedHoursStr != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: (dayWorkedMins >= 480)
                                    ? AppColors.success.withValues(alpha: 0.18)
                                    : AppColors.primary.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                workedHoursStr,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: (dayWorkedMins >= 480) ? AppColors.success : AppColors.primary,
                                ),
                              ),
                            )
                          else
                            Container(
                              width: 4,
                              height: 4,
                              decoration: const BoxDecoration(
                                color: Colors.transparent,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Selected Date Sessions Breakdown Header & Cards
        if (selectedDate != null) ...[
          // Holiday Banner if selected date is a holiday
          if (VnHolidays.getHoliday(selectedDate!) != null) ...[
            Builder(
              builder: (context) {
                final h = VnHolidays.getHoliday(selectedDate!)!;
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF450A0A) : const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFCA5A5)),
                  ),
                  child: Row(
                    children: [
                      const Text('🎉', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              h.name,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFDC2626),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              h.isOfficialOff
                                  ? 'Ngày lễ chính thức VN (Nghỉ lễ hưởng nguyên lương)'
                                  : 'Ngày kỷ niệm truyền thống Việt Nam',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white70 : const Color(0xFF991B1B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],

          Row(
            children: [
              const Icon(LucideIcons.calendarCheck, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Chấm công ngày ${_formatDateVi(selectedDate!)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '${selectedDaySessions.length} ca làm',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (selectedDaySessions.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : AppColors.surface,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: Text(
                  'Không có dữ liệu chấm công cho ngày này',
                  style: TextStyle(fontSize: 13, color: AppColors.textMuted),
                ),
              ),
            )
          else
            for (final a in selectedDaySessions)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _AttendanceSessionCard(
                  attendance: a,
                  isDark: isDark,
                ),
              ),
        ],
      ],
    );
  }

  static String _formatShortDuration(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h > 0 && m > 0) return '${h}h${m}m';
    if (h > 0) return '${h}h';
    return '${m}m';
  }

  static String _formatDateVi(DateTime dt) {
    const weekdays = ['Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy', 'Chủ Nhật'];
    final wd = weekdays[dt.weekday - 1];
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    return '$wd, $d/$m/${dt.year}';
  }
}
