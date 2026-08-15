import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/features/attendance/domain/shift_calculator.dart';

void main() {
  group('ShiftCalculator Unit Tests', () {
    test('Tuesday-Friday (08:00 - 17:00, target 480m): Early checkin at 07:49, current time 16:03 should return 7h 03m worked (423m)', () {
      final checkin = DateTime(2026, 8, 13, 7, 49); // Thursday
      final now = DateTime(2026, 8, 13, 16, 3);

      final result = ShiftCalculator.calculate(
        checkinTime: checkin,
        now: now,
      );

      expect(result.earlyMinutes, equals(11));
      expect(result.workedMinutes, equals(423)); // 8:00 to 16:03 minus 60m lunch = 423m = 7h 03m
      expect(result.remainingMinutes, equals(57)); // 480 - 423 = 57m
      expect(result.isCompleted, isFalse);
      expect(result.stage, equals(ShiftStage.afternoonShift));
      expect(result.estimatedCompletionTime, equals(DateTime(2026, 8, 13, 17, 0)));
      expect(result.config.targetWorkMinutes, equals(480));
    });

    test('Monday (07:30 - 17:00, target 510m / 8h30): Checkin at 07:20, now at 12:00 should return 4h 30m worked (270m)', () {
      final checkin = DateTime(2026, 8, 10, 7, 20); // Monday
      final now = DateTime(2026, 8, 10, 12, 0);

      final result = ShiftCalculator.calculate(
        checkinTime: checkin,
        now: now,
      );

      expect(result.earlyMinutes, equals(10));
      expect(result.workedMinutes, equals(270)); // 07:30 to 12:00 = 4h30 = 270m
      expect(result.morningWorkedMinutes, equals(270));
      expect(result.morningTargetMinutes, equals(270));
      expect(result.morningProgress, equals(1.0));
      expect(result.config.shiftStartHour, equals(7));
      expect(result.config.shiftStartMinute, equals(30));
      expect(result.config.targetHoursFormatted, equals('8h30'));
    });

    test('Monday (07:30 - 17:00): Checkin at 07:30, now at 17:00 should complete 8h30 (510m)', () {
      final checkin = DateTime(2026, 8, 10, 7, 30); // Monday
      final now = DateTime(2026, 8, 10, 17, 0);

      final result = ShiftCalculator.calculate(
        checkinTime: checkin,
        now: now,
      );

      expect(result.workedMinutes, equals(510));
      expect(result.targetMinutes, equals(510));
      expect(result.remainingMinutes, equals(0));
      expect(result.isCompleted, isTrue);
      expect(result.stage, equals(ShiftStage.completed));
      expect(result.badgeLabel, equals('Hoàn thành 8h30 🎉'));
    });

    test('Saturday (08:00 - 16:30, target 450m / 7h30): Checkin at 07:50, now at 16:30 should complete 7h30 (450m)', () {
      final checkin = DateTime(2026, 8, 15, 7, 50); // Saturday
      final now = DateTime(2026, 8, 15, 16, 30);

      final result = ShiftCalculator.calculate(
        checkinTime: checkin,
        now: now,
      );

      expect(result.earlyMinutes, equals(10));
      expect(result.workedMinutes, equals(450)); // 8:00-12:00 (240m) + 13:00-16:30 (210m) = 450m
      expect(result.targetMinutes, equals(450));
      expect(result.morningWorkedMinutes, equals(240));
      expect(result.morningTargetMinutes, equals(240));
      expect(result.afternoonWorkedMinutes, equals(210));
      expect(result.afternoonTargetMinutes, equals(210));
      expect(result.isCompleted, isTrue);
      expect(result.stage, equals(ShiftStage.completed));
      expect(result.badgeLabel, equals('Hoàn thành 7h30 🎉'));
      expect(result.config.afternoonTimeRange, equals('13:00 - 16:30'));
    });

    test('Saturday (08:00 - 16:30): Checkin at 07:50, now at 07:55 should return earlyCheckin stage', () {
      final checkin = DateTime(2026, 8, 15, 7, 50);
      final now = DateTime(2026, 8, 15, 7, 55);

      final result = ShiftCalculator.calculate(
        checkinTime: checkin,
        now: now,
      );

      expect(result.earlyMinutes, equals(10));
      expect(result.workedMinutes, equals(0));
      expect(result.stage, equals(ShiftStage.earlyCheckin));
      expect(result.badgeLabel, contains('Vào ca sớm 10m'));
    });

    test('Checkin at 07:49, current time 12:30 should return lunchBreak stage and 4h 00m worked (240m)', () {
      final checkin = DateTime(2026, 8, 13, 7, 49);
      final now = DateTime(2026, 8, 13, 12, 30);

      final result = ShiftCalculator.calculate(
        checkinTime: checkin,
        now: now,
      );

      expect(result.workedMinutes, equals(240)); // 08:00 to 12:30 minus 30m lunch = 240m
      expect(result.stage, equals(ShiftStage.lunchBreak));
    });

    test('Past unclosed session (missing checkout) caps to that day shiftEnd instead of overflowing', () {
      final oldCheckin = DateTime(2026, 8, 1, 8, 0); // Saturday in past, no now passed

      final result = ShiftCalculator.calculate(
        checkinTime: oldCheckin,
        now: null, // Simulate stale open session
      );

      // Capped at Saturday's shiftEnd (16:30) => 450 minutes max, NOT multi-day overflow
      expect(result.workedMinutes, equals(450));
    });
  });
}
