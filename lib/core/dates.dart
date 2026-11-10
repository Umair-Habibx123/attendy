import 'config.dart';
import 'work_schedule.dart';

/// Date helpers. Attendance days are identified by a "day key" in the form
/// `yyyy-MM-dd`, which sorts correctly as text and is also the Firestore
/// document ID of each attendance day.
class Dates {
  Dates._();

  /// The current date and time in the organisation's time zone.
  static DateTime orgNow([DateTime? utcNow]) {
    final utc = (utcNow ?? DateTime.now()).toUtc();
    final shifted = utc.add(AppConfig.orgUtcOffset);
    // Drop the UTC flag: the fields now represent organisation-local time.
    return DateTime(shifted.year, shifted.month, shifted.day, shifted.hour,
        shifted.minute, shifted.second);
  }

  /// Today's date (midnight) in the organisation's time zone.
  static DateTime orgToday([DateTime? utcNow]) => dateOnly(orgNow(utcNow));

  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static String dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}-${_two(d.day)}';

  static String todayKey([DateTime? utcNow]) => dayKey(orgToday(utcNow));

  static final RegExp _keyPattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  static bool isDayKey(String value) => _keyPattern.hasMatch(value);

  static DateTime parseDayKey(String key) {
    if (!isDayKey(key)) throw FormatException('Not a yyyy-MM-dd day key', key);
    final parts = key.split('-').map(int.parse).toList();
    return DateTime(parts[0], parts[1], parts[2]);
  }

  /// Uses the admin-set [WorkSchedule] (weekly pattern plus holidays).
  static bool isWorkingDay(DateTime d) => WorkSchedule.current.isWorkingDay(d);

  /// Every date from [from] to [to], both included.
  static List<DateTime> daysBetween(DateTime from, DateTime to) {
    final start = dateOnly(from);
    final end = dateOnly(to);
    if (end.isBefore(start)) return const [];
    final days = <DateTime>[];
    // Step by calendar day (not 24h) so daylight-saving shifts can't skip a date.
    for (var d = start; !d.isAfter(end); d = DateTime(d.year, d.month, d.day + 1)) {
      days.add(d);
    }
    return days;
  }

  /// Working days from [from] to [to], both included.
  static List<DateTime> workingDaysBetween(DateTime from, DateTime to) =>
      daysBetween(from, to).where(isWorkingDay).toList();

  static DateTime firstOfMonth(DateTime d) => DateTime(d.year, d.month, 1);

  static DateTime lastOfMonth(DateTime d) => DateTime(d.year, d.month + 1, 0);

  static String _two(int n) => n.toString().padLeft(2, '0');
}
