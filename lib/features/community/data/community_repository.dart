import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../domain/community_models.dart';

/// Which feed to read: people I follow (plus me), or recent public posts from everyone.
enum FeedKind { following, everyone }

class CommunityRepository {
  final ApiClient _apiClient;

  const CommunityRepository(this._apiClient);

  /// GET /api/community/feed or /api/community/recent, 0-based [page].
  Future<FeedPage> fetchFeed(FeedKind kind, {int page = 0, int size = 20}) async {
    final String path = kind == FeedKind.following ? '/community/feed' : '/community/recent';
    final dynamic data =
        (await _apiClient.get(path, queryParameters: <String, dynamic>{'page': page, 'size': size})).data;
    return FeedPage.fromJson(data as Map<String, dynamic>);
  }

  /// PUT or DELETE /api/posts/{id}/like; returns the updated post.
  Future<PostModel> setLike(int postId, {required bool liked}) async {
    final dynamic data = (liked ? await _apiClient.put('/posts/$postId/like') : await _apiClient.delete('/posts/$postId/like')).data;
    return PostModel.fromJson(data as Map<String, dynamic>);
  }

  /// POST /api/posts/share/{memoryId}: shares a memory (visibility defaults to the memory's; a
  /// PRIVATE memory gives 409).
  Future<PostModel> shareMemory(int memoryId) async =>
      PostModel.fromJson((await _apiClient.post('/posts/share/$memoryId')).data as Map<String, dynamic>);
}

final communityRepositoryProvider =
    Provider<CommunityRepository>((Ref ref) => CommunityRepository(ref.watch(apiClientProvider)));
