import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/dates.dart';
import '../../models/app_user.dart';
import '../../models/attendance_status.dart';
import '../../services.dart';
import '../user/history_screen.dart';
import '../widgets.dart';

/// One person, for admins: their attendance calendar (tap a day to correct
/// it), plus role and access controls.
class PersonScreen extends StatefulWidget {
  const PersonScreen({super.key, required this.me, required this.person});
  final AppUser me;
  final AppUser person;
  @override
  State<PersonScreen> createState() => _PersonScreenState();
}

class _PersonScreenState extends State<PersonScreen> {
  final DateTime _today = Dates.orgToday();
  late DateTime _month = Dates.firstOfMonth(_today);

  bool get _isSelf => widget.person.uid == widget.me.uid;

  Future<void> _editDay(DateTime day, AttendanceStatus? current) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(DateFormat('EEEE, d MMMM yyyy').format(day), style: Theme.of(ctx).textTheme.titleMedium),
          ),
          for (final s in [AttendanceStatus.present, AttendanceStatus.absent, AttendanceStatus.leave])
            ListTile(
              leading: Icon(s.icon, color: s.color),
              title: Text('Mark ${s.label.toLowerCase()}'),
              trailing: current == s ? const Icon(Icons.check_rounded) : null,
              onTap: () => Navigator.pop(ctx, s.value),
            ),
          if (current != null && current.isStored)
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: const Text('Clear this day'),
              onTap: () => Navigator.pop(ctx, 'clear'),
            ),
        ]),
      ),
    );
    if (choice == null || !mounted) return;
    await runGuarded(context, () async {
      if (choice == 'clear') {
        await Services.attendance.adminClearDay(widget.person.uid, day);
      } else {
        await Services.attendance.adminSetDay(
          uid: widget.person.uid,
          day: day,
          status: AttendanceStatus.fromValue(choice),
          adminUid: widget.me.uid,
        );
      }
    });
  }

  Future<void> _confirm({required String title, required String message, required String action, required Future<void> Function() run}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(action)),
        ],
      ),
    );
    if (ok == true && mounted) await runGuarded(context, run);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: Services.users.watch(widget.person.uid),
      initialData: widget.person,
      builder: (context, snap) {
        final p = snap.data ?? widget.person;
        return Scaffold(
          appBar: AppBar(
            title: Text(p.name),
            actions: [
              if (!_isSelf)
                PopupMenuButton<String>(
                  onSelected: (v) {
                    switch (v) {
                      case 'role':
                        _confirm(
                          title: p.isAdmin ? 'Remove admin rights?' : 'Make ${p.name} an admin?',
                          message: p.isAdmin
                              ? '${p.name} will become a regular member.'
                              : 'Admins can see everyone, edit attendance, approve leave and manage people.',
                          action: p.isAdmin ? 'Remove' : 'Make admin',
                          run: () => Services.users.setRole(p.uid, p.isAdmin ? UserRole.user : UserRole.admin),
                        );
                      case 'active':
                        _confirm(
                          title: p.active ? 'Deactivate ${p.name}?' : 'Reactivate ${p.name}?',
                          message: p.active
                              ? "They won't be able to check in or request leave. Their history is kept."
                              : 'They can use the app again.',
                          action: p.active ? 'Deactivate' : 'Reactivate',
                          run: () => Services.users.setActive(p.uid, !p.active),
                        );
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'role', child: Text(p.isAdmin ? 'Remove admin rights' : 'Make admin')),
                    PopupMenuItem(value: 'active', child: Text(p.active ? 'Deactivate account' : 'Reactivate account')),
                  ],
                ),
            ],
          ),
          body: Column(children: [
            ListTile(
              leading: UserAvatar(user: p, radius: 26),
              title: Text(p.email),
              subtitle: Text('Joined ${DateFormat('d MMM yyyy').format(p.createdAt)}'),
              trailing: Wrap(spacing: 6, children: [
                if (p.isAdmin) Pill(label: 'Admin', color: Theme.of(context).colorScheme.primary),
                if (!p.active) Pill(label: 'Inactive', color: Theme.of(context).colorScheme.error),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('Tap a day to correct it.', style: Theme.of(context).textTheme.bodySmall),
            ),
            Expanded(
              child: AttendanceMonthView(
                user: p,
                month: _month,
                today: _today,
                onMonthChanged: (m) => setState(() => _month = m),
                onDayTap: _editDay,
              ),
            ),
          ]),
        );
      },
    );
  }
}
