import '../models/attendance_status.dart';
import 'dates.dart';

/// Totals for a date range.
class AttendanceSummary {
  const AttendanceSummary({
    required this.present,
    required this.absent,
    required this.leave,
    required this.workingDays,
  });

  final int present;

  /// Recorded absences plus past working days with no record.
  final int absent;
  final int leave;

  /// Working days in the range that have already happened (or are today
  /// with a record), from the user's join date on.
  final int workingDays;

  /// Share of counted working days marked present, 0–100. Leave days are
  /// excluded from the base, so approved leave doesn't lower the rate.
  double get attendanceRate {
    final base = present + absent;
    return base == 0 ? 0 : present * 100 / base;
  }

  static const empty = AttendanceSummary(present: 0, absent: 0, leave: 0, workingDays: 0);
}

/// Works out each day's status and the totals for a range.
///
/// [records] maps day keys (`yyyy-MM-dd`) to stored statuses. Days before
/// [joinedOn] are ignored. A past working day with no record counts as
/// absent ([AttendanceStatus.missed]); today without a record is
/// [AttendanceStatus.notMarked] and isn't counted yet; future days are skipped.
class AttendanceCalculator {
  AttendanceCalculator({
    required this.records,
    required this.joinedOn,
    required this.today,
  });

  final Map<String, AttendanceStatus> records;
  final DateTime joinedOn;
  final DateTime today;

  /// Status for one day, or null when the day isn't counted at all
  /// (future, before joining, or a non-working day with no record).
  AttendanceStatus? statusOn(DateTime day) {
    final d = Dates.dateOnly(day);
    final key = Dates.dayKey(d);
    final stored = records[key];
    if (d.isAfter(today)) return stored == AttendanceStatus.leave ? stored : null;
    if (stored != null) return stored;
    if (d.isBefore(Dates.dateOnly(joinedOn)) || !Dates.isWorkingDay(d)) return null;
    return d == today ? AttendanceStatus.notMarked : AttendanceStatus.missed;
  }

  AttendanceSummary summarize(DateTime from, DateTime to) {
    var present = 0, absent = 0, leave = 0, working = 0;
    for (final day in Dates.daysBetween(from, to)) {
      final status = statusOn(day);
      if (status == null || day.isAfter(today)) continue;
      switch (status) {
        case AttendanceStatus.present:
          present++;
        case AttendanceStatus.absent:
        case AttendanceStatus.missed:
          absent++;
        case AttendanceStatus.leave:
          leave++;
        case AttendanceStatus.notMarked:
          continue;
      }
      if (Dates.isWorkingDay(day) || status == AttendanceStatus.present) working++;
    }
    return AttendanceSummary(present: present, absent: absent, leave: leave, workingDays: working);
  }
}
