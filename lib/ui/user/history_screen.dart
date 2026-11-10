import 'package:flutter/material.dart';

import '../../core/attendance_summary.dart';
import '../../core/dates.dart';
import '../../models/app_user.dart';
import '../../models/attendance_status.dart';
import '../../services.dart';
import '../common/month_calendar.dart';
import '../widgets.dart';

/// A user's own attendance, month by month.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, required this.me});
  final AppUser me;
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final DateTime _today = Dates.orgToday();
  late DateTime _month = Dates.firstOfMonth(_today);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: AttendanceMonthView(user: widget.me, month: _month, today: _today, onMonthChanged: (m) => setState(() => _month = m)),
    );
  }
}

/// Calendar + totals for one user and month. Shared with the admin's
/// person screen, which passes [onDayTap] to allow corrections.
class AttendanceMonthView extends StatelessWidget {
  const AttendanceMonthView({
    super.key,
    required this.user,
    required this.month,
    required this.today,
    required this.onMonthChanged,
    this.onDayTap,
  });

  final AppUser user;
  final DateTime month;
  final DateTime today;
  final ValueChanged<DateTime> onMonthChanged;
  final void Function(DateTime day, AttendanceStatus? status)? onDayTap;

  @override
  Widget build(BuildContext context) {
    final from = Dates.firstOfMonth(month);
    final to = Dates.lastOfMonth(month);
    return StreamBuilder<Map<String, AttendanceStatus>>(
      key: ValueKey('${user.uid}-${Dates.dayKey(from)}'),
      stream: Services.attendance.watchRange(user.uid, from, to),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: EmptyState(icon: Icons.cloud_off_rounded, title: "Couldn't load attendance", message: '${snap.error}'));
        }
        final calc = AttendanceCalculator(
          records: snap.data ?? const {},
          joinedOn: Dates.orgToday(user.createdAt),
          today: today,
        );
        final summary = calc.summarize(from, to);
        return ListView(padding: const EdgeInsets.all(16), children: [
          MonthSwitcher(month: month, latest: today, onChanged: onMonthChanged),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: snap.hasData
                  ? MonthCalendar(month: month, calculator: calc, onDayTap: onDayTap)
                  : const SizedBox(height: 260, child: Center(child: CircularProgressIndicator())),
            ),
          ),
          const SizedBox(height: 12),
          const CalendarLegend(),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: StatTile(label: 'Present', value: '${summary.present}', color: AttendanceStatus.present.color)),
            const SizedBox(width: 8),
            Expanded(child: StatTile(label: 'Absent', value: '${summary.absent}', color: AttendanceStatus.absent.color)),
            const SizedBox(width: 8),
            Expanded(child: StatTile(label: 'Leave', value: '${summary.leave}', color: AttendanceStatus.leave.color)),
          ]),
          const SizedBox(height: 8),
          Text(
            'Attendance ${summary.attendanceRate.toStringAsFixed(1)}%  ·  working days with no record count as absent',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ]);
      },
    );
  }
}
