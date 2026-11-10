import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/dates.dart';

enum LeaveStatus {
  pending('pending', 'Pending', Color(0xFFD97706)),
  approved('approved', 'Approved', Color(0xFF16A34A)),
  rejected('rejected', 'Rejected', Color(0xFFDC2626));

  const LeaveStatus(this.value, this.label, this.color);
  final String value;
  final String label;
  final Color color;

  static LeaveStatus fromValue(String? v) =>
      LeaveStatus.values.firstWhere((s) => s.value == v, orElse: () => LeaveStatus.pending);
}

/// A leave request, stored at `leaveRequests/{id}`. Admins approve or reject
/// it; approving also marks each working day in the range as leave.
class LeaveRequest {
  const LeaveRequest({
    required this.id,
    required this.uid,
    required this.name,
    required this.from,
    required this.to,
    required this.reason,
    required this.status,
    required this.createdAt,
    this.decidedAt,
    this.adminNote,
  });

  final String id;
  final String uid;
  final String name;

  /// Day keys (`yyyy-MM-dd`), inclusive.
  final String from;
  final String to;
  final String reason;
  final LeaveStatus status;
  final DateTime createdAt;
  final DateTime? decidedAt;
  final String? adminNote;

  DateTime get fromDate => Dates.parseDayKey(from);
  DateTime get toDate => Dates.parseDayKey(to);

  /// Working days the request covers.
  int get workingDayCount => Dates.workingDaysBetween(fromDate, toDate).length;

  factory LeaveRequest.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return LeaveRequest(
      id: doc.id,
      uid: d['uid'] as String? ?? '',
      name: d['name'] as String? ?? '',
      from: d['from'] as String? ?? Dates.todayKey(),
      to: d['to'] as String? ?? Dates.todayKey(),
      reason: d['reason'] as String? ?? '',
      status: LeaveStatus.fromValue(d['status'] as String?),
      // Pending server writes have no timestamp yet; treat them as "now".
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      decidedAt: (d['decidedAt'] as Timestamp?)?.toDate(),
      adminNote: d['adminNote'] as String?,
    );
  }
}
