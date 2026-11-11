import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../domain/country_model.dart';

class CountryRepository {
  final ApiClient _apiClient;

  const CountryRepository(this._apiClient);

  /// GET /api/places/countries (sorted A to Z by the server).
  Future<List<CountryModel>> fetchCountries() async {
    final dynamic data = (await _apiClient.get('/places/countries')).data;
    if (data is! List<dynamic>) return const <CountryModel>[];
    return data
        .whereType<Map<String, dynamic>>()
        .map(CountryModel.fromJson)
        .toList(growable: false);
  }
}

final countryRepositoryProvider = Provider<CountryRepository>(
  (Ref ref) => CountryRepository(ref.watch(apiClientProvider)),
);

/// Countries are seed data, so they are loaded once per session and kept.
final countriesProvider = FutureProvider<List<CountryModel>>(
  (Ref ref) => ref.watch(countryRepositoryProvider).fetchCountries(),
);
