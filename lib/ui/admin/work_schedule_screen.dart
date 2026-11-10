import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/dates.dart';
import '../../core/work_schedule.dart';
import '../../models/app_user.dart';
import '../../services.dart';
import '../widgets.dart';

/// Admin: choose the working weekdays and add named holidays (single days or
/// ranges). Everyone's attendance, leave and reports use this schedule as soon
/// as it's saved.
class WorkScheduleScreen extends StatefulWidget {
  const WorkScheduleScreen({super.key, required this.me});
  final AppUser me;
  @override
  State<WorkScheduleScreen> createState() => _WorkScheduleScreenState();
}

class _WorkScheduleScreenState extends State<WorkScheduleScreen> {
  late WorkSchedule _draft = WorkSchedule.current;
  bool _saving = false;

  static const _names = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  bool get _changed => _draft != WorkSchedule.current;

  Future<void> _addHoliday() async {
    final result = await showModalBottomSheet<(DateTimeRange, String)>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _AddHolidaySheet(),
    );
    if (result == null) return;
    final (range, name) = result;
    setState(() => _draft = _draft.withHolidayRange(range.start, range.end, name));
  }

  Future<void> _save() async {
    if (_draft.workingDays.isEmpty) {
      showMessage(context, 'Choose at least one working day.');
      return;
    }
    setState(() => _saving = true);
    await runGuarded(context, () async {
      await Services.settings.saveSchedule(_draft, adminUid: widget.me.uid);
      if (!mounted) return;
      showMessage(context, 'Work schedule saved. It applies to everyone right away.');
      Navigator.pop(context);
    });
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = Dates.orgToday();
    final monthWorking = Dates.daysBetween(Dates.firstOfMonth(today), Dates.lastOfMonth(today))
        .where(_draft.isWorkingDay)
        .length;
    final groups = _draft.holidayGroups;
    final fmt = DateFormat('EEE d MMM yyyy');

    return Scaffold(
      appBar: AppBar(title: const Text('Work schedule')),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: _saving || !_changed ? null : _save,
            child: _saving
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                : const Text('Save schedule'),
          ),
        ),
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text('Working days', style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          "Days people are expected to check in. Other days never count as absent, and leave doesn't use them.",
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (var d = 1; d <= 7; d++)
            FilterChip(
              label: Text(_names[d - 1]),
              selected: _draft.workingDays.contains(d),
              onSelected: (on) => setState(() => _draft = _draft.withWorkingDays(
                    on ? {..._draft.workingDays, d} : ({..._draft.workingDays}..remove(d)),
                  )),
            ),
        ]),
        const SizedBox(height: 8),
        Text('$monthWorking working days in ${DateFormat('MMMM').format(today)}', style: theme.textTheme.bodySmall),
        const SizedBox(height: 28),
        Row(children: [
          Expanded(child: Text('Holidays', style: theme.textTheme.titleMedium)),
          TextButton.icon(onPressed: _addHoliday, icon: const Icon(Icons.add_rounded), label: const Text('Add')),
        ]),
        Text(
          'Named days off, such as Eid or Independence Day. Add one day or several at once. They never count as absent.',
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        if (groups.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text('No holidays added.', style: theme.textTheme.bodyMedium),
          )
        else
          Card(
            child: Column(children: [
              for (final g in groups)
                ListTile(
                  leading: const Icon(Icons.celebration_outlined),
                  title: Text(g.name.isEmpty ? 'Holiday' : g.name),
                  subtitle: Text(g.keys.length == 1
                      ? fmt.format(Dates.parseDayKey(g.keys.first))
                      : '${fmt.format(Dates.parseDayKey(g.keys.first))} – ${fmt.format(Dates.parseDayKey(g.keys.last))} · ${g.keys.length} days'),
                  trailing: IconButton(
                    tooltip: 'Remove holiday',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => setState(() => _draft = _draft.withoutHolidays(g.keys)),
                  ),
                ),
            ]),
          ),
      ]),
    );
  }
}

/// Name plus one day or a range of days.
class _AddHolidaySheet extends StatefulWidget {
  const _AddHolidaySheet();
  @override
  State<_AddHolidaySheet> createState() => _AddHolidaySheetState();
}

class _AddHolidaySheetState extends State<_AddHolidaySheet> {
  final _name = TextEditingController();
  DateTimeRange? _range;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final today = Dates.orgToday();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(today.year - 1),
      lastDate: DateTime(today.year + 2, 12, 31),
      initialDateRange: _range,
      helpText: 'Holiday dates (tap the same day twice for one day)',
    );
    if (picked != null) setState(() => _range = picked);
  }

  @override
  Widget build(BuildContext context) {
    final r = _range;
    final fmt = DateFormat('EEE d MMM');
    final days = r == null ? 0 : r.end.difference(r.start).inDays + 1;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Add holiday', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        TextField(
          controller: _name,
          autofocus: true,
          maxLength: 40,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. Eid ul-Adha'),
        ),
        const SizedBox(height: 4),
        OutlinedButton.icon(
          onPressed: _pick,
          icon: const Icon(Icons.date_range_rounded),
          label: Text(r == null
              ? 'Choose date(s)'
              : days == 1
                  ? fmt.format(r.start)
                  : '${fmt.format(r.start)} – ${fmt.format(r.end)}  ($days days)'),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: r == null ? null : () => Navigator.pop(context, (r, _name.text)),
          child: const Text('Add'),
        ),
      ]),
    );
  }
}
