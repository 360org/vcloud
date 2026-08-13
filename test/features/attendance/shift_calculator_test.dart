import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/features/attendance/domain/shift_calculator.dart';

void main() {
  group('ShiftCalculator Unit Tests', () {
    const config = ShiftConfig(); // 08:00 - 17:00, lunch 12:00 - 13:00, target 480m

    test('Early checkin at 07:49, current time 16:03 should return 7h 03m worked (423m)', () {
      final checkin = DateTime(2026, 8, 13, 7, 49);
      final now = DateTime(2026, 8, 13, 16, 3);

      final result = ShiftCalculator.calculate(
        checkinTime: checkin,
        now: now,
        config: config,
      );

      expect(result.earlyMinutes, equals(11));
      expect(result.workedMinutes, equals(423)); // 8:00 to 16:03 minus 60m lunch = 423m = 7h 03m
      expect(result.remainingMinutes, equals(57)); // 480 - 423 = 57m
      expect(result.isCompleted, isFalse);
      expect(result.stage, equals(ShiftStage.afternoonShift));
      expect(result.estimatedCompletionTime, equals(DateTime(2026, 8, 13, 17, 0)));
    });

    test('Checkin at 07:49, current time 07:55 should return earlyCheckin stage and 0 worked minutes', () {
      final checkin = DateTime(2026, 8, 13, 7, 49);
      final now = DateTime(2026, 8, 13, 7, 55);

      final result = ShiftCalculator.calculate(
        checkinTime: checkin,
        now: now,
        config: config,
      );

      expect(result.earlyMinutes, equals(11));
      expect(result.workedMinutes, equals(0));
      expect(result.stage, equals(ShiftStage.earlyCheckin));
      expect(result.badgeLabel, contains('Vào ca sớm 11m'));
    });

    test('Checkin at 07:49, current time 12:30 should return lunchBreak stage and 4h 00m worked (240m)', () {
      final checkin = DateTime(2026, 8, 13, 7, 49);
      final now = DateTime(2026, 8, 13, 12, 30);

      final result = ShiftCalculator.calculate(
        checkinTime: checkin,
        now: now,
        config: config,
      );

      expect(result.workedMinutes, equals(240)); // 08:00 to 12:30 minus 30m lunch = 240m
      expect(result.stage, equals(ShiftStage.lunchBreak));
    });

    test('Checkin at 07:49, current time 17:00 should return completed stage and 8h 00m worked (480m)', () {
      final checkin = DateTime(2026, 8, 13, 7, 49);
      final now = DateTime(2026, 8, 13, 17, 0);

      final result = ShiftCalculator.calculate(
        checkinTime: checkin,
        now: now,
        config: config,
      );

      expect(result.workedMinutes, equals(480));
      expect(result.remainingMinutes, equals(0));
      expect(result.isCompleted, isTrue);
      expect(result.stage, equals(ShiftStage.completed));
    });
  });
}
