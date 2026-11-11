import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

final authRepositoryProvider = Provider<AuthRepository>((Ref ref) {
  return AuthRepository(ref.watch(apiClientProvider));
});

/// A successful sign-in: the app JWT and the traveler's username.
class AuthSession {
  final String token;
  final String username;

  const AuthSession({required this.token, required this.username});

  static AuthSession? fromResponse(Response<dynamic> response) {
    final dynamic data = response.data;
    if (response.statusCode != 200 || data is! Map<String, dynamic>) return null;
    final String? token = data['token'] as String?;
    final String? username = data['username'] as String?;
    if (token == null || token.isEmpty || username == null) return null;
    return AuthSession(token: token, username: username);
  }
}

/// Whether a stored token is still accepted by the server.
enum SessionCheck { valid, invalid, unknown }

class AuthRepository {
  final ApiClient _apiClient;

  const AuthRepository(this._apiClient);

  /// Backend URL that starts the web Google sign-in redirect.
  String get googleAuthUrl {
    final String domain = _apiClient.baseUrl.replaceAll(RegExp(r'/api/?$'), '');
    return '$domain/oauth2/authorization/google';
  }

  /// POST /api/auth/login
  Future<AuthSession> login(String username, String password) async {
    try {
      final Response<dynamic> response = await _apiClient.post(
        '/auth/login',
        data: <String, String>{'username': username, 'password': password},
      );
      return AuthSession.fromResponse(response) ?? (throw Exception('Invalid username or password.'));
    } on DioException catch (e) {
      final int? status = e.response?.statusCode;
      if (status == 401 || status == 400) throw Exception('Invalid username or password.');
      throw Exception('Could not reach the server. Please try again.');
    }
  }

  /// POST /api/auth/exchange: swaps the one-time code from the web Google redirect (valid 60 s).
  Future<AuthSession> exchangeGoogleCode(String code) async {
    try {
      final Response<dynamic> response = await _apiClient.post('/auth/exchange', data: <String, String>{'code': code});
      return AuthSession.fromResponse(response) ?? (throw Exception('Google sign-in failed.'));
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) throw Exception('Google sign-in expired. Please try again.');
      throw Exception('Could not reach the server. Please try again.');
    }
  }

  /// POST /api/auth/google: native sign-in with a Google ID token.
  Future<AuthSession> signInWithGoogleIdToken(String idToken) async {
    try {
      final Response<dynamic> response = await _apiClient.post('/auth/google', data: <String, String>{'idToken': idToken});
      return AuthSession.fromResponse(response) ?? (throw Exception('Google sign-in failed.'));
    } on DioException catch (e) {
      final int? status = e.response?.statusCode;
      if (status == 401) throw Exception('Google sign-in failed. Please try again.');
      if (status == 403) throw Exception('Your Google account email is not verified.');
      throw Exception('Could not reach the server. Please try again.');
    }
  }

  /// POST /api/auth/choose-username, once after a first Google sign-in. Both fields optional:
  /// sending neither skips. Returns a new session, because the token names the username.
  Future<AuthSession> chooseUsername({String? username, String? password}) async {
    try {
      final Response<dynamic> response = await _apiClient.post(
        '/auth/choose-username',
        data: <String, String>{
          if (username != null && username.trim().isNotEmpty) 'username': username.trim(),
          if (password != null && password.isNotEmpty) 'password': password,
        },
      );
      return AuthSession.fromResponse(response) ?? (throw Exception('Could not save. Please try again.'));
    } on DioException catch (e) {
      final int? status = e.response?.statusCode;
      if (status == 409) throw Exception('That username is taken. Please try another.');
      if (status == 400) throw Exception(_serverMessage(e) ?? 'Please check the username and password.');
      throw Exception('Could not reach the server. Please try again.');
    }
  }

  static String? _serverMessage(DioException e) {
    final dynamic data = e.response?.data;
    return data is Map<String, dynamic> ? data['message'] as String? : null;
  }

  /// POST /api/auth/register
  Future<void> register({
    required String username,
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      await _apiClient.post(
        '/auth/register',
        data: <String, String>{
          'username': username,
          'email': email,
          'password': password,
          'displayName': displayName,
        },
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        throw Exception('Registration failed: username or email already exists, or a field is invalid.');
      }
      throw Exception('Could not reach the server. Please try again.');
    }
  }

  /// GET /api/auth/check with the current token.
  Future<SessionCheck> checkSession() async {
    try {
      final Response<dynamic> response = await _apiClient.get('/auth/check');
      return response.statusCode == 200 ? SessionCheck.valid : SessionCheck.invalid;
    } on DioException catch (e) {
      final int? status = e.response?.statusCode;
      if (status == 401 || status == 403) return SessionCheck.invalid;
      return SessionCheck.unknown;
    }
  }

  /// POST /api/auth/logout (clears the server cookie; errors are ignored).
  Future<void> logout() async {
    try {
      await _apiClient.post('/auth/logout');
    } catch (_) {}
  }
}
