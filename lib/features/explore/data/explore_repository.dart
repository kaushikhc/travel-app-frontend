import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../auth/presentation/auth_state.dart';
import '../../profile/domain/api_date.dart';
import '../domain/category_model.dart';
import '../domain/place_model.dart';
import '../domain/wishlist_item_model.dart';

class ExploreRepository {
  final ApiClient _apiClient;

  const ExploreRepository(this._apiClient);

  static List<Map<String, dynamic>> _maps(dynamic data) =>
      (data as List<dynamic>).whereType<Map<String, dynamic>>().toList(growable: false);

  /// GET /api/explore/categories (sorted by name).
  Future<List<CategoryModel>> fetchCategories() async =>
      _maps((await _apiClient.get('/explore/categories')).data).map(CategoryModel.fromJson).toList(growable: false);

  /// GET /api/explore/places/category/{category}: matched by category name, any case; the
  /// server returns at most 50 by default.
  Future<List<PlaceModel>> fetchPlacesByCategory(String category) async => _maps(
        (await _apiClient.get('/explore/places/category/${Uri.encodeComponent(category.trim())}')).data,
      ).map(PlaceModel.fromJson).toList(growable: false);

  /// GET /api/places?q=: name search. The server rejects a query shorter than 2 characters (400).
  Future<List<PlaceModel>> searchPlaces(String query) async =>
      _maps((await _apiClient.get('/places', queryParameters: <String, dynamic>{'q': query.trim()})).data)
          .map(PlaceModel.fromJson)
          .toList(growable: false);

  /// POST /api/places with type CITY: adds a city the seed list lacks. The server reuses a city with
  /// the same name (any case) in the same country, so this is safe to repeat.
  Future<PlaceModel> createCity({required String name, required String countryCode}) async =>
      PlaceModel.fromJson((await _apiClient.post('/places', data: cityBody(name: name, countryCode: countryCode))).data as Map<String, dynamic>);

  static Map<String, dynamic> cityBody({required String name, required String countryCode}) =>
      <String, dynamic>{'name': name.trim(), 'type': 'CITY', 'countryCode': countryCode.trim().toUpperCase()};

  /// GET /api/places/{id}
  Future<PlaceModel> fetchPlace(int id) async =>
      PlaceModel.fromJson((await _apiClient.get('/places/$id')).data as Map<String, dynamic>);

  /// GET /api/explore/wishlist (newest first).
  Future<List<WishlistItemModel>> fetchWishlist() async =>
      _maps((await _apiClient.get('/explore/wishlist')).data).map(WishlistItemModel.fromJson).toList(growable: false);

  /// POST /api/explore/wishlist `{placeId}` (201). 409 if the place is already there.
  Future<WishlistItemModel> addToWishlist(int placeId) async => WishlistItemModel.fromJson(
        (await _apiClient.post('/explore/wishlist', data: <String, dynamic>{'placeId': placeId})).data
            as Map<String, dynamic>,
      );

  /// DELETE /api/explore/wishlist/{itemId} (204). The id is the wishlist item's, not the place's.
  Future<void> removeFromWishlist(int itemId) async {
    await _apiClient.delete('/explore/wishlist/$itemId');
  }

  static Map<String, dynamic> planBody({
    required int tripId,
    DateTime? plannedDate,
    String? notes,
    bool removeFromWishlist = false,
  }) =>
      <String, dynamic>{
        'tripId': tripId,
        'plannedDate': plannedDate == null ? null : ApiDate.format(plannedDate),
        'notes': notes == null || notes.trim().isEmpty ? null : notes.trim(),
        'removeFromWishlist': removeFromWishlist,
      };

  /// POST /api/explore/wishlist/{itemId}/plan (201 with the new trip place). The item stays on the
  /// wishlist unless [removeFromWishlist]. 404 if the item or trip is not the caller's, 409 if the
  /// trip already plans the place.
  Future<void> planOnTrip({
    required int itemId,
    required int tripId,
    DateTime? plannedDate,
    String? notes,
    bool removeFromWishlist = false,
  }) async {
    await _apiClient.post(
      '/explore/wishlist/$itemId/plan',
      data: planBody(
        tripId: tripId,
        plannedDate: plannedDate,
        notes: notes,
        removeFromWishlist: removeFromWishlist,
      ),
    );
  }
}

final exploreRepositoryProvider =
    Provider<ExploreRepository>((Ref ref) => ExploreRepository(ref.watch(apiClientProvider)));

final categoriesProvider = FutureProvider.autoDispose<List<CategoryModel>>((Ref ref) {
  ref.watch(authStateProvider.select((AuthState s) => s.isAuthenticated));
  return ref.watch(exploreRepositoryProvider).fetchCategories();
});

/// Places in one category, by category name.
final placesByCategoryProvider = FutureProvider.autoDispose.family<List<PlaceModel>, String>((Ref ref, String name) {
  ref.watch(authStateProvider.select((AuthState s) => s.isAuthenticated));
  return ref.watch(exploreRepositoryProvider).fetchPlacesByCategory(name);
});

/// Name search; callers pass an already debounced, trimmed query of at least 2 characters.
final placeSearchProvider = FutureProvider.autoDispose.family<List<PlaceModel>, String>((Ref ref, String query) {
  ref.watch(authStateProvider.select((AuthState s) => s.isAuthenticated));
  return ref.watch(exploreRepositoryProvider).searchPlaces(query);
});

final placeDetailProvider = FutureProvider.autoDispose.family<PlaceModel, int>((Ref ref, int id) {
  ref.watch(authStateProvider.select((AuthState s) => s.isAuthenticated));
  return ref.watch(exploreRepositoryProvider).fetchPlace(id);
});

final wishlistProvider = FutureProvider.autoDispose<List<WishlistItemModel>>((Ref ref) {
  ref.watch(authStateProvider.select((AuthState s) => s.isAuthenticated));
  return ref.watch(exploreRepositoryProvider).fetchWishlist();
});
