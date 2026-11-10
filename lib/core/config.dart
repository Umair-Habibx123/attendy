/// Organisation-wide settings.
///
/// Attendance days are counted in the organisation's local time, not the
/// phone's. Keep [orgUtcOffset] in sync with the offset in `firestore.rules`
/// (function `orgToday`), which is what actually enforces "today".
class AppConfig {
  AppConfig._();

  static const String appName = 'Attendy';

  /// Pakistan Standard Time (UTC+5, no daylight saving).
  static const Duration orgUtcOffset = Duration(hours: 5);

  /// Default working days, used until an admin saves a schedule in the app
  /// (Admin → Profile → Work schedule). Monday = 1 ... Sunday = 7.
  static const Set<int> defaultWorkingDays = {
    DateTime.monday,
    DateTime.tuesday,
    DateTime.wednesday,
    DateTime.thursday,
    DateTime.friday,
  };

  /// Longest leave a user can request in one go, in calendar days.
  static const int maxLeaveDays = 30;
}
