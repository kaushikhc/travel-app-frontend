import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_app_frontend/features/journey/data/journey_repository.dart';
import 'package:travel_app_frontend/features/journey/domain/trip_memory_view_model.dart';
import 'package:travel_app_frontend/features/journey/presentation/trip_memory_view.dart';

Map<String, dynamic> _json() => <String, dynamic>{
      'trip': <String, dynamic>{'id': 4, 'name': 'Kerala 2025', 'status': 'ARCHIVED', 'startDate': '2025-12-01', 'endDate': '2025-12-03', 'tags': <String>[]},
      'summary': <String, dynamic>{'placesVisited': 2, 'countriesVisited': 1, 'memories': 1, 'photos': 1, 'videos': 0, 'nights': 2},
      'itinerary': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 7, 'kind': 'TRANSPORT', 'startTime': '2025-12-01T05:00:00', 'transportType': 'FLIGHT', 'provider': 'Air',
          'departurePlace': <String, dynamic>{'name': 'BLR'}, 'arrivalPlace': <String, dynamic>{'name': 'COK'},
        },
        <String, dynamic>{'id': 8, 'kind': 'VISIT', 'startTime': '2025-12-02T09:00:00', 'place': <String, dynamic>{'name': 'Fort Kochi'}},
      ],
      'timeline': <Map<String, dynamic>>[
        <String, dynamic>{
          'date': '2025-12-01',
          'entries': <Map<String, dynamic>>[<String, dynamic>{'kind': 'TRANSPORT', 'id': 7, 'at': '2025-12-01T05:00:00'}],
        },
        <String, dynamic>{
          'date': '2025-12-02',
          'entries': <Map<String, dynamic>>[
            <String, dynamic>{'kind': 'VISIT', 'id': 8},
            <String, dynamic>{'kind': 'MEMORY', 'id': 21},
            <String, dynamic>{'kind': 'STAY', 'id': 99},
          ],
        },
      ],
      'placesVisited': <Map<String, dynamic>>[
        <String, dynamic>{'place': <String, dynamic>{'name': 'Fort Kochi'}, 'visitCount': 2},
      ],
      'memories': <Map<String, dynamic>>[
        <String, dynamic>{
          'id': 21, 'tripId': 4, 'title': 'Sunset walk', 'visibility': 'PRIVATE', 'tags': <String>[], 'capturedAt': '2025-12-02T12:00:00',
          'media': <Map<String, dynamic>>[
            <String, dynamic>{'id': 1, 'type': 'IMAGE', 'displayOrder': 0},
            <String, dynamic>{'id': 2, 'type': 'VIDEO', 'displayOrder': 1},
          ],
        },
      ],
    };

class _Repo implements JourneyRepository {
  @override
  Future<TripMemoryViewData> fetchTripMemoryView(int id) async => TripMemoryViewData.fromJson(_json());

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  test('parses the response and resolves timeline references', () {
    final TripMemoryViewData d = TripMemoryViewData.fromJson(_json());
    expect(d.trip.name, 'Kerala 2025');
    expect(d.summary['nights'], 2);
    expect(d.days.map((MemoryViewDay x) => x.date), <DateTime>[DateTime(2025, 12, 1), DateTime(2025, 12, 2)]);
    expect(d.itinerary[TripMemoryViewData.key('TRANSPORT', 7)]!.title, 'BLR → COK');
    expect(d.itinerary[TripMemoryViewData.key('TRANSPORT', 7)]!.subtitle, 'Flight · Air');
    expect(d.itinerary[TripMemoryViewData.key('VISIT', 8)]!.title, 'Fort Kochi');
    expect(d.memories[21]!.displayTitle, 'Sunset walk');
    expect(d.photos.length, 1, reason: 'videos are not shown as photos');
    expect(d.placesVisited.single.visitCount, 2);
  });

  testWidgets('shows summary, timeline entries and places visited', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [journeyRepositoryProvider.overrideWithValue(_Repo())],
      child: const MaterialApp(home: TripMemoryView(tripId: 4)),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Kerala 2025'), findsOneWidget);
    expect(find.text('2 Nights'), findsOneWidget);
    expect(find.text('BLR → COK'), findsOneWidget);
    expect(find.text('Sunset walk'), findsOneWidget);
    expect(find.text('2 visits'), findsOneWidget);
    expect(find.text('Open trip'), findsOneWidget);
  });
}
