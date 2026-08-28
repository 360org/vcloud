/// Row from `public.attendance`.
///
/// `checkinTime` is set when the user checks in, `checkoutTime` is set
/// on the matching check-out. A row with a non-null `checkinTime` and
/// a null `checkoutTime` is the user's currently-open session.
class Attendance {
  const Attendance({
    required this.id,
    required this.userId,
    this.checkinTime,
    this.checkoutTime,
    this.checkinLat,
    this.checkinLng,
    this.checkoutLat,
    this.checkoutLng,
    required this.createdAt,
    this.isStaleOpen = false,
    this.staleAttendanceId,
    this.staleCheckInDate,
    this.suggestedCheckoutTime,
  });

  final String id;
  final String userId;
  final DateTime? checkinTime;
  final DateTime? checkoutTime;
  final double? checkinLat;
  final double? checkinLng;
  // The schema uses latitude/longitude for the latest sample (typically
  // populated on check-out). We expose them under checkout* aliases.
  final double? checkoutLat;
  final double? checkoutLng;
  final DateTime createdAt;

  final bool isStaleOpen;
  final String? staleAttendanceId;
  final String? staleCheckInDate;
  final DateTime? suggestedCheckoutTime;

  bool get isOpen => checkinTime != null && checkoutTime == null;

  Duration? get elapsed {
    final start = checkinTime;
    if (start == null) return null;
    final end = checkoutTime ?? DateTime.now();
    return end.difference(start);
  }

  factory Attendance.fromMap(Map<String, dynamic> map) => Attendance(
    id: (map['id'] ?? map['attendance_id'] ?? map['stale_attendance_id'] ?? '').toString(),
    userId: (map['user_id'] ?? map['employee_id'] ?? '').toString(),
    checkinTime: _readDate(map['checkin_time'] ?? map['check_in'] ?? map['stale_check_in']),
    checkoutTime: _readDate(map['checkout_time'] ?? map['check_out']),
    checkinLat: _readDouble(map['checkin_lat']),
    checkinLng: _readDouble(map['checkin_lng']),
    checkoutLat: _readDouble(map['latitude']),
    checkoutLng: _readDouble(map['longitude']),
    createdAt: _readDate(map['created_at'] ?? map['create_date'] ?? map['stale_check_in']) ?? DateTime.now(),
    isStaleOpen: map['is_stale_open'] == true || map['is_stale_open']?.toString() == 'true',
    staleAttendanceId: (map['stale_attendance_id'] ?? map['id'])?.toString(),
    staleCheckInDate: map['stale_check_in_date']?.toString(),
    suggestedCheckoutTime: _readDate(map['suggested_checkout_time']),
  );
}

enum HrDayAttendanceStatus {
  fullWorkday,
  halfWorkday,
  lateOrEarly,
  holidayOrLeave,
  staleOrMissing,
  weekend,
  future,
}

/// Chi tiết sự kiện chấm công (Đi muộn, Về sớm, Tăng ca OT) để đối chiếu minh bạch
class HrAttendanceEventDetail {
  const HrAttendanceEventDetail({
    required this.date,
    required this.dayName,
    required this.scheduledTime,
    required this.actualTime,
    required this.diffMinutes,
    required this.type,
    this.note,
  });

  final DateTime date;
  final String dayName;
  final String scheduledTime;
  final String actualTime;
  final int diffMinutes;
  final String type; // 'late' | 'early' | 'overtime'
  final String? note;
}

/// Thống kê bảng công HR theo tháng
class HrAttendanceMonthSummary {
  const HrAttendanceMonthSummary({
    required this.targetWorkdays,
    required this.actualWorkdays,
    required this.lateCount,
    required this.lateMinutesTotal,
    required this.earlyLeaveCount,
    required this.earlyMinutesTotal,
    required this.overtimeMinutesTotal,
    required this.totalWorkedMinutes,
    this.lateDetails = const <HrAttendanceEventDetail>[],
    this.earlyDetails = const <HrAttendanceEventDetail>[],
    this.overtimeDetails = const <HrAttendanceEventDetail>[],
  });

  final double targetWorkdays;
  final double actualWorkdays;
  final int lateCount;
  final int lateMinutesTotal;
  final int earlyLeaveCount;
  final int earlyMinutesTotal;
  final int overtimeMinutesTotal;
  final int totalWorkedMinutes;
  final List<HrAttendanceEventDetail> lateDetails;
  final List<HrAttendanceEventDetail> earlyDetails;
  final List<HrAttendanceEventDetail> overtimeDetails;

  factory HrAttendanceMonthSummary.empty() => const HrAttendanceMonthSummary(
    targetWorkdays: 0.0,
    actualWorkdays: 0.0,
    lateCount: 0,
    lateMinutesTotal: 0,
    earlyLeaveCount: 0,
    earlyMinutesTotal: 0,
    overtimeMinutesTotal: 0,
    totalWorkedMinutes: 0,
    lateDetails: <HrAttendanceEventDetail>[],
    earlyDetails: <HrAttendanceEventDetail>[],
    overtimeDetails: <HrAttendanceEventDetail>[],
  );
}

double? _readDouble(Object? v) {
  if (v == null || v == false) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

DateTime? _readDate(Object? v) {
  if (v == null || v == false) return null;
  final str = v.toString().trim();
  if (str.isEmpty) return null;
  try {
    if (str.endsWith('Z') || str.contains('+')) {
      return DateTime.parse(str).toLocal();
    }
    final isoStr = str.contains('T') ? str : str.replaceAll(' ', 'T');
    return DateTime.parse('${isoStr}Z').toLocal();
  } catch (_) {
    return DateTime.tryParse(str)?.toLocal();
  }
}

