import 'package:flutter/material.dart';

import '../core/config.dart';
import 'theme.dart';

/// Shown at launch while Firebase restores the session.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();
  late final Animation<double> _logo = CurvedAnimation(parent: _c, curve: const Interval(0, 0.7, curve: Curves.easeOutBack));
  late final Animation<double> _text = CurvedAnimation(parent: _c, curve: const Interval(0.4, 1, curve: Curves.easeOut));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.seed, Color(0xFF7C3AED)],
          ),
        ),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            ScaleTransition(
              scale: _logo,
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: const Icon(Icons.fact_check_rounded, size: 64, color: Colors.white),
              ),
            ),
            const SizedBox(height: 22),
            FadeTransition(
              opacity: _text,
              child: Column(children: [
                const Text(
                  AppConfig.appName,
                  style: TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                ),
                const SizedBox(height: 6),
                Text(
                  'Attendance made simple',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 15),
                ),
              ]),
            ),
            const SizedBox(height: 40),
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
            ),
          ]),
        ),
      ),
    );
  }
}

/// Covers the app when there's no real internet connection.
class NoInternetScreen extends StatelessWidget {
  const NoInternetScreen({super.key, required this.checking, required this.onRetry});
  final bool checking;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.wifi_off_rounded, size: 72, color: theme.colorScheme.primary),
              const SizedBox(height: 20),
              Text('No internet connection', style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
              const SizedBox(height: 10),
              Text(
                'Attendy needs the internet to record attendance with the server time. '
                'Check your Wi-Fi or mobile data.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 28),
              FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size(200, 52)),
                onPressed: checking ? null : onRetry,
                icon: checking
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.5))
                    : const Icon(Icons.refresh_rounded),
                label: Text(checking ? 'Checking…' : 'Try again'),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
