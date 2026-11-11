import '../../features/auth/presentation/choose_username_view.dart';
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
import '../../features/auth/presentation/google_callback_view.dart';
import 'auth_redirect.dart';

/// Tells [GoRouter] to re-run [authRedirect] when auth or profile state changes.
class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    _ref.listen<AuthState>(authStateProvider, (AuthState? previous, AuthState next) => notifyListeners());
    _ref.listen<ProfileState>(profileNotifierProvider, (ProfileState? previous, ProfileState next) => notifyListeners());
  }

  String? redirect(BuildContext context, GoRouterState state) {
    return authRedirect(
      auth: _ref.read(authStateProvider),
      profile: _ref.read(profileNotifierProvider),
      uri: state.uri,
    );
  }
}

final routerNotifierProvider = Provider<RouterNotifier>((ref) {
  return RouterNotifier(ref);
});

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);

  return GoRouter(
    initialLocation: AppRoutes.loading,
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      GoRoute(
        path: AppRoutes.root,
        builder: (BuildContext context, GoRouterState state) {
          final String? code = state.uri.queryParameters['code'];
          return code != null && code.isNotEmpty ? GoogleCallbackView(code: code) : const LoginView();
        },
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
        path: AppRoutes.chooseUsername,
        builder: (context, state) => const ChooseUsernameView(),
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
