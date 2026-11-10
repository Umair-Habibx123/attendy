import 'config.dart';

/// Which days people are expected to work: a weekly pattern plus specific
/// holidays. Admins edit it in the app; it is stored at
/// `settings/organization` and applied live for everyone.
///
/// Days that aren't working days never count as absent, and approving leave
/// only marks working days.
class WorkSchedule {
  const WorkSchedule({required this.workingDays, this.holidays = const {}, this.holidayNames = const {}});

  /// Weekdays using [DateTime.weekday] numbering: Monday = 1 ... Sunday = 7.
  final Set<int> workingDays;

  /// Specific days off, as `yyyy-MM-dd` keys (public holidays, closures).
  final Set<String> holidays;

  /// Optional names for holidays, keyed by day key (e.g. "Eid ul-Adha").
  final Map<String, String> holidayNames;

  static const WorkSchedule defaults = WorkSchedule(workingDays: AppConfig.defaultWorkingDays);

  /// The schedule in effect. Updated from Firestore when the app is running;
  /// tests set it directly.
  static WorkSchedule current = defaults;

  bool isWorkingDay(DateTime d) => workingDays.contains(d.weekday) && !holidays.contains(_key(d));

  bool isHoliday(DateTime d) => holidays.contains(_key(d));

  /// The holiday's name for [d], or null when it isn't a named holiday.
  String? holidayName(DateTime d) {
    final k = _key(d);
    if (!holidays.contains(k)) return null;
    final name = holidayNames[k];
    return name == null || name.isEmpty ? 'Holiday' : name;
  }

  /// Adds every day from [from] to [to] (inclusive) as a holiday called [name].
  WorkSchedule withHolidayRange(DateTime from, DateTime to, String name) {
    final days = <String>{...holidays};
    final names = <String, String>{...holidayNames};
    for (var d = DateTime(from.year, from.month, from.day);
        !d.isAfter(DateTime(to.year, to.month, to.day));
        d = DateTime(d.year, d.month, d.day + 1)) {
      days.add(_key(d));
      if (name.trim().isNotEmpty) {
        names[_key(d)] = name.trim();
      } else {
        names.remove(_key(d));
      }
    }
    return WorkSchedule(workingDays: workingDays, holidays: days, holidayNames: names);
  }

  WorkSchedule withoutHolidays(Iterable<String> keys) {
    final remove = keys.toSet();
    return WorkSchedule(
      workingDays: workingDays,
      holidays: holidays.difference(remove),
      holidayNames: {...holidayNames}..removeWhere((k, _) => remove.contains(k)),
    );
  }

  WorkSchedule withWorkingDays(Set<int> days) =>
      WorkSchedule(workingDays: days, holidays: holidays, holidayNames: holidayNames);

  /// Holidays grouped into runs of consecutive days with the same name, for
  /// display ("Eid ul-Fitr · 30 Mar – 1 Apr").
  List<HolidayGroup> get holidayGroups {
    final keys = holidays.toList()..sort();
    final groups = <HolidayGroup>[];
    for (final k in keys) {
      final name = holidayNames[k] ?? '';
      final last = groups.isEmpty ? null : groups.last;
      if (last != null && last.name == name && _nextKey(last.keys.last) == k) {
        last.keys.add(k);
      } else {
        groups.add(HolidayGroup(name, [k]));
      }
    }
    return groups;
  }

  factory WorkSchedule.fromMap(Map<String, dynamic>? data) {
    if (data == null) return defaults;
    final days = (data['workingDays'] as List?)
            ?.whereType<num>()
            .map((n) => n.toInt())
            .where((n) => n >= 1 && n <= 7)
            .toSet() ??
        const <int>{};
    final holidays = (data['holidays'] as List?)?.whereType<String>().toSet() ?? const <String>{};
    final rawNames = data['holidayNames'];
    final names = <String, String>{
      if (rawNames is Map)
        for (final e in rawNames.entries)
          if (e.key is String && e.value is String && holidays.contains(e.key)) e.key as String: e.value as String,
    };
    return WorkSchedule(
      workingDays: days.isEmpty ? AppConfig.defaultWorkingDays : days,
      holidays: holidays,
      holidayNames: names,
    );
  }

  Map<String, dynamic> toMap() => {
        'workingDays': (workingDays.toList()..sort()),
        'holidays': (holidays.toList()..sort()),
        'holidayNames': {for (final k in holidays) if ((holidayNames[k] ?? '').isNotEmpty) k: holidayNames[k]},
      };

  static String _key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String _nextKey(String key) {
    final p = key.split('-').map(int.parse).toList();
    return _key(DateTime(p[0], p[1], p[2] + 1));
  }

  @override
  bool operator ==(Object other) =>
      other is WorkSchedule &&
      other.workingDays.length == workingDays.length &&
      other.workingDays.containsAll(workingDays) &&
      other.holidays.length == holidays.length &&
      other.holidays.containsAll(holidays) &&
      _sameNames(other.holidayNames, holidayNames);

  static bool _sameNames(Map<String, String> a, Map<String, String> b) =>
      a.length == b.length && a.entries.every((e) => b[e.key] == e.value);

  @override
  int get hashCode => Object.hash(
        Object.hashAllUnordered(workingDays),
        Object.hashAllUnordered(holidays),
        Object.hashAllUnordered(holidayNames.entries.map((e) => '${e.key}=${e.value}')),
      );
}

/// Consecutive holiday days that share a name.
class HolidayGroup {
  HolidayGroup(this.name, this.keys);
  final String name;
  final List<String> keys;
}
