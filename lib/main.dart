import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'core/config.dart';
import 'core/work_schedule.dart';
import 'firebase_options.dart';
import 'models/app_user.dart';
import 'services.dart';
import 'ui/admin/admin_shell.dart';
import 'ui/auth/login_screen.dart';
import 'ui/auth/verify_email_screen.dart';
import 'ui/splash_and_offline.dart';
import 'ui/theme.dart';
import 'ui/user/user_shell.dart';
import 'ui/widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const AttendyApp());
}

class AttendyApp extends StatelessWidget {
  const AttendyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const AuthGate(),
      // A real reachability check (not just "Wi-Fi is on") covers every
      // screen with a retry page while the internet is unreachable.
      builder: (context, child) => ListenableBuilder(
        listenable: Services.connectivity,
        builder: (context, _) {
          final net = Services.connectivity;
          return Stack(children: [
            child!,
            if (!net.hasInternet) NoInternetScreen(checking: net.isChecking, onRetry: net.retryConnection),
          ]);
        },
      ),
    );
  }
}

/// Decides what to show from the live sign-in state and the live profile,
/// so role changes or deactivation take effect immediately.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  // Keep the splash up for a moment even when the session restores instantly.
  bool _minimumSplashDone = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _minimumSplashDone = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: Services.auth.authChanges(),
      builder: (context, authSnap) {
        if (!_minimumSplashDone || authSnap.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }
        final user = authSnap.data;
        if (user == null) return const LoginScreen();
        if (!user.emailVerified) return const VerifyEmailScreen();
        return StreamBuilder<AppUser?>(
          stream: Services.users.watch(user.uid),
          builder: (context, profileSnap) {
            if (profileSnap.hasError) {
              return MessageScreen(
                icon: Icons.cloud_off_rounded,
                title: "Couldn't load your profile",
                message: 'Check your connection and try again.',
                actionLabel: 'Sign out',
                onAction: Services.auth.signOut,
              );
            }
            if (!profileSnap.hasData) return const SplashScreen();
            final profile = profileSnap.data;
            if (profile == null) {
              return MessageScreen(
                icon: Icons.person_off_rounded,
                title: 'Profile not found',
                message: 'Your account has no profile yet. Sign out and register again, or contact your admin.',
                actionLabel: 'Sign out',
                onAction: Services.auth.signOut,
              );
            }
            if (!profile.active) {
              return MessageScreen(
                icon: Icons.lock_person_rounded,
                title: 'Account deactivated',
                message: 'An admin has deactivated your account. Contact them if this is a mistake.',
                actionLabel: 'Sign out',
                onAction: Services.auth.signOut,
              );
            }
            // The admin-set work schedule (working weekdays and holidays).
            // Every date calculation reads WorkSchedule.current.
            return StreamBuilder<WorkSchedule>(
              stream: Services.settings.watchSchedule(),
              builder: (context, scheduleSnap) {
                WorkSchedule.current = scheduleSnap.data ?? WorkSchedule.defaults;
                return profile.isAdmin ? AdminShell(me: profile) : UserShell(me: profile);
              },
            );
          },
        );
      },
    );
  }
}
