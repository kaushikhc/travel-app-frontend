import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});

class ApiClient {
  late final Dio _dio;
  String? _authToken;

  static const String defaultApiUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://playtime-duchess-unweave.ngrok-free.dev/api',
  );

  ApiClient({String? baseUrl}) {
    String targetUrl = baseUrl ?? defaultApiUrl;
    
    // Dynamically adjust API base URL based on the browser's current location (Uri.base)
    try {
      final currentUri = Uri.base;
      if (currentUri.host.contains('localhost')) {
        targetUrl = 'http://localhost/api';
      } else if (currentUri.host.contains('ngrok-free.dev')) {
        targetUrl = '${currentUri.scheme}://${currentUri.host}/api';
      }
    } catch (_) {
      // Fallback to default in non-browser environments
    }

    _dio = Dio(
      BaseOptions(
        baseUrl: targetUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'ngrok-skip-browser-warning': 'true',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          options.extra['withCredentials'] = true;
          if (_authToken != null && _authToken!.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $_authToken';
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) {
          return handler.next(error);
        },
      ),
    );
  }

  String get baseUrl => _dio.options.baseUrl;

  bool get hasAuthToken => _authToken != null && _authToken!.isNotEmpty;

  void setAuthToken(String token) {
    _authToken = token;
  }

  void clearAuthToken() {
    _authToken = null;
  }

  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) async {
    return await _dio.get(path, queryParameters: queryParameters);
  }

  Future<Response> post(String path, {dynamic data}) async {
    return await _dio.post(path, data: data);
  }

  Future<Response> put(String path, {dynamic data}) async {
    return await _dio.put(path, data: data);
  }

  Future<Response> delete(String path) async {
    return await _dio.delete(path);
  }
}
