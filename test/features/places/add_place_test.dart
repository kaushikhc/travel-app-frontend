import 'package:flutter_test/flutter_test.dart';
import 'package:travel_app_frontend/features/explore/data/explore_repository.dart';
import 'package:travel_app_frontend/features/explore/domain/place_model.dart';

void main() {
  test('placeBody under a city sends only the parent id, a trimmed name and the categories', () {
    expect(
      ExploreRepository.placeBody(name: ' Berlin Zoo ', parentPlaceId: 7, countryCode: 'de', categories: <String>['Zoo', 'Park']),
      <String, dynamic>{'name': 'Berlin Zoo', 'type': 'POINT_OF_INTEREST', 'parentPlaceId': 7, 'categories': <String>['Zoo', 'Park']},
    );
  });

  test('placeBody without a city uses the country and region codes, and skips a blank address', () {
    expect(
      ExploreRepository.placeBody(name: 'Senso-ji', countryCode: 'jp', regionCode: 'jp-13', address: '  '),
      <String, dynamic>{'name': 'Senso-ji', 'type': 'POINT_OF_INTEREST', 'countryCode': 'JP', 'regionCode': 'JP-13'},
    );
  });

  test('PlaceModel shows categories as its kind, else a non-generic type', () {
    final PlaceModel zoo = PlaceModel.fromJson(<String, dynamic>{
      'id': 1, 'name': 'Berlin Zoo', 'type': 'POINT_OF_INTEREST', 'address': 'Hardenbergplatz', 'categories': <String>['Park', 'Zoo'],
    });
    expect(zoo.subtitle, 'Park, Zoo · Hardenbergplatz');
    expect(PlaceModel.fromJson(<String, dynamic>{'id': 2, 'name': 'Rome', 'type': 'CITY'}).subtitle, 'CITY');
    expect(PlaceModel.fromJson(<String, dynamic>{'id': 3, 'name': 'X', 'type': 'POINT_OF_INTEREST'}).subtitle, '');
  });
}
