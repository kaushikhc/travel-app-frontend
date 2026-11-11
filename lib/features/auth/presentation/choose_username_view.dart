import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/presentation/profile_state.dart';
import 'auth_state.dart';

/// Shown once after a first Google sign-in: pick a username and, optionally, a password to log
/// in with them too. Skipping keeps the Google email as the username.
class ChooseUsernameView extends ConsumerStatefulWidget {
  const ChooseUsernameView({super.key});

  @override
  ConsumerState<ChooseUsernameView> createState() => _ChooseUsernameViewState();
}

class _ChooseUsernameViewState extends ConsumerState<ChooseUsernameView> {
  static final RegExp _usernamePattern = RegExp(r'^[A-Za-z0-9._]{3,30}$');

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _username = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit({required bool skip}) async {
    if (!skip && !_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final String? error = await ref
        .read(authStateProvider.notifier)
        .chooseUsername(username: skip ? null : _username.text, password: skip ? null : _password.text);
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _saving = false;
        _error = error;
      });
      return;
    }
    // The router moves on once the reloaded profile says the username is chosen.
    await ref.read(profileNotifierProvider.notifier).loadProfile();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String current = ref.watch(profileNotifierProvider).profile?.username ?? '';
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Text('Choose a username', style: theme.textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    Text(
                      'Add a password too if you want to log in without Google. '
                      'Skip to keep "$current".',
                      style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    TextFormField(
                      key: const Key('choose-username'),
                      controller: _username,
                      enabled: !_saving,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        helperText: '3-30 letters, digits, dots or underscores',
                        prefixIcon: Icon(Icons.alternate_email),
                        border: OutlineInputBorder(),
                      ),
                      validator: (String? v) {
                        final String value = v?.trim() ?? '';
                        if (value.isEmpty) return 'Enter a username, or skip';
                        return _usernamePattern.hasMatch(value)
                            ? null
                            : 'Use 3-30 letters, digits, dots or underscores';
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('choose-password'),
                      controller: _password,
                      enabled: !_saving,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password (optional)',
                        prefixIcon: Icon(Icons.lock_outline),
                        border: OutlineInputBorder(),
                      ),
                      validator: (String? v) =>
                          (v == null || v.isEmpty || v.length >= 8) ? null : 'At least 8 characters',
                    ),
                    if (_error != null) ...<Widget>[
                      const SizedBox(height: 16),
                      Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _saving ? null : () => _submit(skip: false),
                      child: _saving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Save'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: _saving ? null : () => _submit(skip: true),
                      child: const Text('Skip for now'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
