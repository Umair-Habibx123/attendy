import 'package:flutter/material.dart';

/// What happened on a given day for a user.
///
/// Only [present], [absent] and [leave] are stored in Firestore.
/// [missed] and [notMarked] are derived when a working day has no record.
enum AttendanceStatus {
  present('present', 'Present', Icons.check_circle_rounded, Color(0xFF16A34A)),
  absent('absent', 'Absent', Icons.cancel_rounded, Color(0xFFDC2626)),
  leave('leave', 'On leave', Icons.beach_access_rounded, Color(0xFF2563EB)),

  /// A past working day with no record: counted as absent in summaries.
  missed('missed', 'Absent (not marked)', Icons.remove_circle_outline_rounded, Color(0xFFF97316)),

  /// Today, not marked yet.
  notMarked('not_marked', 'Not marked yet', Icons.schedule_rounded, Color(0xFF64748B));

  const AttendanceStatus(this.value, this.label, this.icon, this.color);

  final String value;
  final String label;
  final IconData icon;
  final Color color;

  bool get isStored => this == present || this == absent || this == leave;

  static AttendanceStatus fromValue(String? value) => AttendanceStatus.values.firstWhere(
        (s) => s.value == value,
        orElse: () => AttendanceStatus.absent,
      );
}
