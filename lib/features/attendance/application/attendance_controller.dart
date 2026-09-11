import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/attendance.dart';
import '../data/attendance_repository.dart';
import '../domain/shift_calculator.dart';

final attendanceRepositoryProvider = Provider<AttendanceRepository>(
  (_) => AttendanceRepository(),
);

final attendanceStreamProvider = StreamProvider.autoDispose<List<Attendance>>(
  (ref) {
    final selectedMonth = ref.watch(selectedAttendanceMonthProvider);
    final monthStr = '${selectedMonth.year}-${selectedMonth.month.toString().padLeft(2, '0')}';
    return ref.read(attendanceRepositoryProvider).watchRecent(month: monthStr);
  },
);

final attendanceTodayProvider = StreamProvider.autoDispose<Attendance?>(
  (ref) => ref.read(attendanceRepositoryProvider).watchCurrentOpenAttendance(),
);

class AttendanceActions {
  AttendanceActions(this._repo, this._ref);
  final AttendanceRepository _repo;
  final Ref _ref;

  Future<void> checkIn() async {
    await _repo.checkIn();
    _ref.invalidate(attendanceTodayProvider);
    _ref.invalidate(attendanceStreamProvider);
  }

  Future<void> checkOut() async {
    await _repo.checkOut();
    _ref.invalidate(attendanceTodayProvider);
    _ref.invalidate(attendanceStreamProvider);
  }

  Future<void> resolveStale({
    required String staleAttendanceId,
    DateTime? staleCheckoutTime,
    bool autoCheckInToday = true,
  }) async {
    await _repo.resolveStaleAttendance(
      staleAttendanceId: staleAttendanceId,
      staleCheckoutTime: staleCheckoutTime,
      autoCheckInToday: autoCheckInToday,
    );
    _ref.invalidate(attendanceTodayProvider);
    _ref.invalidate(attendanceStreamProvider);
  }
}

final attendanceActionsProvider = Provider(
  (ref) => AttendanceActions(ref.read(attendanceRepositoryProvider), ref),
);

/// Derived view: today's open row (if any). Used by the attendance screen
/// and home dashboard status card. The source of truth is the `/today`
/// endpoint, not history, because history can contain stale open rows.
final openSessionProvider = Provider<Attendance?>((ref) {
  return ref.watch(attendanceTodayProvider).valueOrNull;
});

final shiftConfigProvider = FutureProvider.autoDispose<ShiftConfig>((ref) async {
  final repo = ref.watch(attendanceRepositoryProvider);
  return repo.getShiftConfig();
});

final currentShiftConfigProvider = Provider<ShiftConfig>((ref) {
  final asyncConfig = ref.watch(shiftConfigProvider);
  return asyncConfig.valueOrNull ?? AttendanceRepository.cachedShiftConfig ?? ShiftConfig.forDate(DateTime.now());
});

/// Quản lý tháng đang xem bảng công (Mặc định: ngày 1 của tháng hiện tại)
final selectedAttendanceMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, 1);
});

/// Tổng số phút chấm công hôm nay (bao gồm các ca đã check-out và ca đang mở).
final todayAttendanceMinutesProvider = Provider<int>((ref) {
  final attendances = ref.watch(attendanceStreamProvider).valueOrNull ?? const <Attendance>[];
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final config = ref.watch(currentShiftConfigProvider);

  var totalMins = 0;
  for (final a in attendances) {
    final inTime = (a.checkinTime ?? a.createdAt).toLocal();
    final inDate = DateTime(inTime.year, inTime.month, inTime.day);
    if (inDate == today && a.checkoutTime != null) {
      final outTime = a.checkoutTime!.toLocal();
      final lunchStart = DateTime(inTime.year, inTime.month, inTime.day, config.lunchStartHour, config.lunchStartMinute);
      final lunchEnd = DateTime(inTime.year, inTime.month, inTime.day, config.lunchEndHour, config.lunchEndMinute);

      final start = (!config.allowEarlyCheckinWorkHours && inTime.isBefore(DateTime(inTime.year, inTime.month, inTime.day, config.shiftStartHour, config.shiftStartMinute)))
          ? DateTime(inTime.year, inTime.month, inTime.day, config.shiftStartHour, config.shiftStartMinute)
          : inTime;
      final end = outTime;
      if (end.isAfter(start)) {
        final rawMins = end.difference(start).inMinutes;
        final overlapStart = start.isAfter(lunchStart) ? start : lunchStart;
        final overlapEnd = end.isBefore(lunchEnd) ? end : lunchEnd;
        var lunchMins = 0;
        if (overlapEnd.isAfter(overlapStart)) {
          lunchMins = overlapEnd.difference(overlapStart).inMinutes;
        }
        totalMins += (rawMins - lunchMins).clamp(0, 1440);
      }
    }
  }
  return totalMins;
});

/// Tính toán bảng thống kê ngày công HR cho tháng đang chọn
final hrAttendanceMonthSummaryProvider = Provider<HrAttendanceMonthSummary>((ref) {
  final targetMonth = ref.watch(selectedAttendanceMonthProvider);
  final attendances = ref.watch(attendanceStreamProvider).valueOrNull ?? const <Attendance>[];

  final y = targetMonth.year;
  final m = targetMonth.month;
  final daysInMonth = DateTime(y, m + 1, 0).day;

  // Tính số ngày công chuẩn trong tháng (loại trừ Chủ Nhật)
  double targetWorkdays = 0.0;
  for (int day = 1; day <= daysInMonth; day++) {
    final d = DateTime(y, m, day);
    if (d.weekday != DateTime.sunday) {
      targetWorkdays += 1.0;
    }
  }

  // Nhóm các lượt chấm công theo ngày trong tháng
  final monthAttendancesByDay = <int, List<Attendance>>{};
  for (final a in attendances) {
    final t = (a.checkinTime ?? a.createdAt).toLocal();
    if (t.year == y && t.month == m) {
      monthAttendancesByDay.putIfAbsent(t.day, () => <Attendance>[]).add(a);
    }
  }

  double actualWorkdays = 0.0;
  int lateCount = 0;
  int lateMinutesTotal = 0;
  int earlyLeaveCount = 0;
  int earlyMinutesTotal = 0;
  int overtimeMinutesTotal = 0;
  int totalWorkedMinutes = 0;

  final lateDetails = <HrAttendanceEventDetail>[];
  final earlyDetails = <HrAttendanceEventDetail>[];
  final overtimeDetails = <HrAttendanceEventDetail>[];

  final sortedDays = monthAttendancesByDay.keys.toList()..sort();
  for (final day in sortedDays) {
    final dayAttendances = monthAttendancesByDay[day]!;
    final firstIn = dayAttendances.where((a) => a.checkinTime != null).toList()
      ..sort((a, b) => a.checkinTime!.compareTo(b.checkinTime!));
    if (firstIn.isEmpty) continue;

    final earliest = firstIn.first;
    final latest = dayAttendances.where((a) => a.checkoutTime != null).toList()
      ..sort((a, b) => b.checkoutTime!.compareTo(a.checkoutTime!));

    final inTime = earliest.checkinTime!.toLocal();
    final outTime = latest.isNotEmpty ? latest.first.checkoutTime!.toLocal() : null;

    final cfg = ShiftConfig.forDate(inTime);
    final shiftStart = DateTime(inTime.year, inTime.month, inTime.day, cfg.shiftStartHour, cfg.shiftStartMinute);
    final shiftEnd = DateTime(inTime.year, inTime.month, inTime.day, cfg.shiftEndHour, cfg.shiftEndMinute);

    final shiftStartFormatted = '${cfg.shiftStartHour.toString().padLeft(2, '0')}:${cfg.shiftStartMinute.toString().padLeft(2, '0')}';
    final shiftEndFormatted = '${cfg.shiftEndHour.toString().padLeft(2, '0')}:${cfg.shiftEndMinute.toString().padLeft(2, '0')}';
    final inTimeFormatted = '${inTime.hour.toString().padLeft(2, '0')}:${inTime.minute.toString().padLeft(2, '0')}';
    final outTimeFormatted = outTime != null ? '${outTime.hour.toString().padLeft(2, '0')}:${outTime.minute.toString().padLeft(2, '0')}' : '--:--';

    // Đi muộn (vượt quá 5 phút dung sai)
    if (inTime.isAfter(shiftStart.add(const Duration(minutes: 5)))) {
      final diff = inTime.difference(shiftStart).inMinutes;
      lateCount++;
      lateMinutesTotal += diff;
      lateDetails.add(HrAttendanceEventDetail(
        date: inTime,
        dayName: cfg.dayName,
        scheduledTime: shiftStartFormatted,
        actualTime: inTimeFormatted,
        diffMinutes: diff,
        type: 'late',
        note: 'Ca vào $shiftStartFormatted · Chấm lúc $inTimeFormatted',
      ));
    }

    // Về sớm (ra trước 5 phút)
    if (outTime != null && outTime.isBefore(shiftEnd.subtract(const Duration(minutes: 5)))) {
      final diff = shiftEnd.difference(outTime).inMinutes;
      earlyLeaveCount++;
      earlyMinutesTotal += diff;
      earlyDetails.add(HrAttendanceEventDetail(
        date: outTime,
        dayName: cfg.dayName,
        scheduledTime: shiftEndFormatted,
        actualTime: outTimeFormatted,
        diffMinutes: diff,
        type: 'early',
        note: 'Ca tan $shiftEndFormatted · Ra lúc $outTimeFormatted',
      ));
    }

    // Tính tổng phút làm trong ngày
    var dayWorkedMins = 0;
    var dayOvertimeMins = 0;
    for (final a in dayAttendances) {
      if (a.checkinTime != null) {
        final calc = ShiftCalculator.calculate(
          checkinTime: a.checkinTime,
          now: a.checkoutTime,
          config: cfg,
        );
        dayWorkedMins += calc.workedMinutes;
        dayOvertimeMins += calc.overtimeMinutes;
      }
    }
    totalWorkedMinutes += dayWorkedMins;
    overtimeMinutesTotal += dayOvertimeMins;

    if (dayOvertimeMins > 0) {
      overtimeDetails.add(HrAttendanceEventDetail(
        date: inTime,
        dayName: cfg.dayName,
        scheduledTime: shiftEndFormatted,
        actualTime: outTimeFormatted,
        diffMinutes: dayOvertimeMins,
        type: 'overtime',
        note: 'Làm thêm ${(dayOvertimeMins ~/ 60)}h ${(dayOvertimeMins % 60)}p ngoài giờ quy định',
      ));
    }

    // Quy đổi số công của ngày
    if (dayWorkedMins >= (cfg.targetWorkMinutes - 15)) {
      actualWorkdays += 1.0;
    } else if (dayWorkedMins >= 180) {
      actualWorkdays += 0.5;
    } else if (dayWorkedMins > 0) {
      actualWorkdays += (dayWorkedMins / cfg.targetWorkMinutes).clamp(0.1, 0.4);
    }
  }

  return HrAttendanceMonthSummary(
    targetWorkdays: targetWorkdays,
    actualWorkdays: (actualWorkdays * 10).round() / 10.0,
    lateCount: lateCount,
    lateMinutesTotal: lateMinutesTotal,
    earlyLeaveCount: earlyLeaveCount,
    earlyMinutesTotal: earlyMinutesTotal,
    overtimeMinutesTotal: overtimeMinutesTotal,
    totalWorkedMinutes: totalWorkedMinutes,
    lateDetails: lateDetails,
    earlyDetails: earlyDetails,
    overtimeDetails: overtimeDetails,
  );
});

/// Map trạng thái chấm công theo từng ngày trong tháng để vẽ chấm màu trên Calendar
final dayAttendanceStatusMapProvider = Provider<Map<int, HrDayAttendanceStatus>>((ref) {
  final targetMonth = ref.watch(selectedAttendanceMonthProvider);
  final attendances = ref.watch(attendanceStreamProvider).valueOrNull ?? const <Attendance>[];
  final now = DateTime.now();

  final y = targetMonth.year;
  final m = targetMonth.month;
  final daysInMonth = DateTime(y, m + 1, 0).day;

  final monthAttendancesByDay = <int, List<Attendance>>{};
  for (final a in attendances) {
    final t = (a.checkinTime ?? a.createdAt).toLocal();
    if (t.year == y && t.month == m) {
      monthAttendancesByDay.putIfAbsent(t.day, () => <Attendance>[]).add(a);
    }
  }

  final statusMap = <int, HrDayAttendanceStatus>{};
  for (int day = 1; day <= daysInMonth; day++) {
    final d = DateTime(y, m, day);
    if (d.isAfter(now)) {
      statusMap[day] = HrDayAttendanceStatus.future;
      continue;
    }
    if (d.weekday == DateTime.sunday) {
      statusMap[day] = HrDayAttendanceStatus.weekend;
      continue;
    }

    final dayList = monthAttendancesByDay[day];
    if (dayList == null || dayList.isEmpty) {
      statusMap[day] = HrDayAttendanceStatus.staleOrMissing;
      continue;
    }

    var dayWorkedMins = 0;
    bool hasLateOrEarly = false;
    final cfg = ShiftConfig.forDate(d);
    final shiftStart = DateTime(d.year, d.month, d.day, cfg.shiftStartHour, cfg.shiftStartMinute);
    final shiftEnd = DateTime(d.year, d.month, d.day, cfg.shiftEndHour, cfg.shiftEndMinute);

    for (final a in dayList) {
      if (a.checkinTime != null) {
        final localIn = a.checkinTime!.toLocal();
        final localOut = a.checkoutTime?.toLocal();
        if (localIn.isAfter(shiftStart.add(const Duration(minutes: 5)))) {
          hasLateOrEarly = true;
        }
        if (localOut != null && localOut.isBefore(shiftEnd.subtract(const Duration(minutes: 5)))) {
          hasLateOrEarly = true;
        }
        final calc = ShiftCalculator.calculate(
          checkinTime: localIn,
          now: localOut,
          config: cfg,
        );
        dayWorkedMins += calc.workedMinutes;
      }
    }

    if (dayWorkedMins >= (cfg.targetWorkMinutes - 15)) {
      statusMap[day] = hasLateOrEarly ? HrDayAttendanceStatus.lateOrEarly : HrDayAttendanceStatus.fullWorkday;
    } else if (dayWorkedMins >= 180) {
      statusMap[day] = HrDayAttendanceStatus.halfWorkday;
    } else {
      statusMap[day] = HrDayAttendanceStatus.staleOrMissing;
    }
  }

  return statusMap;
});

