import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/leave_request.dart';
import '../../services.dart';
import '../user/leave_screen.dart';
import '../widgets.dart';

/// Admin inbox: pending requests to decide, plus recent decisions.
class LeaveRequestsScreen extends StatelessWidget {
  const LeaveRequestsScreen({super.key, required this.me});
  final AppUser me;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Leave requests'),
          bottom: const TabBar(tabs: [Tab(text: 'Pending'), Tab(text: 'Approved'), Tab(text: 'Rejected')]),
        ),
        body: TabBarView(children: [
          _RequestList(me: me, status: LeaveStatus.pending),
          _RequestList(me: me, status: LeaveStatus.approved),
          _RequestList(me: me, status: LeaveStatus.rejected),
        ]),
      ),
    );
  }
}

class _RequestList extends StatefulWidget {
  const _RequestList({required this.me, required this.status});
  final AppUser me;
  final LeaveStatus status;
  @override
  State<_RequestList> createState() => _RequestListState();
}

class _RequestListState extends State<_RequestList> with AutomaticKeepAliveClientMixin {
  late final Stream<List<LeaveRequest>> _stream = Services.leave.watchByStatus(widget.status);
  final Set<String> _busy = {};

  @override
  bool get wantKeepAlive => true;

  Future<void> _decide(LeaveRequest r, bool approve) async {
    final note = await _askNote(approve);
    if (note == null || !mounted) return; // cancelled
    setState(() => _busy.add(r.id));
    await runGuarded(context, () async {
      if (approve) {
        await Services.leave.approve(r, adminUid: widget.me.uid, note: note);
        if (mounted) showMessage(context, 'Approved. ${r.workingDayCount} day(s) marked as leave for ${r.name}.');
      } else {
        await Services.leave.reject(r, adminUid: widget.me.uid, note: note);
        if (mounted) showMessage(context, 'Request rejected.');
      }
    });
    if (mounted) setState(() => _busy.remove(r.id));
  }

  /// Returns the optional note, or null if the admin cancelled.
  Future<String?> _askNote(bool approve) {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(approve ? 'Approve leave?' : 'Reject leave?'),
        content: TextField(
          controller: c,
          maxLength: 300,
          decoration: InputDecoration(labelText: approve ? 'Note (optional)' : 'Reason (optional)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, c.text), child: Text(approve ? 'Approve' : 'Reject')),
        ],
      ),
    ).whenComplete(c.dispose);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return StreamBuilder<List<LeaveRequest>>(
      stream: _stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: EmptyState(icon: Icons.cloud_off_rounded, title: "Couldn't load requests", message: '${snap.error}'));
        }
        if (!snap.hasData) return const Center(child: CircularProgressIndicator());
        final requests = snap.data!;
        if (requests.isEmpty) {
          return Center(
            child: EmptyState(
              icon: Icons.inbox_outlined,
              title: widget.status == LeaveStatus.pending ? 'Nothing to review' : 'No ${widget.status.label.toLowerCase()} requests',
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: requests.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final r = requests[i];
            final busy = _busy.contains(r.id);
            return LeaveCard(
              request: r,
              showName: true,
              trailing: widget.status != LeaveStatus.pending
                  ? null
                  : busy
                      ? const Padding(padding: EdgeInsets.all(8), child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)))
                      : Row(mainAxisSize: MainAxisSize.min, children: [
                          TextButton(onPressed: () => _decide(r, false), child: const Text('Reject')),
                          const SizedBox(width: 4),
                          FilledButton(
                            style: FilledButton.styleFrom(minimumSize: const Size(0, 40)),
                            onPressed: () => _decide(r, true),
                            child: const Text('Approve'),
                          ),
                        ]),
            );
          },
        );
      },
    );
  }
}
