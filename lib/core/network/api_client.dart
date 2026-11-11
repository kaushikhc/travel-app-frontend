import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});

class ApiClient {
  late final Dio _dio;
  String? _authToken;

  /// Called once per rejected session: a 401 on a call made with the current token (not on the
  /// `/auth/...` calls, where 401 can simply mean wrong credentials). Set by the auth notifier.
  void Function()? onUnauthorized;

  static const String defaultApiUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://playtime-duchess-unweave.ngrok-free.dev/api',
  );

  ApiClient({String? baseUrl, HttpClientAdapter? adapter}) {
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
        headers: headersFor(targetUrl),
      ),
    );

    if (adapter != null) _dio.httpClientAdapter = adapter;

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
          if (isSessionRejection(error, _authToken)) onUnauthorized?.call();
          return handler.next(error);
        },
      ),
    );
  }

  /// True when [error] is a 401 for a request that carried [currentToken] (so a late answer to
  /// an old request cannot sign out a newer session) and is not an `/auth/` call.
  static bool isSessionRejection(DioException error, String? currentToken) {
    if (error.response?.statusCode != 401 || currentToken == null || currentToken.isEmpty) return false;
    if (error.requestOptions.path.startsWith('/auth/')) return false;
    return error.requestOptions.headers['Authorization'] == 'Bearer $currentToken';
  }

  String get baseUrl => _dio.options.baseUrl;

  /// Default headers. The ngrok header is sent only to ngrok hosts: the backend's CORS
  /// allows just Authorization, Content-Type and Accept, so any other header makes the
  /// browser's preflight fail and every call from localhost:8080 look like a network error.
  static Map<String, String> headersFor(String baseUrl) {
    final Map<String, String> headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (Uri.tryParse(baseUrl)?.host.contains('ngrok') ?? false) {
      headers['ngrok-skip-browser-warning'] = 'true';
    }
    return headers;
  }

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

  Future<Response> patch(String path, {dynamic data}) async {
    return await _dio.patch(path, data: data);
  }

  Future<Response> delete(String path) async {
    return await _dio.delete(path);
  }
}
