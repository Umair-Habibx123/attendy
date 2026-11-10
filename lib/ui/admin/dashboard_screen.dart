import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/dates.dart';
import '../../core/work_schedule.dart';
import '../../data/attendance_repository.dart';
import '../../models/app_user.dart';
import '../../models/attendance_status.dart';
import '../../models/leave_request.dart';
import '../../services.dart';
import '../widgets.dart';
import 'person_screen.dart';

/// Today at a glance: who's in, who's on leave, who hasn't checked in.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.me, required this.onOpenLeave});
  final AppUser me;
  final VoidCallback onOpenLeave;
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DateTime _today = Dates.orgToday();
  late final Stream<List<AppUser>> _users = Services.users.watchAll();
  late final Stream<List<AttendanceEntry>> _todayEntries = Services.attendance.watchDateAcrossUsers(Dates.dayKey(_today));
  late final Stream<List<LeaveRequest>> _pending = Services.leave.watchByStatus(LeaveStatus.pending);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Today')),
      body: StreamBuilder<List<AppUser>>(
        stream: _users,
        builder: (context, usersSnap) => StreamBuilder<List<AttendanceEntry>>(
          stream: _todayEntries,
          builder: (context, entriesSnap) {
            final error = usersSnap.error ?? entriesSnap.error;
            if (error != null) {
              return Center(child: EmptyState(icon: Icons.cloud_off_rounded, title: "Couldn't load today", message: '$error'));
            }
            if (!usersSnap.hasData || !entriesSnap.hasData) return const Center(child: CircularProgressIndicator());

            final members = usersSnap.data!.where((u) => u.active && !u.isAdmin).toList();
            final status = {for (final e in entriesSnap.data!) e.uid: e.status};
            int count(AttendanceStatus s) => members.where((u) => status[u.uid] == s).length;
            final waiting = members.where((u) => !status.containsKey(u.uid)).toList();

            return ListView(padding: const EdgeInsets.all(16), children: [
              Text(DateFormat('EEEE, d MMMM yyyy').format(_today), style: theme.textTheme.titleMedium),
              const SizedBox(height: 12),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.7,
                children: [
                  StatTile(label: 'Present', value: '${count(AttendanceStatus.present)}', color: AttendanceStatus.present.color, icon: AttendanceStatus.present.icon),
                  StatTile(label: 'On leave', value: '${count(AttendanceStatus.leave)}', color: AttendanceStatus.leave.color, icon: AttendanceStatus.leave.icon),
                  StatTile(label: 'Absent', value: '${count(AttendanceStatus.absent)}', color: AttendanceStatus.absent.color, icon: AttendanceStatus.absent.icon),
                  StatTile(label: 'Not checked in', value: '${waiting.length}', color: AttendanceStatus.notMarked.color, icon: AttendanceStatus.notMarked.icon),
                ],
              ),
              const SizedBox(height: 12),
              StreamBuilder<List<LeaveRequest>>(
                stream: _pending,
                builder: (context, snap) {
                  final n = snap.data?.length ?? 0;
                  if (n == 0) return const SizedBox.shrink();
                  return Card(
                    color: LeaveStatus.pending.color.withValues(alpha: 0.12),
                    child: ListTile(
                      leading: Icon(Icons.inbox_rounded, color: LeaveStatus.pending.color),
                      title: Text('$n leave request${n == 1 ? '' : 's'} waiting'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: widget.onOpenLeave,
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              Text(
                Dates.isWorkingDay(_today)
                    ? 'Not checked in yet'
                    : WorkSchedule.current.isHoliday(_today)
                        ? 'Not checked in (holiday: ${WorkSchedule.current.holidayName(_today)})'
                        : 'Not checked in (today is a day off)',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (members.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: EmptyState(icon: Icons.group_add_outlined, title: 'No members yet', message: 'People appear here after they sign up.'),
                )
              else if (waiting.isEmpty)
                Text('Everyone is accounted for. 🎉', style: theme.textTheme.bodyMedium)
              else
                Card(
                  child: Column(children: [
                    for (final u in waiting)
                      ListTile(
                        leading: UserAvatar(user: u),
                        title: Text(u.name),
                        subtitle: Text(u.email),
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PersonScreen(me: widget.me, person: u))),
                      ),
                  ]),
                ),
            ]);
          },
        ),
      ),
    );
  }
}
