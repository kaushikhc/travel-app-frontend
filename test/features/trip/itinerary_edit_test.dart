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
  Future<void> updateTripPlace(int tripId, int id, {DateTime? plannedDate, String? notes, String? status}) async =>
      calls.add('update $tripId/$id $status $notes');

  @override
  Future<void> deleteTripPlace(int tripId, int id) async => calls.add('delete place $tripId/$id');

  @override
  Future<void> deleteVisit(int tripId, int id) async => calls.add('delete visit $tripId/$id');

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

TripDetail _detail() => TripDetail(
      trip: const TripModel(id: 5, name: 'Kerala', status: TripStatus.upcoming),
      places: const <TripPlaceItem>[TripPlaceItem(id: 1, placeId: 11, name: 'Fort Kochi', status: 'PLANNED', notes: 'Old')],
      visits: <VisitItem>[VisitItem(id: 2, placeId: 12, name: 'Beach', visitedAt: DateTime.utc(2026, 12, 2, 9))],
    );

void main() {
  test('request bodies match the backend', () {
    expect(TripRepository.tripPlaceBody(placeId: 3, plannedDate: DateTime(2026, 12, 1), notes: ' hi '),
        <String, dynamic>{'placeId': 3, 'plannedDate': '2026-12-01', 'notes': 'hi'});
    expect(TripRepository.tripPlaceBody(placeId: 3), <String, dynamic>{'placeId': 3});
    expect(TripRepository.tripPlaceUpdateBody(status: 'SKIPPED'), <String, dynamic>{'plannedDate': null, 'notes': null, 'status': 'SKIPPED'});
    final Map<String, dynamic> v = TripRepository.visitBody(tripPlaceId: 1, placeId: 9, visitedAt: DateTime.utc(2026, 12, 2, 9), notes: '');
    expect(v['tripPlaceId'], 1);
    expect(v.containsKey('placeId'), isFalse);
    expect(v['visitedAt'], '2026-12-02T09:00:00.000');
    expect(v['leftAt'], isNull);
    expect(v['notes'], isNull);
    expect(TripRepository.visitBody(placeId: 9, visitedAt: DateTime.utc(2026, 1, 1))['placeId'], 9);
  });

  test('place ids are parsed', () {
    expect(TripPlaceItem.fromJson(<String, dynamic>{'id': 1, 'place': <String, dynamic>{'id': 11, 'name': 'X'}}).placeId, 11);
    expect(VisitItem.fromJson(<String, dynamic>{'id': 1, 'place': <String, dynamic>{'id': 12, 'name': 'Y'}}).placeId, 12);
  });

  testWidgets('edit a place to skipped, then delete place and visit', (WidgetTester tester) async {
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
    expect(find.text('Add place'), findsOneWidget);
    expect(find.text('Log visit'), findsOneWidget);

    await tester.tap(find.byTooltip('Options').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(find.text('Edit place'), findsOneWidget);
    await tester.tap(find.text('Skipped'));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(repo.calls, <String>['update 5/1 SKIPPED Old']);

    await tester.tap(find.byTooltip('Options').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(repo.calls.last, 'delete place 5/1');

    await tester.tap(find.byTooltip('Options').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete').last);
    await tester.pumpAndSettle();
    expect(repo.calls.last, 'delete visit 5/2');
  });
}
