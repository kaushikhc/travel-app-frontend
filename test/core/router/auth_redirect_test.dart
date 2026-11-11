import 'package:flutter_test/flutter_test.dart';
import 'package:travel_app_frontend/core/router/auth_redirect.dart';
import 'package:travel_app_frontend/features/auth/domain/user_model.dart';
import 'package:travel_app_frontend/features/auth/presentation/auth_state.dart';
import 'package:travel_app_frontend/features/profile/domain/profile_model.dart';
import 'package:travel_app_frontend/features/profile/presentation/profile_state.dart';

const ProfileModel _complete = ProfileModel(
  travelerId: 1, username: 'ana', displayName: 'Ana', email: 'ana@example.com', bio: 'Hi', homeCountryId: 1);
const ProfileModel _incomplete = ProfileModel(
  travelerId: 1, username: 'ana', displayName: 'Ana', email: 'ana@example.com');

const AuthState _signedIn = AuthState.authenticated(UserModel(username: 'ana'));

String? _go(String location, AuthState auth, [ProfileState? profile]) =>
    authRedirect(auth: auth, profile: profile ?? ProfileState.idle(), uri: Uri.parse(location));

void main() {
  group('signed out', () {
    test('checking a saved session shows loading', () {
      expect(_go('/home', const AuthState.checking()), AppRoutes.loading);
      expect(_go('/loading', const AuthState.checking()), isNull);
    });

    test('any screen goes to login, login stays', () {
      expect(_go('/home', const AuthState.unauthenticated()), AppRoutes.login);
      expect(_go('/', const AuthState.unauthenticated()), AppRoutes.login);
      expect(_go('/login', const AuthState.unauthenticated()), isNull);
      expect(_go('/login', const AuthState.loading()), isNull);
      expect(_go('/login', const AuthState.error('x')), isNull);
    });

    test('web Google callback stays put while the code is exchanged', () {
      expect(_go('/?code=abc', const AuthState.checking()), isNull);
      expect(_go('/?code=abc', const AuthState.loading()), isNull);
      expect(_go('/?code=', const AuthState.unauthenticated()), AppRoutes.login);
    });
  });

  group('signed in', () {
    test('waits on loading while the profile loads', () {
      expect(_go('/login', _signedIn, ProfileState.initial()), AppRoutes.loading);
      expect(_go('/?code=abc', _signedIn, ProfileState.initial()), AppRoutes.loading);
      expect(_go('/loading', _signedIn, ProfileState.initial()), isNull);
    });

    test('incomplete profile is sent to setup', () {
      final ProfileState p = ProfileState.success(_incomplete);
      expect(_go('/loading', _signedIn, p), AppRoutes.profileSetup);
      expect(_go('/home', _signedIn, p), AppRoutes.profileSetup);
      expect(_go('/profile-setup', _signedIn, p), isNull);
    });

    test('a first Google sign-in picks a username before profile setup', () {
      final ProfileState p = ProfileState.success(const ProfileModel(
          travelerId: 1, username: 'ana@example.com', displayName: 'Ana', email: 'ana@example.com',
          usernameChosen: false));
      expect(_go('/loading', _signedIn, p), AppRoutes.chooseUsername);
      expect(_go('/profile-setup', _signedIn, p), AppRoutes.chooseUsername);
      expect(_go('/choose-username', _signedIn, p), isNull);
      expect(_go('/choose-username', _signedIn, ProfileState.success(_incomplete)), AppRoutes.profileSetup);
      expect(_go('/choose-username', _signedIn, ProfileState.success(_complete)), AppRoutes.home);
    });

    test('complete profile leaves entry screens for home and stays elsewhere', () {
      final ProfileState p = ProfileState.success(_complete);
      for (final String path in <String>['/', '/login', '/loading', '/profile-setup', '/?code=abc']) {
        expect(_go(path, _signedIn, p), AppRoutes.home, reason: path);
      }
      expect(_go('/home', _signedIn, p), isNull);
      expect(_go('/explore', _signedIn, p), isNull);
    });

    test('profile error does not loop: entry screens go home, others stay', () {
      final ProfileState p = ProfileState.error('offline');
      expect(_go('/loading', _signedIn, p), AppRoutes.home);
      expect(_go('/home', _signedIn, p), isNull);
    });
  });
}
