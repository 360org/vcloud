import 'package:intl/intl.dart';

/// Centralized date/time formatting so every timestamp in the app
/// reads identically. Add helpers here when a new format is needed
/// in 2+ places — keeping presentation out of feature code.
class Dates {
  Dates._();

  // Static formatters are cheap to allocate but cheaper to reuse.
  static final _time = DateFormat.jm(); // 9:08 AM
  static final _date = DateFormat.yMMMd(); // Jun 20, 2026
  static final _iso = DateFormat('yyyy-MM-dd'); // 2026-06-20
  static final _hm = DateFormat.Hm(); // 09:08

  static String time(DateTime dt) => _time.format(dt.toLocal());

  static String date(DateTime dt) => _date.format(dt.toLocal());

  static String dateVi(DateTime dt) {
    final local = dt.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    return '$day/$month/${local.year}';
  }

  /// Format SLA status into friendly Vietnamese label (e.g. "Trễ hạn 5 ngày", "Hạn hôm nay", "Còn 2 ngày").
  static String slaLabelVi(DateTime deadline, {DateTime? now}) {
    final n = now ?? DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    final targetLocal = deadline.toLocal();
    final targetDay = DateTime(targetLocal.year, targetLocal.month, targetLocal.day);

    if (targetDay.isBefore(today)) {
      final days = today.difference(targetDay).inDays;
      if (days <= 0) return 'Trễ hạn hôm nay';
      return 'Trễ hạn $days ngày';
    } else {
      final days = targetDay.difference(today).inDays;
      if (days == 0) return 'Hạn hôm nay';
      if (days == 1) return 'Hạn ngày mai';
      if (days < 7) return 'Còn $days ngày';
      return 'Hạn ${dateVi(deadline)}';
    }
  }

  static String isoDate(DateTime dt) => _iso.format(dt.toLocal());

  static String hm(DateTime dt) => _hm.format(dt.toLocal());

  /// "now" → "9:08 AM"; "yesterday" → "Yesterday"; "3 days ago" → "3d".
  static String chatListLabel(DateTime dt, {DateTime? now}) {
    final n = now ?? DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    final local = dt.toLocal();
    final d = DateTime(local.year, local.month, local.day);
    final diff = today.difference(d).inDays;
    if (diff == 0) return time(local);
    if (diff == 1) return 'Yesterday';
    if (diff < 7) return '${diff}d';
    return isoDate(dt);
  }

  static String chatListLabelVi(DateTime dt, {DateTime? now}) {
    final n = now ?? DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    final local = dt.toLocal();
    final day = DateTime(local.year, local.month, local.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return hm(local);
    if (diff == 1) return 'Hôm qua';
    if (diff < 7) return '$diff ngày';
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}';
  }

  static String relativeShort(DateTime dt, {DateTime? now}) {
    final n = now ?? DateTime.now();
    final diff = n.difference(dt.toLocal());
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return isoDate(dt);
  }

  /// 1h 30m / 45m — used for today totals on the home dashboard.
  static String humanDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0 && m > 0) return '${h}h ${m}m';
    if (h > 0) return '${h}h';
    return '${m}m';
  }

  /// Form like "01:23:45" for an always-positive duration.
  static String hms(Duration d) {
    final h = d.inHours.abs().toString().padLeft(2, '0');
    final m = d.inMinutes.abs().remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.abs().remainder(60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  /// Chuẩn hóa và parse DateTime từ Odoo Server hoặc Local Cache
  static DateTime? parseOdooUtc(dynamic value) {
    if (value == null || value == false) return null;
    if (value is DateTime) return value.isUtc ? value.toLocal() : value;
    final text = value.toString().trim();
    if (text.isEmpty) return null;

    final parsed = DateTime.tryParse(text);
    if (parsed == null) return null;

    // Nếu chuỗi đã có chỉ định múi giờ (Z hoặc +07:00 / -05:00)
    final hasTz = RegExp(r'(z|[+-]\d\d:?\d\d)$', caseSensitive: false).hasMatch(text);
    if (hasTz || parsed.isUtc) {
      return parsed.toLocal();
    }

    // Nếu không có múi giờ, đối với Odoo Server chuỗi YYYY-MM-DD HH:mm:ss là UTC
    // Nhưng nếu chuỗi có chữ 'T' (dạng ISO từ DateTime.toIso8601String() của Flutter), đó là Local Time
    if (text.contains('T')) {
      return parsed;
    }

    final utcDt = DateTime.utc(
      parsed.year,
      parsed.month,
      parsed.day,
      parsed.hour,
      parsed.minute,
      parsed.second,
      parsed.millisecond,
      parsed.microsecond,
    );
    return utcDt.toLocal();
  }

  /// Format chuẩn ngày/giờ hiển thị cho Chat List:
  /// - Hôm nay: "15:21" (HH:mm)
  /// - Hôm qua: "Hôm qua"
  /// - Trong tuần: "Th 4", "Th 5"...
  /// - Xa hơn: "14/08" (dd/MM)
  static String chatTimestamp(DateTime dt, {DateTime? now}) {
    final n = now ?? DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    final local = dt.toLocal();
    final date = DateTime(local.year, local.month, local.day);

    if (date == today) {
      return DateFormat('HH:mm').format(local);
    } else if (date == today.subtract(const Duration(days: 1))) {
      return 'Hôm qua';
    } else if (n.difference(local).inDays < 7) {
      return DateFormat('E', 'vi').format(local);
    } else {
      return DateFormat('dd/MM').format(local);
    }
  }
}
