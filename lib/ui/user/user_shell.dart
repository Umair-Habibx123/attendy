import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../common/profile_screen.dart';
import 'history_screen.dart';
import 'leave_screen.dart';
import 'today_screen.dart';

class UserShell extends StatefulWidget {
  const UserShell({super.key, required this.me});
  final AppUser me;
  @override
  State<UserShell> createState() => _UserShellState();
}

class _UserShellState extends State<UserShell> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      TodayScreen(me: widget.me),
      HistoryScreen(me: widget.me),
      LeaveScreen(me: widget.me),
      ProfileScreen(me: widget.me),
    ];
    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.today_outlined), selectedIcon: Icon(Icons.today), label: 'Today'),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: 'History'),
          NavigationDestination(icon: Icon(Icons.beach_access_outlined), selectedIcon: Icon(Icons.beach_access), label: 'Leave'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
