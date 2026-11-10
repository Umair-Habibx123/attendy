/// Form validators. Return null when the value is fine, or a message.
class Validators {
  Validators._();

  static String? name(String? v) {
    final s = v?.trim() ?? '';
    if (s.length < 2) return 'Enter your name';
    if (s.length > 60) return 'Keep it under 60 characters';
    return null;
  }

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? email(String? v) =>
      _emailPattern.hasMatch(v?.trim() ?? '') ? null : 'Enter a valid email address';

  static String? password(String? v) {
    final s = v ?? '';
    if (s.length < 8) return 'Use at least 8 characters';
    if (!RegExp(r'[A-Za-z]').hasMatch(s) || !RegExp(r'[0-9]').hasMatch(s)) {
      return 'Include at least one letter and one number';
    }
    return null;
  }

  static String? leaveReason(String? v) {
    final s = v?.trim() ?? '';
    if (s.length < 3) return 'Give a short reason';
    if (s.length > 500) return 'Keep it under 500 characters';
    return null;
  }
}
