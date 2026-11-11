import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_app_frontend/features/trip/data/trip_repository.dart';
import 'package:travel_app_frontend/features/trip/domain/trip_detail_model.dart';
import 'package:travel_app_frontend/features/trip/domain/trip_model.dart';
import 'package:travel_app_frontend/features/trip/presentation/trip_detail_view.dart';

Widget _app(TripDetail detail) => ProviderScope(
      overrides: [tripDetailProvider(5).overrideWith((Ref ref) async => detail)],
      child: const MaterialApp(home: TripDetailView(tripId: 5)),
    );

void main() {
  test('sub-list models parse API JSON', () {
    final TripPlaceItem p = TripPlaceItem.fromJson(<String, dynamic>{
      'id': 1, 'place': <String, dynamic>{'name': 'Fort Kochi', 'type': 'CITY'},
      'plannedDate': '2026-12-01', 'status': 'PLANNED',
    });
    expect(p.name, 'Fort Kochi');
    expect(p.plannedDate, DateTime(2026, 12, 1));

    final StayItem s = StayItem.fromJson(<String, dynamic>{
      'id': 2, 'name': '', 'place': <String, dynamic>{'name': 'Hotel Z'}, 'checkIn': '2026-12-01T10:00:00',
    });
    expect(s.name, 'Hotel Z');
    expect(s.checkIn, DateTime.utc(2026, 12, 1, 10));
    expect(s.checkOut, isNull);

    final TransportItem t = TransportItem.fromJson(<String, dynamic>{
      'id': 3, 'type': 'FLIGHT', 'departurePlace': <String, dynamic>{'name': 'BLR'},
      'arrivalPlace': null, 'departureDatetime': '2026-12-01T05:00:00Z',
    });
    expect(t.from, 'BLR');
    expect(t.to, '');
    expect(t.departure, DateTime.utc(2026, 12, 1, 5));

    final VisitItem v = VisitItem.fromJson(<String, dynamic>{
      'id': 4, 'place': <String, dynamic>{'name': 'Beach'}, 'visitedAt': '2026-12-02T08:30:00',
    });
    expect(v.name, 'Beach');
    expect(v.leftAt, isNull);
  });

  testWidgets('shows trip header and sections with empty states', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(TripDetail(
      trip: const TripModel(id: 5, name: 'Kerala', status: TripStatus.upcoming, description: 'Backwaters', tags: <String>['beach']),
      places: const <TripPlaceItem>[TripPlaceItem(id: 1, name: 'Fort Kochi')],
    )));
    await tester.pumpAndSettle();
    expect(find.text('Kerala'), findsOneWidget);
    expect(find.text('Upcoming'), findsOneWidget);
    expect(find.text('Backwaters'), findsOneWidget);
    expect(find.text('beach'), findsOneWidget);
    expect(find.text('Fort Kochi'), findsOneWidget);
    expect(find.text('No stays added yet.'), findsOneWidget);
    expect(find.text('No transport added yet.'), findsOneWidget);
    expect(find.text('No visits logged yet.'), findsOneWidget);
  });
}
