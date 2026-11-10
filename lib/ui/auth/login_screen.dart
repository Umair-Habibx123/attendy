import 'package:flutter/material.dart';

import '../../core/config.dart';
import '../../services.dart';
import '../widgets.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _hide = true;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    await runGuarded(context, () => Services.auth.signIn(_email.text, _password.text));
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _forgotPassword() async {
    final controller = TextEditingController(text: _email.text);
    final email = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset password'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Your email', prefixIcon: Icon(Icons.email_outlined)),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Send link'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (email == null || email.isEmpty || !mounted) return;
    await runGuarded(context, () async {
      await Services.auth.sendPasswordReset(email);
      if (mounted) showMessage(context, 'If an account exists for $email, a reset link is on its way.');
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _form,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const _Logo(),
                  const SizedBox(height: 24),
                  Text('Welcome back', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text('Sign in to mark your attendance.',
                      style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 28),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.email_outlined)),
                    validator: (v) => (v == null || !v.contains('@')) ? 'Enter your email' : null,
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _password,
                    obscureText: _hide,
                    autofillHints: const [AutofillHints.password],
                    onFieldSubmitted: (_) => _signIn(),
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                      suffixIcon: IconButton(
                        tooltip: _hide ? 'Show password' : 'Hide password',
                        icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                        onPressed: () => setState(() => _hide = !_hide),
                      ),
                    ),
                    validator: (v) => (v == null || v.isEmpty) ? 'Enter your password' : null,
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(onPressed: _busy ? null : _forgotPassword, child: const Text('Forgot password?')),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: _busy ? null : _signIn,
                    child: _busy
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                        : const Text('Sign in'),
                  ),
                  const SizedBox(height: 16),
                  Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const Text('New here?'),
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterScreen())),
                      child: const Text('Create an account'),
                    ),
                  ]),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(children: [
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(16)),
        child: Icon(Icons.fact_check_rounded, color: scheme.onPrimary, size: 30),
      ),
      const SizedBox(width: 12),
      Text(AppConfig.appName, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
    ]);
  }
}
