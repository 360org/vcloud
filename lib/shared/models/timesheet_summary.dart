class TimesheetSummary {
  const TimesheetSummary({
    required this.totalHours,
    required this.count,
    this.dateFrom,
    this.dateTo,
  });

  final double totalHours;
  final int count;
  final String? dateFrom;
  final String? dateTo;

  factory TimesheetSummary.fromMap(Map<String, dynamic> m) {
    final hours = (m['total_hours'] as num?)?.toDouble() ?? 0.0;
    final cnt = (m['count'] as num?)?.toInt() ?? 0;
    return TimesheetSummary(
      totalHours: hours,
      count: cnt,
      dateFrom: m['date_from']?.toString(),
      dateTo: m['date_to']?.toString(),
    );
  }
}
