import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_app_frontend/features/trip/data/trip_repository.dart';
import 'package:travel_app_frontend/features/trip/domain/itinerary.dart';
import 'package:travel_app_frontend/features/trip/domain/trip_detail_model.dart';
import 'package:travel_app_frontend/features/trip/domain/trip_model.dart';
import 'package:travel_app_frontend/features/trip/presentation/trip_itinerary_view.dart';

TripDetail _detail() => TripDetail(
  trip: TripModel(
    id: 5,
    name: 'Kerala',
    status: TripStatus.upcoming,
    startDate: DateTime(2026, 12, 1),
    endDate: DateTime(2026, 12, 3),
  ),
  places: <TripPlaceItem>[
    TripPlaceItem(
      id: 1,
      name: 'Fort Kochi',
      plannedDate: DateTime(2026, 12, 2),
    ),
    const TripPlaceItem(id: 2, name: 'Munnar'),
  ],
  stays: <StayItem>[
    StayItem(
      id: 3,
      name: 'Hotel Z',
      checkIn: DateTime(2026, 12, 1, 15).toUtc(),
      checkOut: DateTime(2026, 12, 3, 11).toUtc(),
    ),
  ],
  transports: <TransportItem>[
    TransportItem(
      id: 4,
      from: 'BLR',
      to: 'COK',
      type: 'FLIGHT',
      departure: DateTime(2026, 12, 1, 6).toUtc(),
    ),
  ],
  visits: <VisitItem>[
    VisitItem(
      id: 5,
      name: 'Beach',
      visitedAt: DateTime(2026, 12, 2, 9).toUtc(),
    ),
  ],
);

void main() {
  test('groups by local day, sorted, with all-day entries first', () {
    final Itinerary it = buildItinerary(_detail());
    expect(it.days.map((ItineraryDay d) => d.date), <DateTime>[
      DateTime(2026, 12, 1),
      DateTime(2026, 12, 2),
      DateTime(2026, 12, 3),
    ]);
    expect(it.days[0].entries.map((ItineraryEntry e) => e.title), <String>[
      'BLR → COK',
      'Hotel Z',
    ]);
    expect(it.days[1].entries.map((ItineraryEntry e) => e.title), <String>[
      'Fort Kochi',
      'Beach',
    ]);
    expect(it.days[2].entries.single.subtitle, 'Check-out');
    expect(it.unscheduled.single.title, 'Munnar');
  });

  test(
    'lists empty days in the trip range and days outside it with entries',
    () {
      final Itinerary it = buildItinerary(
        TripDetail(
          trip: TripModel(
            id: 1,
            name: 'T',
            status: TripStatus.upcoming,
            startDate: DateTime(2026, 12, 1),
            endDate: DateTime(2026, 12, 3),
          ),
          places: <TripPlaceItem>[
            TripPlaceItem(
              id: 1,
              name: 'Early',
              plannedDate: DateTime(2026, 11, 30),
            ),
          ],
        ),
      );
      expect(it.days.length, 4);
      expect(it.days.first.entries.single.title, 'Early');
      expect(it.days.last.entries, isEmpty);
      expect(it.isEmpty, isFalse);
    },
  );

  test('empty trip is empty', () {
    expect(
      buildItinerary(
        const TripDetail(
          trip: TripModel(id: 1, name: 'T', status: TripStatus.draft),
        ),
      ).isEmpty,
      isTrue,
    );
  });

  testWidgets('view shows days and the undated section', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tripDetailProvider(5).overrideWith((Ref ref) async => _detail()),
        ],
        child: const MaterialApp(home: TripItineraryView(tripId: 5)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Day 1'), findsOneWidget);
    expect(find.text('Fort Kochi'), findsOneWidget);
    expect(find.text('No date yet'), findsOneWidget);
    expect(find.text('Munnar'), findsOneWidget);
  });

  test('entries carry their place id so they can link to memories', () {
    final TripDetail d = TripDetail(
      trip: TripModel(id: 5, name: 'Kerala', status: TripStatus.upcoming),
      places: const <TripPlaceItem>[
        TripPlaceItem(id: 1, placeId: 77, name: 'Kochi'),
        TripPlaceItem(id: 2, name: 'Unlinked'),
      ],
      stays: const <StayItem>[],
      transports: const <TransportItem>[],
      visits: const <VisitItem>[],
    );
    final Itinerary it = buildItinerary(d);
    expect(it.unscheduled.map((ItineraryEntry e) => e.placeId), <int?>[77, null]);
  });
}
