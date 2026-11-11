import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_app_frontend/core/network/api_client.dart';
import 'package:travel_app_frontend/features/explore/data/explore_repository.dart';
import 'package:travel_app_frontend/features/explore/domain/category_model.dart';
import 'package:travel_app_frontend/features/explore/domain/place_model.dart';
import 'package:travel_app_frontend/features/explore/domain/wishlist_item_model.dart';
import 'package:travel_app_frontend/features/explore/presentation/explore_view.dart';

const Map<String, dynamic> _place = <String, dynamic>{
  'id': 11,
  'name': 'Fort Kochi',
  'type': 'ATTRACTION',
  'latitude': 9.96,
  'longitude': 76.24,
  'address': 'Kochi, Kerala',
  'isoCode': null,
  'countryId': 5,
};

const Map<String, dynamic> _item = <String, dynamic>{
  'id': 4,
  'placeId': 11,
  'placeName': 'Fort Kochi',
  'place': _place,
  'plannedTripIds': <int>[3],
  'visited': true,
  'createdAt': '2026-11-11T12:00:00',
};

class FakeApi extends ApiClient {
  FakeApi() : super(baseUrl: 'https://api.example/api');
  final List<String> calls = <String>[];
  Map<String, dynamic>? query;
  Object? body;

  Response<dynamic> _ok(String path, Object? data, [int code = 200]) =>
      Response<dynamic>(requestOptions: RequestOptions(path: path), statusCode: code, data: data);

  @override
  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) async {
    calls.add('GET $path');
    if (queryParameters != null) query = queryParameters;
    if (path == '/explore/wishlist') return _ok(path, <Map<String, dynamic>>[_item]);
    if (path == '/explore/categories') {
      return _ok(path, <Map<String, dynamic>>[
        <String, dynamic>{'id': 1, 'name': 'Beach', 'parentCategoryId': null},
      ]);
    }
    if (path.startsWith('/places/')) return _ok(path, _place);
    return _ok(path, <Map<String, dynamic>>[_place]);
  }

  @override
  Future<Response> post(String path, {dynamic data}) async {
    calls.add('POST $path');
    body = data;
    return _ok(path, path.endsWith('/plan') ? <String, dynamic>{'id': 1} : _item, 201);
  }

  @override
  Future<Response> delete(String path) async {
    calls.add('DELETE $path');
    return _ok(path, null, 204);
  }
}

void main() {
  test('PlaceModel, CategoryModel and WishlistItemModel read the API json', () {
    final PlaceModel p = PlaceModel.fromJson(_place);
    expect(p.id, 11);
    expect(p.latitude, 9.96);
    expect(p.isoCode, isNull);
    expect(p.subtitle, 'ATTRACTION · Kochi, Kerala');
    final CategoryModel c = CategoryModel.fromJson(<String, dynamic>{'id': 1, 'name': 'Beach', 'parentCategoryId': 2});
    expect((c.id, c.name, c.parentCategoryId), (1, 'Beach', 2));
    final WishlistItemModel w = WishlistItemModel.fromJson(_item);
    expect(w.id, 4);
    expect(w.place.name, 'Fort Kochi');
    expect(w.plannedTripIds, <int>[3]);
    expect(w.visited, isTrue);
    expect(w.createdAt, DateTime.utc(2026, 11, 11, 12));
    final WishlistItemModel flat =
        WishlistItemModel.fromJson(<String, dynamic>{'id': 5, 'placeId': 9, 'placeName': 'Old'});
    expect((flat.place.id, flat.place.name, flat.visited), (9, 'Old', false));
  });

  test('repository uses the documented paths, params and bodies', () async {
    final FakeApi api = FakeApi();
    final ExploreRepository repo = ExploreRepository(api);
    expect((await repo.fetchCategories()).single.name, 'Beach');
    expect((await repo.fetchPlacesByCategory(' Hill Station ')).single.id, 11);
    expect(api.calls.last, 'GET /explore/places/category/Hill%20Station');
    expect((await repo.searchPlaces(' kochi ')).single.id, 11);
    expect(api.query, <String, dynamic>{'q': 'kochi'});
    expect((await repo.fetchPlace(11)).name, 'Fort Kochi');
    expect((await repo.fetchWishlist()).single.id, 4);
    await repo.addToWishlist(11);
    expect(api.body, <String, dynamic>{'placeId': 11});
    await repo.removeFromWishlist(4);
    await repo.planOnTrip(itemId: 4, tripId: 3, plannedDate: DateTime(2026, 12, 1), notes: ' lunch ');
    expect(api.body, <String, dynamic>{
      'tripId': 3,
      'plannedDate': '2026-12-01',
      'notes': 'lunch',
      'removeFromWishlist': false,
    });
    expect(api.calls, <String>[
      'GET /explore/categories',
      'GET /explore/places/category/Hill%20Station',
      'GET /places',
      'GET /places/11',
      'GET /explore/wishlist',
      'POST /explore/wishlist',
      'DELETE /explore/wishlist/4',
      'POST /explore/wishlist/4/plan',
    ]);
  });

  Widget app(FakeApi api) => ProviderScope(
        overrides: [exploreRepositoryProvider.overrideWithValue(ExploreRepository(api))],
        child: const MaterialApp(home: ExploreView(searchDelay: Duration(milliseconds: 10))),
      );

  testWidgets('lists the first category and toggles the wishlist', (WidgetTester tester) async {
    final FakeApi api = FakeApi();
    await tester.pumpWidget(app(api));
    await tester.pumpAndSettle();
    expect(api.calls, contains('GET /explore/places/category/Beach'));
    expect(find.text('Fort Kochi'), findsOneWidget);
    // Fort Kochi is on the wishlist: filled heart, tapping removes item 4.
    expect(find.byIcon(Icons.favorite), findsWidgets);
    await tester.tap(find.byTooltip('Remove from wishlist'));
    await tester.pumpAndSettle();
    expect(api.calls, contains('DELETE /explore/wishlist/4'));
  });

  testWidgets('search runs after the debounce and the wishlist tab lists items', (WidgetTester tester) async {
    final FakeApi api = FakeApi();
    await tester.pumpWidget(app(api));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'ko');
    await tester.pumpAndSettle();
    expect(api.calls, contains('GET /places'));
    expect(api.query, <String, dynamic>{'q': 'ko'});
    await tester.tap(find.text('Wishlist'));
    await tester.pumpAndSettle();
    expect(find.text('Plan into trip'), findsOneWidget);
    expect(find.text('Visited'), findsOneWidget);
  });
}
