import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/dates.dart';
import '../models/attendance_status.dart';
import '../models/leave_request.dart';

/// Leave requests at `leaveRequests/{id}`.
class LeaveRepository {
  LeaveRepository({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _requests => _db.collection('leaveRequests');

  Future<void> submit({
    required String uid,
    required String name,
    required DateTime from,
    required DateTime to,
    required String reason,
  }) {
    return _requests.add({
      'uid': uid,
      'name': name,
      'from': Dates.dayKey(from),
      'to': Dates.dayKey(to),
      'reason': reason.trim(),
      'status': LeaveStatus.pending.value,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// The signed-in user's own requests, newest first.
  Stream<List<LeaveRequest>> watchMine(String uid) => _requests
      .where('uid', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .snapshots()
      .map(_toList);

  /// Admin: requests with one status, newest first.
  Stream<List<LeaveRequest>> watchByStatus(LeaveStatus status) => _requests
      .where('status', isEqualTo: status.value)
      .orderBy('createdAt', descending: true)
      .limit(100)
      .snapshots()
      .map(_toList);

  /// The user withdraws a request that hasn't been decided yet.
  Future<void> cancel(LeaveRequest r) => _requests.doc(r.id).delete();

  /// Admin approves: the request and every working day it covers are updated
  /// together in one batch, so they can't get out of step.
  Future<void> approve(LeaveRequest r, {required String adminUid, String? note}) async {
    final batch = _db.batch();
    batch.update(_requests.doc(r.id), {
      'status': LeaveStatus.approved.value,
      'decidedAt': FieldValue.serverTimestamp(),
      'decidedBy': adminUid,
      if (note != null && note.trim().isNotEmpty) 'adminNote': note.trim(),
    });
    for (final day in Dates.workingDaysBetween(r.fromDate, r.toDate)) {
      final key = Dates.dayKey(day);
      batch.set(_db.collection('attendance').doc(r.uid).collection('days').doc(key), {
        'uid': r.uid,
        'date': key,
        'status': AttendanceStatus.leave.value,
        'markedAt': FieldValue.serverTimestamp(),
        'markedBy': adminUid,
      });
    }
    await batch.commit();
  }

  Future<void> reject(LeaveRequest r, {required String adminUid, String? note}) {
    return _requests.doc(r.id).update({
      'status': LeaveStatus.rejected.value,
      'decidedAt': FieldValue.serverTimestamp(),
      'decidedBy': adminUid,
      if (note != null && note.trim().isNotEmpty) 'adminNote': note.trim(),
    });
  }

  static List<LeaveRequest> _toList(QuerySnapshot<Map<String, dynamic>> q) =>
      q.docs.map(LeaveRequest.fromDoc).toList();
}
