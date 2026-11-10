import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/leave_request.dart';
import '../../services.dart';
import '../common/profile_screen.dart';
import 'dashboard_screen.dart';
import 'leave_requests_screen.dart';
import 'people_screen.dart';
import 'reports_screen.dart';

class AdminShell extends StatefulWidget {
  const AdminShell({super.key, required this.me});
  final AppUser me;
  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _tab = 0;
  late final Stream<List<LeaveRequest>> _pending = Services.leave.watchByStatus(LeaveStatus.pending);

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardScreen(me: widget.me, onOpenLeave: () => setState(() => _tab = 2)),
      PeopleScreen(me: widget.me),
      LeaveRequestsScreen(me: widget.me),
      ReportsScreen(me: widget.me),
      ProfileScreen(me: widget.me),
    ];
    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: StreamBuilder<List<LeaveRequest>>(
        stream: _pending,
        builder: (context, snap) {
          final pending = snap.data?.length ?? 0;
          return NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            destinations: [
              const NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Today'),
              const NavigationDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups), label: 'People'),
              NavigationDestination(
                icon: Badge(isLabelVisible: pending > 0, label: Text('$pending'), child: const Icon(Icons.inbox_outlined)),
                selectedIcon: Badge(isLabelVisible: pending > 0, label: Text('$pending'), child: const Icon(Icons.inbox)),
                label: 'Leave',
              ),
              const NavigationDestination(icon: Icon(Icons.summarize_outlined), selectedIcon: Icon(Icons.summarize), label: 'Reports'),
              const NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
            ],
          );
        },
      ),
    );
  }
}
