import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/features/attendance/domain/shift_calculator.dart';
import 'package:vcloud/features/attendance/presentation/widgets/checkout_dialog.dart';
import 'package:vcloud/features/ticket/application/ticket_controller.dart';
import 'package:vcloud/features/timesheet/application/task_controller.dart';
import 'package:vcloud/features/timesheet/application/timesheet_controller.dart';
import 'package:vcloud/shared/models/attendance.dart';
import 'package:vcloud/shared/models/task.dart';
import 'package:vcloud/shared/models/ticket.dart';
import 'package:vcloud/shared/models/timesheet.dart';

void main() {
  group('Attendance Checkout & Shift Calculation Tests', () {
    testWidgets(
      'CheckoutDialog renders both project tasks and tickets for selection',
      (tester) async {
        final dummyTask = Task(
          id: 'task_888',
          userId: '1',
          title: 'Phát triển màn hình Attendance',
          category: TimesheetCategory.erp,
          dueDate: DateTime(2026, 9, 10),
          createdAt: DateTime(2026, 9, 10),
          updatedAt: DateTime(2026, 9, 10),
          projectId: '45',
          projectName: 'Dự án Odoo VCloud',
        );

        final dummyTicket = Ticket(
          id: 'ticket_777',
          title: 'Hỗ trợ khách hàng cấu hình SaaS',
          status: TicketStatus.doing,
          createdBy: 'user_1',
          assignedTo: 'user_1',
          createdAt: DateTime(2026, 9, 10),
          updatedAt: DateTime(2026, 9, 10),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              todayTasksSplitProvider.overrideWithValue((
                open: [dummyTask],
                done: [],
              )),
              ticketsProvider.overrideWith(
                (ref) => Stream.value([dummyTicket]),
              ),
            ],
            child: MaterialApp(
              theme: ThemeData(useMaterial3: false),
              home: const Scaffold(body: CheckoutDialog()),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Kiểm tra tiêu đề và các phần tử UI
        expect(find.text('Check Out'), findsOneWidget);
        expect(find.text('Mô tả công việc (tùy chọn)'), findsOneWidget);
        expect(
          find.text('Liên kết với task / công việc (tùy chọn)'),
          findsOneWidget,
        );

        // Kiểm tra badge và tên Task
        expect(find.text('Task'), findsOneWidget);
        expect(find.text('Phát triển màn hình Attendance'), findsOneWidget);
        expect(find.text('Dự án Odoo VCloud'), findsOneWidget);

        // Kiểm tra badge và tên Ticket
        expect(find.text('Ticket'), findsOneWidget);
        expect(find.text('Hỗ trợ khách hàng cấu hình SaaS'), findsOneWidget);

        // Nút CHECK-OUT luôn hiển thị và enabled cho phép checkout tự do
        expect(find.text('CHECK-OUT'), findsOneWidget);

        // Nhập mô tả công việc
        await tester.enterText(
          find.byType(TextField),
          'Đã hoàn tất task chấm công',
        );
        await tester.pumpAndSettle();

        // Chọn task dự án
        await tester.tap(find.text('Phát triển màn hình Attendance'));
        await tester.pumpAndSettle();
      },
    );

    test(
      'Checkout actual work duration computation matches ShiftCalculator',
      () {
        final checkin = DateTime(2026, 9, 10, 8, 0); // Thursday
        final checkout = DateTime(
          2026,
          9,
          10,
          11,
          45,
        ); // 3h45m = 225 minutes worked

        final calc = ShiftCalculator.calculate(
          checkinTime: checkin,
          now: checkout,
        );
        final workedMins = calc.workedMinutes;
        expect(workedMins, equals(225));

        final elapsed = Duration(minutes: workedMins);
        final durationBucket = durationBucketForElapsed(elapsed);

        // 225 minutes (> 52m) bucketed into sixty
        expect(durationBucket, equals(TimesheetDuration.sixty));
        expect(elapsed.inMinutes, equals(225));
      },
    );

    test('Short shift work duration calculates bucket appropriately', () {
      final checkin = DateTime(2026, 9, 10, 8, 0);
      final checkout = DateTime(2026, 9, 10, 8, 30); // 30 minutes

      final calc = ShiftCalculator.calculate(
        checkinTime: checkin,
        now: checkout,
      );
      final workedMins = calc.workedMinutes;
      expect(workedMins, equals(30));

      final elapsed = Duration(minutes: workedMins);
      final durationBucket = durationBucketForElapsed(elapsed);
      expect(durationBucket, equals(TimesheetDuration.thirty));
    });

    test(
      'Attendance calendar date grouping with UTC checkin accurately maps to Local date key',
      () {
        // Giả lập check-in lúc 17:30 UTC ngày 2026-09-09 -> tương đương 00:30 ngày 2026-09-10 (GMT+7)
        final utcCheckin = DateTime.utc(2026, 9, 9, 17, 30);
        final localCheckin = utcCheckin.toLocal();

        final att = Attendance(
          id: 'att_utc_test',
          userId: '1',
          createdAt: utcCheckin,
          checkinTime: utcCheckin,
        );

        // Phải toLocal() trước khi trích xuất year-month-day
        final t = (att.checkinTime ?? att.createdAt).toLocal();
        final key =
            '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';

        expect(key, equals('2026-09-10'));
        expect(t.day, equals(localCheckin.day));
      },
    );
  });
}
