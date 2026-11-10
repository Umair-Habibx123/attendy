import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Sign-up, sign-in and password handling. Firebase Authentication owns
/// passwords; Firestore only stores the profile.
class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? db})
      : _auth = auth ?? FirebaseAuth.instance,
        _db = db ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;

  /// Fires on sign-in, sign-out, token refresh and profile changes.
  Stream<User?> authChanges() => _auth.idTokenChanges();

  User? get currentUser => _auth.currentUser;

  /// Creates the account and its profile. Every new account is a regular
  /// user: admins are promoted by another admin (or once in the console).
  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
    final user = cred.user!;
    await user.updateDisplayName(name.trim());
    await _db.collection('users').doc(user.uid).set({
      'name': name.trim(),
      'email': user.email,
      'role': 'user',
      'active': true,
      'photo': null,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await user.sendEmailVerification();
  }

  Future<void> signIn(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email.trim(), password: password);

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());

  Future<void> resendVerification() async => _auth.currentUser?.sendEmailVerification();

  /// Reloads the user so a just-clicked verification link is picked up.
  /// Once verified, the ID token is refreshed too: the security rules read
  /// `email_verified` from the token, and refreshing it also notifies
  /// [authChanges] so the app moves on from the verify screen.
  Future<bool> refreshVerified() async {
    final user = _auth.currentUser;
    if (user == null) return false;
    await user.reload();
    final verified = _auth.currentUser?.emailVerified ?? false;
    if (verified) await _auth.currentUser?.getIdToken(true);
    return verified;
  }

  /// Changes the real sign-in password. Firebase requires a recent sign-in,
  /// so the current password is checked first.
  Future<void> changePassword({required String current, required String next}) async {
    final user = _auth.currentUser!;
    final cred = EmailAuthProvider.credential(email: user.email!, password: current);
    await user.reauthenticateWithCredential(cred);
    await user.updatePassword(next);
  }

  Future<void> signOut() => _auth.signOut();

  /// Human-readable message for a FirebaseAuthException code.
  static String messageFor(Object error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'invalid-email':
          return 'That email address looks wrong.';
        case 'user-disabled':
          return 'This account has been disabled.';
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'Email or password is incorrect.';
        case 'email-already-in-use':
          return 'An account with this email already exists.';
        case 'weak-password':
          return 'Choose a stronger password (at least 8 characters).';
        case 'too-many-requests':
          return 'Too many attempts. Please wait a moment and try again.';
        case 'network-request-failed':
          return 'No internet connection.';
        case 'requires-recent-login':
          return 'Please sign in again, then retry.';
      }
      return error.message ?? 'Something went wrong (${error.code}).';
    }
    if (error is FirebaseException && error.code == 'permission-denied') {
      return 'You are not allowed to do that.';
    }
    return 'Something went wrong. Please try again.';
  }
}
