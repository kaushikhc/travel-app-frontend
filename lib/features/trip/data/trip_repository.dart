import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/time/api_time.dart';
import '../../auth/presentation/auth_state.dart';
import '../../profile/domain/api_date.dart';
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

  /// POST /api/trips. Status is not sent: the server derives it from the dates
  /// (no dates = DRAFT). Dates go as `yyyy-MM-dd`.
  Future<TripModel> createTrip({
    required String name,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    int? coverMediaId,
    List<String> tags = const <String>[],
  }) async {
    return TripModel.fromJson(
        (await _apiClient.post('/trips', data: _body(name, description, startDate, endDate, coverMediaId, tags))).data
            as Map<String, dynamic>);
  }

  static Map<String, dynamic> _body(String name, String? description, DateTime? startDate, DateTime? endDate,
          int? coverMediaId, List<String> tags) =>
      <String, dynamic>{
        'name': name.trim(),
        'description': (description == null || description.trim().isEmpty) ? null : description.trim(),
        'startDate': startDate == null ? null : ApiDate.format(startDate),
        'endDate': endDate == null ? null : ApiDate.format(endDate),
        'coverMediaId': coverMediaId,
        'tags': tags,
      };

  /// PUT /api/trips/{id}. The backend replaces every field: a null description,
  /// date or cover clears it, so always send the full current values.
  Future<TripModel> updateTrip(
    int id, {
    required String name,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    int? coverMediaId,
    List<String> tags = const <String>[],
  }) async =>
      TripModel.fromJson(
          (await _apiClient.put('/trips/$id', data: _body(name, description, startDate, endDate, coverMediaId, tags))).data
              as Map<String, dynamic>);

  /// GET /api/trips: all the traveler's trips, newest first.
  Future<List<TripModel>> fetchTrips() => _list('/trips', TripModel.fromJson);

  /// DELETE /api/trips/{id}: removes the trip and everything on it.
  Future<void> deleteTrip(int id) async {
    await _apiClient.delete('/trips/$id');
  }

  /// POST /api/trips/{tripId}/places: plans an existing place, optionally on a date. 409 if already planned.
  Future<void> addTripPlace(int tripId, {required int placeId, DateTime? plannedDate, String? notes}) async {
    await _apiClient.post('/trips/$tripId/places', data: tripPlaceBody(placeId: placeId, plannedDate: plannedDate, notes: notes));
  }

  static Map<String, dynamic> tripPlaceBody({required int placeId, DateTime? plannedDate, String? notes}) => <String, dynamic>{
        'placeId': placeId,
        if (plannedDate != null) 'plannedDate': ApiDate.format(plannedDate),
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      };

  /// PUT /api/trips/{tripId}/places/{id}: replaces date and notes (null clears them); [status] is
  /// PLANNED or SKIPPED, or null to keep it.
  Future<void> updateTripPlace(int tripId, int id, {DateTime? plannedDate, String? notes, String? status}) async {
    await _apiClient.put('/trips/$tripId/places/$id', data: tripPlaceUpdateBody(plannedDate: plannedDate, notes: notes, status: status));
  }

  static Map<String, dynamic> tripPlaceUpdateBody({DateTime? plannedDate, String? notes, String? status}) => <String, dynamic>{
        'plannedDate': plannedDate == null ? null : ApiDate.format(plannedDate),
        'notes': notes == null || notes.trim().isEmpty ? null : notes.trim(),
        'status': ?status,
      };

  /// DELETE /api/trips/{tripId}/places/{id}
  Future<void> deleteTripPlace(int tripId, int id) async {
    await _apiClient.delete('/trips/$tripId/places/$id');
  }

  /// POST (new) or PUT (when [id] is set) on /api/trips/{tripId}/visits. Say where with exactly one of
  /// [tripPlaceId] or [placeId]. Times are sent as UTC. The backend replaces the whole visit on PUT.
  Future<void> saveVisit(
    int tripId, {
    int? id,
    int? tripPlaceId,
    int? placeId,
    required DateTime visitedAt,
    DateTime? leftAt,
    String? notes,
  }) async {
    final Map<String, dynamic> body = visitBody(tripPlaceId: tripPlaceId, placeId: placeId, visitedAt: visitedAt, leftAt: leftAt, notes: notes);
    if (id == null) {
      await _apiClient.post('/trips/$tripId/visits', data: body);
    } else {
      await _apiClient.put('/trips/$tripId/visits/$id', data: body);
    }
  }

  static Map<String, dynamic> visitBody({int? tripPlaceId, int? placeId, required DateTime visitedAt, DateTime? leftAt, String? notes}) =>
      <String, dynamic>{
        'tripPlaceId': ?tripPlaceId,
        if (tripPlaceId == null) 'placeId': ?placeId,
        'visitedAt': ApiTime.formatApi(visitedAt),
        'leftAt': leftAt == null ? null : ApiTime.formatApi(leftAt),
        'notes': notes == null || notes.trim().isEmpty ? null : notes.trim(),
      };

  /// DELETE /api/trips/{tripId}/visits/{id}
  Future<void> deleteVisit(int tripId, int id) async {
    await _apiClient.delete('/trips/$tripId/visits/$id');
  }

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

/// All the traveler's trips (for pickers and names), newest first.
final tripsProvider = FutureProvider.autoDispose<List<TripModel>>((Ref ref) {
  ref.watch(authStateProvider.select((AuthState s) => s.isAuthenticated));
  return ref.watch(tripRepositoryProvider).fetchTrips();
});
