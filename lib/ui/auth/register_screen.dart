import 'package:flutter/material.dart';

import '../../core/validators.dart';
import '../../services.dart';
import '../widgets.dart';

/// Sign-up. There is no role picker: every account starts as a regular
/// user, and an admin promotes people from the People screen.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  bool _hide = true;

  @override
  void dispose() {
    for (final c in [_name, _email, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _register() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    await runGuarded(context, () async {
      await Services.auth.register(name: _name.text, email: _email.text, password: _password.text);
      // AuthGate now shows the verify-email screen; close this page.
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    });
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _form,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  TextFormField(
                    controller: _name,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.name],
                    decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.badge_outlined)),
                    validator: Validators.name,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.email],
                    decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
                    validator: Validators.email,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _password,
                    obscureText: _hide,
                    textInputAction: TextInputAction.next,
                    autofillHints: const [AutofillHints.newPassword],
                    decoration: InputDecoration(
                      labelText: 'Password',
                      helperText: 'At least 8 characters, with a letter and a number',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        tooltip: _hide ? 'Show password' : 'Hide password',
                        icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        onPressed: () => setState(() => _hide = !_hide),
                      ),
                    ),
                    validator: Validators.password,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _confirm,
                    obscureText: _hide,
                    onFieldSubmitted: (_) => _register(),
                    decoration: const InputDecoration(labelText: 'Confirm password', prefixIcon: Icon(Icons.lock_outline_rounded)),
                    validator: (v) => v != _password.text ? 'Passwords do not match' : null,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _busy ? null : _register,
                    child: _busy
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                        : const Text('Create account'),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "We'll email you a link to verify your address before you can mark attendance.",
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
