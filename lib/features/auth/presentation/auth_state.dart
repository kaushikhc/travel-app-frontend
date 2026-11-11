import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/token_storage.dart';
import '../data/auth_repository.dart';
import '../data/google_sign_in_gateway.dart';
import '../domain/user_model.dart';

/// checking: restoring a saved session at start-up. loading: a sign-in or sign-out is running.
enum AuthStatus { checking, unauthenticated, loading, authenticated, error }

@immutable
class AuthState {
  final AuthStatus status;
  final UserModel? user;
  final String? errorMessage;

  const AuthState({required this.status, this.user, this.errorMessage});

  const AuthState.checking() : this(status: AuthStatus.checking);
  const AuthState.unauthenticated() : this(status: AuthStatus.unauthenticated);
  const AuthState.loading() : this(status: AuthStatus.loading);
  const AuthState.authenticated(UserModel? user) : this(status: AuthStatus.authenticated, user: user);
  const AuthState.error(String message) : this(status: AuthStatus.error, errorMessage: message);

  bool get isAuthenticated => status == AuthStatus.authenticated;
}

/// Owns the session: the token in secure storage and on the API client. The router only reads this.
class AuthNotifier extends Notifier<AuthState> {
  AuthRepository get _repository => ref.read(authRepositoryProvider);
  ApiClient get _apiClient => ref.read(apiClientProvider);
  TokenStorage get _storage => ref.read(tokenStorageProvider);
  GoogleSignInGateway get _google => ref.read(googleSignInGatewayProvider);

  @override
  AuthState build() {
    Future<void>.microtask(restoreSession);
    return const AuthState.checking();
  }

  /// Signs back in with a saved token. A token the server rejects is dropped; if the server
  /// can't be reached the user stays signed in and requests retry later.
  Future<void> restoreSession() async {
    final String? token = await _storage.read();
    // Another sign-in (e.g. the web Google callback) may have started meanwhile; it wins.
    if (!ref.mounted || state.status != AuthStatus.checking) return;
    if (token == null || token.isEmpty) {
      state = const AuthState.unauthenticated();
      return;
    }
    _apiClient.setAuthToken(token);
    final SessionCheck check = await _repository.checkSession();
    if (!ref.mounted || state.status != AuthStatus.checking) return;
    if (check == SessionCheck.invalid) {
      await _clearSession();
      state = const AuthState.unauthenticated();
      return;
    }
    // Profile details (username, display name) come from /profile/me.
    state = AuthState.authenticated(null);
  }

  Future<bool> login(String username, String password) {
    return _signIn(() => _repository.login(username, password));
  }

  /// Web: called by the callback route with the one-time code from the Google redirect.
  Future<bool> exchangeGoogleCode(String code) {
    return _signIn(() => _repository.exchangeGoogleCode(code));
  }

  /// Android: native Google sign-in. Returns false if it failed or the user cancelled.
  Future<bool> signInWithGoogleNative() async {
    state = const AuthState.loading();
    try {
      final String? idToken = await _google.obtainIdToken();
      if (!ref.mounted) return false;
      if (idToken == null) {
        state = const AuthState.unauthenticated();
        return false;
      }
      return await _signIn(() => _repository.signInWithGoogleIdToken(idToken));
    } catch (e) {
      if (ref.mounted) state = AuthState.error(_message(e));
      return false;
    }
  }

  Future<bool> register({
    required String username,
    required String email,
    required String password,
    required String displayName,
  }) async {
    state = const AuthState.loading();
    try {
      await _repository.register(username: username, email: email, password: password, displayName: displayName);
      if (ref.mounted) state = const AuthState.unauthenticated();
      return true;
    } catch (e) {
      if (ref.mounted) state = AuthState.error(_message(e));
      return false;
    }
  }

  Future<void> logout() async {
    state = const AuthState.loading();
    await _repository.logout();
    try {
      await _google.signOut();
    } catch (_) {}
    await _clearSession();
    if (ref.mounted) state = const AuthState.unauthenticated();
  }

  Future<bool> _signIn(Future<AuthSession> Function() request) async {
    state = const AuthState.loading();
    try {
      final AuthSession session = await request();
      await _storage.write(session.token);
      _apiClient.setAuthToken(session.token);
      if (ref.mounted) state = AuthState.authenticated(UserModel(username: session.username));
      return true;
    } catch (e) {
      if (ref.mounted) state = AuthState.error(_message(e));
      return false;
    }
  }

  /// Picks a username (and optional password) after a first Google sign-in, or skips when both
  /// are empty. Swaps in the new token without leaving the signed-in state. Returns an error
  /// message, or null on success.
  Future<String?> chooseUsername({String? username, String? password}) async {
    try {
      final AuthSession session =
          await _repository.chooseUsername(username: username, password: password);
      await _storage.write(session.token);
      _apiClient.setAuthToken(session.token);
      if (ref.mounted) state = AuthState.authenticated(UserModel(username: session.username));
      return null;
    } catch (e) {
      return _message(e);
    }
  }

  Future<void> _clearSession() async {
    _apiClient.clearAuthToken();
    await _storage.clear();
  }

  static String _message(Object e) => e.toString().replaceAll('Exception: ', '');
}

final authStateProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
