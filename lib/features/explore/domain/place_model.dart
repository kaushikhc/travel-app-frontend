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

  const PlaceModel({
    required this.id,
    required this.name,
    this.type,
    this.latitude,
    this.longitude,
    this.address,
    this.isoCode,
    this.countryId,
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
    );
  }

  /// Type and address on one line, for list rows.
  String get subtitle => <String>[
        if (type != null && type!.trim().isNotEmpty) type!.trim(),
        if (address != null && address!.trim().isNotEmpty) address!.trim(),
      ].join(' · ');
}
