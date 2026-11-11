import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/core/notifications/attendance_local_reminder_service.dart';
import 'package:vcloud/features/attendance/domain/shift_calculator.dart';

void main() {
  group('Attendance Reminder Cutoff Protection Tests (Anti-Late-Alarm)', () {
    const standardShift = ShiftConfig(
      shiftStartHour: 8,
      shiftStartMinute: 0,
      shiftEndHour: 17,
      shiftEndMinute: 0,
      lunchStartHour: 12,
      lunchStartMinute: 0,
      lunchEndHour: 13,
      lunchEndMinute: 0,
    );

    test('1. Morning Check-in: 07:30 (before shift) is NOT past morning cutoff', () {
      final time = DateTime(2026, 11, 9, 7, 30);
      final isCutoff = AttendanceLocalReminderService.isPastMorningCheckInCutoff(
        currentTime: time,
        shiftConfig: standardShift,
      );
      expect(isCutoff, isFalse);
    });

    test('2. Morning Check-in: 08:05 (reminder target time) is NOT past morning cutoff', () {
      final time = DateTime(2026, 11, 9, 8, 5);
      final isCutoff = AttendanceLocalReminderService.isPastMorningCheckInCutoff(
        currentTime: time,
        shiftConfig: standardShift,
      );
      expect(isCutoff, isFalse);
    });

    test('3. Morning Check-in: 11:59 (edge case right before noon) is NOT past cutoff', () {
      final time = DateTime(2026, 11, 9, 11, 59);
      final isCutoff = AttendanceLocalReminderService.isPastMorningCheckInCutoff(
        currentTime: time,
        shiftConfig: standardShift,
      );
      expect(isCutoff, isFalse);
    });

    test('4. Morning Check-in: Exactly 12:00 (lunch start) IS past morning cutoff', () {
      final time = DateTime(2026, 11, 9, 12, 0);
      final isCutoff = AttendanceLocalReminderService.isPastMorningCheckInCutoff(
        currentTime: time,
        shiftConfig: standardShift,
      );
      expect(isCutoff, isTrue);
    });

    test('5. Morning Check-in: 14:30 afternoon IS past morning cutoff', () {
      final time = DateTime(2026, 11, 9, 14, 30);
      final isCutoff = AttendanceLocalReminderService.isPastMorningCheckInCutoff(
        currentTime: time,
        shiftConfig: standardShift,
      );
      expect(isCutoff, isTrue);
    });

    test('6. Morning Check-in: 21:14 night (incident scenario of Quoc Anh) IS past morning cutoff', () {
      final time = DateTime(2026, 11, 9, 21, 14);
      final isCutoff = AttendanceLocalReminderService.isPastMorningCheckInCutoff(
        currentTime: time,
        shiftConfig: standardShift,
      );
      expect(isCutoff, isTrue);
    });

    test('7. Morning Check-in: Custom shift with 11:30 lunch cutoff respects custom minute boundary', () {
      const customShift = ShiftConfig(
        shiftStartHour: 7,
        shiftStartMinute: 30,
        shiftEndHour: 16,
        shiftEndMinute: 30,
        lunchStartHour: 11,
        lunchStartMinute: 30,
      );

      final before = DateTime(2026, 11, 9, 11, 29);
      final atCutoff = DateTime(2026, 11, 9, 11, 30);
      final after = DateTime(2026, 11, 9, 11, 31);

      expect(AttendanceLocalReminderService.isPastMorningCheckInCutoff(currentTime: before, shiftConfig: customShift), isFalse);
      expect(AttendanceLocalReminderService.isPastMorningCheckInCutoff(currentTime: atCutoff, shiftConfig: customShift), isTrue);
      expect(AttendanceLocalReminderService.isPastMorningCheckInCutoff(currentTime: after, shiftConfig: customShift), isTrue);
    });

    test('8. Afternoon Check-out: 17:35 (normal reminder time) is NOT past night cutoff', () {
      final time = DateTime(2026, 11, 9, 17, 35);
      final isCutoff = AttendanceLocalReminderService.isPastAfternoonCheckOutCutoff(
        currentTime: time,
      );
      expect(isCutoff, isFalse);
    });

    test('9. Afternoon Check-out: 21:59 (edge case before 22:00) is NOT past night cutoff', () {
      final time = DateTime(2026, 11, 9, 21, 59);
      final isCutoff = AttendanceLocalReminderService.isPastAfternoonCheckOutCutoff(
        currentTime: time,
      );
      expect(isCutoff, isFalse);
    });

    test('10. Afternoon Check-out: 22:01 night IS past cutoff and prevented', () {
      final time = DateTime(2026, 11, 9, 22, 1);
      final isCutoff = AttendanceLocalReminderService.isPastAfternoonCheckOutCutoff(
        currentTime: time,
      );
      expect(isCutoff, isTrue);
    });

    test('11. Afternoon Check-out: Late night 23:45 IS past cutoff', () {
      final lateNight = DateTime(2026, 11, 9, 23, 45);

      expect(AttendanceLocalReminderService.isPastAfternoonCheckOutCutoff(currentTime: lateNight), isTrue);
    });

    test('12. Fallback without explicit ShiftConfig defaults to 12:00 noon cutoff', () {
      final at1155 = DateTime(2026, 11, 9, 11, 55);
      final at1205 = DateTime(2026, 11, 9, 12, 5);

      expect(AttendanceLocalReminderService.isPastMorningCheckInCutoff(currentTime: at1155), isFalse);
      expect(AttendanceLocalReminderService.isPastMorningCheckInCutoff(currentTime: at1205), isTrue);
    });
  });
}
