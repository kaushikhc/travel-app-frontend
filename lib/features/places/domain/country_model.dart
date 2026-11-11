import 'package:flutter/foundation.dart';

/// A country from `GET /api/places/countries`. [id] is the place id used as `homeCountryId`.
@immutable
class CountryModel {
  final int id;
  final String name;
  final String? isoCode;

  const CountryModel({required this.id, required this.name, this.isoCode});

  factory CountryModel.fromJson(Map<String, dynamic> json) => CountryModel(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String? ?? '',
        isoCode: json['isoCode'] as String?,
      );

  /// Flag emoji from a two-letter ISO code, or an empty string.
  String get flag {
    final String? code = isoCode?.toUpperCase();
    if (code == null || code.length != 2 || !RegExp(r'^[A-Z]{2}$').hasMatch(code)) return '';
    return String.fromCharCodes(code.codeUnits.map((int c) => 0x1F1E6 + c - 0x41));
  }

  @override
  bool operator ==(Object other) => other is CountryModel && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
