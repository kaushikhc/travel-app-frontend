import 'package:flutter/foundation.dart';
import '../../../core/time/api_time.dart';

/// Backend trip statuses: past trips are archived as soon as they end.
enum TripStatus {
  draft,
  upcoming,
  active,
  archived;

  static TripStatus fromApi(String? value) => TripStatus.values.firstWhere(
        (TripStatus s) => s.name.toUpperCase() == value?.toUpperCase(),
        orElse: () => TripStatus.draft,
      );
}

/// A trip from `TripResponse`. Start and end are calendar dates (no time zone); other
/// timestamps are UTC.
@immutable
class TripModel {
  final int id;
  final String name;
  final String? description;
  final DateTime? startDate;
  final DateTime? endDate;
  final TripStatus status;
  final int? coverMediaId;
  final List<String> tags;
  final DateTime? createdAt;

  const TripModel({
    required this.id,
    required this.name,
    required this.status,
    this.description,
    this.startDate,
    this.endDate,
    this.coverMediaId,
    this.tags = const <String>[],
    this.createdAt,
  });

  factory TripModel.fromJson(Map<String, dynamic> json) => TripModel(
        id: (json['id'] as num).toInt(),
        name: json['name'] as String? ?? '',
        description: json['description'] as String?,
        startDate: _date(json['startDate'] as String?),
        endDate: _date(json['endDate'] as String?),
        status: TripStatus.fromApi(json['status'] as String?),
        coverMediaId: (json['coverMediaId'] as num?)?.toInt(),
        tags: (json['tags'] as List<dynamic>? ?? const <dynamic>[]).whereType<String>().toList(growable: false),
        createdAt: ApiTime.parseUtc(json['createdAt'] as String?),
      );

  /// `YYYY-MM-DD` as a plain calendar date.
  static DateTime? _date(String? value) {
    if (value == null || value.isEmpty) return null;
    final DateTime? parsed = DateTime.tryParse(value);
    return parsed == null ? null : DateTime(parsed.year, parsed.month, parsed.day);
  }

  /// Number of calendar days, counting both ends, or null without both dates.
  int? get totalDays {
    if (startDate == null || endDate == null) return null;
    return endDate!.difference(startDate!).inDays + 1;
  }

  /// Day of the trip [today] falls on (1-based), clamped to the trip's length.
  int? dayOfTrip(DateTime today) {
    final int? total = totalDays;
    if (startDate == null || total == null) return null;
    final int day = _dateOnly(today).difference(startDate!).inDays + 1;
    return day.clamp(1, total);
  }

  /// Whole days from [today] until the start, or null without a start date.
  int? daysUntilStart(DateTime today) =>
      startDate?.difference(_dateOnly(today)).inDays;

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}

/// `GET /api/trips/home`: the trip happening now, other active trips, upcoming and drafts.
@immutable
class HomeOverview {
  final TripModel? current;
  final List<TripModel> alsoActive;
  final List<TripModel> upcoming;
  final List<TripModel> drafts;

  const HomeOverview({this.current, this.alsoActive = const <TripModel>[], this.upcoming = const <TripModel>[], this.drafts = const <TripModel>[]});

  factory HomeOverview.fromJson(Map<String, dynamic> json) {
    List<TripModel> list(String key) => (json[key] as List<dynamic>? ?? const <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(TripModel.fromJson)
        .toList(growable: false);
    final Object? current = json['current'];
    return HomeOverview(
      current: current is Map<String, dynamic> ? TripModel.fromJson(current) : null,
      alsoActive: list('alsoActive'),
      upcoming: list('upcoming'),
      drafts: list('drafts'),
    );
  }
}

/// The lifetime numbers shown on Home, from `GET /api/statistics/me`.
@immutable
class TravelStats {
  final int countriesVisited;
  final int tripsCompleted;
  final int memories;

  const TravelStats({required this.countriesVisited, required this.tripsCompleted, required this.memories});

  factory TravelStats.fromJson(Map<String, dynamic> json) => TravelStats(
        countriesVisited: (json['countriesVisited'] as num?)?.toInt() ?? 0,
        tripsCompleted: (json['tripsCompleted'] as num?)?.toInt() ?? 0,
        memories: (json['memories'] as num?)?.toInt() ?? 0,
      );
}
