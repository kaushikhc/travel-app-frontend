import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

class MediaRepository {
  final ApiClient _apiClient;

  const MediaRepository(this._apiClient);

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
