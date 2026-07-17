import 'package:flutter_test/flutter_test.dart';
import 'package:vcloud/core/utils/date_format.dart';

void main() {
  test('chatListLabelVi formats message time in local timezone', () {
    final utcTime = DateTime.utc(2026, 7, 2, 8, 5);
    final localTime = utcTime.toLocal();
    final now = DateTime(localTime.year, localTime.month, localTime.day, 20);

    expect(Dates.chatListLabelVi(utcTime, now: now), Dates.hm(localTime));
  });

  test('chatListLabelVi formats older local days in Vietnamese', () {
    final now = DateTime(2026, 7, 2, 12);

    expect(
      Dates.chatListLabelVi(DateTime(2026, 7, 1, 22), now: now),
      'Hôm qua',
    );
    expect(
      Dates.chatListLabelVi(DateTime(2026, 6, 29, 22), now: now),
      '3 ngày',
    );
    expect(Dates.chatListLabelVi(DateTime(2026, 6, 20, 22), now: now), '20/06');
  });
}
