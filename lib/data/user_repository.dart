import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';

/// Profiles at `users/{uid}`.
class UserRepository {
  UserRepository({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _users => _db.collection('users');

  Stream<AppUser?> watch(String uid) =>
      _users.doc(uid).snapshots().map((s) => s.exists ? AppUser.fromDoc(s) : null);

  /// All users, sorted by name (admins only, enforced by the rules).
  Stream<List<AppUser>> watchAll() => _users.orderBy('name').snapshots().map(
        (q) => q.docs.map(AppUser.fromDoc).toList(),
      );

  Future<List<AppUser>> fetchAll() async {
    final q = await _users.orderBy('name').get();
    return q.docs.map(AppUser.fromDoc).toList();
  }

  /// Users may change only their own name and photo.
  Future<void> updateProfile(String uid, {required String name, String? photoBase64, bool removePhoto = false}) {
    return _users.doc(uid).update({
      'name': name.trim(),
      if (photoBase64 != null) 'photo': photoBase64,
      if (removePhoto) 'photo': null,
    });
  }

  /// Admin actions. The rules stop admins changing their own role or status,
  /// so there is always at least one active admin.
  Future<void> setActive(String uid, bool active) => _users.doc(uid).update({'active': active});

  Future<void> setRole(String uid, UserRole role) => _users.doc(uid).update({'role': role.name});
}
