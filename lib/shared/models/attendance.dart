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
    id: map['id'] as String,
    userId: map['user_id'] as String,
    checkinTime: _readDate(map['checkin_time']),
    checkoutTime: _readDate(map['checkout_time']),
    checkinLat: (map['checkin_lat'] as num?)?.toDouble(),
    checkinLng: (map['checkin_lng'] as num?)?.toDouble(),
    checkoutLat: (map['latitude'] as num?)?.toDouble(),
    checkoutLng: (map['longitude'] as num?)?.toDouble(),
    createdAt: DateTime.parse(map['created_at'] as String),
  );
}

DateTime? _readDate(Object? v) {
  if (v == null) return null;
  return DateTime.parse(v as String);
}
