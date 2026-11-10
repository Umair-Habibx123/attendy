import 'package:flutter/material.dart';

import '../../core/attendance_summary.dart';
import '../../core/dates.dart';
import '../../models/attendance_status.dart';

/// A month grid with each day coloured by its attendance status.
class MonthCalendar extends StatelessWidget {
  const MonthCalendar({super.key, required this.month, required this.calculator, this.onDayTap});

  final DateTime month;
  final AttendanceCalculator calculator;

  /// When set (admins), days can be tapped to change their status.
  final void Function(DateTime day, AttendanceStatus? status)? onDayTap;

  static const _weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final first = Dates.firstOfMonth(month);
    final daysInMonth = Dates.lastOfMonth(month).day;
    final leadingBlanks = first.weekday - 1;
    final cells = leadingBlanks + daysInMonth;
    final rows = (cells / 7).ceil();

    return Column(children: [
      Row(
        children: [
          for (final w in _weekdays)
            Expanded(
              child: Center(
                child: Text(w, style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ),
            ),
        ],
      ),
      const SizedBox(height: 6),
      for (var r = 0; r < rows; r++)
        Row(children: [
          for (var c = 0; c < 7; c++) Expanded(child: _cell(context, r * 7 + c - leadingBlanks + 1, daysInMonth)),
        ]),
    ]);
  }

  Widget _cell(BuildContext context, int dayNumber, int daysInMonth) {
    if (dayNumber < 1 || dayNumber > daysInMonth) return const SizedBox(height: 44);
    final theme = Theme.of(context);
    final day = DateTime(month.year, month.month, dayNumber);
    final status = calculator.statusOn(day);
    final isToday = day == calculator.today;
    final color = status?.color;
    final label = '${Dates.dayKey(day)}: ${status?.label ?? (Dates.isWorkingDay(day) ? 'no record' : 'day off')}';

    return Semantics(
      label: label,
      button: onDayTap != null,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onDayTap == null ? null : () => onDayTap!(day, status),
          child: Container(
            height: 40,
            decoration: BoxDecoration(
              color: color?.withValues(alpha: status == AttendanceStatus.notMarked ? 0.08 : 0.16),
              borderRadius: BorderRadius.circular(10),
              border: isToday ? Border.all(color: theme.colorScheme.primary, width: 2) : null,
            ),
            alignment: Alignment.center,
            child: Text(
              '$dayNumber',
              style: TextStyle(
                fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                color: color ?? (Dates.isWorkingDay(day) ? null : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The colour legend under a calendar.
class CalendarLegend extends StatelessWidget {
  const CalendarLegend({super.key});
  @override
  Widget build(BuildContext context) {
    const items = [AttendanceStatus.present, AttendanceStatus.leave, AttendanceStatus.absent, AttendanceStatus.missed];
    return Wrap(spacing: 14, runSpacing: 6, children: [
      for (final s in items)
        Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: s.color, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 6),
          Text(s.label, style: Theme.of(context).textTheme.bodySmall),
        ]),
    ]);
  }
}
