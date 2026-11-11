import 'package:flutter/foundation.dart';

/// A collection and the traveler's progress on it (`CollectionSummary`). [global] collections are
/// shared and read-only.
@immutable
class CollectionSummary {
  final int id;
  final String name;
  final String? description;
  final bool global;
  final int total;
  final int visited;
  final double percent;

  const CollectionSummary({
    required this.id,
    required this.name,
    this.description,
    this.global = false,
    this.total = 0,
    this.visited = 0,
    this.percent = 0,
  });

  factory CollectionSummary.fromJson(Map<String, dynamic> j) => CollectionSummary(
        id: (j['id'] as num).toInt(),
        name: j['name'] as String? ?? '',
        description: j['description'] as String?,
        global: j['global'] as bool? ?? false,
        total: (j['total'] as num?)?.toInt() ?? 0,
        visited: (j['visited'] as num?)?.toInt() ?? 0,
        percent: (j['percent'] as num?)?.toDouble() ?? 0,
      );
}

/// One place in a collection and whether the traveler has been there.
@immutable
class CollectionItem {
  final int placeId;
  final String name;
  final String? type;
  final bool visited;

  const CollectionItem({required this.placeId, required this.name, this.type, this.visited = false});

  factory CollectionItem.fromJson(Map<String, dynamic> j) {
    final Object? place = j['place'];
    final Map<String, dynamic> p = place is Map<String, dynamic> ? place : const <String, dynamic>{};
    return CollectionItem(
      placeId: (p['id'] as num?)?.toInt() ?? 0,
      name: p['name'] as String? ?? '',
      type: p['type'] as String?,
      visited: j['visited'] as bool? ?? false,
    );
  }
}

/// `CollectionDetail`: the collection with every item.
@immutable
class CollectionDetail {
  final CollectionSummary collection;
  final List<CollectionItem> items;

  const CollectionDetail({required this.collection, required this.items});

  factory CollectionDetail.fromJson(Map<String, dynamic> j) => CollectionDetail(
        collection: CollectionSummary.fromJson(j['collection'] as Map<String, dynamic>),
        items: <CollectionItem>[
          for (final Object? i in j['items'] as List<dynamic>? ?? const <dynamic>[])
            if (i is Map<String, dynamic>) CollectionItem.fromJson(i),
        ],
      );
}
