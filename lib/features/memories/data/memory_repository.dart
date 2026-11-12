import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/time/api_time.dart';
import '../../auth/presentation/auth_state.dart';
import '../domain/memory_model.dart';

class MemoryRepository {
  final ApiClient _apiClient;

  const MemoryRepository(this._apiClient);

  /// GET /api/memories (newest first). [tag] filters on the server, any case.
  /// [placeId] keeps memories at that place or at places inside it (a city's sights), [tripId] one trip.
  Future<List<MemoryModel>> fetchMemories({String? tag, int? tripId, int? placeId}) async {
    final bool filter = tag != null && tag.trim().isNotEmpty;
    final Map<String, dynamic> query = <String, dynamic>{
      if (filter) 'tag': tag.trim(),
      'tripId': ?tripId,
      'placeId': ?placeId,
    };
    final dynamic data = (await _apiClient.get(
      '/memories',
      queryParameters: query.isEmpty ? null : query,
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
  /// [capturedAt] is sent as a UTC `LocalDateTime` (no offset). Leave it null to let the backend use
  /// the earliest capture time of the photos (their EXIF), else the time of saving.
  Future<MemoryModel> createMemory({
    int? tripId,
    int? placeId,
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
                  placeId: placeId,
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
    int? placeId,
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
      'placeId': ?placeId,
      'title': clean(title),
      'note': clean(note),
      'visibility': visibility.apiName,
      'capturedAt': capturedAt == null ? null : ApiTime.formatApi(capturedAt),
      'tags': tags,
      'mediaIds': mediaIds,
    };
  }

  /// PATCH /api/memories/{id}. See [updateBody] for what is sent.
  Future<MemoryModel> updateMemory(
    int id, {
    required String title,
    required String note,
    required MemoryVisibility visibility,
    required List<String> tags,
    required List<int> mediaIds,
    DateTime? capturedAt,
  }) async {
    return MemoryModel.fromJson(
      (await _apiClient.patch(
            '/memories/$id',
            data: updateBody(
              title: title,
              note: note,
              visibility: visibility,
              tags: tags,
              mediaIds: mediaIds,
              capturedAt: capturedAt,
            ),
          )).data
          as Map<String, dynamic>,
    );
  }

  /// The PATCH body. The backend leaves out-of-body fields unchanged, so `visitId` and `placeId`
  /// are never sent here (a JSON null would clear visit and place), and `capturedAt` is sent only
  /// when the traveler changed it. Title and note
  /// are sent trimmed, and an empty string clears them. `tags` and `mediaIds` replace the whole
  /// set or list; media left out of `mediaIds` is deleted by the server if nothing else uses it.
  static Map<String, dynamic> updateBody({
    required String title,
    required String note,
    required MemoryVisibility visibility,
    required List<String> tags,
    required List<int> mediaIds,
    DateTime? capturedAt,
  }) => <String, dynamic>{
    'title': title.trim(),
    if (capturedAt != null) 'capturedAt': ApiTime.formatApi(capturedAt),
    'note': note.trim(),
    'visibility': visibility.apiName,
    'tags': tags,
    'mediaIds': mediaIds,
  };

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

/// Memories at one place (or inside it, for a city) on one trip: the itinerary's memories link.
final placeMemoriesProvider =
    FutureProvider.autoDispose.family<List<MemoryModel>, ({int tripId, int placeId})>((Ref ref, ({int tripId, int placeId}) key) {
  ref.watch(authStateProvider.select((AuthState s) => s.isAuthenticated));
  return ref.watch(memoryRepositoryProvider).fetchMemories(tripId: key.tripId, placeId: key.placeId);
});

final memoryDetailProvider = FutureProvider.autoDispose.family<MemoryModel, int>((Ref ref, int id) {
  ref.watch(authStateProvider.select((AuthState s) => s.isAuthenticated));
  return ref.watch(memoryRepositoryProvider).fetchMemory(id);
});
