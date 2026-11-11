import 'package:flutter/foundation.dart';
import '../../../core/time/api_time.dart';
import 'trip_model.dart';

/// Name of a `PlaceResponse`, or an empty string when absent.
String _placeName(Object? place) =>
    place is Map<String, dynamic> ? (place['name'] as String? ?? '') : '';

/// Id of a `PlaceResponse`, or null when absent.
int? _placeId(Object? place) => place is Map<String, dynamic> ? (place['id'] as num?)?.toInt() : null;

DateTime? _localDate(String? value) {
  if (value == null || value.isEmpty) return null;
  final DateTime? parsed = DateTime.tryParse(value);
  return parsed == null ? null : DateTime(parsed.year, parsed.month, parsed.day);
}

/// From `TripPlaceResponse`: a place planned on the trip. [plannedDate] is a calendar date.
@immutable
class TripPlaceItem {
  final int id;
  final int? placeId;
  final String name;
  final String? type;
  final DateTime? plannedDate;
  final String? status;
  final String? notes;

  const TripPlaceItem({required this.id, this.placeId, required this.name, this.type, this.plannedDate, this.status, this.notes});

  factory TripPlaceItem.fromJson(Map<String, dynamic> json) {
    final Object? place = json['place'];
    return TripPlaceItem(
      id: (json['id'] as num).toInt(),
      placeId: _placeId(place),
      name: _placeName(place),
      type: place is Map<String, dynamic> ? place['type'] as String? : null,
      plannedDate: _localDate(json['plannedDate'] as String?),
      status: json['status'] as String?,
      notes: json['notes'] as String?,
    );
  }
}

/// From `AccommodationResponse`. Check-in and out are UTC timestamps.
@immutable
class StayItem {
  final int id;
  final String name;
  final String? type;
  final DateTime? checkIn;
  final DateTime? checkOut;

  const StayItem({required this.id, required this.name, this.type, this.checkIn, this.checkOut});

  factory StayItem.fromJson(Map<String, dynamic> json) {
    final String own = json['name'] as String? ?? '';
    return StayItem(
      id: (json['id'] as num).toInt(),
      name: own.isNotEmpty ? own : _placeName(json['place']),
      type: json['type'] as String?,
      checkIn: ApiTime.parseUtc(json['checkIn'] as String?),
      checkOut: ApiTime.parseUtc(json['checkOut'] as String?),
    );
  }
}

/// From `TransportResponse`. Departure and arrival are UTC timestamps.
@immutable
class TransportItem {
  final int id;
  final String? type;
  final String from;
  final String to;
  final DateTime? departure;
  final DateTime? arrival;
  final String? provider;

  const TransportItem({required this.id, required this.from, required this.to, this.type, this.departure, this.arrival, this.provider});

  factory TransportItem.fromJson(Map<String, dynamic> json) => TransportItem(
        id: (json['id'] as num).toInt(),
        type: json['type'] as String?,
        from: _placeName(json['departurePlace']),
        to: _placeName(json['arrivalPlace']),
        departure: ApiTime.parseUtc(json['departureDatetime'] as String?),
        arrival: ApiTime.parseUtc(json['arrivalDatetime'] as String?),
        provider: json['provider'] as String?,
      );
}

/// From `VisitResponse`. Visit times are UTC timestamps.
@immutable
class VisitItem {
  final int id;
  final int? placeId;
  final String name;
  final DateTime? visitedAt;
  final DateTime? leftAt;
  final String? notes;

  const VisitItem({required this.id, this.placeId, required this.name, this.visitedAt, this.leftAt, this.notes});

  factory VisitItem.fromJson(Map<String, dynamic> json) => VisitItem(
        id: (json['id'] as num).toInt(),
        placeId: _placeId(json['place']),
        name: _placeName(json['place']),
        visitedAt: ApiTime.parseUtc(json['visitedAt'] as String?),
        leftAt: ApiTime.parseUtc(json['leftAt'] as String?),
        notes: json['notes'] as String?,
      );
}

/// Everything the Trip Detail screen shows.
@immutable
class TripDetail {
  final TripModel trip;
  final List<TripPlaceItem> places;
  final List<StayItem> stays;
  final List<TransportItem> transports;
  final List<VisitItem> visits;

  const TripDetail({
    required this.trip,
    this.places = const <TripPlaceItem>[],
    this.stays = const <StayItem>[],
    this.transports = const <TransportItem>[],
    this.visits = const <VisitItem>[],
  });
}
