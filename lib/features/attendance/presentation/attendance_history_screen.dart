import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/date_format.dart';
import '../../../shared/models/attendance.dart';
import '../../../shared/widgets/app_scaffold.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/loading_view.dart';
import '../application/attendance_controller.dart';

class AttendanceHistoryScreen extends ConsumerWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rows = ref.watch(attendanceStreamProvider);
    return AppScaffold(
      title: 'History',
      body: rows.when(
        data: (list) {
          if (list.isEmpty) {
            return const EmptyState(
              icon: Icons.event_busy,
              title: 'No attendance yet',
              subtitle: 'Once you check in, your history will appear here.',
            );
          }
          // group by date
          final byDate = <String, List<Attendance>>{};
          for (final a in list) {
            final key = Dates.isoDate(a.createdAt.toLocal());
            byDate.putIfAbsent(key, () => <Attendance>[]).add(a);
          }
          final groups = byDate.entries.toList()
            ..sort((a, b) => b.key.compareTo(a.key));

          return ListView.builder(
            itemCount: groups.length,
            itemBuilder: (_, i) {
              final g = groups[i];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      g.key,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  for (final a in g.value) _row(a),
                ],
              );
            },
          );
        },
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(error: e),
      ),
    );
  }

  Widget _row(Attendance a) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: const Icon(Icons.access_time),
        title: Text(
          a.checkinTime != null
              ? '${Dates.time(a.checkinTime!)} → '
                    '${a.checkoutTime != null ? Dates.time(a.checkoutTime!) : 'still in'}'
              : 'No check-in',
        ),
        subtitle: Text(
          a.checkinLat != null && a.checkinLng != null
              ? '(${a.checkinLat!.toStringAsFixed(4)}, ${a.checkinLng!.toStringAsFixed(4)})'
              : '',
        ),
        trailing: a.elapsed != null && a.isOpen
            ? Text(Dates.humanDuration(a.elapsed!))
            : null,
      ),
    );
  }
}
