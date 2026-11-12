import 'package:flutter_test/flutter_test.dart';
import 'package:travel_app_frontend/features/explore/data/explore_repository.dart';

void main() {
  test('cityBody trims, upper-cases the country and sends type CITY', () {
    expect(
      ExploreRepository.cityBody(name: '  Hallstatt ', countryCode: 'at'),
      <String, dynamic>{'name': 'Hallstatt', 'type': 'CITY', 'countryCode': 'AT'},
    );
  });
}
