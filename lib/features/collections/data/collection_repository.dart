import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../auth/presentation/auth_state.dart';
import '../domain/collection_models.dart';

class CollectionRepository {
  final ApiClient _apiClient;

  const CollectionRepository(this._apiClient);

  /// GET /api/collections: global ones first as the server orders them, then the traveler's own.
  Future<List<CollectionSummary>> fetchCollections() async =>
      ((await _apiClient.get('/collections')).data as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(CollectionSummary.fromJson)
          .toList(growable: false);

  /// GET /api/collections/{id}
  Future<CollectionDetail> fetchCollection(int id) async =>
      CollectionDetail.fromJson((await _apiClient.get('/collections/$id')).data as Map<String, dynamic>);

  /// POST /api/collections (name required, at most 100 characters server side).
  Future<CollectionSummary> create({required String name, String? description}) async =>
      CollectionSummary.fromJson((await _apiClient.post('/collections', data: body(name, description))).data as Map<String, dynamic>);

  /// PUT /api/collections/{id}: renames or changes the description (403 for a global collection).
  Future<CollectionSummary> update(int id, {required String name, String? description}) async =>
      CollectionSummary.fromJson((await _apiClient.put('/collections/$id', data: body(name, description))).data as Map<String, dynamic>);

  static Map<String, dynamic> body(String name, String? description) => <String, dynamic>{
        'name': name.trim(),
        'description': description == null || description.trim().isEmpty ? null : description.trim(),
      };

  /// DELETE /api/collections/{id}
  Future<void> delete(int id) async {
    await _apiClient.delete('/collections/$id');
  }

  /// POST /api/collections/{id}/items (409 if the place is already there).
  Future<void> addPlace(int id, int placeId) async {
    await _apiClient.post('/collections/$id/items', data: <String, dynamic>{'placeId': placeId});
  }

  /// DELETE /api/collections/{id}/items/{placeId}
  Future<void> removePlace(int id, int placeId) async {
    await _apiClient.delete('/collections/$id/items/$placeId');
  }
}

final collectionRepositoryProvider = Provider<CollectionRepository>((Ref ref) => CollectionRepository(ref.watch(apiClientProvider)));

final collectionsProvider = FutureProvider.autoDispose<List<CollectionSummary>>((Ref ref) {
  ref.watch(authStateProvider.select((AuthState s) => s.isAuthenticated));
  return ref.watch(collectionRepositoryProvider).fetchCollections();
});

final collectionDetailProvider = FutureProvider.autoDispose.family<CollectionDetail, int>((Ref ref, int id) {
  ref.watch(authStateProvider.select((AuthState s) => s.isAuthenticated));
  return ref.watch(collectionRepositoryProvider).fetchCollection(id);
});
