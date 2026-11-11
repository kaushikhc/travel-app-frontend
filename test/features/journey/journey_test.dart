import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_app_frontend/features/journey/data/journey_repository.dart';
import 'package:travel_app_frontend/features/journey/domain/journey_models.dart';
import 'package:travel_app_frontend/features/journey/presentation/journey_view.dart';
import 'package:travel_app_frontend/features/journey/presentation/world_map.dart';

class _FakeRepo implements JourneyRepository {
  final List<String?> timelineCalls = <String?>[];

  @override
  Future<LifetimeStats> fetchStats() async => const LifetimeStats(countriesVisited: 3, distanceKm: 12345, nights: 9);

  @override
  Future<List<VisitedCountry>> fetchCountries() async =>
      const <VisitedCountry>[VisitedCountry(name: 'India', tripCount: 2, regions: <String>['Kerala'])];

  @override
  Future<List<PastTrip>> fetchPastTrips() async => const <PastTrip>[PastTrip(id: 4, name: 'Kerala 2025', placesVisited: 5)];

  @override
  Future<MapData> fetchMap() async => const MapData();

  @override
  Future<TimelinePage> fetchTimeline({String? before, int limit = 50}) async {
    timelineCalls.add(before);
    return before == null
        ? const TimelinePage(entries: <TimelineEntry>[TimelineEntry(kind: 'VISIT', title: 'Beach')], nextBefore: '2026-01-01T00:00:00')
        : const TimelinePage(entries: <TimelineEntry>[TimelineEntry(kind: 'MEMORY', title: 'Sunset')]);
  }
}

void main() {
  test('models parse API JSON', () {
    final MapData m = MapData.fromJson(<String, dynamic>{
      'features': <Map<String, dynamic>>[
        <String, dynamic>{'geometry': <String, dynamic>{'type': 'Point', 'coordinates': <double>[76.2, 9.9]}},
        <String, dynamic>{
          'geometry': <String, dynamic>{
            'type': 'LineString',
            'coordinates': <List<double>>[<double>[77.5, 12.9], <double>[76.2, 9.9]],
          },
        },
        <String, dynamic>{'geometry': null},
      ],
    });
    expect(m.points.single, (lon: 76.2, lat: 9.9));
    expect(m.paths.single.$1.lat, 12.9);
    final mapBounds = WorldMapPainter.bounds(m);
    expect(mapBounds.minLon, lessThan(76.2));
    expect(mapBounds.maxLon, greaterThan(77.5));

    final TimelineEntry e = TimelineEntry.fromJson(<String, dynamic>{
      'kind': 'TRANSPORT', 'id': 1, 'time': '2026-12-01T05:00:00', 'tripId': 4,
      'departurePlace': <String, dynamic>{'name': 'BLR'}, 'arrivalPlace': <String, dynamic>{'name': 'COK'},
    });
    expect(e.title, 'BLR → COK');
    expect(e.time, DateTime.utc(2026, 12, 1, 5));
    final PastTrip t = PastTrip.fromJson(<String, dynamic>{'id': 1, 'name': 'T', 'startDate': '2026-05-01', 'memories': 2});
    expect(t.startDate, DateTime(2026, 5, 1));
    final VisitedCountry c = VisitedCountry.fromJson(<String, dynamic>{
      'name': 'India', 'regions': <Map<String, dynamic>>[<String, dynamic>{'name': 'Kerala'}],
    });
    expect(c.regions, <String>['Kerala']);
  });

  testWidgets('shows stats, past trips and pages the timeline', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final _FakeRepo repo = _FakeRepo();
    await tester.pumpWidget(ProviderScope(
      overrides: [journeyRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: JourneyView()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('12,345'), findsOneWidget);
    expect(find.text('India'), findsOneWidget);
    expect(find.textContaining('Kerala'), findsOneWidget);

    await tester.tap(find.text('Map'));
    await tester.pumpAndSettle();
    expect(find.text('No visited places with a location yet.'), findsOneWidget);

    await tester.tap(find.text('Past trips'));
    await tester.pumpAndSettle();
    expect(find.text('Kerala 2025'), findsOneWidget);

    await tester.tap(find.text('Timeline'));
    await tester.pumpAndSettle();
    expect(find.text('Beach'), findsOneWidget);
    await tester.tap(find.text('Load more'));
    await tester.pumpAndSettle();
    expect(find.text('Sunset'), findsOneWidget);
    expect(repo.timelineCalls, <String?>[null, '2026-01-01T00:00:00']);
  });
}
