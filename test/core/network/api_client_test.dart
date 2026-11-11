import 'package:flutter_test/flutter_test.dart';
import 'package:travel_app_frontend/core/network/api_client.dart';

void main() {
  test('local backend gets only headers its CORS allows', () {
    expect(ApiClient.headersFor('http://localhost/api').keys.toSet(), <String>{'Content-Type', 'Accept'});
  });

  test('ngrok host also gets the ngrok header', () {
    expect(ApiClient.headersFor('https://abc.ngrok-free.dev/api')['ngrok-skip-browser-warning'], 'true');
  });
}
