import 'package:flutter/foundation.dart';
import 'trip_detail_model.dart';

/// What kind of thing an itinerary entry is.
enum ItineraryKind { place, checkIn, checkOut, transport, visit }

/// One line in a day of the itinerary. [time] is a local (device zone) time, or null for
/// all-day entries such as a planned place.
@immutable
class ItineraryEntry {
  final ItineraryKind kind;
  final String title;
  final String subtitle;
  final DateTime? time;

  /// The canonical place behind the entry (a planned place, a stay or a visit), or null. Entries
  /// with a place link to that place's memories.
  final int? placeId;

  const ItineraryEntry({
    required this.kind,
    required this.title,
    this.subtitle = '',
    this.time,
    this.placeId,
  });
}

/// A calendar day (local date) and its entries, all-day first, then by time.
@immutable
class ItineraryDay {
  final DateTime date;
  final List<ItineraryEntry> entries;

  const ItineraryDay({required this.date, required this.entries});
}

/// The itinerary: dated [days] plus [unscheduled] places that have no planned date.
@immutable
class Itinerary {
  final List<ItineraryDay> days;
  final List<ItineraryEntry> unscheduled;

  const Itinerary({required this.days, required this.unscheduled});

  bool get isEmpty =>
      days.every((ItineraryDay d) => d.entries.isEmpty) && unscheduled.isEmpty;
}

/// Longest trip range for which empty days are listed; longer ranges only show days with entries.
const int maxEmptyDays = 120;

DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

String _title(String s) => s.isEmpty
    ? s
    : s[0].toUpperCase() + s.substring(1).toLowerCase().replaceAll('_', ' ');

/// Builds the day-by-day itinerary from a trip's places, stays, transport and visits.
/// Timestamps are shown in the device time zone. Every day of the trip's date range is listed
/// (when the range is at most [maxEmptyDays]), plus any day outside it that has an entry.
Itinerary buildItinerary(TripDetail d) {
  final Map<DateTime, List<ItineraryEntry>> byDay =
      <DateTime, List<ItineraryEntry>>{};
  final List<ItineraryEntry> unscheduled = <ItineraryEntry>[];

  void add(DateTime day, ItineraryEntry e) =>
      byDay.putIfAbsent(day, () => <ItineraryEntry>[]).add(e);

  for (final TripPlaceItem p in d.places) {
    final ItineraryEntry e = ItineraryEntry(
      kind: ItineraryKind.place,
      title: p.name,
      placeId: p.placeId,
      subtitle: <String>[
        if (p.status != null) _title(p.status!),
        if (p.notes?.isNotEmpty == true) p.notes!,
      ].join(' · '),
    );
    if (p.plannedDate == null) {
      unscheduled.add(e);
    } else {
      add(_day(p.plannedDate!), e);
    }
  }
  for (final StayItem s in d.stays) {
    if (s.checkIn != null) {
      final DateTime t = s.checkIn!.toLocal();
      add(
        _day(t),
        ItineraryEntry(
          kind: ItineraryKind.checkIn,
          title: s.name,
          subtitle: 'Check-in',
          time: t,
          placeId: s.placeId,
        ),
      );
    }
    if (s.checkOut != null) {
      final DateTime t = s.checkOut!.toLocal();
      add(
        _day(t),
        ItineraryEntry(
          kind: ItineraryKind.checkOut,
          title: s.name,
          subtitle: 'Check-out',
          time: t,
          placeId: s.placeId,
        ),
      );
    }
  }
  for (final TransportItem t in d.transports) {
    final DateTime? dep = t.departure?.toLocal();
    if (dep == null) continue;
    final String route = <String>[
      t.from,
      t.to,
    ].where((String x) => x.isNotEmpty).join(' → ');
    add(
      _day(dep),
      ItineraryEntry(
        kind: ItineraryKind.transport,
        title: route.isNotEmpty
            ? route
            : (t.type == null ? 'Transport' : _title(t.type!)),
        subtitle: <String>[
          if (route.isNotEmpty && t.type != null) _title(t.type!),
          if (t.provider?.isNotEmpty == true) t.provider!,
        ].join(' · '),
        time: dep,
      ),
    );
  }
  for (final VisitItem v in d.visits) {
    if (v.visitedAt == null) continue;
    final DateTime t = v.visitedAt!.toLocal();
    add(
      _day(t),
      ItineraryEntry(
        kind: ItineraryKind.visit,
        title: v.name,
        subtitle: 'Visited',
        time: t,
        placeId: v.placeId,
      ),
    );
  }

  final DateTime? start = d.trip.startDate;
  final DateTime? end = d.trip.endDate;
  if (start != null &&
      end != null &&
      !end.isBefore(start) &&
      end.difference(start).inDays < maxEmptyDays) {
    // Calendar-day stepping (DST safe).
    for (
      DateTime x = _day(start);
      !x.isAfter(end);
      x = DateTime(x.year, x.month, x.day + 1)
    ) {
      byDay.putIfAbsent(x, () => <ItineraryEntry>[]);
    }
  }

  final List<DateTime> keys = byDay.keys.toList()..sort();
  final List<ItineraryDay> days = <ItineraryDay>[
    for (final DateTime k in keys)
      ItineraryDay(
        date: k,
        entries: byDay[k]!
          ..sort((ItineraryEntry a, ItineraryEntry b) {
            if (a.time == null && b.time == null) return 0;
            if (a.time == null) return -1;
            if (b.time == null) return 1;
            return a.time!.compareTo(b.time!);
          }),
      ),
  ];
  return Itinerary(days: days, unscheduled: unscheduled);
}
