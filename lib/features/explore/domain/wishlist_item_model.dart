import 'package:flutter/foundation.dart';
import '../../../core/time/api_time.dart';
import 'place_model.dart';

/// A wishlist entry from `WishlistItemResponse`. [plannedTripIds] are the traveler's trips that
/// already plan the place; [visited] says a visit was recorded.
@immutable
class WishlistItemModel {
  final int id;
  final PlaceModel place;
  final List<int> plannedTripIds;
  final bool visited;
  final DateTime? createdAt;

  const WishlistItemModel({
    required this.id,
    required this.place,
    this.plannedTripIds = const <int>[],
    this.visited = false,
    this.createdAt,
  });

  factory WishlistItemModel.fromJson(Map<String, dynamic> json) {
    final Object? place = json['place'];
    final int placeId = (json['placeId'] as num?)?.toInt() ?? 0;
    return WishlistItemModel(
      id: (json['id'] as num).toInt(),
      // `place` is the full object; placeId and placeName are the older flat fields.
      place: place is Map<String, dynamic>
          ? PlaceModel.fromJson(place)
          : PlaceModel(id: placeId, name: json['placeName'] as String? ?? ''),
      plannedTripIds: (json['plannedTripIds'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<num>()
          .map((num n) => n.toInt())
          .toList(growable: false),
      visited: json['visited'] as bool? ?? false,
      createdAt: ApiTime.parseUtc(json['createdAt'] as String?),
    );
  }
}
