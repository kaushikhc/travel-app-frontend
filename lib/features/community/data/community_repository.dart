import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../domain/community_models.dart';

/// Which feed to read: people I follow (plus me), or recent public posts from everyone.
enum FeedKind { following, everyone }

/// Which of my own connection lists to read.
enum ConnectionKind { followers, following }

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

  /// GET /api/travelers/{id}
  Future<TravelerCard> fetchTraveler(int id) async =>
      TravelerCard.fromJson((await _apiClient.get('/travelers/$id')).data as Map<String, dynamic>);

  /// GET /api/travelers/{id}/posts, 0-based [page].
  Future<FeedPage> fetchTravelerPosts(int id, {int page = 0, int size = 20}) async => FeedPage.fromJson(
      (await _apiClient.get('/travelers/$id/posts', queryParameters: <String, dynamic>{'page': page, 'size': size})).data
          as Map<String, dynamic>);

  /// GET /api/community/followers or /following: the signed-in traveler's own lists, 0-based [page].
  Future<List<TravelerCard>> fetchConnections(ConnectionKind kind, {int page = 0, int size = 50}) async {
    final String path = kind == ConnectionKind.followers ? '/community/followers' : '/community/following';
    final dynamic data =
        (await _apiClient.get(path, queryParameters: <String, dynamic>{'page': page, 'size': size})).data;
    return (data as List<dynamic>).map((dynamic e) => TravelerCard.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// PUT or DELETE /api/travelers/{id}/follow; returns the updated card (400 for yourself).
  Future<TravelerCard> setFollow(int id, {required bool follow}) async {
    final dynamic data = (follow ? await _apiClient.put('/travelers/$id/follow') : await _apiClient.delete('/travelers/$id/follow')).data;
    return TravelerCard.fromJson(data as Map<String, dynamic>);
  }

  /// POST /api/posts/share/{memoryId}: shares a memory (visibility defaults to the memory's; a
  /// PRIVATE memory gives 409).
  Future<PostModel> shareMemory(int memoryId) async =>
      PostModel.fromJson((await _apiClient.post('/posts/share/$memoryId')).data as Map<String, dynamic>);
}

final communityRepositoryProvider =
    Provider<CommunityRepository>((Ref ref) => CommunityRepository(ref.watch(apiClientProvider)));

final travelerProvider = FutureProvider.autoDispose.family<TravelerCard, int>(
    (Ref ref, int id) => ref.watch(communityRepositoryProvider).fetchTraveler(id));

final travelerPostsProvider = FutureProvider.autoDispose.family<FeedPage, int>(
    (Ref ref, int id) => ref.watch(communityRepositoryProvider).fetchTravelerPosts(id));

final connectionsProvider = FutureProvider.autoDispose.family<List<TravelerCard>, ConnectionKind>(
    (Ref ref, ConnectionKind kind) => ref.watch(communityRepositoryProvider).fetchConnections(kind));
