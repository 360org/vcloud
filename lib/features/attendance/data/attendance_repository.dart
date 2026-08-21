import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../../../core/api/odoo_api_client.dart';
import '../../../core/error/failure.dart';
import '../../../core/notifications/realtime_constants.dart';
import '../../../shared/models/attendance.dart';
import '../domain/shift_calculator.dart';

class AttendanceRepository {
  AttendanceRepository({OdooApiClient? client})
    : _client = client ?? odooApiClient;

  final OdooApiClient _client;
  static ShiftConfig? cachedShiftConfig;

  Future<ShiftConfig> getShiftConfig({DateTime? date}) async {
    try {
      final query = date != null ? <String, Object?>{'date': date.toIso8601String().split('T').first} : <String, Object?>{};
      final res = await _client.get('/api/v1/mobile/attendance/config', query: query);
      if (res is Map) {
        final config = ShiftConfig.fromMap(Map<String, dynamic>.from(res));
        cachedShiftConfig = config;
        return config;
      }
    } catch (_) {}
    return cachedShiftConfig ?? ShiftConfig.forDate(date ?? DateTime.now());
  }

  Future<void> ensurePermission() async {
    final svc = await Geolocator.isLocationServiceEnabled();
    if (!svc) {
      throw Failure('Turn on Location services to check in.');
    }
    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied) {
      throw Failure('Location permission was denied.');
    }
    if (perm == LocationPermission.deniedForever) {
      throw Failure(
        'Location permission is permanently denied. Open Settings to allow.',
      );
    }
  }

  Future<Position> currentPosition() {
    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 10),
    );
  }

  Future<Attendance> checkIn() async {
    final current = await currentOpenAttendance();
    if (current != null) return current;

    await ensurePermission();
    final pos = await currentPosition();
    try {
      final res = await _client.post(
        '/api/v1/mobile/attendance/check-in',
        body: <String, dynamic>{
          'latitude': pos.latitude,
          'longitude': pos.longitude,
        },
      );
      return Attendance.fromMap(_attendanceFromCheckIn(res));
    } on Failure catch (e) {
      if (_isAlreadyCheckedIn(e.message)) {
        final refreshed = await currentOpenAttendance();
        if (refreshed != null) return refreshed;
      }
      rethrow;
    }
  }

  Future<Attendance?> currentOpenAttendance() async {
    final today = await _client.get('/api/v1/mobile/attendance/today');
    return _attendanceFromToday(today);
  }

  /// Emits the current open attendance immediately, then periodically while a
  /// consumer is visible. Foreground Odoo/FCM notifications trigger an
  /// immediate provider invalidation; polling keeps the state correct when a
  /// notification is delayed or the session is opened on another device.
  Stream<Attendance?> watchCurrentOpenAttendance({
    Duration pollInterval = RealtimeIntervals.attendance,
  }) {
    final controller = StreamController<Attendance?>();
    bool inFlight = false;
    Timer? timer;

    Future<void> refresh() async {
      if (inFlight || controller.isClosed) return;
      inFlight = true;
      try {
        final attendance = await currentOpenAttendance();
        if (!controller.isClosed) controller.add(attendance);
      } catch (e) {
        if (!controller.isClosed) controller.addError(e);
      } finally {
        inFlight = false;
      }
    }

    controller.onListen = () {
      refresh();
      void scheduleNextPoll() {
        if (controller.isClosed) return;
        timer?.cancel();
        timer = Timer(pollInterval, () async {
          if (!controller.isClosed) {
            await refresh();
            scheduleNextPoll();
          }
        });
      }
      scheduleNextPoll();
    };
    controller.onCancel = () {
      timer?.cancel();
      timer = null;
    };
    return controller.stream;
  }

  Future<Attendance> checkOut() async {
    final open = await currentOpenAttendance();
    if (open == null) {
      throw Failure('Bạn chưa có phiên check-in đang mở để check-out.');
    }
    await ensurePermission();
    final pos = await currentPosition();
    final res = await _client.post(
      '/api/v1/mobile/attendance/check-out/${open.id}',
      body: <String, dynamic>{
        'latitude': pos.latitude,
        'longitude': pos.longitude,
      },
    );
    return Attendance.fromMap(_attendanceFromCheckOut(res));
  }

  Stream<List<Attendance>> watchRecent({int limit = 500}) {
    final controller = StreamController<List<Attendance>>();

    Future<void> refresh() async {
      try {
        final res = await _client.get(
          '/api/v1/mobile/attendance/history',
          query: <String, Object?>{'limit': limit},
        );
        final list = (res as List)
            .cast<Map<String, dynamic>>()
            .map(_attendanceFromHistory)
            .map(Attendance.fromMap)
            .toList();
        if (!controller.isClosed) controller.add(list);
      } catch (e) {
        if (!controller.isClosed) {
          controller.addError(Failure('Reload failed: $e'));
        }
      }
    }

    controller.onListen = refresh;
    return controller.stream;
  }

  Map<String, dynamic> _attendanceFromCheckIn(dynamic raw) {
    final map = Map<String, dynamic>.from(raw as Map);
    return <String, dynamic>{
      'id': map['id'].toString(),
      'user_id': map['employee_id'].toString(),
      'checkin_time': map['check_in'],
      'checkout_time': null,
      'checkin_lat': null,
      'checkin_lng': null,
      'latitude': null,
      'longitude': null,
      'created_at': map['check_in'] ?? DateTime.now().toIso8601String(),
    };
  }

  Attendance? _attendanceFromToday(dynamic raw) {
    final map = Map<String, dynamic>.from(raw as Map);
    if (map['shift_config'] is Map) {
      try {
        cachedShiftConfig = ShiftConfig.fromMap(Map<String, dynamic>.from(map['shift_config'] as Map));
      } catch (_) {}
    }
    final attendanceState = map['attendance_state']?.toString().toLowerCase();
    final isCheckedIn =
        map['is_checked_in'] == true ||
        map['checked_in'] == true ||
        attendanceState == 'checked_in' ||
        attendanceState == 'checked-in';
    final attId = map['current_attendance_id'] ?? map['attendance_id'];
    final checkIn = map['check_in'] ?? map['last_check_in'];
    if (!isCheckedIn || attId == null || checkIn == null) return null;

    return Attendance.fromMap(<String, dynamic>{
      'id': attId.toString(),
      'user_id': map['employee_id']?.toString() ?? '',
      'checkin_time': checkIn,
      'checkout_time': null,
      'checkin_lat': null,
      'checkin_lng': null,
      'latitude': null,
      'longitude': null,
      'created_at': checkIn,
    });
  }

  Map<String, dynamic> _attendanceFromCheckOut(dynamic raw) {
    final map = Map<String, dynamic>.from(raw as Map);
    return <String, dynamic>{
      'id': map['id'].toString(),
      'user_id': '',
      'checkin_time': map['check_in'],
      'checkout_time': map['check_out'],
      'checkin_lat': null,
      'checkin_lng': null,
      'latitude': null,
      'longitude': null,
      'created_at': map['check_in'] ?? DateTime.now().toIso8601String(),
    };
  }

  Map<String, dynamic> _attendanceFromHistory(Map<String, dynamic> map) {
    return <String, dynamic>{
      'id': map['id'].toString(),
      'user_id': _many2OneId(map['employee_id']) ?? '',
      'checkin_time': map['check_in'],
      'checkout_time': map['check_out'],
      'checkin_lat': (map['in_latitude'] as num?)?.toDouble(),
      'checkin_lng': (map['in_longitude'] as num?)?.toDouble(),
      'latitude': (map['out_latitude'] as num?)?.toDouble(),
      'longitude': (map['out_longitude'] as num?)?.toDouble(),
      'created_at': map['check_in'] ?? DateTime.now().toIso8601String(),
    };
  }

  String? _many2OneId(Object? value) {
    if (value is List && value.isNotEmpty) return value.first.toString();
    if (value is int) return value.toString();
    return null;
  }

  bool _isAlreadyCheckedIn(String message) {
    final normalized = message.toLowerCase();
    return normalized.contains('already') &&
        (normalized.contains('check in') ||
            normalized.contains('check-in') ||
            normalized.contains('checked in'));
  }
}
