import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/app_exception.dart';
import '../core/dates.dart';
import '../models/attendance_status.dart';

/// One stored attendance day, read across users by admins.
class AttendanceEntry {
  const AttendanceEntry({required this.uid, required this.date, required this.status});
  final String uid;
  final String date;
  final AttendanceStatus status;
}

/// Attendance at `attendance/{uid}/days/{yyyy-MM-dd}`: one document per day.
///
/// The day key comes from the organisation's time zone, and the security
/// rules check it against the server clock, so a user can only ever mark
/// *today*, whatever their phone's clock says.
class AttendanceRepository {
  AttendanceRepository({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _days(String uid) =>
      _db.collection('attendance').doc(uid).collection('days');

  /// Marks the signed-in user present for today. Throws [AlreadyMarked] if
  /// today already has a record, [WrongClock] if the server rejects the date
  /// (the phone's date is off by a day), and [NoConnection] when offline.
  ///
  /// Uses a transaction, which only succeeds once the server has accepted the
  /// write. (A plain write shows up on screen immediately and would then be
  /// rolled back if the rules reject it, making "checked in" flash briefly.)
  Future<void> markPresentToday(String uid) async {
    final key = Dates.todayKey();
    final ref = _days(uid).doc(key);
    try {
      await _db.runTransaction((tx) async {
        final existing = await tx.get(ref);
        if (existing.exists) {
          throw AlreadyMarked(AttendanceStatus.fromValue(existing.data()?['status'] as String?));
        }
        tx.set(ref, {
          'uid': uid,
          'date': key,
          'status': AttendanceStatus.present.value,
          'markedAt': FieldValue.serverTimestamp(),
          'markedBy': uid,
        });
      });
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') throw const WrongClock();
      if (e.code == 'unavailable') throw const NoConnection();
      rethrow;
    }
  }

  /// Stored statuses for one user between two dates (inclusive).
  Stream<Map<String, AttendanceStatus>> watchRange(String uid, DateTime from, DateTime to) {
    return _days(uid)
        .where('date', isGreaterThanOrEqualTo: Dates.dayKey(from))
        .where('date', isLessThanOrEqualTo: Dates.dayKey(to))
        .snapshots()
        .map(_toMap);
  }

  Future<Map<String, AttendanceStatus>> fetchRange(String uid, DateTime from, DateTime to) async {
    final q = await _days(uid)
        .where('date', isGreaterThanOrEqualTo: Dates.dayKey(from))
        .where('date', isLessThanOrEqualTo: Dates.dayKey(to))
        .get();
    return _toMap(q);
  }

  /// Admin: set or correct one day for any user.
  Future<void> adminSetDay({
    required String uid,
    required DateTime day,
    required AttendanceStatus status,
    required String adminUid,
  }) {
    assert(status.isStored);
    final key = Dates.dayKey(day);
    return _days(uid).doc(key).set({
      'uid': uid,
      'date': key,
      'status': status.value,
      'markedAt': FieldValue.serverTimestamp(),
      'markedBy': adminUid,
    });
  }

  /// Admin: remove a day's record (it then counts as not marked or absent).
  Future<void> adminClearDay(String uid, DateTime day) => _days(uid).doc(Dates.dayKey(day)).delete();

  /// Admin: every stored record for one date, across all users.
  Stream<List<AttendanceEntry>> watchDateAcrossUsers(String dayKey) {
    return _db
        .collectionGroup('days')
        .where('date', isEqualTo: dayKey)
        .snapshots()
        .map((q) => q.docs.map(_entry).toList());
  }

  /// Admin: every stored record in a date range, across all users (reports).
  Future<List<AttendanceEntry>> fetchRangeAcrossUsers(DateTime from, DateTime to) async {
    final q = await _db
        .collectionGroup('days')
        .where('date', isGreaterThanOrEqualTo: Dates.dayKey(from))
        .where('date', isLessThanOrEqualTo: Dates.dayKey(to))
        .get();
    return q.docs.map(_entry).toList();
  }

  static Map<String, AttendanceStatus> _toMap(QuerySnapshot<Map<String, dynamic>> q) => {
        for (final d in q.docs) d.id: AttendanceStatus.fromValue(d.data()['status'] as String?),
      };

  static AttendanceEntry _entry(QueryDocumentSnapshot<Map<String, dynamic>> d) => AttendanceEntry(
        uid: d.data()['uid'] as String? ?? d.reference.parent.parent!.id,
        date: d.id,
        status: AttendanceStatus.fromValue(d.data()['status'] as String?),
      );
}

class AlreadyMarked extends AppException {
  AlreadyMarked(this.status) : super('Today is already recorded as "${status.label}".');
  final AttendanceStatus status;
}

class WrongClock extends AppException {
  const WrongClock()
      : super("Your phone's date doesn't match today's date. Turn on automatic date and time, then try again.");
}

class NoConnection extends AppException {
  const NoConnection() : super('No internet connection. Check-in needs to reach the server, so try again once you\'re online.');
}
