import 'package:flutter_test/flutter_test.dart';
import 'package:travel_app_frontend/features/trip/domain/trip_model.dart';

Map<String, dynamic> _trip(int id, String status, {String? start, String? end}) => <String, dynamic>{
      'id': id,
      'name': 'Trip $id',
      'status': status,
      'startDate': start,
      'endDate': end,
      'tags': <String>['beach', 'family'],
      'createdAt': '2026-11-01T08:00:00',
    };

void main() {
  test('reads TripResponse with backend statuses and UTC timestamps', () {
    final TripModel t = TripModel.fromJson(_trip(7, 'ACTIVE', start: '2026-11-09', end: '2026-11-20'));
    expect(t.status, TripStatus.active);
    expect(t.startDate, DateTime(2026, 11, 9));
    expect(t.tags, <String>['beach', 'family']);
    expect(t.createdAt, DateTime.utc(2026, 11, 1, 8));
    expect(TripStatus.fromApi('ARCHIVED'), TripStatus.archived);
    expect(TripStatus.fromApi('UNKNOWN'), TripStatus.draft);
  });

  test('trip timing counts calendar days', () {
    final TripModel t = TripModel.fromJson(_trip(1, 'ACTIVE', start: '2026-11-09', end: '2026-11-20'));
    expect(t.totalDays, 12);
    expect(t.dayOfTrip(DateTime(2026, 11, 11, 23, 59)), 3);
    expect(t.dayOfTrip(DateTime(2026, 12, 1)), 12);
    expect(t.daysUntilStart(DateTime(2026, 11, 1, 18)), 8);
    expect(TripModel.fromJson(_trip(2, 'DRAFT')).totalDays, isNull);
  });

  test('home overview handles a missing current trip', () {
    final HomeOverview h = HomeOverview.fromJson(<String, dynamic>{
      'current': null,
      'alsoActive': <dynamic>[],
      'upcoming': <dynamic>[_trip(3, 'UPCOMING', start: '2026-12-01', end: '2026-12-05')],
      'drafts': <dynamic>[_trip(4, 'DRAFT')],
    });
    expect(h.current, isNull);
    expect(h.upcoming.single.id, 3);
    expect(h.drafts.single.status, TripStatus.draft);
  });
}
