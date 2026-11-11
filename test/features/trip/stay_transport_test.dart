import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_app_frontend/features/trip/data/trip_repository.dart';
import 'package:travel_app_frontend/features/trip/domain/trip_detail_model.dart';
import 'package:travel_app_frontend/features/trip/domain/trip_model.dart';
import 'package:travel_app_frontend/features/trip/presentation/trip_detail_view.dart';

class _Repo implements TripRepository {
  final List<String> calls = <String>[];

  @override
  Future<void> saveStay(int tripId,
      {int? id, required String type, required int placeId, String? name, required DateTime checkIn, DateTime? checkOut, String? bookingReference, String? notes, Object? metadata}) async {
    calls.add('stay $tripId/$id $type place=$placeId ref=$bookingReference meta=$metadata out=${checkOut?.toUtc().toIso8601String()}');
  }

  @override
  Future<void> saveTransport(int tripId,
      {int? id, required String type, int? fromPlaceId, int? toPlaceId, required DateTime departure, DateTime? arrival, String? provider, String? referenceNumber, String? notes, Object? metadata}) async {
    calls.add('transport $tripId/$id $type $fromPlaceId>$toPlaceId meta=$metadata');
  }

  @override
  Future<void> deleteTransport(int tripId, int id) async => calls.add('delete transport $tripId/$id');

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

TripDetail _detail() => TripDetail(
      trip: const TripModel(id: 5, name: 'Kerala', status: TripStatus.upcoming),
      stays: <StayItem>[
        StayItem(
          id: 3,
          placeId: 30,
          name: 'Hotel Z',
          type: 'HOSTEL',
          checkIn: DateTime.utc(2026, 12, 1, 10),
          checkOut: DateTime.utc(2026, 12, 3, 8),
          bookingReference: 'ABC',
          metadata: const <String, dynamic>{'wifi': true},
        ),
      ],
      transports: <TransportItem>[
        TransportItem(id: 4, type: 'TRAIN', from: 'BLR', to: 'COK', fromPlaceId: 1, toPlaceId: 2, departure: DateTime.utc(2026, 12, 1, 5), metadata: const <String, dynamic>{'k': 1}),
      ],
    );

void main() {
  test('request bodies match the backend', () {
    final Map<String, dynamic> s = TripRepository.stayBody(type: 'HOTEL', placeId: 3, name: ' ', checkIn: DateTime.utc(2026, 12, 1, 10), bookingReference: ' X ');
    expect(s, <String, dynamic>{
      'type': 'HOTEL', 'placeId': 3, 'name': null, 'checkIn': '2026-12-01T10:00:00.000', 'checkOut': null,
      'bookingReference': 'X', 'notes': null, 'metadata': null,
    });
    final Map<String, dynamic> t = TripRepository.transportBody(type: 'FLIGHT', toPlaceId: 2, departure: DateTime.utc(2026, 12, 1, 5), provider: 'Air');
    expect(t['departurePlaceId'], isNull);
    expect(t['arrivalPlaceId'], 2);
    expect(t['departureDatetime'], '2026-12-01T05:00:00.000');
    expect(t['provider'], 'Air');
  });

  test('models keep ids, notes and metadata', () {
    final StayItem s = StayItem.fromJson(<String, dynamic>{
      'id': 1, 'type': 'HOTEL', 'place': <String, dynamic>{'id': 9, 'name': 'P'}, 'name': 'N', 'bookingReference': 'R', 'notes': 'n', 'metadata': <String, dynamic>{'a': 1},
    });
    expect((s.placeId, s.name, s.bookingReference, s.notes), (9, 'N', 'R', 'n'));
    expect(s.metadata, <String, dynamic>{'a': 1});
    final TransportItem t = TransportItem.fromJson(<String, dynamic>{
      'id': 2, 'departurePlace': <String, dynamic>{'id': 1, 'name': 'A'}, 'referenceNumber': 'XY1', 'notes': 'z',
    });
    expect((t.fromPlaceId, t.toPlaceId, t.referenceNumber, t.notes), (1, null, 'XY1', 'z'));
  });

  testWidgets('edit a stay keeps its metadata, delete a transport', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final _Repo repo = _Repo();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        tripDetailProvider(5).overrideWith((Ref ref) async => _detail()),
        tripRepositoryProvider.overrideWithValue(repo),
      ],
      child: const MaterialApp(home: TripDetailView(tripId: 5)),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Add stay'), findsOneWidget);
    expect(find.text('Add transport'), findsOneWidget);

    await tester.tap(find.byTooltip('Options').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(find.text('Edit stay'), findsOneWidget);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(repo.calls.single, startsWith('stay 5/3 HOSTEL place=30 ref=ABC meta={wifi: true} out=2026-12-03T08:00:00.000Z'));

    await tester.tap(find.byTooltip('Options').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(repo.calls.last, 'transport 5/4 TRAIN 1>2 meta={k: 1}');

    await tester.tap(find.byTooltip('Options').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(repo.calls.last, 'delete transport 5/4');
  });
}
