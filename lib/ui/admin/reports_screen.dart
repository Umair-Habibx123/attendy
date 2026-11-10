import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/dates.dart';
import '../../models/app_user.dart';
import '../../reports/report.dart';
import '../../services.dart';
import '../widgets.dart';

/// Builds an attendance report for a date range and exports it as CSV
/// (spreadsheets) or PDF (printing and sharing).
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key, required this.me});
  final AppUser me;
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final DateTime _today = Dates.orgToday();
  late DateTimeRange _range = DateTimeRange(start: Dates.firstOfMonth(_today), end: _today);
  bool _includeAdmins = false;
  AttendanceReport? _report;
  bool _loading = false;

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(_today.year - 3),
      lastDate: _today,
      initialDateRange: _range,
      helpText: 'Report period',
    );
    if (picked != null) {
      setState(() {
        _range = picked;
        _report = null;
      });
    }
  }

  void _setPreset(DateTime from, DateTime to) => setState(() {
        _range = DateTimeRange(start: from, end: to.isAfter(_today) ? _today : to);
        _report = null;
      });

  Future<void> _generate() async {
    setState(() => _loading = true);
    await runGuarded(context, () async {
      final users = await Services.users.fetchAll();
      final entries = await Services.attendance.fetchRangeAcrossUsers(_range.start, _range.end);
      final included = users.where((u) => _includeAdmins || !u.isAdmin).toList();
      setState(() => _report = AttendanceReport.build(from: _range.start, to: _range.end, users: included, entries: entries));
    });
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = DateFormat('d MMM yyyy');
    final lastMonth = DateTime(_today.year, _today.month - 1);
    final report = _report;
    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('Period', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _pickRange,
                icon: const Icon(Icons.date_range_rounded),
                label: Text('${fmt.format(_range.start)} – ${fmt.format(_range.end)}'),
              ),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: [
                ActionChip(label: const Text('This month'), onPressed: () => _setPreset(Dates.firstOfMonth(_today), _today)),
                ActionChip(label: const Text('Last month'), onPressed: () => _setPreset(Dates.firstOfMonth(lastMonth), Dates.lastOfMonth(lastMonth))),
                ActionChip(label: const Text('This year'), onPressed: () => _setPreset(DateTime(_today.year), _today)),
              ]),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Include admins'),
                value: _includeAdmins,
                onChanged: (v) => setState(() {
                  _includeAdmins = v;
                  _report = null;
                }),
              ),
              FilledButton.icon(
                onPressed: _loading ? null : _generate,
                icon: _loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5))
                    : const Icon(Icons.analytics_outlined),
                label: const Text('Generate report'),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 16),
        if (report != null) ...[
          Row(children: [
            Expanded(child: Text('${report.rows.length} people', style: theme.textTheme.titleMedium)),
            TextButton.icon(
              onPressed: () => runGuarded(context, () => Services.reports.shareCsv(report)),
              icon: const Icon(Icons.table_chart_outlined),
              label: const Text('CSV'),
            ),
            TextButton.icon(
              onPressed: () => runGuarded(context, () => Services.reports.sharePdf(report)),
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('PDF'),
            ),
          ]),
          const SizedBox(height: 8),
          Card(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Name')),
                  DataColumn(label: Text('Present'), numeric: true),
                  DataColumn(label: Text('Absent'), numeric: true),
                  DataColumn(label: Text('Leave'), numeric: true),
                  DataColumn(label: Text('Rate'), numeric: true),
                ],
                rows: [
                  for (final r in report.rows)
                    DataRow(cells: [
                      DataCell(Text(r.name)),
                      DataCell(Text('${r.summary.present}')),
                      DataCell(Text('${r.summary.absent}')),
                      DataCell(Text('${r.summary.leave}')),
                      DataCell(Text('${r.summary.attendanceRate.toStringAsFixed(0)}%')),
                    ]),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text('Absent includes working days with no check-in.', style: theme.textTheme.bodySmall),
        ],
      ]),
    );
  }
}
