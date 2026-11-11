import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../auth/presentation/auth_state.dart';
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
