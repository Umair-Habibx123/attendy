import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/config.dart';
import '../../core/dates.dart';
import '../../core/validators.dart';
import '../../models/app_user.dart';
import '../../models/leave_request.dart';
import '../../services.dart';
import '../widgets.dart';

/// The user's leave requests and a form to ask for more.
class LeaveScreen extends StatelessWidget {
  const LeaveScreen({super.key, required this.me});
  final AppUser me;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Leave')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (_) => _NewLeaveSheet(me: me),
        ),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Request leave'),
      ),
      body: StreamBuilder<List<LeaveRequest>>(
        stream: Services.leave.watchMine(me.uid),
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: EmptyState(icon: Icons.cloud_off_rounded, title: "Couldn't load requests", message: '${snap.error}'));
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final requests = snap.data!;
          if (requests.isEmpty) {
            return const Center(
              child: EmptyState(
                icon: Icons.beach_access_outlined,
                title: 'No leave requests yet',
                message: 'Tap "Request leave" to ask for time off. An admin will approve or reject it.',
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            itemCount: requests.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) => LeaveCard(
              request: requests[i],
              trailing: requests[i].status == LeaveStatus.pending
                  ? TextButton(
                      onPressed: () => runGuarded(context, () => Services.leave.cancel(requests[i])),
                      child: const Text('Withdraw'),
                    )
                  : null,
            ),
          );
        },
      ),
    );
  }
}

/// A leave request summary, used by users and admins.
class LeaveCard extends StatelessWidget {
  const LeaveCard({super.key, required this.request, this.showName = false, this.trailing});
  final LeaveRequest request;
  final bool showName;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = DateFormat('d MMM yyyy');
    final range = request.from == request.to
        ? fmt.format(request.fromDate)
        : '${fmt.format(request.fromDate)} – ${fmt.format(request.toDate)}';
    final days = request.workingDayCount;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text(showName ? request.name : range, style: theme.textTheme.titleMedium),
            ),
            Pill(label: request.status.label, color: request.status.color),
          ]),
          if (showName) ...[const SizedBox(height: 2), Text(range, style: theme.textTheme.bodyMedium)],
          const SizedBox(height: 4),
          Text('$days working day${days == 1 ? '' : 's'}',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          Text(request.reason),
          if (request.adminNote != null && request.adminNote!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Admin: ${request.adminNote}', style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
          ],
          if (trailing != null) Align(alignment: Alignment.centerRight, child: trailing),
        ]),
      ),
    );
  }
}

class _NewLeaveSheet extends StatefulWidget {
  const _NewLeaveSheet({required this.me});
  final AppUser me;
  @override
  State<_NewLeaveSheet> createState() => _NewLeaveSheetState();
}

class _NewLeaveSheetState extends State<_NewLeaveSheet> {
  final _form = GlobalKey<FormState>();
  final _reason = TextEditingController();
  final DateTime _today = Dates.orgToday();
  DateTimeRange? _range;
  bool _busy = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _pickDates() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: _today,
      lastDate: DateTime(_today.year + 1, _today.month, _today.day),
      initialDateRange: _range,
      helpText: 'Leave dates',
    );
    if (picked != null) setState(() => _range = picked);
  }

  Future<void> _submit() async {
    if (_range == null) {
      showMessage(context, 'Pick the dates first.');
      return;
    }
    if (!_form.currentState!.validate()) return;
    final days = _range!.end.difference(_range!.start).inDays + 1;
    if (days > AppConfig.maxLeaveDays) {
      showMessage(context, 'You can request up to ${AppConfig.maxLeaveDays} days at a time.');
      return;
    }
    setState(() => _busy = true);
    await runGuarded(context, () async {
      await Services.leave.submit(
        uid: widget.me.uid,
        name: widget.me.name,
        from: _range!.start,
        to: _range!.end,
        reason: _reason.text,
      );
      if (!mounted) return;
      Navigator.pop(context);
      showMessage(context, 'Leave requested. You\'ll see the decision here.');
    });
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat('EEE d MMM');
    final r = _range;
    final working = r == null ? 0 : Dates.workingDaysBetween(r.start, r.end).length;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: Form(
        key: _form,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Request leave', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _pickDates,
            icon: const Icon(Icons.date_range_rounded),
            label: Text(r == null ? 'Choose dates' : '${fmt.format(r.start)} – ${fmt.format(r.end)}  ($working working days)'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _reason,
            maxLines: 3,
            maxLength: 500,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Reason'),
            validator: Validators.leaveReason,
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                : const Text('Send request'),
          ),
        ]),
      ),
    );
  }
}
