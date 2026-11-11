import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../domain/user_model.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AuthRepository(apiClient);
});

class AuthRepository {
  final ApiClient _apiClient;

  AuthRepository(this._apiClient);

  /// Dynamically computes Google OAuth2 URL based on configured API base URL
  String get googleAuthUrl {
    final baseUrl = _apiClient.baseUrl;
    final domain = baseUrl.replaceAll(RegExp(r'/api/?$'), '');
    return '$domain/oauth2/authorization/google';
  }

  /// POST /api/auth/login
  Future<String?> login(String username, String password) async {
    try {
      final response = await _apiClient.post(
        '/auth/login',
        data: {
          'username': username,
          'password': password,
        },
      );
      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        return data['token'] as String?;
      }
      return null;
    } on DioException catch (e) {
      if (e.response?.statusCode == 401 || e.response?.statusCode == 400) {
        throw Exception('Invalid username or password.');
      }
      throw Exception('Server error during login: ${e.message}');
    }
  }

  /// POST /api/auth/register
  Future<UserModel> register({
    required String username,
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final response = await _apiClient.post(
        '/auth/register',
        data: {
          'username': username,
          'email': email,
          'password': password,
          'displayName': displayName,
        },
      );

      if (response.statusCode == 201 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        return UserModel(
          id: data['id']?.toString() ?? '1',
          username: data['username'] as String? ?? username,
          email: data['email'] as String? ?? email,
        );
      }
      throw Exception('Failed to create account.');
    } on DioException catch (e) {
      if (e.response?.statusCode == 400) {
        throw Exception('Registration failed: Username or Email already exists.');
      }
      throw Exception('Server error during registration: ${e.message}');
    }
  }

  /// GET /api/auth/check
  Future<bool> checkLoginStatus() async {
    try {
      final response = await _apiClient.get('/auth/check');
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// POST /api/auth/logout
  Future<void> logout() async {
    try {
      await _apiClient.post('/auth/logout');
    } catch (_) {
      // Ignore logout network errors
    }
  }
}
