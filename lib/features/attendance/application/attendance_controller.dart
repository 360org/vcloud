import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/attendance.dart';
import '../data/attendance_repository.dart';
import '../domain/shift_calculator.dart';

final attendanceRepositoryProvider = Provider<AttendanceRepository>(
  (_) => AttendanceRepository(),
);

final attendanceStreamProvider = StreamProvider.autoDispose<List<Attendance>>(
  (ref) => ref.read(attendanceRepositoryProvider).watchRecent(),
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
