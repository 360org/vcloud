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
    this.morningTargetMinutes = 240, // 4 hours
    this.afternoonTargetMinutes = 240, // 4 hours
    this.targetWorkMinutes = 480, // 8 hours
    this.allowEarlyCheckinWorkHours = false,
    this.dayName = 'Ngày làm việc',
  });

  final int shiftStartHour;
  final int shiftStartMinute;
  final int shiftEndHour;
  final int shiftEndMinute;
  final int lunchStartHour;
  final int lunchStartMinute;
  final int lunchEndHour;
  final int lunchEndMinute;
  final int morningTargetMinutes;
  final int afternoonTargetMinutes;
  final int targetWorkMinutes;
  final bool allowEarlyCheckinWorkHours;
  final String dayName;

  /// Returns the standard shift configuration based on the day of the week:
  /// - Thứ Hai (T2): 07:30 - 17:00, lunch 12:00 - 13:00 (Sáng: 4h30, Chiều: 4h => 8h30 / 510m)
  /// - Thứ Bảy (T7): 08:00 - 16:30, lunch 12:00 - 13:00 (Sáng: 4h, Chiều: 3h30 => 7h30 / 450m)
  /// - Thứ Ba -> Thứ Sáu (T3-T6): 08:00 - 17:00, lunch 12:00 - 13:00 (Sáng: 4h, Chiều: 4h => 8h / 480m)
  /// - Chủ Nhật (CN): Ngày nghỉ
  static ShiftConfig forDate(DateTime date) {
    return forWeekday(date.weekday);
  }

  static ShiftConfig forWeekday(int weekday) {
    switch (weekday) {
      case DateTime.monday: // 1
        return const ShiftConfig(
          shiftStartHour: 7,
          shiftStartMinute: 30,
          shiftEndHour: 17,
          shiftEndMinute: 0,
          lunchStartHour: 12,
          lunchStartMinute: 0,
          lunchEndHour: 13,
          lunchEndMinute: 0,
          morningTargetMinutes: 270, // 4h30
          afternoonTargetMinutes: 240, // 4h00
          targetWorkMinutes: 510, // 8h30
          dayName: 'Thứ Hai',
        );
      case DateTime.saturday: // 6
        return const ShiftConfig(
          shiftStartHour: 8,
          shiftStartMinute: 0,
          shiftEndHour: 16,
          shiftEndMinute: 30,
          lunchStartHour: 12,
          lunchStartMinute: 0,
          lunchEndHour: 13,
          lunchEndMinute: 0,
          morningTargetMinutes: 240, // 4h00
          afternoonTargetMinutes: 210, // 3h30
          targetWorkMinutes: 450, // 7h30
          dayName: 'Thứ Bảy',
        );
      case DateTime.sunday: // 7
        return const ShiftConfig(
          shiftStartHour: 8,
          shiftStartMinute: 0,
          shiftEndHour: 17,
          shiftEndMinute: 0,
          lunchStartHour: 12,
          lunchStartMinute: 0,
          lunchEndHour: 13,
          lunchEndMinute: 0,
          morningTargetMinutes: 240,
          afternoonTargetMinutes: 240,
          targetWorkMinutes: 480,
          dayName: 'Chủ Nhật',
        );
      default: // Tuesday - Friday (2, 3, 4, 5)
        return const ShiftConfig(
          shiftStartHour: 8,
          shiftStartMinute: 0,
          shiftEndHour: 17,
          shiftEndMinute: 0,
          lunchStartHour: 12,
          lunchStartMinute: 0,
          lunchEndHour: 13,
          lunchEndMinute: 0,
          morningTargetMinutes: 240, // 4h00
          afternoonTargetMinutes: 240, // 4h00
          targetWorkMinutes: 480, // 8h00
          dayName: 'Thứ Ba - Thứ Sáu',
        );
    }
  }

  String get targetHoursFormatted {
    final h = targetWorkMinutes ~/ 60;
    final m = targetWorkMinutes % 60;
    if (m == 0) return '${h}h';
    return '${h}h${m.toString().padLeft(2, '0')}';
  }

  String get morningHoursFormatted {
    final h = morningTargetMinutes ~/ 60;
    final m = morningTargetMinutes % 60;
    if (m == 0) return '${h}h';
    return '${h}h${m.toString().padLeft(2, '0')}';
  }

  String get afternoonHoursFormatted {
    final h = afternoonTargetMinutes ~/ 60;
    final m = afternoonTargetMinutes % 60;
    if (m == 0) return '${h}h';
    return '${h}h${m.toString().padLeft(2, '0')}';
  }

  String get morningTimeRange {
    final sH = shiftStartHour.toString().padLeft(2, '0');
    final sM = shiftStartMinute.toString().padLeft(2, '0');
    final lH = lunchStartHour.toString().padLeft(2, '0');
    final lM = lunchStartMinute.toString().padLeft(2, '0');
    return '$sH:$sM - $lH:$lM';
  }

  String get lunchTimeRange {
    final lH = lunchStartHour.toString().padLeft(2, '0');
    final lM = lunchStartMinute.toString().padLeft(2, '0');
    final eH = lunchEndHour.toString().padLeft(2, '0');
    final eM = lunchEndMinute.toString().padLeft(2, '0');
    return '$lH:$lM - $eH:$eM';
  }

  String get afternoonTimeRange {
    final lH = lunchEndHour.toString().padLeft(2, '0');
    final lM = lunchEndMinute.toString().padLeft(2, '0');
    final eH = shiftEndHour.toString().padLeft(2, '0');
    final eM = shiftEndMinute.toString().padLeft(2, '0');
    return '$lH:$lM - $eH:$eM';
  }
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
    required this.config,
    this.morningWorkedMinutes = 0,
    this.morningTargetMinutes = 240,
    this.morningProgress = 0.0,
    this.afternoonWorkedMinutes = 0,
    this.afternoonTargetMinutes = 240,
    this.afternoonProgress = 0.0,
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
  final ShiftConfig config;

  final int morningWorkedMinutes;
  final int morningTargetMinutes;
  final double morningProgress;

  final int afternoonWorkedMinutes;
  final int afternoonTargetMinutes;
  final double afternoonProgress;

  bool get isCompleted => workedMinutes >= targetMinutes;
}

/// Core logic utility for calculating shift progress and worked hours.
class ShiftCalculator {
  const ShiftCalculator._();

  static ShiftProgressResult calculate({
    required DateTime? checkinTime,
    DateTime? now,
    ShiftConfig? config,
  }) {
    final effectiveDate = (checkinTime ?? now ?? DateTime.now()).toLocal();
    final effectiveConfig = config ?? ShiftConfig.forDate(effectiveDate);
    final targetMins = effectiveConfig.targetWorkMinutes;

    final today = DateTime.now();
    final isPastDate = checkinTime != null &&
        (effectiveDate.year < today.year ||
            (effectiveDate.year == today.year &&
                (effectiveDate.month < today.month ||
                    (effectiveDate.month == today.month && effectiveDate.day < today.day))));

    final shiftEnd = DateTime(
      effectiveDate.year,
      effectiveDate.month,
      effectiveDate.day,
      effectiveConfig.shiftEndHour,
      effectiveConfig.shiftEndMinute,
    );

    // If an attendance record from the past was not checked out (now == null),
    // cap the elapsed time to the end of that day's shift to avoid counting days of phantom work.
    DateTime currentTime;
    if (now != null) {
      currentTime = now;
    } else if (isPastDate) {
      currentTime = shiftEnd;
    } else {
      currentTime = DateTime.now();
    }

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
        config: effectiveConfig,
        morningWorkedMinutes: 0,
        morningTargetMinutes: effectiveConfig.morningTargetMinutes,
        morningProgress: 0.0,
        afternoonWorkedMinutes: 0,
        afternoonTargetMinutes: effectiveConfig.afternoonTargetMinutes,
        afternoonProgress: 0.0,
      );
    }

    final date = checkinTime.toLocal();
    final shiftStart = DateTime(
      date.year,
      date.month,
      date.day,
      effectiveConfig.shiftStartHour,
      effectiveConfig.shiftStartMinute,
    );
    final lunchStart = DateTime(
      date.year,
      date.month,
      date.day,
      effectiveConfig.lunchStartHour,
      effectiveConfig.lunchStartMinute,
    );
    final lunchEnd = DateTime(
      date.year,
      date.month,
      date.day,
      effectiveConfig.lunchEndHour,
      effectiveConfig.lunchEndMinute,
    );

    // 1. Calculate early arrival minutes
    var earlyMins = 0;
    if (checkinTime.isBefore(shiftStart)) {
      earlyMins = shiftStart.difference(checkinTime).inMinutes;
    }

    // 2. Determine effective start time for official work hours
    final effectiveStart = (!effectiveConfig.allowEarlyCheckinWorkHours && checkinTime.isBefore(shiftStart))
        ? shiftStart
        : checkinTime;

    // 3. Compute worked minutes up to currentTime (excluding lunch overlap)
    final workedMins = _calculateWorkedMinutes(
      start: effectiveStart,
      end: currentTime,
      lunchStart: lunchStart,
      lunchEnd: lunchEnd,
    );

    // 4. Calculate morning & afternoon segment breakdown
    var morningWorked = 0;
    final mStart = checkinTime.isBefore(shiftStart) ? shiftStart : checkinTime;
    final mEnd = currentTime.isBefore(lunchStart) ? currentTime : lunchStart;
    if (mEnd.isAfter(mStart)) {
      morningWorked = mEnd.difference(mStart).inMinutes.clamp(0, effectiveConfig.morningTargetMinutes);
    } else if (currentTime.isAfter(lunchStart)) {
      morningWorked = effectiveConfig.morningTargetMinutes;
    }

    var afternoonWorked = 0;
    if (currentTime.isAfter(lunchEnd)) {
      final aStart = lunchEnd;
      final aEnd = currentTime.isBefore(shiftEnd) ? currentTime : shiftEnd;
      if (aEnd.isAfter(aStart)) {
        afternoonWorked = aEnd.difference(aStart).inMinutes.clamp(0, effectiveConfig.afternoonTargetMinutes);
      } else if (currentTime.isAfter(shiftEnd)) {
        afternoonWorked = effectiveConfig.afternoonTargetMinutes;
      }
    }

    final morningProg = effectiveConfig.morningTargetMinutes > 0
        ? (morningWorked / effectiveConfig.morningTargetMinutes).clamp(0.0, 1.0)
        : 0.0;
    final afternoonProg = effectiveConfig.afternoonTargetMinutes > 0
        ? (afternoonWorked / effectiveConfig.afternoonTargetMinutes).clamp(0.0, 1.0)
        : 0.0;

    // 5. Calculate progress ratio
    final progress = targetMins > 0 ? (workedMins / targetMins).clamp(0.0, 1.0) : 0.0;
    final remainingMins = (targetMins - workedMins).clamp(0, targetMins);
    final overtimeMins = (workedMins > targetMins) ? (workedMins - targetMins) : 0;

    // 6. Estimated completion time
    final estCompletion = _calculateEstimatedCompletion(
      start: effectiveStart,
      lunchStart: lunchStart,
      lunchEnd: lunchEnd,
      targetWorkMinutes: targetMins,
    );

    // 7. Determine stage and human readable status text
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
    final targetFormatted = effectiveConfig.targetHoursFormatted;

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
        badgeLabel = 'Hoàn thành $targetFormatted 🎉';
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
      config: effectiveConfig,
      morningWorkedMinutes: morningWorked,
      morningTargetMinutes: effectiveConfig.morningTargetMinutes,
      morningProgress: morningProg,
      afternoonWorkedMinutes: afternoonWorked,
      afternoonTargetMinutes: effectiveConfig.afternoonTargetMinutes,
      afternoonProgress: afternoonProg,
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
