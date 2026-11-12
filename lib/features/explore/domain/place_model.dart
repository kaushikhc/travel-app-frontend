import 'package:flutter/foundation.dart';

/// A place from `PlaceResponse`. The API has no photo or rating for places.
@immutable
class PlaceModel {
  final int id;
  final String name;
  final String? type;
  final double? latitude;
  final double? longitude;
  final String? address;
  final String? isoCode;
  final int? countryId;
  final int? regionId;
  final int? cityId;

  /// Kinds of place such as Zoo or Temple (names from `GET /api/explore/categories`), A to Z.
  final List<String> categories;

  const PlaceModel({
    required this.id,
    required this.name,
    this.type,
    this.latitude,
    this.longitude,
    this.address,
    this.isoCode,
    this.countryId,
    this.regionId,
    this.cityId,
    this.categories = const <String>[],
  });

  factory PlaceModel.fromJson(Map<String, dynamic> json) {
    return PlaceModel(
      id: (json['id'] as num).toInt(),
      name: json['name'] as String? ?? '',
      type: json['type'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      address: json['address'] as String?,
      isoCode: json['isoCode'] as String?,
      countryId: (json['countryId'] as num?)?.toInt(),
      regionId: (json['regionId'] as num?)?.toInt(),
      cityId: (json['cityId'] as num?)?.toInt(),
      categories: (json['categories'] as List<dynamic>? ?? const <dynamic>[]).whereType<String>().toList(growable: false),
    );
  }

  /// What kind of place this is: its categories (Zoo, Park), else its type unless that is the generic
  /// point of interest. Empty when unknown.
  String get kind {
    if (categories.isNotEmpty) return categories.join(', ');
    final String t = type?.trim() ?? '';
    return t == 'POINT_OF_INTEREST' ? '' : t;
  }

  /// Kind and address on one line, for list rows.
  String get subtitle => <String>[
        if (kind.isNotEmpty) kind,
        if (address != null && address!.trim().isNotEmpty) address!.trim(),
      ].join(' · ');
}
