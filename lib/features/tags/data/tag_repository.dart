import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../auth/presentation/auth_state.dart';

class TagRepository {
  final ApiClient _apiClient;

  const TagRepository(this._apiClient);

  /// GET /api/tags: every tag the traveler already uses, most used first.
  Future<List<String>> fetchTags() async {
    final dynamic data = (await _apiClient.get('/tags')).data;
    if (data is! List<dynamic>) return const <String>[];
    return <String>[
      for (final Map<String, dynamic> m
          in data.whereType<Map<String, dynamic>>())
        if ((m['tag'] as String?)?.trim().isNotEmpty ?? false)
          (m['tag'] as String).trim(),
    ];
  }
}

final tagRepositoryProvider = Provider<TagRepository>(
  (Ref ref) => TagRepository(ref.watch(apiClientProvider)),
);

/// The traveler's existing tags, for suggestions in tag fields.
final myTagsProvider = FutureProvider.autoDispose<List<String>>((Ref ref) {
  ref.watch(authStateProvider.select((AuthState s) => s.isAuthenticated));
  return ref.watch(tagRepositoryProvider).fetchTags();
});
