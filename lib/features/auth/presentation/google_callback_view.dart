import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'auth_state.dart';

/// Web only: the backend's Google redirect lands here with a one-time code, which must be
/// exchanged within 60 seconds. On failure the login screen shows the error.
class GoogleCallbackView extends ConsumerStatefulWidget {
  final String code;

  const GoogleCallbackView({super.key, required this.code});

  @override
  ConsumerState<GoogleCallbackView> createState() => _GoogleCallbackViewState();
}

class _GoogleCallbackViewState extends ConsumerState<GoogleCallbackView> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _exchange());
  }

  Future<void> _exchange() async {
    final bool ok = await ref.read(authStateProvider.notifier).exchangeGoogleCode(widget.code);
    // On success the router moves on by itself; on failure leave the callback URL.
    if (!ok && mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0D0D1A),
      body: Center(child: CircularProgressIndicator(color: Color(0xFF7C6AF7))),
    );
  }
}
