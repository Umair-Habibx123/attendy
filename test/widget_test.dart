import 'package:attendy/core/attendance_summary.dart';
import 'package:attendy/core/dates.dart';
import 'package:attendy/core/validators.dart';
import 'package:attendy/core/work_schedule.dart';
import 'package:attendy/data/attendance_repository.dart';
import 'package:attendy/models/app_user.dart';
import 'package:attendy/models/attendance_status.dart';
import 'package:attendy/reports/report.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Every test starts from the default Monday–Friday schedule.
  setUp(() => WorkSchedule.current = WorkSchedule.defaults);

  group('WorkSchedule (set by admins)', () {
    test('Saturday can be made a working day', () {
      final sat = DateTime(2026, 11, 7);
      expect(Dates.isWorkingDay(sat), isFalse);
      WorkSchedule.current = const WorkSchedule(workingDays: {1, 2, 3, 4, 5, 6});
      expect(Dates.isWorkingDay(sat), isTrue);
    });

    test('holidays are never working days, so they never count as absent', () {
      WorkSchedule.current = const WorkSchedule(workingDays: {1, 2, 3, 4, 5}, holidays: {'2026-11-09'});
      expect(Dates.isWorkingDay(DateTime(2026, 11, 9)), isFalse);
      final calc = AttendanceCalculator(records: const {}, joinedOn: DateTime(2026, 11, 2), today: DateTime(2026, 11, 11));
      expect(calc.statusOn(DateTime(2026, 11, 9)), isNull);
      expect(calc.summarize(DateTime(2026, 11, 9), DateTime(2026, 11, 10)).absent, 1); // only the 10th
    });

    test('a named multi-day holiday is added and grouped', () {
      final s = WorkSchedule.defaults.withHolidayRange(DateTime(2026, 3, 30), DateTime(2026, 4, 1), 'Eid ul-Fitr');
      expect(s.holidays, {'2026-03-30', '2026-03-31', '2026-04-01'});
      expect(s.holidayName(DateTime(2026, 3, 31)), 'Eid ul-Fitr');
      expect(s.holidayGroups.single.keys.length, 3);
      expect(s.withoutHolidays(s.holidayGroups.single.keys).holidays, isEmpty);
    });

    test('reads from and writes to the Firestore shape', () {
      final s = WorkSchedule.fromMap({'workingDays': [6, 1, 2, 9], 'holidays': ['2026-12-25']});
      expect(s.workingDays, {1, 2, 6}); // 9 is ignored
      expect(s.toMap(), {'workingDays': [1, 2, 6], 'holidays': ['2026-12-25'], 'holidayNames': <String, String>{}});
      expect(WorkSchedule.fromMap(null), WorkSchedule.defaults);
      expect(WorkSchedule.fromMap({'workingDays': []}).workingDays, WorkSchedule.defaults.workingDays);
    });
  });

  group('Dates', () {
    test('organisation date is UTC+5, independent of the phone', () {
      // 20:30 UTC on 10 Nov is already 01:30 on 11 Nov in Pakistan.
      expect(Dates.todayKey(DateTime.utc(2026, 11, 10, 20, 30)), '2026-11-11');
      expect(Dates.todayKey(DateTime.utc(2026, 11, 10, 18, 59)), '2026-11-10');
    });

    test('day keys round-trip and reject bad input', () {
      expect(Dates.dayKey(DateTime(2026, 3, 7)), '2026-03-07');
      expect(Dates.parseDayKey('2026-03-07'), DateTime(2026, 3, 7));
      expect(() => Dates.parseDayKey('7/3/2026'), throwsFormatException);
    });

    test('working days skip weekends', () {
      // Fri 6 Nov 2026 to Mon 9 Nov 2026: Fri and Mon only.
      final days = Dates.workingDaysBetween(DateTime(2026, 11, 6), DateTime(2026, 11, 9));
      expect(days.map(Dates.dayKey), ['2026-11-06', '2026-11-09']);
      expect(Dates.daysBetween(DateTime(2026, 11, 9), DateTime(2026, 11, 6)), isEmpty);
    });
  });

  group('AttendanceCalculator', () {
    // Wed 11 Nov 2026 is "today". The user joined Mon 2 Nov.
    final today = DateTime(2026, 11, 11);
    final calc = AttendanceCalculator(
      records: {
        '2026-11-02': AttendanceStatus.present,
        '2026-11-03': AttendanceStatus.present,
        '2026-11-04': AttendanceStatus.leave,
        '2026-11-05': AttendanceStatus.absent,
        // 6 Nov (Fri) has no record -> missed
        '2026-11-07': AttendanceStatus.present, // Saturday, but they came in
        '2026-11-09': AttendanceStatus.present,
        '2026-11-10': AttendanceStatus.present,
        '2026-11-13': AttendanceStatus.leave, // approved future leave
      },
      joinedOn: DateTime(2026, 11, 2),
      today: today,
    );

    test('past working days with no record count as absent', () {
      expect(calc.statusOn(DateTime(2026, 11, 6)), AttendanceStatus.missed);
    });

    test('today without a record is "not marked", not absent', () {
      expect(calc.statusOn(today), AttendanceStatus.notMarked);
    });

    test('days before joining, weekends and the future are not counted', () {
      expect(calc.statusOn(DateTime(2026, 10, 30)), isNull);
      expect(calc.statusOn(DateTime(2026, 11, 8)), isNull); // Sunday, no record
      expect(calc.statusOn(DateTime(2026, 11, 12)), isNull);
      expect(calc.statusOn(DateTime(2026, 11, 13)), AttendanceStatus.leave, reason: 'upcoming leave is shown');
    });

    test('totals for the month so far', () {
      final s = calc.summarize(DateTime(2026, 11, 1), DateTime(2026, 11, 30));
      expect(s.present, 5); // 2, 3, 7 (Sat), 9, 10
      expect(s.absent, 2); // 5 (recorded) + 6 (missed)
      expect(s.leave, 1); // 4; the future leave on 13 isn't counted yet
      expect(s.attendanceRate, closeTo(5 * 100 / 7, 0.001));
    });
  });

  group('AttendanceReport', () {
    final users = [
      AppUser(uid: 'b', name: 'Bilal', email: 'bilal@example.com', role: UserRole.user, active: true, createdAt: DateTime(2026, 11, 2)),
      AppUser(uid: 'a', name: 'Ayesha, "Ash"', email: 'ash@example.com', role: UserRole.user, active: true, createdAt: DateTime(2026, 11, 2)),
    ];
    final report = AttendanceReport.build(
      from: DateTime(2026, 11, 2),
      to: DateTime(2026, 11, 4),
      users: users,
      entries: const [
        AttendanceEntry(uid: 'a', date: '2026-11-02', status: AttendanceStatus.present),
        AttendanceEntry(uid: 'a', date: '2026-11-03', status: AttendanceStatus.present),
        AttendanceEntry(uid: 'a', date: '2026-11-04', status: AttendanceStatus.leave),
        AttendanceEntry(uid: 'b', date: '2026-11-02', status: AttendanceStatus.present),
      ],
      today: DateTime(2026, 11, 10),
      generatedAt: DateTime(2026, 11, 10, 9),
    );

    test('rows are sorted by name with correct totals', () {
      expect(report.rows.map((r) => r.name), ['Ayesha, "Ash"', 'Bilal']);
      expect(report.table[0].sublist(2), ['2', '0', '1', '100.0']);
      expect(report.table[1].sublist(2), ['1', '2', '0', '33.3']); // 3rd and 4th missed
    });

    test('CSV quotes commas and quotes (RFC 4180)', () {
      final lines = report.toCsv().split('\r\n');
      expect(lines.first, 'Name,Email,Present,Absent,Leave,Attendance %');
      expect(lines[1], '"Ayesha, ""Ash""",ash@example.com,2,0,1,100.0');
      expect(lines[2], 'Bilal,bilal@example.com,1,2,0,33.3');
    });
  });

  group('Validators', () {
    test('password needs 8+ characters with a letter and a number', () {
      expect(Validators.password('short1'), isNotNull);
      expect(Validators.password('longpassword'), isNotNull);
      expect(Validators.password('longpass1'), isNull);
    });

    test('email and leave reason', () {
      expect(Validators.email('a@b.co'), isNull);
      expect(Validators.email('not-an-email'), isNotNull);
      expect(Validators.leaveReason('ok'), isNotNull);
      expect(Validators.leaveReason('Family wedding'), isNull);
    });
  });
}
