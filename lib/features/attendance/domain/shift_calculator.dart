import 'package:flutter/foundation.dart';

/// Configuration for standard work shifts.
@immutable
class ShiftConfig {
  const ShiftConfig({
    this.shiftStartHour = 8,
    this.shiftStartMinute = 0,
    this.shiftEndHour = 17,
    this.shiftEndMinute = 0,
    this.lunchStartHour = 12,
    this.lunchStartMinute = 0,
    this.lunchEndHour = 13,
    this.lunchEndMinute = 0,
    this.targetWorkMinutes = 480, // 8 hours
    this.allowEarlyCheckinWorkHours = false,
  });

  final int shiftStartHour;
  final int shiftStartMinute;
  final int shiftEndHour;
  final int shiftEndMinute;
  final int lunchStartHour;
  final int lunchStartMinute;
  final int lunchEndHour;
  final int lunchEndMinute;
  final int targetWorkMinutes;

  /// If false, work hours start counting at shiftStart (08:00) even if check-in was early (e.g. 07:49).
  final bool allowEarlyCheckinWorkHours;
}

/// Stage of the current work shift.
enum ShiftStage {
  notCheckedIn,
  earlyCheckin,
  morningShift,
  lunchBreak,
  afternoonShift,
  completed,
  overtime,
}

/// Result of shift calculation.
@immutable
class ShiftProgressResult {
  const ShiftProgressResult({
    required this.stage,
    required this.workedMinutes,
    required this.targetMinutes,
    required this.remainingMinutes,
    required this.earlyMinutes,
    required this.overtimeMinutes,
    required this.progress,
    required this.statusText,
    required this.badgeLabel,
    required this.estimatedCompletionTime,
  });

  final ShiftStage stage;
  final int workedMinutes;
  final int targetMinutes;
  final int remainingMinutes;
  final int earlyMinutes;
  final int overtimeMinutes;
  final double progress; // 0.0 to 1.0
  final String statusText;
  final String badgeLabel;
  final DateTime? estimatedCompletionTime;

  bool get isCompleted => workedMinutes >= targetMinutes;
}

/// Core logic utility for calculating shift progress and worked hours.
class ShiftCalculator {
  const ShiftCalculator._();

  static ShiftProgressResult calculate({
    required DateTime? checkinTime,
    DateTime? now,
    ShiftConfig config = const ShiftConfig(),
  }) {
    final currentTime = now ?? DateTime.now();
    final targetMins = config.targetWorkMinutes;

    if (checkinTime == null) {
      return ShiftProgressResult(
        stage: ShiftStage.notCheckedIn,
        workedMinutes: 0,
        targetMinutes: targetMins,
        remainingMinutes: targetMins,
        earlyMinutes: 0,
        overtimeMinutes: 0,
        progress: 0.0,
        statusText: 'Chưa vào ca làm việc',
        badgeLabel: 'Chưa vào ca',
        estimatedCompletionTime: null,
      );
    }

    final date = checkinTime.toLocal();
    final shiftStart = DateTime(
      date.year,
      date.month,
      date.day,
      config.shiftStartHour,
      config.shiftStartMinute,
    );
    final lunchStart = DateTime(
      date.year,
      date.month,
      date.day,
      config.lunchStartHour,
      config.lunchStartMinute,
    );
    final lunchEnd = DateTime(
      date.year,
      date.month,
      date.day,
      config.lunchEndHour,
      config.lunchEndMinute,
    );
    final shiftEnd = DateTime(
      date.year,
      date.month,
      date.day,
      config.shiftEndHour,
      config.shiftEndMinute,
    );

    // 1. Calculate early arrival minutes
    var earlyMins = 0;
    if (checkinTime.isBefore(shiftStart)) {
      earlyMins = shiftStart.difference(checkinTime).inMinutes;
    }

    // 2. Determine effective start time for official work hours
    final effectiveStart = (!config.allowEarlyCheckinWorkHours && checkinTime.isBefore(shiftStart))
        ? shiftStart
        : checkinTime;

    // 3. Compute worked minutes up to currentTime (excluding lunch overlap)
    final workedMins = _calculateWorkedMinutes(
      start: effectiveStart,
      end: currentTime,
      lunchStart: lunchStart,
      lunchEnd: lunchEnd,
    );

    // 4. Calculate progress ratio
    final progress = (workedMins / targetMins).clamp(0.0, 1.0);
    final remainingMins = (targetMins - workedMins).clamp(0, targetMins);
    final overtimeMins = (workedMins > targetMins) ? (workedMins - targetMins) : 0;

    // 5. Estimated completion time
    final estCompletion = _calculateEstimatedCompletion(
      start: effectiveStart,
      lunchStart: lunchStart,
      lunchEnd: lunchEnd,
      targetWorkMinutes: targetMins,
    );

    // 6. Determine stage and human readable status text
    final stage = _determineStage(
      checkinTime: checkinTime,
      currentTime: currentTime,
      shiftStart: shiftStart,
      lunchStart: lunchStart,
      lunchEnd: lunchEnd,
      shiftEnd: shiftEnd,
      workedMinutes: workedMins,
      targetMinutes: targetMins,
    );

    final workedFormatted = _formatDurationVi(workedMins);
    final remainingFormatted = _formatDurationVi(remainingMins);
    final overtimeFormatted = _formatDurationVi(overtimeMins);

    String statusText;
    String badgeLabel;

    switch (stage) {
      case ShiftStage.notCheckedIn:
        badgeLabel = 'Chưa vào ca';
        statusText = 'Chưa vào ca làm việc';
        break;
      case ShiftStage.earlyCheckin:
        badgeLabel = 'Vào ca sớm ${earlyMins}m';
        statusText = 'Đến sớm $earlyMins phút • Ca làm bắt đầu lúc ${_formatTime(shiftStart)}';
        break;
      case ShiftStage.morningShift:
        badgeLabel = 'Đang ca sáng';
        statusText = 'Đang ca sáng • Đã làm $workedFormatted';
        break;
      case ShiftStage.lunchBreak:
        badgeLabel = 'Nghỉ trưa 🍱';
        statusText = 'Đang trong giờ nghỉ trưa (${_formatTime(lunchStart)} - ${_formatTime(lunchEnd)}) • Đã làm $workedFormatted';
        break;
      case ShiftStage.afternoonShift:
        badgeLabel = 'Đang ca chiều';
        statusText = 'Đang ca chiều • Đã làm $workedFormatted (Còn $remainingFormatted)';
        break;
      case ShiftStage.completed:
        badgeLabel = 'Hoàn thành 8h 🎉';
        statusText = '🎉 Chúc mừng! Đã hoàn thành $workedFormatted làm việc xuất sắc!';
        break;
      case ShiftStage.overtime:
        badgeLabel = 'Tăng ca OT';
        statusText = 'Đang tăng ca (OT): +$overtimeFormatted';
        break;
    }

    return ShiftProgressResult(
      stage: stage,
      workedMinutes: workedMins,
      targetMinutes: targetMins,
      remainingMinutes: remainingMins,
      earlyMinutes: earlyMins,
      overtimeMinutes: overtimeMins,
      progress: progress,
      statusText: statusText,
      badgeLabel: badgeLabel,
      estimatedCompletionTime: estCompletion,
    );
  }

  static int _calculateWorkedMinutes({
    required DateTime start,
    required DateTime end,
    required DateTime lunchStart,
    required DateTime lunchEnd,
  }) {
    if (end.isBefore(start)) return 0;

    final rawMinutes = end.difference(start).inMinutes;

    // Calculate overlap with lunch interval [lunchStart, lunchEnd]
    final overlapStart = start.isAfter(lunchStart) ? start : lunchStart;
    final overlapEnd = end.isBefore(lunchEnd) ? end : lunchEnd;

    var lunchMinutes = 0;
    if (overlapEnd.isAfter(overlapStart)) {
      lunchMinutes = overlapEnd.difference(overlapStart).inMinutes;
    }

    return (rawMinutes - lunchMinutes).clamp(0, 1440);
  }

  static DateTime _calculateEstimatedCompletion({
    required DateTime start,
    required DateTime lunchStart,
    required DateTime lunchEnd,
    required int targetWorkMinutes,
  }) {
    final lunchDurationMins = lunchEnd.difference(lunchStart).inMinutes;
    final endWithoutLunch = start.add(Duration(minutes: targetWorkMinutes));

    // If target range spans across lunch start, add lunch break duration
    if (start.isBefore(lunchStart) && endWithoutLunch.isAfter(lunchStart)) {
      return endWithoutLunch.add(Duration(minutes: lunchDurationMins));
    }
    return endWithoutLunch;
  }

  static ShiftStage _determineStage({
    required DateTime checkinTime,
    required DateTime currentTime,
    required DateTime shiftStart,
    required DateTime lunchStart,
    required DateTime lunchEnd,
    required DateTime shiftEnd,
    required int workedMinutes,
    required int targetMinutes,
  }) {
    if (currentTime.isBefore(shiftStart)) {
      return ShiftStage.earlyCheckin;
    }
    if (workedMinutes >= targetMinutes) {
      if (currentTime.isAfter(shiftEnd.add(const Duration(minutes: 15)))) {
        return ShiftStage.overtime;
      }
      return ShiftStage.completed;
    }
    if (currentTime.isAfter(lunchStart) && currentTime.isBefore(lunchEnd)) {
      return ShiftStage.lunchBreak;
    }
    if (currentTime.isBefore(lunchStart)) {
      return ShiftStage.morningShift;
    }
    return ShiftStage.afternoonShift;
  }

  static String _formatDurationVi(int minutes) {
    if (minutes <= 0) return '0h 0m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h == 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m}m';
  }

  static String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}
