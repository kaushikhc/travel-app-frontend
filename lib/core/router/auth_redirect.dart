import '../../features/auth/presentation/auth_state.dart';
import '../../features/profile/presentation/profile_state.dart';

/// Route paths that the auth flow knows about.
abstract final class AppRoutes {
  static const String root = '/';
  static const String login = '/login';
  static const String loading = '/loading';
  static const String profileSetup = '/profile-setup';
  static const String chooseUsername = '/choose-username';
  static const String home = '/home';
  static const String newTrip = '/trips/new';
  static String editTrip(int id) => '/trips/$id/edit';
  static const String memories = '/memories';
  static const String capture = '/capture';
  static String memoryDetail(int id) => '/memories/$id';
  static String editMemory(int id) => '/memories/$id/edit';
}

/// Where the router should send the user, or null to stay. A pure function of the current state
/// and location: it never changes state, so it cannot loop. Sign-in side effects live in
/// [AuthNotifier] and the callback screen.
String? authRedirect({required AuthState auth, required ProfileState profile, required Uri uri}) {
  final String path = uri.path.isEmpty ? AppRoutes.root : uri.path;
  final bool isGoogleCallback =
      path == AppRoutes.root && (uri.queryParameters['code']?.isNotEmpty ?? false);

  // Web Google redirect lands on /?code=...; the callback screen exchanges it.
  if (isGoogleCallback && !auth.isAuthenticated) return null;

  switch (auth.status) {
    case AuthStatus.checking:
      return path == AppRoutes.loading ? null : AppRoutes.loading;
    case AuthStatus.unauthenticated:
    case AuthStatus.loading:
    case AuthStatus.error:
      return path == AppRoutes.login ? null : AppRoutes.login;
    case AuthStatus.authenticated:
      break;
  }

  const Set<String> entryPaths = <String>{AppRoutes.root, AppRoutes.login, AppRoutes.loading};

  if (profile.isLoading) {
    return path == AppRoutes.loading ? null : AppRoutes.loading;
  }
  if (profile.profile == null) {
    // Profile failed to load: let the user in; screens can retry.
    return entryPaths.contains(path) || path == AppRoutes.profileSetup ? AppRoutes.home : null;
  }
  if (profile.needsUsername) {
    return path == AppRoutes.chooseUsername ? null : AppRoutes.chooseUsername;
  }
  if (profile.needsSetup) {
    return path == AppRoutes.profileSetup ? null : AppRoutes.profileSetup;
  }
  return entryPaths.contains(path) || path == AppRoutes.profileSetup || path == AppRoutes.chooseUsername
      ? AppRoutes.home
      : null;
}
