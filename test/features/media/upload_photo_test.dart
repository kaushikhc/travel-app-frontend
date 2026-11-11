import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_app_frontend/core/network/api_client.dart';
import 'package:travel_app_frontend/features/media/data/media_repository.dart';

class FakeApi extends ApiClient {
  FakeApi() : super(baseUrl: 'https://api.example/api');
  final List<String> posts = <String>[];
  Object? uploadBody;

  @override
  Future<Response> post(String path, {dynamic data}) async {
    posts.add(path);
    if (path == '/media/uploads') uploadBody = data;
    final Map<String, dynamic> body = path == '/media/uploads'
        ? <String, dynamic>{
            'mediaId': 42,
            'uploadUrl': 'https://bucket.example/media/1/a.jpg?sig=1',
            'method': 'PUT',
            'headers': <String, dynamic>{'Content-Type': 'image/jpeg'},
          }
        : <String, dynamic>{'id': 42, 'status': 'READY'};
    return Response(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
      data: body,
    );
  }
}

class FailingAdapter implements HttpClientAdapter {
  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async =>
      ResponseBody.fromString('boom', 500);

  @override
  void close({bool force = false}) {}
}

class RecordingAdapter implements HttpClientAdapter {
  RequestOptions? request;
  List<int> body = <int>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    request = options;
    if (requestStream != null) {
      await for (final Uint8List chunk in requestStream) {
        body.addAll(chunk);
      }
    }
    return ResponseBody.fromString('', 200);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test('a failing storage PUT is reported with its step and HTTP status', () async {
    final Dio storage = Dio()..httpClientAdapter = FailingAdapter();
    await expectLater(
      MediaRepository(FakeApi(), storage: storage).uploadPhoto(Uint8List.fromList(<int>[1]), 'image/jpeg'),
      throwsA(
        isA<MediaUploadException>()
            .having((MediaUploadException e) => e.step, 'step', 'storage')
            .having((MediaUploadException e) => e.statusCode, 'statusCode', 500),
      ),
    );
  });

  test('uploadPhoto asks for a ticket, PUTs the bytes to the bucket without API headers, then completes', () async {
    final FakeApi api = FakeApi()..setAuthToken('secret-jwt');
    final RecordingAdapter adapter = RecordingAdapter();
    final Dio storage = Dio()..httpClientAdapter = adapter;
    final Uint8List bytes = Uint8List.fromList(<int>[1, 2, 3, 4]);

    final int id = await MediaRepository(api, storage: storage).uploadPhoto(bytes, 'image/jpeg');

    expect(id, 42);
    expect(api.posts, <String>['/media/uploads', '/media/42/complete']);
    expect(api.uploadBody, <String, dynamic>{'mimeType': 'image/jpeg', 'sizeBytes': 4});
    expect(adapter.request!.method, 'PUT');
    expect(adapter.request!.uri.toString(), 'https://bucket.example/media/1/a.jpg?sig=1');
    expect(adapter.request!.headers['Content-Type'] ?? adapter.request!.contentType, 'image/jpeg');
    expect(adapter.request!.headers.containsKey('Authorization'), isFalse);
    expect(adapter.body, <int>[1, 2, 3, 4]);
  });

  test('photoMimeType maps the extensions the backend accepts', () {
    expect(photoMimeType('Me.JPG'), 'image/jpeg');
    expect(photoMimeType('a.heic'), 'image/heic');
    expect(photoMimeType('a.gif'), isNull);
    expect(photoMimeType('noext'), isNull);
  });
}
