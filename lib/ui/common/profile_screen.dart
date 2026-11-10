import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/validators.dart';
import '../../models/app_user.dart';
import '../../services.dart';
import '../admin/work_schedule_screen.dart';
import '../widgets.dart';

/// Profile for both users and admins: name, photo, password, sign out.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.me});
  final AppUser me;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Center(child: _PhotoEditor(me: me)),
        const SizedBox(height: 12),
        Center(child: Text(me.name, style: theme.textTheme.titleLarge)),
        Center(child: Text(me.email, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant))),
        const SizedBox(height: 8),
        Center(child: Pill(label: me.isAdmin ? 'Admin' : 'Member', color: theme.colorScheme.primary)),
        const SizedBox(height: 24),
        Card(
          child: Column(children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Change name'),
              onTap: () => _editName(context),
            ),
            const Divider(height: 1),
            if (me.isAdmin) ...[
              ListTile(
                leading: const Icon(Icons.event_available_outlined),
                title: const Text('Work schedule'),
                subtitle: const Text('Working days and holidays'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => WorkScheduleScreen(me: me))),
              ),
              const Divider(height: 1),
            ],
            ListTile(
              leading: const Icon(Icons.password_rounded),
              title: const Text('Change password'),
              onTap: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                showDragHandle: true,
                builder: (_) => const _ChangePasswordSheet(),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(Icons.logout_rounded, color: theme.colorScheme.error),
              title: Text('Sign out', style: TextStyle(color: theme.colorScheme.error)),
              onTap: Services.auth.signOut,
            ),
          ]),
        ),
      ]),
    );
  }

  Future<void> _editName(BuildContext context) async {
    final controller = TextEditingController(text: me.name);
    final formKey = GlobalKey<FormState>();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Your name'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            validator: Validators.name,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              if (formKey.currentState!.validate()) Navigator.pop(ctx, controller.text.trim());
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name == me.name || !context.mounted) return;
    await runGuarded(context, () => Services.users.updateProfile(me.uid, name: name));
  }
}

class _PhotoEditor extends StatefulWidget {
  const _PhotoEditor({required this.me});
  final AppUser me;
  @override
  State<_PhotoEditor> createState() => _PhotoEditorState();
}

class _PhotoEditorState extends State<_PhotoEditor> {
  bool _busy = false;

  Future<void> _pick() async {
    // A small, compressed thumbnail keeps the profile document tiny.
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 256,
      maxHeight: 256,
      imageQuality: 70,
    );
    if (file == null || !mounted) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    if (bytes.length > 100 * 1024) {
      showMessage(context, 'That photo is too large. Try a different one.');
      return;
    }
    setState(() => _busy = true);
    await runGuarded(context, () => Services.users.updateProfile(widget.me.uid, name: widget.me.name, photoBase64: base64Encode(bytes)));
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      UserAvatar(user: widget.me, radius: 48),
      Positioned(
        right: 0,
        bottom: 0,
        child: IconButton.filled(
          tooltip: 'Change photo',
          onPressed: _busy ? null : _pick,
          icon: _busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.photo_camera_outlined, size: 20),
        ),
      ),
    ]);
  }
}

class _ChangePasswordSheet extends StatefulWidget {
  const _ChangePasswordSheet();
  @override
  State<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends State<_ChangePasswordSheet> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    await runGuarded(context, () async {
      await Services.auth.changePassword(current: _current.text, next: _next.text);
      if (!mounted) return;
      Navigator.pop(context);
      showMessage(context, 'Password changed.');
    });
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
      child: Form(
        key: _form,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Change password', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextFormField(
            controller: _current,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Current password'),
            validator: (v) => (v == null || v.isEmpty) ? 'Enter your current password' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _next,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'New password', helperText: 'At least 8 characters, with a letter and a number'),
            validator: Validators.password,
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: _busy
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                : const Text('Update password'),
          ),
        ]),
      ),
    );
  }
}
