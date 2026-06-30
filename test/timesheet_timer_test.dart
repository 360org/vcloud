import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/features/timesheet/application/timesheet_controller.dart';
import 'package:vcloud/shared/models/timesheet.dart';

void main() {
  test('durationBucketForElapsed maps fixed MVP buckets', () {
    expect(
      durationBucketForElapsed(const Duration(minutes: 0)),
      TimesheetDuration.fifteen,
    );
    expect(
      durationBucketForElapsed(const Duration(minutes: 22)),
      TimesheetDuration.fifteen,
    );
    expect(
      durationBucketForElapsed(const Duration(minutes: 23)),
      TimesheetDuration.thirty,
    );
    expect(
      durationBucketForElapsed(const Duration(minutes: 38)),
      TimesheetDuration.fortyFive,
    );
    expect(
      durationBucketForElapsed(const Duration(minutes: 53)),
      TimesheetDuration.sixty,
    );
    expect(
      durationBucketForElapsed(const Duration(minutes: 90)),
      TimesheetDuration.sixty,
    );
  });

  test('timer controller starts, pauses, resumes, and resets', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final controller = container.read(
      timesheetTimerControllerProvider.notifier,
    );

    expect(container.read(timesheetTimerControllerProvider).isIdle, isTrue);

    controller.updateTask('Refine design');
    controller.start();
    expect(container.read(timesheetTimerControllerProvider).isRunning, isTrue);
    expect(
      container.read(timesheetTimerControllerProvider).taskName,
      'Refine design',
    );

    controller.pause();
    expect(container.read(timesheetTimerControllerProvider).isPaused, isTrue);

    controller.resume();
    expect(container.read(timesheetTimerControllerProvider).isRunning, isTrue);

    controller.reset();
    expect(container.read(timesheetTimerControllerProvider).isIdle, isTrue);
    expect(container.read(timesheetTimerControllerProvider).taskName, isEmpty);
  });
}
