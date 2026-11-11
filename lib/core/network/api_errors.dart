import 'package:dio/dio.dart';

/// The server's `{message}` for a failed call, else [fallback] (or a connection hint when the
/// server could not be reached).
String apiErrorMessage(Object error, String fallback) {
  if (error is DioException) {
    final dynamic data = error.response?.data;
    if (data is Map<String, dynamic> && data['message'] is String) return data['message'] as String;
    if (error.response == null) return 'Could not reach the server. Please try again.';
  }
  return fallback;
}
