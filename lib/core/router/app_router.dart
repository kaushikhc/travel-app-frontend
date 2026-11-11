import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/auth_state.dart';
import '../../features/auth/presentation/login_view.dart';
import '../../features/navigation/presentation/main_scaffold.dart';
import '../../features/trip/presentation/trips_view.dart';
import '../../features/memories/presentation/memories_view.dart';
import '../../features/capture/presentation/capture_view.dart';
import '../../features/explore/presentation/explore_view.dart';
import '../../features/profile/presentation/profile_view.dart';
import '../../features/profile/presentation/profile_setup_view.dart';
import '../../features/profile/presentation/profile_state.dart';

/// A [ChangeNotifier] that wraps [AuthState] and [ProfileState] changes so
/// [GoRouter] can listen to both without rebuilding the router instance.
class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    _ref.listen<AuthState>(authStateProvider, (previous, next) {
      // Reset profile state when user logs out
      if (next.status == AuthStatus.unauthenticated) {
        _ref.read(profileNotifierProvider.notifier).reset();
      }
      notifyListeners();
    });
    _ref.listen<ProfileState>(profileNotifierProvider, (previous, next) {
      notifyListeners();
    });
  }

  String? redirect(BuildContext context, GoRouterState state) {
    final authState = _ref.read(authStateProvider);
    final currentPath = state.matchedLocation;

    // ── OAuth callback ────────────────────────────────────────────────────────
    final token = state.uri.queryParameters['token'];
    final username = state.uri.queryParameters['username'];
    final email = state.uri.queryParameters['email'];

    if (token != null && token.isNotEmpty) {
      // Set auth state with the token from the callback
      _ref.read(authStateProvider.notifier).handleOAuthCallback(
            token: token,
            username: username ?? 'Traveler',
            email: email,
          );
      // Kick off profile load — router re-evaluates when ProfileState changes
      _ref.read(profileNotifierProvider.notifier).loadProfile();
      return '/loading';
    }

    // ── Auth guard ───────────────────────────────────────────────────────────
    final isAuthenticated = authState.status == AuthStatus.authenticated;
    final isOnLogin = currentPath == '/login';
    final isOnSetup = currentPath == '/profile-setup';
    final isOnLoading = currentPath == '/loading';

    if (!isAuthenticated && !isOnLogin) return '/login';

    if (isAuthenticated && isOnLogin) {
      // Kick off profile load; router re-fires once ProfileState resolves
      _ref.read(profileNotifierProvider.notifier).loadProfileOnce();
      return '/loading';
    }

    // ── Profile completeness guard ────────────────────────────────────────────
    if (isAuthenticated) {
      final profileState = _ref.read(profileNotifierProvider);

      // While loading: show loading screen
      if (profileState.isLoading && !isOnLoading) return '/loading';

      // Profile failed to load (error) — let them into home anyway, they can retry
      if (!profileState.isLoading && profileState.profile == null && !isOnLoading) {
        // Error state: proceed to home rather than infinite loop
        return '/home';
      }

      // Profile loaded and incomplete → force setup
      if (profileState.needsSetup && !isOnSetup) return '/profile-setup';

      // Profile is complete → don't stay on setup or loading pages
      if (!profileState.isLoading && !profileState.needsSetup && profileState.profile != null) {
        if (isOnSetup || isOnLoading) return '/home';
      }
    }

    return null;
  }
}

final routerNotifierProvider = Provider<RouterNotifier>((ref) {
  return RouterNotifier(ref);
});

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const LoginView(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginView(),
      ),
      GoRoute(
        path: '/loading',
        builder: (context, state) => const _LoadingScreen(),
      ),
      GoRoute(
        path: '/profile-setup',
        builder: (context, state) => const ProfileSetupView(),
      ),
      ShellRoute(
        builder: (context, state, child) {
          return MainScaffold(
            currentPath: state.matchedLocation,
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: '/home',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: TripsView(),
            ),
          ),
          GoRoute(
            path: '/memories',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: MemoriesView(),
            ),
          ),
          GoRoute(
            path: '/capture',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: CaptureView(),
            ),
          ),
          GoRoute(
            path: '/explore',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ExploreView(),
            ),
          ),
          GoRoute(
            path: '/profile',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ProfileView(),
            ),
          ),
        ],
      ),
    ],
  );
});

/// Full-screen loading indicator shown while profile is being fetched.
class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF0D0D1A),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF7C6AF7)),
            SizedBox(height: 20),
            Text(
              'Getting your profile…',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
