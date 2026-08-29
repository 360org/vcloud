import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_format.dart';
import '../../../core/utils/vn_holidays.dart';
import '../../../shared/models/attendance.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/app_toast.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../../auth/application/auth_controller.dart';
import '../application/attendance_controller.dart';
import '../domain/shift_calculator.dart';

class AttendanceHistoryScreen extends ConsumerStatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  ConsumerState<AttendanceHistoryScreen> createState() => _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends ConsumerState<AttendanceHistoryScreen> {
  bool _isCalendarView = false;
  bool _showAllHistory = false;
  late DateTime _selectedMonth;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateTime(now.year, now.month, 1);
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  void _onMonthChanged(DateTime newMonth) {
    setState(() {
      _selectedMonth = newMonth;
    });
    ref.read(selectedAttendanceMonthProvider.notifier).state = newMonth;
  }

  Future<void> _openMonthPicker() async {
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _MonthYearPickerSheet(initialDate: _selectedMonth),
    );
    if (picked != null) {
      _onMonthChanged(picked);
    }
  }

  void _openExportSummary(HrAttendanceMonthSummary summary) {
    final user = ref.read(authControllerProvider).valueOrNull;
    final meta = user?.userMetadata;
    final rawName = meta?['display_name'];
    final name = (rawName is String ? rawName : (rawName != null && rawName != false ? rawName.toString() : null))?.trim();
    final displayName = (name != null && name.isNotEmpty)
        ? name
        : (user?.email?.split('@').first ?? 'Nhân viên');

    showDialog(
      context: context,
      builder: (ctx) => _ExportAttendanceSummaryDialog(
        month: _selectedMonth,
        summary: summary,
        userName: displayName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = ref.watch(attendanceStreamProvider);
    final hrSummary = ref.watch(hrAttendanceMonthSummaryProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();

    return AppScaffold(
      title: 'Bảng công ${_selectedMonth.month}/${_selectedMonth.year}',
      actions: [
        IconButton(
          onPressed: _openMonthPicker,
          icon: const Icon(
            LucideIcons.calendarSearch,
            color: Colors.white,
            size: 20,
          ),
          tooltip: 'Chọn Tháng/Năm nhanh',
        ),
        IconButton(
          onPressed: () => _openExportSummary(hrSummary),
          icon: const Icon(
            LucideIcons.fileSpreadsheet,
            color: Colors.white,
            size: 20,
          ),
          tooltip: 'Xuất báo cáo công',
        ),
        IconButton(
          onPressed: () {
            setState(() {
              _isCalendarView = !_isCalendarView;
            });
          },
          icon: Icon(
            _isCalendarView ? LucideIcons.list : LucideIcons.calendarDays,
            color: Colors.white,
            size: 20,
          ),
          tooltip: _isCalendarView ? 'Xem dạng danh sách' : 'Xem dạng lịch',
        ),
      ],
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(attendanceStreamProvider);
          ref.invalidate(attendanceTodayProvider);
        },
        child: rows.when(
          data: (list) {
            if (list.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 60),
                children: [
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(LucideIcons.calendarOff, size: 36, color: Color(0xFF94A3B8)),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Chưa có dữ liệu chấm công',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Lịch sử vào/ra ca của bạn sẽ hiển thị chi tiết tại đây.',
                          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: () {
                            ref.invalidate(attendanceStreamProvider);
                            ref.invalidate(attendanceTodayProvider);
                          },
                          icon: const Icon(LucideIcons.refreshCw, size: 16),
                          label: const Text('Tải lại dữ liệu'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF00C83A),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

          final openCount = list.where((a) => a.isOpen).length;

          if (_isCalendarView) {
            final monthList = list.where((a) {
              final t = a.checkinTime ?? a.createdAt;
              return t.year == _selectedMonth.year && t.month == _selectedMonth.month;
            }).toList();
            final calTotalSessions = monthList.length;
            final calTotalMins = _totalMinutes(monthList);

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                // Summary Overview Header Card for Selected Month in Calendar View
                _SummaryBannerCard(
                  title: 'Tổng quan Tháng ${_selectedMonth.month}/${_selectedMonth.year}',
                  totalSessions: calTotalSessions,
                  totalMinutes: calTotalMins,
                  openCount: openCount,
                  isDark: isDark,
                ).animate().fadeIn(duration: 350.ms).slideY(begin: -0.08, end: 0),
                const SizedBox(height: 14),

                // HR KPIs Card: Tổng ngày công chuẩn, đi muộn, về sớm, OT
                _HrAttendanceKpisCard(
                  summary: hrSummary,
                  month: _selectedMonth,
                  isDark: isDark,
                  onDateSelected: (newDate) {
                    setState(() {
                      _selectedDate = newDate;
                      _isCalendarView = true;
                    });
                  },
                ).animate().fadeIn(duration: 380.ms, delay: 60.ms),
                const SizedBox(height: 16),

                _AttendanceCalendarView(
                  attendances: list,
                  selectedMonth: _selectedMonth,
                  selectedDate: _selectedDate,
                  isDark: isDark,
                  onMonthChanged: _onMonthChanged,
                  onDateSelected: (newDate) {
                    setState(() => _selectedDate = newDate);
                  },
                ).animate().fadeIn(duration: 350.ms),
              ],
            );
          }

          // List View Scope: current month vs all-time
          final currentMonthList = list.where((a) {
            final t = a.checkinTime ?? a.createdAt;
            return t.year == now.year && t.month == now.month;
          }).toList();

          final isAllTime = _showAllHistory || currentMonthList.isEmpty;
          final activeList = isAllTime ? list : currentMonthList;
          final totalSessions = activeList.length;
          final totalMins = _totalMinutes(activeList);
          final bannerTitle = isAllTime
              ? 'Tổng quan toàn bộ'
              : 'Tổng quan Tháng ${now.month}/${now.year}';

          // Group by date for List View
          final byDate = <String, List<Attendance>>{};
          for (final a in activeList) {
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
                title: bannerTitle,
                totalSessions: totalSessions,
                totalMinutes: totalMins,
                openCount: openCount,
                isDark: isDark,
                showFilterToggle: currentMonthList.isNotEmpty && list.length > currentMonthList.length,
                isAllHistory: _showAllHistory,
                onToggleFilter: () {
                  setState(() => _showAllHistory = !_showAllHistory);
                },
              ).animate().fadeIn(duration: 350.ms).slideY(begin: -0.08, end: 0),
              const SizedBox(height: 14),

              // HR KPIs Card
              _HrAttendanceKpisCard(
                summary: hrSummary,
                month: _selectedMonth,
                isDark: isDark,
                onDateSelected: (newDate) {
                  setState(() {
                    _selectedDate = newDate;
                    _isCalendarView = true;
                  });
                },
              ).animate().fadeIn(duration: 380.ms, delay: 60.ms),
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
    required this.title,
    required this.totalSessions,
    required this.totalMinutes,
    required this.openCount,
    required this.isDark,
    this.showFilterToggle = false,
    this.isAllHistory = false,
    this.onToggleFilter,
  });

  final String title;
  final int totalSessions;
  final int totalMinutes;
  final int openCount;
  final bool isDark;
  final bool showFilterToggle;
  final bool isAllHistory;
  final VoidCallback? onToggleFilter;

  @override
  Widget build(BuildContext context) {
    final humanTime = Dates.humanDuration(Duration(minutes: totalMinutes));

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF064E3B), const Color(0xFF047857)]
              : [const Color(0xFF00C83A), const Color(0xFF009D2E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x3300C83A),
            blurRadius: 20,
            offset: Offset(0, 8),
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
                  color: Colors.white.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  LucideIcons.history,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (showFilterToggle && onToggleFilter != null) ...[
                InkWell(
                  onTap: onToggleFilter,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isAllHistory ? 'Xem Tháng này' : 'Xem Tất cả',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],
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
                color: Colors.white.withValues(alpha: 0.2),
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
            color: AppColors.primary,
          ),
          const SizedBox(width: 8),
          Text(
            formattedDate,
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFFE7FBEA),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$sessionCount ca',
              style: const TextStyle(
                color: Color(0xFF009D2E),
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
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOpen
              ? const Color(0xFF00C83A).withValues(alpha: 0.6)
              : (isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE2E8F0)),
          width: isOpen ? 1.5 : 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 16,
            offset: Offset(0, 4),
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
                        ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFE7FBEA))
                        : (isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isOpen ? LucideIcons.circleDot : LucideIcons.checkCircle2,
                        size: 13,
                        color: isOpen
                            ? (isDark ? const Color(0xFF34D399) : const Color(0xFF009D2E))
                            : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        isOpen ? 'Đang trong ca' : 'Hoàn thành ca',
                        style: TextStyle(
                          color: isOpen
                              ? (isDark ? const Color(0xFF34D399) : const Color(0xFF009D2E))
                              : (isDark ? const Color(0xFFE2E8F0) : const Color(0xFF475569)),
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
                      color: isDark ? const Color(0xFF064E3B) : const Color(0xFFE7FBEA),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LucideIcons.timer,
                          size: 13,
                          color: isDark ? const Color(0xFF34D399) : const Color(0xFF009D2E),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          durationStr,
                          style: TextStyle(
                            color: isDark ? const Color(0xFF34D399) : const Color(0xFF009D2E),
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
                      color: isDark ? const Color(0xFF132A20) : const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDark ? const Color(0xFF1E5B3E) : const Color(0xFFBBF7D0),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF16A34A).withValues(alpha: isDark ? 0.25 : 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            LucideIcons.logIn,
                            size: 16,
                            color: isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Vào ca',
                                style: TextStyle(
                                  color: isDark ? const Color(0xFF86EFAC) : const Color(0xFF166534),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                inTimeStr,
                                style: TextStyle(
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
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

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(
                    LucideIcons.arrowRight,
                    size: 18,
                    color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                  ),
                ),

                // Check-out Column
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isOpen
                          ? (isDark ? const Color(0xFF2B2012) : const Color(0xFFFFFBEB))
                          : (isDark ? const Color(0xFF132A20) : const Color(0xFFF0FDF4)),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isOpen
                            ? (isDark ? const Color(0xFF78450F) : const Color(0xFFFDE68A))
                            : (isDark ? const Color(0xFF1E5B3E) : const Color(0xFFBBF7D0)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isOpen
                                ? const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.25 : 0.15)
                                : const Color(0xFF16A34A).withValues(alpha: isDark ? 0.25 : 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            isOpen ? LucideIcons.clock : LucideIcons.logOut,
                            size: 16,
                            color: isOpen
                                ? (isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706))
                                : (isDark ? const Color(0xFF4ADE80) : const Color(0xFF16A34A)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isOpen ? 'Trạng thái' : 'Ra ca',
                                style: TextStyle(
                                  color: isOpen
                                      ? (isDark ? const Color(0xFFFCD34D) : const Color(0xFF92400E))
                                      : (isDark ? const Color(0xFF86EFAC) : const Color(0xFF166534)),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                outTimeStr,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isOpen
                                      ? (isDark ? const Color(0xFFFBBF24) : const Color(0xFFD97706))
                                      : (isDark ? Colors.white : const Color(0xFF0F172A)),
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
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      LucideIcons.mapPin,
                      size: 13,
                      color: Color(0xFF00C83A),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Tọa độ GPS: (${a.checkinLat!.toStringAsFixed(4)}, ${a.checkinLng!.toStringAsFixed(4)})',
                        style: TextStyle(
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
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

class _AttendanceCalendarView extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final daysInMonth = DateTime(selectedMonth.year, selectedMonth.month + 1, 0).day;
    final firstWeekday = DateTime(selectedMonth.year, selectedMonth.month, 1).weekday; // 1=Mon, 7=Sun
    final leadingEmpty = firstWeekday - 1;

    final weekLabels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    final now = DateTime.now();
    final dayStatusMap = ref.watch(dayAttendanceStatusMapProvider);

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
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
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
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: Icon(
                          LucideIcons.chevronLeft,
                          size: 20,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
                        onPressed: () {
                          onMonthChanged(DateTime(selectedMonth.year, selectedMonth.month - 1, 1));
                        },
                      ),
                      IconButton(
                        icon: Icon(
                          LucideIcons.chevronRight,
                          size: 20,
                          color: isDark ? Colors.white : const Color(0xFF0F172A),
                        ),
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
                      ? (isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626))
                      : (isSat
                          ? (isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB))
                          : (isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B)));

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
              Divider(height: 1, thickness: 0.5, color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              const SizedBox(height: 10),

              // Calendar Days Grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: leadingEmpty + daysInMonth,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  childAspectRatio: 0.72,
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

                  final dayStatus = dayStatusMap[dayNum];
                  Color? statusDotColor;
                  if (dayStatus == HrDayAttendanceStatus.fullWorkday) {
                    statusDotColor = const Color(0xFF22C55E);
                  } else if (dayStatus == HrDayAttendanceStatus.halfWorkday) {
                    statusDotColor = const Color(0xFFF97316);
                  } else if (dayStatus == HrDayAttendanceStatus.lateOrEarly) {
                    statusDotColor = const Color(0xFFEAB308);
                  } else if (dayStatus == HrDayAttendanceStatus.staleOrMissing) {
                    statusDotColor = const Color(0xFFEF4444);
                  }

                  // Cell background color
                  final cellBg = isSelected
                      ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFE7FBEA))
                      : (holiday != null
                          ? (isDark ? const Color(0xFF3B1D1D) : const Color(0xFFFEF2F2))
                          : (isSunday
                              ? (isDark ? const Color(0xFF2A1515) : const Color(0xFFFEF2F2))
                              : (isToday ? (isDark ? const Color(0xFF064E3B).withValues(alpha: 0.5) : const Color(0xFFE7FBEA)) : Colors.transparent)));

                  // Cell border color
                  final cellBorder = isSelected
                      ? const Color(0xFF00C83A)
                      : (holiday != null
                          ? (isDark ? const Color(0xFF991B1B) : const Color(0xFFFCA5A5))
                          : (isToday ? const Color(0xFF00C83A).withValues(alpha: 0.6) : Colors.transparent));

                  // Day text color
                  final dayTextColor = isSelected
                      ? (isDark ? const Color(0xFF34D399) : const Color(0xFF009D2E))
                      : (holiday != null
                          ? (isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626))
                          : (isSunday
                              ? (isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626))
                              : (isSaturday
                                  ? (isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB))
                                  : (isToday
                                      ? (isDark ? const Color(0xFF34D399) : const Color(0xFF009D2E))
                                      : (isDark ? Colors.white : const Color(0xFF1E293B))))));

                  return InkWell(
                    onTap: () => onDateSelected(dayDate),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: cellBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: cellBorder,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
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
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                                decoration: BoxDecoration(
                                  color: (isDark ? const Color(0xFFDC2626) : const Color(0xFFDC2626)).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  holiday.shortLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w900,
                                    color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626),
                                  ),
                                ),
                              ),
                            )
                          else if (workedHoursStr != null)
                            Builder(
                              builder: (context) {
                                final dayTarget = ShiftConfig.forDate(dayDate).targetWorkMinutes;
                                final isComplete = dayWorkedMins >= dayTarget;
                                return FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: isComplete
                                          ? (isDark ? const Color(0xFF064E3B) : const Color(0xFFDCFCE7))
                                          : (isDark ? const Color(0xFF451A03) : const Color(0xFFFEF3C7)),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      workedHoursStr,
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                        color: isComplete
                                            ? (isDark ? const Color(0xFF86EFAC) : const Color(0xFF15803D))
                                            : (isDark ? const Color(0xFFFCD34D) : const Color(0xFFB45309)),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            )
                          else if (statusDotColor != null)
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: statusDotColor,
                                shape: BoxShape.circle,
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
              const SizedBox(height: 12),
              // Legend Row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _CalendarLegendItem(color: const Color(0xFF22C55E), label: 'Đủ công', isDark: isDark),
                  const SizedBox(width: 12),
                  _CalendarLegendItem(color: const Color(0xFFEAB308), label: 'Muộn/Sớm', isDark: isDark),
                  const SizedBox(width: 12),
                  _CalendarLegendItem(color: const Color(0xFFF97316), label: 'Nửa công', isDark: isDark),
                  const SizedBox(width: 12),
                  _CalendarLegendItem(color: const Color(0xFFEF4444), label: 'Thiếu công', isDark: isDark),
                ],
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
                    color: isDark ? const Color(0xFF3B1D1D) : const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? const Color(0xFF991B1B) : const Color(0xFFFCA5A5)),
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
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: isDark ? const Color(0xFFFCA5A5) : const Color(0xFFDC2626),
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
              const Icon(LucideIcons.calendarCheck, size: 16, color: Color(0xFF00C83A)),
              const SizedBox(width: 8),
              Text(
                'Chấm công ngày ${_formatDateVi(selectedDate!)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              const Spacer(),
              Text(
                '${selectedDaySessions.length} ca làm',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (selectedDaySessions.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
                ),
              ),
              child: const Center(
                child: Text(
                  'Không có dữ liệu chấm công cho ngày này',
                  style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
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

class _CalendarLegendItem extends StatelessWidget {
  const _CalendarLegendItem({
    required this.color,
    required this.label,
    required this.isDark,
  });

  final Color color;
  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
          ),
        ),
      ],
    );
  }
}

class _HrAttendanceKpisCard extends StatelessWidget {
  const _HrAttendanceKpisCard({
    required this.summary,
    required this.month,
    required this.isDark,
    this.onDateSelected,
  });

  final HrAttendanceMonthSummary summary;
  final DateTime month;
  final bool isDark;
  final ValueChanged<DateTime>? onDateSelected;

  @override
  Widget build(BuildContext context) {
    final progress = summary.targetWorkdays > 0
        ? (summary.actualWorkdays / summary.targetWorkdays).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFF00C83A).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(LucideIcons.award, color: Color(0xFF00C83A), size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bảng đối soát công HR',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tháng ${month.month}/${month.year} · Chuẩn ${summary.targetWorkdays.toStringAsFixed(0)} ngày công',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF00C83A).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${summary.actualWorkdays} / ${summary.targetWorkdays.toStringAsFixed(0)} công',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF00C83A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00C83A)),
            ),
          ),
          const SizedBox(height: 14),
          // 3 KPIs Grid (Ẩn Đi muộn theo yêu cầu)
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _KpiMiniBox(
                  icon: LucideIcons.clockCheck,
                  label: 'Tổng giờ công',
                  value: '${(summary.totalWorkedMinutes ~/ 60)}h ${(summary.totalWorkedMinutes % 60)}p',
                  color: const Color(0xFF10B981),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: _KpiMiniBox(
                  icon: LucideIcons.flame,
                  label: 'Làm thêm (OT)',
                  value: '${(summary.overtimeMinutesTotal ~/ 60)}h ${(summary.overtimeMinutesTotal % 60)}p',
                  color: const Color(0xFF3B82F6),
                  isDark: isDark,
                  showDetailHint: summary.overtimeDetails.isNotEmpty,
                  onTap: () {
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (ctx) => _HrEventDetailsBottomSheet(
                        title: 'Chi tiết Làm thêm (OT)',
                        subtitle: 'Danh sách các ngày làm thêm ngoài giờ quy định',
                        items: summary.overtimeDetails,
                        type: 'overtime',
                        color: const Color(0xFF3B82F6),
                        onDateSelected: onDateSelected,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: _KpiMiniBox(
                  icon: LucideIcons.doorOpen,
                  label: 'Về sớm',
                  value: '${summary.earlyLeaveCount} lần (${summary.earlyMinutesTotal}p)',
                  color: const Color(0xFFF97316),
                  isDark: isDark,
                  showDetailHint: summary.earlyLeaveCount > 0,
                  onTap: () {
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (ctx) => _HrEventDetailsBottomSheet(
                        title: 'Chi tiết Về sớm (${summary.earlyLeaveCount} lần)',
                        subtitle: 'Đối chiếu giờ tan ca chuẩn và giờ chấm công thực tế',
                        items: summary.earlyDetails,
                        type: 'early',
                        color: const Color(0xFFF97316),
                        onDateSelected: onDateSelected,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KpiMiniBox extends StatelessWidget {
  const _KpiMiniBox({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
    this.onTap,
    this.showDetailHint = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool isDark;
  final VoidCallback? onTap;
  final bool showDetailHint;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: isDark ? 0.12 : 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 13, color: color),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                  if (showDetailHint)
                    Icon(LucideIcons.chevronRight, size: 12, color: color.withValues(alpha: 0.7)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom Sheet hiển thị danh sách đối chiếu chi tiết Đi muộn / Về sớm / Tăng ca
class _HrEventDetailsBottomSheet extends StatelessWidget {
  const _HrEventDetailsBottomSheet({
    required this.title,
    required this.subtitle,
    required this.items,
    required this.type,
    required this.color,
    this.onDateSelected,
  });

  final String title;
  final String subtitle;
  final List<HrAttendanceEventDetail> items;
  final String type;
  final Color color;
  final ValueChanged<DateTime>? onDateSelected;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.8,
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  type == 'late'
                      ? LucideIcons.alarmClockOff
                      : (type == 'early' ? LucideIcons.doorOpen : LucideIcons.flame),
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(LucideIcons.x, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (items.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  const Icon(LucideIcons.sparkles, color: Color(0xFF00C83A), size: 36),
                  const SizedBox(height: 12),
                  Text(
                    type == 'late'
                        ? 'Tuyệt vời! Không có ngày nào đi muộn 🎉'
                        : (type == 'early' ? 'Tuyệt vời! Không có ngày nào về sớm 🎉' : 'Không có ghi nhận làm thêm giờ'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Toàn bộ các phiên chấm công đều tuân thủ chuẩn ca làm việc.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, idx) {
                  final item = items[idx];
                  final dayStr = '${item.dayName}, ${item.date.day.toString().padLeft(2, '0')}/${item.date.month.toString().padLeft(2, '0')}/${item.date.year}';
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: color.withValues(alpha: 0.25)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              dayStr,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                type == 'late'
                                    ? 'Muộn ${item.diffMinutes}p'
                                    : (type == 'early' ? 'Về sớm ${item.diffMinutes}p' : '+${(item.diffMinutes ~/ 60)}h ${(item.diffMinutes % 60)}p'),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: color,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF0F172A) : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      type == 'early' ? 'Giờ tan ca chuẩn' : 'Giờ vào ca chuẩn',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? Colors.white60 : const Color(0xFF64748B),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      item.scheduledTime,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(width: 1, height: 26, color: isDark ? Colors.white12 : Colors.black12),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      type == 'early' ? 'Thực tế Check-out' : 'Thực tế Check-in',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isDark ? Colors.white60 : const Color(0xFF64748B),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      item.actualTime,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        color: color,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (onDateSelected != null) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: InkWell(
                              onTap: () {
                                Navigator.pop(context);
                                onDateSelected!(DateTime(item.date.year, item.date.month, item.date.day));
                              },
                              borderRadius: BorderRadius.circular(6),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      'Xem trên lịch',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: Color(0xFF00C83A),
                                      ),
                                    ),
                                    SizedBox(width: 2),
                                    Icon(LucideIcons.chevronRight, size: 12, color: Color(0xFF00C83A)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _MonthYearPickerSheet extends StatefulWidget {
  const _MonthYearPickerSheet({required this.initialDate});

  final DateTime initialDate;

  @override
  State<_MonthYearPickerSheet> createState() => _MonthYearPickerSheetState();
}

class _MonthYearPickerSheetState extends State<_MonthYearPickerSheet> {
  late int _selectedYear;
  late int _selectedMonth;

  @override
  void initState() {
    super.initState();
    _selectedYear = widget.initialDate.year;
    _selectedMonth = widget.initialDate.month;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final years = [_selectedYear - 2, _selectedYear - 1, _selectedYear, _selectedYear + 1];

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Chọn Tháng & Năm',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(LucideIcons.x, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Năm Chips
          Text(
            'Năm',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: years.map((y) {
                final isSel = y == _selectedYear;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text('$y', style: TextStyle(fontWeight: FontWeight.w800, color: isSel ? Colors.white : null)),
                    selected: isSel,
                    selectedColor: const Color(0xFF00C83A),
                    onSelected: (val) {
                      if (val) setState(() => _selectedYear = y);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 18),
          // 12 Tháng Grid
          Text(
            'Tháng',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 12,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              childAspectRatio: 1.6,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemBuilder: (context, index) {
              final m = index + 1;
              final isSel = m == _selectedMonth;
              return InkWell(
                onTap: () {
                  setState(() => _selectedMonth = m);
                  Navigator.pop(context, DateTime(_selectedYear, _selectedMonth, 1));
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSel
                        ? const Color(0xFF00C83A)
                        : (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9)),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSel ? const Color(0xFF00C83A) : Colors.transparent,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'Thg $m',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: isSel
                            ? Colors.white
                            : (isDark ? Colors.white : const Color(0xFF0F172A)),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ExportAttendanceSummaryDialog extends StatelessWidget {
  const _ExportAttendanceSummaryDialog({
    required this.month,
    required this.summary,
    required this.userName,
  });

  final DateTime month;
  final HrAttendanceMonthSummary summary;
  final String userName;

  String _buildExportText() {
    final buffer = StringBuffer();
    buffer.writeln('📋 BÁO CÁO BẢNG CÔNG THÁNG ${month.month}/${month.year}');
    buffer.writeln('----------------------------------------');
    buffer.writeln('👤 Nhân viên: $userName');
    buffer.writeln('📅 Tháng làm việc: ${month.month}/${month.year}');
    buffer.writeln('✅ Ngày công thực tế: ${summary.actualWorkdays} / ${summary.targetWorkdays.toStringAsFixed(0)} công');
    buffer.writeln('📊 Tổng thời lượng công: ${(summary.totalWorkedMinutes ~/ 60)}h ${(summary.totalWorkedMinutes % 60)}p');
    buffer.writeln('⚡ Giờ làm thêm (OT): ${(summary.overtimeMinutesTotal ~/ 60)}h ${(summary.overtimeMinutesTotal % 60)}p');
    if (summary.earlyLeaveCount > 0) {
      buffer.writeln('🏃 Về sớm: ${summary.earlyLeaveCount} lần (${summary.earlyMinutesTotal} phút)');
    } else {
      buffer.writeln('🏃 Về sớm: 0 lần (0 phút)');
    }
    buffer.writeln('----------------------------------------');
    buffer.writeln('*Xuất tự động từ hệ thống chấm công VCloud Mobile*');
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final exportText = _buildExportText();
    final progress = summary.targetWorkdays > 0
        ? (summary.actualWorkdays / summary.targetWorkdays).clamp(0.0, 1.0)
        : 0.0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00C83A).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(LucideIcons.fileSpreadsheet, color: Color(0xFF00C83A), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Báo cáo Bảng công',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: -0.2),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Tháng ${month.month}/${month.year} • $userName',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(LucideIcons.x, size: 20),
                  style: IconButton.styleFrom(
                    backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Card 1: Ngày công thực tế (Hero Card with Progress)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [const Color(0xFF064E3B).withValues(alpha: 0.4), const Color(0xFF0F172A)]
                      : [const Color(0xFFECFDF5), const Color(0xFFF0FDF4)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark ? const Color(0xFF059669).withValues(alpha: 0.3) : const Color(0xFFA7F3D0),
                  width: 1.2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(LucideIcons.award, color: Color(0xFF059669), size: 18),
                          const SizedBox(width: 6),
                          Text(
                            'Ngày công thực tế',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isDark ? const Color(0xFFA7F3D0) : const Color(0xFF065F46),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF00C83A).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${(progress * 100).toStringAsFixed(0)}% Đạt chuẩn',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF059669),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        '${summary.actualWorkdays}',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : const Color(0xFF065F46),
                          height: 1,
                        ),
                      ),
                      Text(
                        ' / ${summary.targetWorkdays.toStringAsFixed(0)} công',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF059669),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 7,
                      backgroundColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFD1FAE5),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00C83A)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Card 2: Lưới 2 cột chỉ số nổi bật (Tổng giờ & OT)
            Row(
              children: [
                // Tổng giờ công
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
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
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(LucideIcons.clockCheck, size: 15, color: Color(0xFF10B981)),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Tổng giờ làm',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${(summary.totalWorkedMinutes ~/ 60)}h ${(summary.totalWorkedMinutes % 60)}p',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Làm thêm (OT)
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
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
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(LucideIcons.flame, size: 15, color: Color(0xFF3B82F6)),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Làm thêm (OT)',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${(summary.overtimeMinutesTotal ~/ 60)}h ${(summary.overtimeMinutesTotal % 60)}p',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Card 3: Trạng thái Về sớm (Thẻ thông tin gọn đẹp)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    summary.earlyLeaveCount > 0 ? LucideIcons.doorOpen : LucideIcons.checkCircle2,
                    size: 16,
                    color: summary.earlyLeaveCount > 0 ? const Color(0xFFF97316) : const Color(0xFF059669),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      summary.earlyLeaveCount > 0
                          ? 'Về sớm: ${summary.earlyLeaveCount} lần (${summary.earlyMinutesTotal} phút)'
                          : 'Về sớm: 0 lần (Tuân thủ chuẩn giờ ra ca)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: summary.earlyLeaveCount > 0
                            ? const Color(0xFFF97316)
                            : (isDark ? const Color(0xFFA7F3D0) : const Color(0xFF065F46)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(LucideIcons.x, size: 16),
                    label: const Text('Đóng'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      side: BorderSide(
                        color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: exportText));
                      Navigator.pop(context);
                      AppToast.success(context, title: 'Đã sao chép bảng công vào bộ nhớ tạm!');
                    },
                    icon: const Icon(LucideIcons.copy, size: 16),
                    label: const Text(
                      'Sao chép gửi Kế toán',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF00C83A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      elevation: 2,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

