import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../explore/domain/place_model.dart';
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

  /// GET /api/places/countries/{code}/regions: states, provinces and so on, A to Z.
  Future<List<PlaceModel>> fetchRegions(String countryCode) async => _places(
        (await _apiClient.get('/places/countries/${Uri.encodeComponent(countryCode)}/regions')).data,
      );

  /// GET /api/places/cities for a country, narrowed to a region when [regionCode] is given. Seeded cities have no
  /// region, so with a region only cities added under it come back.
  Future<List<PlaceModel>> fetchCities({required String countryCode, String? regionCode}) async => _places(
        (await _apiClient.get('/places/cities', queryParameters: <String, dynamic>{
          'countryCode': countryCode,
          'regionCode': ?regionCode,
        }))
            .data,
      );

  static List<PlaceModel> _places(dynamic data) => data is! List<dynamic>
      ? const <PlaceModel>[]
      : data.whereType<Map<String, dynamic>>().map(PlaceModel.fromJson).toList(growable: false);
}

final countryRepositoryProvider = Provider<CountryRepository>(
  (Ref ref) => CountryRepository(ref.watch(apiClientProvider)),
);

/// Countries are seed data, so they are loaded once per session and kept.
final countriesProvider = FutureProvider<List<CountryModel>>(
  (Ref ref) => ref.watch(countryRepositoryProvider).fetchCountries(),
);

/// (country code, region code or null) -> regions / cities, kept for the session.
final regionsProvider = FutureProvider.family<List<PlaceModel>, String>(
  (Ref ref, String countryCode) => ref.watch(countryRepositoryProvider).fetchRegions(countryCode),
);

final citiesProvider = FutureProvider.family<List<PlaceModel>, ({String countryCode, String? regionCode})>(
  (Ref ref, ({String countryCode, String? regionCode}) key) =>
      ref.watch(countryRepositoryProvider).fetchCities(countryCode: key.countryCode, regionCode: key.regionCode),
);
