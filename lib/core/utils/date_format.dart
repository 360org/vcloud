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
}
