import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/time/api_time.dart';
import '../../auth/presentation/auth_state.dart';
import '../domain/memory_model.dart';

class MemoryRepository {
  final ApiClient _apiClient;

  const MemoryRepository(this._apiClient);

  /// GET /api/memories (newest first). [tag] filters on the server, any case.
  Future<List<MemoryModel>> fetchMemories({String? tag}) async {
    final bool filter = tag != null && tag.trim().isNotEmpty;
    final dynamic data = (await _apiClient.get(
      '/memories',
      queryParameters: filter ? <String, dynamic>{'tag': tag.trim()} : null,
    ))
        .data;
    return (data as List<dynamic>).whereType<Map<String, dynamic>>().map(MemoryModel.fromJson).toList(growable: false);
  }

  /// GET /api/memories/{id}
  Future<MemoryModel> fetchMemory(int id) async =>
      MemoryModel.fromJson((await _apiClient.get('/memories/$id')).data as Map<String, dynamic>);

  /// POST /api/memories (JSON). Photos are uploaded first with `MediaRepository.uploadPhoto`
  /// and passed as [mediaIds] in display order. The backend needs a title, a note or at least
  /// one photo, and a trip: without [tripId] it uses the traveler's ACTIVE trip (409 if none).
  /// [capturedAt] is sent as a UTC `LocalDateTime` (no offset).
  Future<MemoryModel> createMemory({
    int? tripId,
    String? title,
    String? note,
    MemoryVisibility visibility = MemoryVisibility.private,
    DateTime? capturedAt,
    List<String> tags = const <String>[],
    List<int> mediaIds = const <int>[],
  }) async {
    return MemoryModel.fromJson(
        (await _apiClient.post('/memories',
                data: createBody(
                  tripId: tripId,
                  title: title,
                  note: note,
                  visibility: visibility,
                  capturedAt: capturedAt,
                  tags: tags,
                  mediaIds: mediaIds,
                )))
            .data as Map<String, dynamic>);
  }

  static Map<String, dynamic> createBody({
    int? tripId,
    String? title,
    String? note,
    required MemoryVisibility visibility,
    DateTime? capturedAt,
    required List<String> tags,
    required List<int> mediaIds,
  }) {
    String? clean(String? s) => (s == null || s.trim().isEmpty) ? null : s.trim();
    return <String, dynamic>{
      'tripId': tripId,
      'title': clean(title),
      'note': clean(note),
      'visibility': visibility.apiName,
      'capturedAt': capturedAt == null ? null : ApiTime.formatApi(capturedAt),
      'tags': tags,
      'mediaIds': mediaIds,
    };
  }

  /// DELETE /api/memories/{id} (204).
  Future<void> deleteMemory(int id) async {
    await _apiClient.delete('/memories/$id');
  }
}

final memoryRepositoryProvider =
    Provider<MemoryRepository>((Ref ref) => MemoryRepository(ref.watch(apiClientProvider)));

/// All the traveler's memories, newest first. Reloaded when the signed-in user changes.
final memoriesProvider = FutureProvider.autoDispose<List<MemoryModel>>((Ref ref) {
  ref.watch(authStateProvider.select((AuthState s) => s.isAuthenticated));
  return ref.watch(memoryRepositoryProvider).fetchMemories();
});

final memoryDetailProvider = FutureProvider.autoDispose.family<MemoryModel, int>((Ref ref, int id) {
  ref.watch(authStateProvider.select((AuthState s) => s.isAuthenticated));
  return ref.watch(memoryRepositoryProvider).fetchMemory(id);
});
