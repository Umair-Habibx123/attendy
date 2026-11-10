import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/work_schedule.dart';

/// Organisation settings at `settings/organization`: the work schedule.
/// Everyone signed in can read it; only admins can change it (rules).
class SettingsRepository {
  SettingsRepository({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> get _doc => _db.collection('settings').doc('organization');

  /// The live schedule; falls back to Monday–Friday until an admin saves one.
  Stream<WorkSchedule> watchSchedule() =>
      _doc.snapshots().map((s) => WorkSchedule.fromMap(s.data()));

  Future<void> saveSchedule(WorkSchedule schedule, {required String adminUid}) {
    return _doc.set({
      ...schedule.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
      'updatedBy': adminUid,
    });
  }
}
