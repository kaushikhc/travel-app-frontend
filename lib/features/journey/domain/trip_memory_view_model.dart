import 'package:flutter/foundation.dart';
import '../../../core/time/api_time.dart';
import '../../memories/domain/memory_model.dart';
import '../../trip/domain/trip_model.dart';

String _name(Object? place) => place is Map<String, dynamic> ? (place['name'] as String? ?? '') : '';

String _title(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase().replaceAll('_', ' ');

/// A transport, stay or visit of the trip (`TripMemoryView.ItineraryItem`).
@immutable
class MemoryViewItem {
  final int id;
  final String kind;
  final DateTime? startTime;
  final String title;
  final String subtitle;

  const MemoryViewItem({required this.id, required this.kind, this.startTime, required this.title, this.subtitle = ''});

  factory MemoryViewItem.fromJson(Map<String, dynamic> j) {
    final String kind = j['kind'] as String? ?? '';
    final String route = <String>[_name(j['departurePlace']), _name(j['arrivalPlace'])].where((String x) => x.isNotEmpty).join(' → ');
    final String own = j['name'] as String? ?? '';
    final String place = _name(j['place']);
    final String? type = (j['transportType'] ?? j['accommodationType']) as String?;
    return MemoryViewItem(
      id: (j['id'] as num).toInt(),
      kind: kind,
      startTime: ApiTime.parseUtc(j['startTime'] as String?),
      title: kind == 'TRANSPORT'
          ? (route.isNotEmpty ? route : (type == null ? 'Transport' : _title(type)))
          : (own.isNotEmpty ? own : place),
      subtitle: <String>[
        if (kind == 'TRANSPORT' && route.isNotEmpty && type != null) _title(type),
        if (kind == 'TRANSPORT' && (j['provider'] as String?)?.isNotEmpty == true) j['provider'] as String,
        if (kind == 'STAY') 'Stay${type == null ? '' : ' · ${_title(type)}'}',
        if (kind == 'VISIT') 'Visit',
      ].join(' · '),
    );
  }
}

/// A place visited on the trip, with how often.
@immutable
class VisitedPlaceSummary {
  final String name;
  final int visitCount;

  const VisitedPlaceSummary({required this.name, required this.visitCount});
}

/// One reference in a day's timeline: a `kind` (TRANSPORT, STAY, VISIT, MEMORY) and an id into
/// the itinerary or the memories.
@immutable
class TimelineRef {
  final String kind;
  final int id;

  const TimelineRef(this.kind, this.id);
}

@immutable
class MemoryViewDay {
  final DateTime date;
  final List<TimelineRef> entries;

  const MemoryViewDay({required this.date, required this.entries});
}

/// `GET /history/trips/{id}`: everything the Trip Memory View shows.
@immutable
class TripMemoryViewData {
  final TripModel trip;
  final Map<String, int> summary;
  final Map<String, MemoryViewItem> itinerary;
  final List<MemoryViewDay> days;
  final List<VisitedPlaceSummary> placesVisited;
  final Map<int, MemoryModel> memories;

  const TripMemoryViewData({
    required this.trip,
    this.summary = const <String, int>{},
    this.itinerary = const <String, MemoryViewItem>{},
    this.days = const <MemoryViewDay>[],
    this.placesVisited = const <VisitedPlaceSummary>[],
    this.memories = const <int, MemoryModel>{},
  });

  static String key(String kind, int id) => '$kind:$id';

  /// Every photo of every memory, in memory order.
  List<MemoryMedia> get photos => <MemoryMedia>[
        for (final MemoryModel m in memories.values)
          for (final MemoryMedia p in m.media)
            if (!p.isVideo) p,
      ];

  factory TripMemoryViewData.fromJson(Map<String, dynamic> j) {
    final Map<String, MemoryViewItem> itinerary = <String, MemoryViewItem>{};
    for (final Object? i in j['itinerary'] as List<dynamic>? ?? const <dynamic>[]) {
      if (i is Map<String, dynamic>) {
        final MemoryViewItem item = MemoryViewItem.fromJson(i);
        itinerary[key(item.kind, item.id)] = item;
      }
    }
    final Map<int, MemoryModel> memories = <int, MemoryModel>{
      for (final Object? m in j['memories'] as List<dynamic>? ?? const <dynamic>[])
        if (m is Map<String, dynamic>) (m['id'] as num).toInt(): MemoryModel.fromJson(m),
    };
    final List<MemoryViewDay> days = <MemoryViewDay>[];
    for (final Object? d in j['timeline'] as List<dynamic>? ?? const <dynamic>[]) {
      if (d is! Map<String, dynamic>) continue;
      final DateTime? date = DateTime.tryParse(d['date'] as String? ?? '');
      if (date == null) continue;
      days.add(MemoryViewDay(
        date: DateTime(date.year, date.month, date.day),
        entries: <TimelineRef>[
          for (final Object? e in d['entries'] as List<dynamic>? ?? const <dynamic>[])
            if (e is Map<String, dynamic> && e['id'] is num) TimelineRef(e['kind'] as String? ?? '', (e['id'] as num).toInt()),
        ],
      ));
    }
    final Map<String, dynamic> s = j['summary'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    return TripMemoryViewData(
      trip: TripModel.fromJson(j['trip'] as Map<String, dynamic>),
      summary: <String, int>{for (final MapEntry<String, dynamic> e in s.entries) if (e.value is num) e.key: (e.value as num).toInt()},
      itinerary: itinerary,
      days: days,
      placesVisited: <VisitedPlaceSummary>[
        for (final Object? p in j['placesVisited'] as List<dynamic>? ?? const <dynamic>[])
          if (p is Map<String, dynamic>) VisitedPlaceSummary(name: _name(p['place']), visitCount: (p['visitCount'] as num?)?.toInt() ?? 1),
      ],
      memories: memories,
    );
  }
}
