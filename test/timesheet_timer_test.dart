import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/core/error/failure.dart';
import 'package:vcloud/features/timesheet/application/task_controller.dart';
import 'package:vcloud/features/timesheet/application/timesheet_controller.dart';
import 'package:vcloud/shared/models/task.dart';
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

  test(
    'derived task split returns an empty list when task stream fails',
    () async {
      final container = ProviderContainer(
        overrides: [
          todayTasksProvider.overrideWith(
            (ref) => Stream<List<Task>>.error(Failure('boom')),
          ),
        ],
      );
      addTearDown(container.dispose);

      container.listen(todayTasksProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);

      final split = container.read(todayTasksSplitProvider);

      expect(split.open, isEmpty);
      expect(split.done, isEmpty);
    },
  );

  test(
    'derived today minutes returns zero when timesheet stream fails',
    () async {
      final container = ProviderContainer(
        overrides: [
          timesheetStreamProvider.overrideWith(
            (ref) => Stream<List<TimesheetEntry>>.error(Failure('boom')),
          ),
        ],
      );
      addTearDown(container.dispose);

      container.listen(timesheetStreamProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);

      expect(container.read(todayTotalMinutesProvider), 0);
    },
  );
}
