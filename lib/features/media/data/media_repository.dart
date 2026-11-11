import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

/// The image types the backend accepts, by file extension.
const Map<String, String> photoMimeTypes = <String, String>{
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'png': 'image/png',
  'webp': 'image/webp',
  'heic': 'image/heic',
  'heif': 'image/heif',
};

/// The mime type for a picked file name, or null if the backend won't take it.
String? photoMimeType(String fileName) {
  final int dot = fileName.lastIndexOf('.');
  return dot < 0 ? null : photoMimeTypes[fileName.substring(dot + 1).toLowerCase()];
}

class MediaRepository {
  final ApiClient _apiClient;
  final Dio _storage;

  /// [storage] sends the file to the signed upload URL. It must be a plain client: the
  /// API's base URL, JSON headers and bearer token must not go to the bucket.
  MediaRepository(this._apiClient, {Dio? storage}) : _storage = storage ?? Dio();

  /// Uploads a photo the way the backend expects: ask for a signed URL, PUT the bytes
  /// there, then confirm. Returns the media id, ready to attach (profile photo, trip cover).
  Future<int> uploadPhoto(Uint8List bytes, String mimeType) async {
    final Map<String, dynamic> ticket =
        (await _apiClient.post(
              '/media/uploads',
              data: <String, dynamic>{'mimeType': mimeType, 'sizeBytes': bytes.length},
            )).data
            as Map<String, dynamic>;
    final int mediaId = ticket['mediaId'] as int;
    final Map<String, dynamic> headers = Map<String, dynamic>.from(
      (ticket['headers'] as Map<String, dynamic>?) ?? <String, dynamic>{},
    );
    await _storage.request<void>(
      ticket['uploadUrl'] as String,
      data: bytes,
      options: Options(method: ticket['method'] as String? ?? 'PUT', headers: headers),
    );
    await _apiClient.post('/media/$mediaId/complete');
    return mediaId;
  }

  /// GET /api/media/{id}: the signed download link, or null if the media is missing,
  /// not the caller's, or not uploaded yet.
  Future<String?> fetchDownloadUrl(int mediaId) async {
    try {
      final dynamic data = (await _apiClient.get('/media/$mediaId')).data;
      if (data is! Map<String, dynamic> || data['status'] != 'READY') return null;
      final String? url = data['url'] as String?;
      return (url == null || url.isEmpty) ? null : url;
    } on DioException catch (e) {
      final int? status = e.response?.statusCode;
      if (status == 404 || status == 403) return null;
      rethrow;
    }
  }
}

final mediaRepositoryProvider = Provider<MediaRepository>((Ref ref) => MediaRepository(ref.watch(apiClientProvider)));

/// Signed links expire after the backend's download TTL (1 hour by default), so a link is
/// reused for a bit less than that and then fetched again.
const Duration mediaUrlReuse = Duration(minutes: 50);

/// The download link for a media id, cached for [mediaUrlReuse].
final mediaUrlProvider = FutureProvider.autoDispose.family<String?, int>((Ref ref, int mediaId) async {
  final String? url = await ref.watch(mediaRepositoryProvider).fetchDownloadUrl(mediaId);
  final link = ref.keepAlive();
  final Timer timer = Timer(mediaUrlReuse, link.close);
  ref.onDispose(timer.cancel);
  return url;
});
