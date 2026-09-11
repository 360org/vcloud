class TimesheetSummary {
  const TimesheetSummary({
    required this.totalHours,
    required this.count,
    this.dateFrom,
    this.dateTo,
    this.projectId,
  });

  final double totalHours;
  final int count;
  final String? dateFrom;
  final String? dateTo;
  final String? projectId;

  factory TimesheetSummary.fromMap(Map<String, dynamic> raw) {
    final m = (raw['data'] is Map)
        ? Map<String, dynamic>.from(raw['data'])
        : (raw['result'] is Map)
            ? Map<String, dynamic>.from(raw['result'])
            : raw;
    final hours = (m['total_hours'] ?? m['hours'] ?? m['total']) as num?;
    final cnt = (m['count'] ?? m['total_count'] ?? m['length']) as num?;
    return TimesheetSummary(
      totalHours: hours?.toDouble() ?? 0.0,
      count: cnt?.toInt() ?? 0,
      dateFrom: m['date_from']?.toString(),
      dateTo: m['date_to']?.toString(),
      projectId: m['project_id']?.toString(),
    );
  }
}
