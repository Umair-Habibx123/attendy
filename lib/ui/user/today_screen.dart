import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/attendance_summary.dart';
import '../../core/dates.dart';
import '../../core/work_schedule.dart';
import '../../models/app_user.dart';
import '../../models/attendance_status.dart';
import '../../services.dart';
import '../widgets.dart';

/// Today's status, a one-tap check-in, and this month's totals.
class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key, required this.me});
  final AppUser me;
  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  bool _busy = false;
  late final DateTime _today = Dates.orgToday();
  late final Stream<Map<String, AttendanceStatus>> _month = Services.attendance
      .watchRange(widget.me.uid, Dates.firstOfMonth(_today), Dates.lastOfMonth(_today));

  Future<void> _checkIn() async {
    setState(() => _busy = true);
    await runGuarded(context, () async {
      await Services.attendance.markPresentToday(widget.me.uid);
      if (mounted) showMessage(context, "You're checked in for today.");
    });
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final firstName = widget.me.name.split(' ').first;
    return Scaffold(
      appBar: AppBar(title: Text('Hi, $firstName')),
      body: StreamBuilder<Map<String, AttendanceStatus>>(
        stream: _month,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: EmptyState(icon: Icons.cloud_off_rounded, title: "Couldn't load attendance", message: '${snap.error}'));
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final calc = AttendanceCalculator(records: snap.data!, joinedOn: Dates.orgToday(widget.me.createdAt), today: _today);
          final todayStatus = calc.statusOn(_today);
          final summary = calc.summarize(Dates.firstOfMonth(_today), _today);
          final canCheckIn = todayStatus == AttendanceStatus.notMarked ||
              (todayStatus == null && !Dates.isWorkingDay(_today) && !snap.data!.containsKey(Dates.dayKey(_today)));

          return ListView(padding: const EdgeInsets.all(16), children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(DateFormat('EEEE, d MMMM').format(_today), style: theme.textTheme.titleMedium),
                  const SizedBox(height: 12),
                  if (todayStatus != null && todayStatus != AttendanceStatus.notMarked)
                    Row(children: [
                      Icon(todayStatus.icon, color: todayStatus.color, size: 40),
                      const SizedBox(width: 12),
                      Expanded(child: Text(_statusLine(todayStatus), style: theme.textTheme.titleLarge)),
                    ])
                  else ...[
                    Text(
                      Dates.isWorkingDay(_today)
                          ? "You haven't checked in yet."
                          : WorkSchedule.current.isHoliday(_today)
                              ? 'Today is a holiday: ${WorkSchedule.current.holidayName(_today)}. You can still check in.'
                              : "It's a day off, but you can still check in.",
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _busy || !canCheckIn ? null : _checkIn,
                      icon: _busy
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5))
                          : const Icon(Icons.how_to_reg_rounded),
                      label: const Text("I'm here"),
                    ),
                    const SizedBox(height: 8),
                    Text('Recorded with the server time, so the date on your phone doesn\'t matter.',
                        style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ]),
              ),
            ),
            const SizedBox(height: 20),
            Text('This month', style: theme.textTheme.titleMedium),
            const SizedBox(height: 10),
            _SummaryRow(summary: summary),
          ]);
        },
      ),
    );
  }

  String _statusLine(AttendanceStatus s) => switch (s) {
        AttendanceStatus.present => "You're checked in",
        AttendanceStatus.leave => "You're on leave today",
        AttendanceStatus.absent => 'Marked absent today',
        _ => s.label,
      };
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.summary});
  final AttendanceSummary summary;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.7,
      children: [
        StatTile(label: 'Present', value: '${summary.present}', color: AttendanceStatus.present.color, icon: AttendanceStatus.present.icon),
        StatTile(label: 'Absent', value: '${summary.absent}', color: AttendanceStatus.absent.color, icon: AttendanceStatus.absent.icon),
        StatTile(label: 'On leave', value: '${summary.leave}', color: AttendanceStatus.leave.color, icon: AttendanceStatus.leave.icon),
        StatTile(
          label: 'Attendance',
          value: '${summary.attendanceRate.toStringAsFixed(0)}%',
          color: Theme.of(context).colorScheme.primary,
          icon: Icons.insights_rounded,
        ),
      ],
    );
  }
}
