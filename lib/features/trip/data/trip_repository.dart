import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../auth/presentation/auth_state.dart';
import '../domain/trip_detail_model.dart';
import '../domain/trip_model.dart';

class TripRepository {
  final ApiClient _apiClient;

  const TripRepository(this._apiClient);

  /// GET /api/trips/home
  Future<HomeOverview> fetchHome() async =>
      HomeOverview.fromJson((await _apiClient.get('/trips/home')).data as Map<String, dynamic>);

  /// GET /api/statistics/me
  Future<TravelStats> fetchStats() async =>
      TravelStats.fromJson((await _apiClient.get('/statistics/me')).data as Map<String, dynamic>);

  /// GET /api/trips/{id}
  Future<TripModel> fetchTrip(int id) async =>
      TripModel.fromJson((await _apiClient.get('/trips/$id')).data as Map<String, dynamic>);

  Future<List<T>> _list<T>(String path, T Function(Map<String, dynamic>) parse) async =>
      ((await _apiClient.get(path)).data as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(parse)
          .toList(growable: false);

  /// The trip plus its places, stays, transports and visits, loaded in parallel.
  Future<TripDetail> fetchTripDetail(int id) async {
    final List<Object> r = await Future.wait<Object>(<Future<Object>>[
      fetchTrip(id),
      _list('/trips/$id/places', TripPlaceItem.fromJson),
      _list('/trips/$id/accommodations', StayItem.fromJson),
      _list('/trips/$id/transports', TransportItem.fromJson),
      _list('/trips/$id/visits', VisitItem.fromJson),
    ]);
    return TripDetail(
      trip: r[0] as TripModel,
      places: r[1] as List<TripPlaceItem>,
      stays: r[2] as List<StayItem>,
      transports: r[3] as List<TransportItem>,
      visits: r[4] as List<VisitItem>,
    );
  }
}

final tripRepositoryProvider = Provider<TripRepository>((Ref ref) => TripRepository(ref.watch(apiClientProvider)));

/// Reloaded each time Home is opened and whenever the signed-in user changes.
final homeOverviewProvider = FutureProvider.autoDispose<HomeOverview>((Ref ref) {
  ref.watch(authStateProvider.select((AuthState s) => s.isAuthenticated));
  return ref.watch(tripRepositoryProvider).fetchHome();
});

final travelStatsProvider = FutureProvider.autoDispose<TravelStats>((Ref ref) {
  ref.watch(authStateProvider.select((AuthState s) => s.isAuthenticated));
  return ref.watch(tripRepositoryProvider).fetchStats();
});

final tripDetailProvider = FutureProvider.autoDispose.family<TripDetail, int>((Ref ref, int tripId) {
  ref.watch(authStateProvider.select((AuthState s) => s.isAuthenticated));
  return ref.watch(tripRepositoryProvider).fetchTripDetail(tripId);
});
