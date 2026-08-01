import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/models/attendance.dart';
import '../data/attendance_repository.dart';

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
