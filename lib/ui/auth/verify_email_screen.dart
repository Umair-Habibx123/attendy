import 'dart:async';

import 'package:flutter/material.dart';

import '../../services.dart';
import '../widgets.dart';

/// Shown until the user clicks the link in the verification email.
/// It checks automatically every few seconds.
class VerifyEmailScreen extends StatefulWidget {
  const VerifyEmailScreen({super.key});
  @override
  State<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends State<VerifyEmailScreen> {
  Timer? _timer;
  bool _resent = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) => Services.auth.refreshVerified());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final email = Services.auth.currentUser?.email ?? 'your email';
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.mark_email_unread_outlined, size: 64, color: theme.colorScheme.primary),
                const SizedBox(height: 20),
                Text('Check your inbox', style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
                const SizedBox(height: 10),
                Text(
                  'We sent a verification link to $email. Open it, then come back here: '
                  'this screen continues on its own.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 28),
                FilledButton.tonal(
                  onPressed: _resent
                      ? null
                      : () => runGuarded(context, () async {
                            await Services.auth.resendVerification();
                            setState(() => _resent = true);
                            if (context.mounted) showMessage(context, 'Verification email sent again.');
                          }),
                  child: Text(_resent ? 'Email sent' : 'Resend email'),
                ),
                const SizedBox(height: 8),
                TextButton(onPressed: Services.auth.signOut, child: const Text('Use a different account')),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
