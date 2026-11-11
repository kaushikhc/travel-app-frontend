import 'package:flutter/foundation.dart';
import '../../../core/time/api_time.dart';

/// `StatisticsResponse`: lifetime statistics.
@immutable
class LifetimeStats {
  final int tripsCompleted;
  final int countriesVisited;
  final int citiesVisited;
  final int continentsVisited;
  final int placesVisited;
  final int flights;
  final int journeys;
  final int stays;
  final int nights;
  final int distanceKm;
  final int memories;

  const LifetimeStats({
    this.tripsCompleted = 0,
    this.countriesVisited = 0,
    this.citiesVisited = 0,
    this.continentsVisited = 0,
    this.placesVisited = 0,
    this.flights = 0,
    this.journeys = 0,
    this.stays = 0,
    this.nights = 0,
    this.distanceKm = 0,
    this.memories = 0,
  });

  factory LifetimeStats.fromJson(Map<String, dynamic> j) {
    int n(String k) => (j[k] as num?)?.toInt() ?? 0;
    return LifetimeStats(
      tripsCompleted: n('tripsCompleted'),
      countriesVisited: n('countriesVisited'),
      citiesVisited: n('citiesVisited'),
      continentsVisited: n('continentsVisited'),
      placesVisited: n('placesVisited'),
      flights: n('flights'),
      journeys: n('journeys'),
      stays: n('stays'),
      nights: n('nights'),
      distanceKm: n('distanceKm'),
      memories: n('memories'),
    );
  }
}

/// A visited country from `GET /history/regions`.
@immutable
class VisitedCountry {
  final String name;
  final String? isoCode;
  final int visitCount;
  final int stayCount;
  final int tripCount;
  final List<String> regions;

  const VisitedCountry({required this.name, this.isoCode, this.visitCount = 0, this.stayCount = 0, this.tripCount = 0, this.regions = const <String>[]});

  factory VisitedCountry.fromJson(Map<String, dynamic> j) => VisitedCountry(
        name: j['name'] as String? ?? '',
        isoCode: j['isoCode'] as String?,
        visitCount: (j['visitCount'] as num?)?.toInt() ?? 0,
        stayCount: (j['stayCount'] as num?)?.toInt() ?? 0,
        tripCount: (j['tripCount'] as num?)?.toInt() ?? 0,
        regions: <String>[
          for (final Object? r in j['regions'] as List<dynamic>? ?? const <dynamic>[])
            if (r is Map<String, dynamic> && (r['name'] as String?)?.isNotEmpty == true) r['name'] as String,
        ],
      );
}

/// A past (archived) trip from `GET /history/trips`.
@immutable
class PastTrip {
  final int id;
  final String name;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? coverMediaId;
  final int placesVisited;
  final int countriesVisited;
  final int memories;

  const PastTrip({
    required this.id,
    required this.name,
    this.startDate,
    this.endDate,
    this.coverMediaId,
    this.placesVisited = 0,
    this.countriesVisited = 0,
    this.memories = 0,
  });

  factory PastTrip.fromJson(Map<String, dynamic> j) {
    DateTime? date(String? v) {
      final DateTime? d = v == null ? null : DateTime.tryParse(v);
      return d == null ? null : DateTime(d.year, d.month, d.day);
    }

    return PastTrip(
      id: (j['id'] as num).toInt(),
      name: j['name'] as String? ?? '',
      startDate: date(j['startDate'] as String?),
      endDate: date(j['endDate'] as String?),
      coverMediaId: (j['coverMediaId'] as num?)?.toInt(),
      placesVisited: (j['placesVisited'] as num?)?.toInt() ?? 0,
      countriesVisited: (j['countriesVisited'] as num?)?.toInt() ?? 0,
      memories: (j['memories'] as num?)?.toInt() ?? 0,
    );
  }
}

/// One lifetime timeline entry. [kind] is TRIP_START, TRIP_END, TRANSPORT, STAY, VISIT or MEMORY.
@immutable
class TimelineEntry {
  final String kind;
  final int? id;
  final DateTime? time;
  final int? tripId;
  final String? tripName;
  final String title;

  const TimelineEntry({required this.kind, this.id, this.time, this.tripId, this.tripName, this.title = ''});

  factory TimelineEntry.fromJson(Map<String, dynamic> j) {
    String place(Object? p) => p is Map<String, dynamic> ? (p['name'] as String? ?? '') : '';
    final String route = <String>[place(j['departurePlace']), place(j['arrivalPlace'])].where((String x) => x.isNotEmpty).join(' → ');
    final String title = <String?>[j['title'] as String?, route, place(j['place']), j['tripName'] as String?]
        .firstWhere((String? x) => x != null && x.isNotEmpty, orElse: () => '')!;
    return TimelineEntry(
      kind: j['kind'] as String? ?? '',
      id: (j['id'] as num?)?.toInt(),
      time: ApiTime.parseUtc(j['time'] as String?),
      tripId: (j['tripId'] as num?)?.toInt(),
      tripName: j['tripName'] as String?,
      title: title,
    );
  }
}

/// A page of the lifetime timeline; [nextBefore] (raw, as sent by the server) is null on the last page.
@immutable
class TimelinePage {
  final List<TimelineEntry> entries;
  final String? nextBefore;

  const TimelinePage({required this.entries, this.nextBefore});

  factory TimelinePage.fromJson(Map<String, dynamic> j) => TimelinePage(
        entries: <TimelineEntry>[
          for (final Object? e in j['entries'] as List<dynamic>? ?? const <dynamic>[])
            if (e is Map<String, dynamic>) TimelineEntry.fromJson(e),
        ],
        nextBefore: j['nextBefore'] as String?,
      );
}

/// A point `[longitude, latitude]`.
typedef GeoPoint = ({double lon, double lat});

/// The world map data (`GET /history/map`, GeoJSON): visited places and travel paths.
@immutable
class MapData {
  final List<GeoPoint> points;
  final List<(GeoPoint, GeoPoint)> paths;

  const MapData({this.points = const <GeoPoint>[], this.paths = const <(GeoPoint, GeoPoint)>[]});

  bool get isEmpty => points.isEmpty && paths.isEmpty;

  static GeoPoint? _pt(Object? c) => c is List<dynamic> && c.length >= 2 && c[0] is num && c[1] is num
      ? (lon: (c[0] as num).toDouble(), lat: (c[1] as num).toDouble())
      : null;

  factory MapData.fromJson(Map<String, dynamic> j) {
    final List<GeoPoint> points = <GeoPoint>[];
    final List<(GeoPoint, GeoPoint)> paths = <(GeoPoint, GeoPoint)>[];
    for (final Object? f in j['features'] as List<dynamic>? ?? const <dynamic>[]) {
      final Object? g = f is Map<String, dynamic> ? f['geometry'] : null;
      if (g is! Map<String, dynamic>) continue;
      final Object? c = g['coordinates'];
      if (g['type'] == 'Point') {
        final GeoPoint? p = _pt(c);
        if (p != null) points.add(p);
      } else if (g['type'] == 'LineString' && c is List<dynamic> && c.length >= 2) {
        final GeoPoint? a = _pt(c.first);
        final GeoPoint? b = _pt(c.last);
        if (a != null && b != null) paths.add((a, b));
      }
    }
    return MapData(points: points, paths: paths);
  }
}
