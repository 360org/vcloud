import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vcloud/shared/models/attendance.dart';
import 'package:vcloud/features/attendance/application/attendance_controller.dart';

void main() {
  group('Smart Attendance & Stale Recovery Model Tests', () {
    test('1. Attendance.fromMap correctly parses is_stale_open and suggested_checkout_time', () {
      final map = {
        'id': '101',
        'employee_id': '45',
        'is_stale_open': true,
        'stale_attendance_id': '101',
        'stale_check_in_date': '2026-08-27',
        'stale_check_in': '2026-08-27T08:00:00Z',
        'suggested_checkout_time': '2026-08-27T17:30:00Z',
        'created_at': '2026-08-27T08:00:00Z',
      };

      final att = Attendance.fromMap(map);
      expect(att.isStaleOpen, isTrue);
      expect(att.staleAttendanceId, equals('101'));
      expect(att.staleCheckInDate, equals('2026-08-27'));
      expect(att.suggestedCheckoutTime, isNotNull);
      expect(att.isOpen, isTrue);
    });

    test('2. Attendance.fromMap with normal check-in has isStaleOpen false', () {
      final map = {
        'attendance_id': 202,
        'employee_id': 45,
        'is_checked_in': true,
        'check_in': '2026-08-28T08:00:00Z',
      };

      final att = Attendance.fromMap(map);
      expect(att.isStaleOpen, isFalse);
      expect(att.id, equals('202'));
      expect(att.isOpen, isTrue);
    });
  });

  group('HR Attendance KPI & Workdays Calculation Tests', () {
    test('3. Calculates target and actual workdays accurately', () async {
      final container = ProviderContainer(
        overrides: [
          selectedAttendanceMonthProvider.overrideWith((ref) => DateTime(2026, 8, 1)),
          attendanceStreamProvider.overrideWith((ref) => Stream.value([
            // Ngày 3/8 (Thứ Hai): Ca T2 từ 07:30 đến 17:00 -> Đi đúng giờ 07:30, về 17:30 -> 1.0 công
            Attendance(
              id: '1',
              userId: '1',
              checkinTime: DateTime(2026, 8, 3, 7, 30),
              checkoutTime: DateTime(2026, 8, 3, 17, 0),
              createdAt: DateTime(2026, 8, 3, 7, 30),
            ),
            // Ngày 4/8 (Thứ Ba): Ca T3 từ 08:00 đến 17:00 -> Đi muộn 30p (8h30), về đúng giờ -> 1.0 công, lateCount = 1
            Attendance(
              id: '2',
              userId: '1',
              checkinTime: DateTime(2026, 8, 4, 8, 30),
              checkoutTime: DateTime(2026, 8, 4, 17, 0),
              createdAt: DateTime(2026, 8, 4, 8, 30),
            ),
            // Ngày 5/8 (Thứ Tư): Ca T4 từ 08:00 đến 17:00 -> Làm nửa ngày (4h) -> 0.5 công, earlyLeaveCount = 1
            Attendance(
              id: '3',
              userId: '1',
              checkinTime: DateTime(2026, 8, 5, 8, 0),
              checkoutTime: DateTime(2026, 8, 5, 12, 0), // 4h
              createdAt: DateTime(2026, 8, 5, 8, 0),
            ),
          ])),
        ],
      );

      await container.read(attendanceStreamProvider.future);
      final summary = container.read(hrAttendanceMonthSummaryProvider);
      expect(summary.targetWorkdays, equals(26.0)); // Tháng 8/2026 có 31 ngày, 5 Chủ Nhật -> 26 ngày làm việc
      expect(summary.actualWorkdays, equals(2.0));
      expect(summary.lateCount, equals(1));
      expect(summary.lateDetails.length, equals(1));
      expect(summary.lateDetails.first.actualTime, equals('08:30'));
      expect(summary.lateDetails.first.scheduledTime, equals('08:00'));
      expect(summary.lateDetails.first.diffMinutes, equals(30));

      expect(summary.earlyLeaveCount, equals(1));
      expect(summary.earlyDetails.length, equals(1));
      expect(summary.earlyDetails.first.actualTime, equals('12:00'));
      expect(summary.earlyDetails.first.scheduledTime, equals('17:00'));

      expect(summary.totalWorkedMinutes, greaterThan(0));
    });

    test('4. Correctly classifies day status map for Calendar view', () async {
      final container = ProviderContainer(
        overrides: [
          selectedAttendanceMonthProvider.overrideWith((ref) => DateTime(2026, 8, 1)),
          attendanceStreamProvider.overrideWith((ref) => Stream.value([
            // Ngày 3/8 (Thứ Hai): Ca T2 từ 07:30 đến 17:00 -> Đúng giờ
            Attendance(
              id: '1',
              userId: '1',
              checkinTime: DateTime(2026, 8, 3, 7, 30),
              checkoutTime: DateTime(2026, 8, 3, 17, 0),
              createdAt: DateTime(2026, 8, 3, 7, 30),
            ),
          ])),
        ],
      );

      await container.read(attendanceStreamProvider.future);
      final statusMap = container.read(dayAttendanceStatusMapProvider);
      expect(statusMap[3], equals(HrDayAttendanceStatus.fullWorkday));
      expect(statusMap[2], equals(HrDayAttendanceStatus.weekend)); // Ngày 2/8/2026 là Chủ Nhật
    });
  });
}
