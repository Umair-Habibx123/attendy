import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../services.dart';
import '../widgets.dart';
import 'person_screen.dart';

/// Everyone with an account. Tap a person to see their attendance and
/// manage their role or access.
class PeopleScreen extends StatefulWidget {
  const PeopleScreen({super.key, required this.me});
  final AppUser me;
  @override
  State<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends State<PeopleScreen> {
  late final Stream<List<AppUser>> _users = Services.users.watchAll();
  String _query = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('People')),
      body: StreamBuilder<List<AppUser>>(
        stream: _users,
        builder: (context, snap) {
          if (snap.hasError) {
            return Center(child: EmptyState(icon: Icons.cloud_off_rounded, title: "Couldn't load people", message: '${snap.error}'));
          }
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final q = _query.toLowerCase();
          final people = snap.data!
              .where((u) => q.isEmpty || u.name.toLowerCase().contains(q) || u.email.toLowerCase().contains(q))
              .toList();
          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                decoration: const InputDecoration(hintText: 'Search by name or email', prefixIcon: Icon(Icons.search_rounded)),
              ),
            ),
            Expanded(
              child: people.isEmpty
                  ? const Center(child: EmptyState(icon: Icons.person_search_outlined, title: 'Nobody found'))
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: people.length,
                      itemBuilder: (context, i) {
                        final u = people[i];
                        return ListTile(
                          leading: UserAvatar(user: u),
                          title: Text(u.uid == widget.me.uid ? '${u.name} (you)' : u.name),
                          subtitle: Text(u.email),
                          trailing: Wrap(spacing: 6, children: [
                            if (u.isAdmin) Pill(label: 'Admin', color: Theme.of(context).colorScheme.primary),
                            if (!u.active) Pill(label: 'Inactive', color: Theme.of(context).colorScheme.error),
                          ]),
                          onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => PersonScreen(me: widget.me, person: u))),
                        );
                      },
                    ),
            ),
          ]);
        },
      ),
    );
  }
}
