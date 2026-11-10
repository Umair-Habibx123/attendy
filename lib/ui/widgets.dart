import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/app_exception.dart';
import '../data/auth_service.dart';
import '../models/app_user.dart';
import '../models/attendance_status.dart';

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

/// Full-screen message with one action (errors, deactivated account, ...).
class MessageScreen extends StatelessWidget {
  const MessageScreen({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: EmptyState(icon: icon, title: title, message: message, actionLabel: actionLabel, onAction: onAction),
          ),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 56, color: theme.colorScheme.primary.withValues(alpha: 0.6)),
        const SizedBox(height: 16),
        Text(title, style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
        if (message != null) ...[
          const SizedBox(height: 8),
          Text(message!, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center),
        ],
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: 20),
          OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ],
    );
  }
}

class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.user, this.radius = 22, this.overrideBytes});
  final AppUser user;
  final double radius;
  final Uint8List? overrideBytes;

  @override
  Widget build(BuildContext context) {
    final bytes = overrideBytes ?? user.photoBytes;
    final scheme = Theme.of(context).colorScheme;
    return CircleAvatar(
      radius: radius,
      backgroundColor: scheme.primaryContainer,
      foregroundColor: scheme.onPrimaryContainer,
      backgroundImage: bytes != null ? MemoryImage(bytes) : null,
      child: bytes == null ? Text(user.initials, style: TextStyle(fontSize: radius * 0.8, fontWeight: FontWeight.w600)) : null,
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key, this.compact = false});
  final AttendanceStatus status;
  final bool compact;

  @override
  Widget build(BuildContext context) => Pill(
        label: status.label,
        color: status.color,
        icon: compact ? null : status.icon,
      );
}

/// Small rounded label with a tinted background.
class Pill extends StatelessWidget {
  const Pill({super.key, required this.label, required this.color, this.icon});
  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[Icon(icon, size: 14, color: color), const SizedBox(width: 4)],
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
      ]),
    );
  }
}

/// A big number with a label, for dashboards and summaries.
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value, required this.color, this.icon});
  final String label;
  final String value;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (icon != null) Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(value, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700, color: color)),
          Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        ]),
      ),
    );
  }
}

/// "< November 2026 >" switcher used by history screens.
class MonthSwitcher extends StatelessWidget {
  const MonthSwitcher({super.key, required this.month, required this.onChanged, this.latest});
  final DateTime month;
  final ValueChanged<DateTime> onChanged;
  final DateTime? latest;

  @override
  Widget build(BuildContext context) {
    final canGoForward = latest == null ||
        DateTime(month.year, month.month + 1).isBefore(DateTime(latest!.year, latest!.month + 1));
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      IconButton(
        tooltip: 'Previous month',
        onPressed: () => onChanged(DateTime(month.year, month.month - 1)),
        icon: const Icon(Icons.chevron_left_rounded),
      ),
      Text(DateFormat('MMMM yyyy').format(month), style: Theme.of(context).textTheme.titleMedium),
      IconButton(
        tooltip: 'Next month',
        onPressed: canGoForward ? () => onChanged(DateTime(month.year, month.month + 1)) : null,
        icon: const Icon(Icons.chevron_right_rounded),
      ),
    ]);
  }
}

/// Shows a friendly message for any error: Firebase errors are translated,
/// the app's own exceptions (e.g. WrongClock) use their message.
void showError(BuildContext context, Object error) {
  if (!context.mounted) return;
  final String text;
  if (error is FirebaseException) {
    text = AuthService.messageFor(error);
  } else if (error is AppException) {
    text = error.message;
  } else {
    text = 'Something went wrong. Please try again.';
  }
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text), behavior: SnackBarBehavior.floating));
}

void showMessage(BuildContext context, String text) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text), behavior: SnackBarBehavior.floating));
}

/// Wraps a button action: shows a spinner state via [busy] and reports errors.
Future<void> runGuarded(BuildContext context, Future<void> Function() action) async {
  try {
    await action();
  } catch (e) {
    if (context.mounted) showError(context, e);
  }
}
