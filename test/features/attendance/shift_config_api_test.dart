import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/features/attendance/domain/shift_calculator.dart';

void main() {
  group('ShiftConfig Dynamic API Mapping & Calculation Tests', () {
    test('ShiftConfig.fromMap parses complete backend JSON payload accurately', () {
      final jsonPayload = <String, dynamic>{
        'day_name': 'Thứ Ba - Thứ Sáu',
        'shift_start_hour': 8,
        'shift_start_minute': 0,
        'shift_end_hour': 17,
        'shift_end_minute': 0,
        'lunch_start_hour': 12,
        'lunch_start_minute': 0,
        'lunch_end_hour': 13,
        'lunch_end_minute': 0,
        'morning_target_minutes': 240,
        'afternoon_target_minutes': 240,
        'target_work_minutes': 480,
        'allow_early_checkin_work_hours': false,
      };

      final config = ShiftConfig.fromMap(jsonPayload);

      expect(config.dayName, equals('Thứ Ba - Thứ Sáu'));
      expect(config.shiftStartHour, equals(8));
      expect(config.shiftEndHour, equals(17));
      expect(config.lunchStartHour, equals(12));
      expect(config.lunchEndHour, equals(13));
      expect(config.morningTargetMinutes, equals(240));
      expect(config.afternoonTargetMinutes, equals(240));
      expect(config.targetWorkMinutes, equals(480));
      expect(config.morningHoursFormatted, equals('4h'));
      expect(config.afternoonHoursFormatted, equals('4h'));
      expect(config.targetHoursFormatted, equals('8h'));
      expect(config.morningTimeRange, equals('08:00 - 12:00'));
      expect(config.lunchTimeRange, equals('12:00 - 13:00'));
      expect(config.afternoonTimeRange, equals('13:00 - 17:00'));
    });

    test('ShiftConfig.fromMap handles custom company shifts from Odoo resource.calendar', () {
      // Ví dụ ca làm việc đặc thù 07:30 - 16:30 (Sáng: 4h30, Chiều: 3h30 => 8h)
      final customPayload = <String, dynamic>{
        'day_name': 'Ca Đặc Thù',
        'shift_start_hour': 7,
        'shift_start_minute': 30,
        'shift_end_hour': 16,
        'shift_end_minute': 30,
        'lunch_start_hour': 12,
        'lunch_start_minute': 0,
        'lunch_end_hour': 13,
        'lunch_end_minute': 0,
        'morning_target_minutes': 270,
        'afternoon_target_minutes': 210,
        'target_work_minutes': 480,
        'allow_early_checkin_work_hours': true,
      };

      final config = ShiftConfig.fromMap(customPayload);

      expect(config.dayName, equals('Ca Đặc Thù'));
      expect(config.shiftStartHour, equals(7));
      expect(config.shiftStartMinute, equals(30));
      expect(config.morningHoursFormatted, equals('4h30'));
      expect(config.afternoonHoursFormatted, equals('3h30'));
      expect(config.morningTimeRange, equals('07:30 - 12:00'));
      expect(config.afternoonTimeRange, equals('13:00 - 16:30'));
    });

    test('ShiftCalculator calculates correct progress using dynamic API config', () {
      const config = ShiftConfig(
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
        dayName: 'Thứ Ba - Thứ Sáu',
      );

      final now = DateTime.now();
      // Giả lập checkin lúc 8:00 sáng
      final checkin = DateTime(now.year, now.month, now.day, 8, 0);

      final progress = ShiftCalculator.calculate(
        checkinTime: checkin,
        config: config,
      );

      expect(progress.config.dayName, equals('Thứ Ba - Thứ Sáu'));
      expect(progress.config.targetWorkMinutes, equals(480));
      expect(progress.config.morningTargetMinutes, equals(240));
    });

    test('ShiftConfig.toMap serializes accurately for local persistence', () {
      const config = ShiftConfig(
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
        dayName: 'Thứ Hai',
      );

      final map = config.toMap();
      expect(map['day_name'], equals('Thứ Hai'));
      expect(map['target_work_minutes'], equals(480));
      expect(map['morning_target_minutes'], equals(240));

      final restored = ShiftConfig.fromMap(map);
      expect(restored.dayName, equals(config.dayName));
      expect(restored.targetWorkMinutes, equals(config.targetWorkMinutes));
    });
  });
}
