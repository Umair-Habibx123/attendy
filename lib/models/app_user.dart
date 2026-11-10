import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { user, admin }

/// A user profile, stored at `users/{uid}`.
///
/// The password is never stored here: Firebase Authentication owns it.
class AppUser {
  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.active,
    required this.createdAt,
    this.photoBase64,
  });

  final String uid;
  final String name;
  final String email;
  final UserRole role;

  /// Admins can deactivate accounts; inactive users can't record anything.
  final bool active;
  final DateTime createdAt;

  /// Small JPEG thumbnail, base64-encoded (kept tiny to fit Firestore's
  /// 1 MB document limit; Cloud Storage needs the paid plan).
  final String? photoBase64;

  bool get isAdmin => role == UserRole.admin;

  Uint8List? get photoBytes {
    final p = photoBase64;
    if (p == null || p.isEmpty) return null;
    try {
      return base64Decode(p);
    } on FormatException {
      return null;
    }
  }

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    // `username` is the field name used by the first version of the app.
    final rawName = (d['name'] ?? d['username']) as String?;
    return AppUser(
      uid: doc.id,
      name: rawName != null && rawName.trim().isNotEmpty ? rawName.trim() : 'Unnamed',
      email: d['email'] as String? ?? '',
      role: d['role'] == 'admin' ? UserRole.admin : UserRole.user,
      active: d['active'] as bool? ?? true,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime(2000),
      photoBase64: d['photo'] as String?,
    );
  }
}
