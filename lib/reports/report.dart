import '../core/attendance_summary.dart';
import '../core/dates.dart';
import '../data/attendance_repository.dart';
import '../models/app_user.dart';
import '../models/attendance_status.dart';

/// One person's totals in a report.
class ReportRow {
  const ReportRow({required this.name, required this.email, required this.summary});
  final String name;
  final String email;
  final AttendanceSummary summary;
}

/// An attendance report for a date range: one row per user.
class AttendanceReport {
  const AttendanceReport({required this.from, required this.to, required this.rows, required this.generatedAt});

  final DateTime from;
  final DateTime to;
  final List<ReportRow> rows;
  final DateTime generatedAt;

  String get title => 'Attendance ${Dates.dayKey(from)} to ${Dates.dayKey(to)}';

  /// Builds a report from users and their stored attendance records.
  /// Each user's join date (in organisation time) limits which days count.
  factory AttendanceReport.build({
    required DateTime from,
    required DateTime to,
    required List<AppUser> users,
    required List<AttendanceEntry> entries,
    DateTime? today,
    DateTime? generatedAt,
  }) {
    final byUser = <String, Map<String, AttendanceStatus>>{};
    for (final e in entries) {
      (byUser[e.uid] ??= {})[e.date] = e.status;
    }
    final now = today ?? Dates.orgToday();
    final rows = [
      for (final u in users)
        ReportRow(
          name: u.name,
          email: u.email,
          summary: AttendanceCalculator(
            records: byUser[u.uid] ?? const {},
            joinedOn: Dates.orgToday(u.createdAt),
            today: now,
          ).summarize(from, to),
        ),
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return AttendanceReport(from: from, to: to, rows: rows, generatedAt: generatedAt ?? DateTime.now());
  }

  static const headers = ['Name', 'Email', 'Present', 'Absent', 'Leave', 'Attendance %'];

  /// The table as plain values, shared by the CSV and PDF exports.
  List<List<String>> get table => [
        for (final r in rows)
          [
            r.name,
            r.email,
            '${r.summary.present}',
            '${r.summary.absent}',
            '${r.summary.leave}',
            r.summary.attendanceRate.toStringAsFixed(1),
          ],
      ];

  /// RFC 4180 CSV: fields with commas, quotes or line breaks are quoted.
  String toCsv() {
    String field(String v) =>
        RegExp(r'[",\r\n]').hasMatch(v) ? '"${v.replaceAll('"', '""')}"' : v;
    final lines = [headers, ...table].map((row) => row.map(field).join(','));
    return '${lines.join('\r\n')}\r\n';
  }
}
