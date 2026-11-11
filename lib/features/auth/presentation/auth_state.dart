import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../data/auth_repository.dart';
import '../domain/user_model.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

class AuthState {
  final AuthStatus status;
  final UserModel? user;
  final String? errorMessage;

  const AuthState({
    required this.status,
    this.user,
    this.errorMessage,
  });

  factory AuthState.initial() => const AuthState(status: AuthStatus.unauthenticated);
  factory AuthState.loading() => const AuthState(status: AuthStatus.loading);
  factory AuthState.authenticated(UserModel user) => AuthState(status: AuthStatus.authenticated, user: user);
  factory AuthState.unauthenticated() => const AuthState(status: AuthStatus.unauthenticated);
  factory AuthState.error(String message) => AuthState(status: AuthStatus.error, errorMessage: message);
}

class AuthNotifier extends Notifier<AuthState> {
  late final AuthRepository _authRepository;
  late final ApiClient _apiClient;

  @override
  AuthState build() {
    _authRepository = ref.watch(authRepositoryProvider);
    _apiClient = ref.watch(apiClientProvider);
    checkStatus();
    return AuthState.unauthenticated();
  }

  Future<void> checkStatus() async {
    // If no JWT token is stored, user is strictly unauthenticated
    if (!_apiClient.hasAuthToken) {
      state = AuthState.unauthenticated();
      return;
    }

    try {
      final isLoggedIn = await _authRepository
          .checkLoginStatus()
          .timeout(const Duration(seconds: 2), onTimeout: () => false);

      if (isLoggedIn) {
        state = AuthState.authenticated(
          const UserModel(id: '1', username: 'Traveler', email: 'user@travelapp.com'),
        );
      } else {
        _apiClient.clearAuthToken();
        state = AuthState.unauthenticated();
      }
    } catch (_) {
      _apiClient.clearAuthToken();
      state = AuthState.unauthenticated();
    }
  }

  void handleOAuthCallback({
    required String token,
    required String username,
    String? email,
  }) {
    _apiClient.setAuthToken(token);
    state = AuthState.authenticated(
      UserModel(
        id: '1',
        username: username,
        email: email ?? '$username@travelapp.com',
      ),
    );
  }

  Future<bool> login(String username, String password) async {
    state = AuthState.loading();
    try {
      final token = await _authRepository.login(username, password);
      if (token != null && token.isNotEmpty) {
        _apiClient.setAuthToken(token);
        state = AuthState.authenticated(
          UserModel(id: '1', username: username, email: '$username@travelapp.com'),
        );
        return true;
      }
      state = AuthState.error('Invalid credentials.');
      return false;
    } catch (e) {
      state = AuthState.error(e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }

  Future<bool> register({
    required String username,
    required String email,
    required String password,
    required String displayName,
  }) async {
    state = AuthState.loading();
    try {
      await _authRepository.register(
        username: username,
        email: email,
        password: password,
        displayName: displayName,
      );
      state = AuthState.unauthenticated();
      return true;
    } catch (e) {
      state = AuthState.error(e.toString().replaceAll('Exception: ', ''));
      return false;
    }
  }

  Future<void> logout() async {
    state = AuthState.loading();
    await _authRepository.logout();
    _apiClient.clearAuthToken();
    state = AuthState.unauthenticated();
  }
}

final authStateProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
