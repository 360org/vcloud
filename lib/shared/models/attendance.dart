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

  bool get isOpen => checkinTime != null && checkoutTime == null;

  Duration? get elapsed {
    final start = checkinTime;
    if (start == null) return null;
    final end = checkoutTime ?? DateTime.now();
    return end.difference(start);
  }

  factory Attendance.fromMap(Map<String, dynamic> map) => Attendance(
    id: (map['id'] ?? map['attendance_id'] ?? '').toString(),
    userId: (map['user_id'] ?? map['employee_id'] ?? '').toString(),
    checkinTime: _readDate(map['checkin_time'] ?? map['check_in']),
    checkoutTime: _readDate(map['checkout_time'] ?? map['check_out']),
    checkinLat: _readDouble(map['checkin_lat']),
    checkinLng: _readDouble(map['checkin_lng']),
    checkoutLat: _readDouble(map['latitude']),
    checkoutLng: _readDouble(map['longitude']),
    createdAt: _readDate(map['created_at'] ?? map['create_date']) ?? DateTime.now(),
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
