import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../auth/presentation/auth_state.dart';
import '../domain/journey_models.dart';
import '../domain/trip_memory_view_model.dart';

class JourneyRepository {
  final ApiClient _apiClient;

  const JourneyRepository(this._apiClient);

  List<Map<String, dynamic>> _maps(dynamic data) => (data as List<dynamic>).whereType<Map<String, dynamic>>().toList(growable: false);

  /// GET /api/statistics/me
  Future<LifetimeStats> fetchStats() async =>
      LifetimeStats.fromJson((await _apiClient.get('/statistics/me')).data as Map<String, dynamic>);

  /// GET /api/history/regions (countries, with their regions)
  Future<List<VisitedCountry>> fetchCountries() async {
    final Map<String, dynamic> data = (await _apiClient.get('/history/regions')).data as Map<String, dynamic>;
    return <VisitedCountry>[
      for (final Object? c in data['countries'] as List<dynamic>? ?? const <dynamic>[])
        if (c is Map<String, dynamic>) VisitedCountry.fromJson(c),
    ];
  }

  /// GET /api/history/trips (past trips, newest first)
  Future<List<PastTrip>> fetchPastTrips() async =>
      _maps((await _apiClient.get('/history/trips')).data).map(PastTrip.fromJson).toList(growable: false);

  /// GET /api/history/trips/{id}: the Trip Memory View in one response.
  Future<TripMemoryViewData> fetchTripMemoryView(int id) async =>
      TripMemoryViewData.fromJson((await _apiClient.get('/history/trips/$id')).data as Map<String, dynamic>);

  /// GET /api/history/map (GeoJSON)
  Future<MapData> fetchMap() async => MapData.fromJson((await _apiClient.get('/history/map')).data as Map<String, dynamic>);

  /// GET /api/history/timeline, newest first; pass the previous page's `nextBefore` as [before].
  Future<TimelinePage> fetchTimeline({String? before, int limit = 50}) async => TimelinePage.fromJson((await _apiClient.get(
        '/history/timeline',
        queryParameters: <String, dynamic>{'limit': limit, 'before': ?before},
      ))
          .data as Map<String, dynamic>);
}

final journeyRepositoryProvider = Provider<JourneyRepository>((Ref ref) => JourneyRepository(ref.watch(apiClientProvider)));

Future<T> _authed<T>(Ref ref, Future<T> Function(JourneyRepository r) call) {
  ref.watch(authStateProvider.select((AuthState s) => s.isAuthenticated));
  return call(ref.watch(journeyRepositoryProvider));
}

final lifetimeStatsProvider = FutureProvider.autoDispose<LifetimeStats>((Ref ref) => _authed(ref, (JourneyRepository r) => r.fetchStats()));
final visitedCountriesProvider =
    FutureProvider.autoDispose<List<VisitedCountry>>((Ref ref) => _authed(ref, (JourneyRepository r) => r.fetchCountries()));
final pastTripsProvider = FutureProvider.autoDispose<List<PastTrip>>((Ref ref) => _authed(ref, (JourneyRepository r) => r.fetchPastTrips()));
final journeyMapProvider = FutureProvider.autoDispose<MapData>((Ref ref) => _authed(ref, (JourneyRepository r) => r.fetchMap()));
final tripMemoryViewProvider = FutureProvider.autoDispose.family<TripMemoryViewData, int>(
    (Ref ref, int id) => _authed(ref, (JourneyRepository r) => r.fetchTripMemoryView(id)));
