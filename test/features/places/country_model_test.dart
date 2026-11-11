import 'package:flutter_test/flutter_test.dart';
import 'package:travel_app_frontend/features/places/domain/country_model.dart';

void main() {
  test('reads PlaceResponse fields and builds a flag', () {
    final CountryModel c = CountryModel.fromJson(<String, dynamic>{'id': 42, 'name': 'India', 'type': 'COUNTRY', 'isoCode': 'IN'});
    expect(c.id, 42);
    expect(c.name, 'India');
    expect(c.flag, '🇮🇳');
  });

  test('no flag without a two-letter code', () {
    expect(const CountryModel(id: 1, name: 'X').flag, '');
    expect(const CountryModel(id: 1, name: 'X', isoCode: 'IND').flag, '');
  });
}
