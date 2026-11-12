import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_app_frontend/features/tags/data/tag_repository.dart';
import 'package:travel_app_frontend/core/network/api_client.dart';
import 'package:travel_app_frontend/features/trip/data/trip_repository.dart';
import 'package:travel_app_frontend/features/trip/presentation/create_trip_view.dart';
import 'package:travel_app_frontend/features/media/data/media_repository.dart';
import 'package:travel_app_frontend/features/trip/domain/trip_model.dart';

class FakeApi extends ApiClient {
  FakeApi() : super(baseUrl: 'https://api.example/api');
  final List<String> posts = <String>[];
  Object? body;

  @override
  Future<Response> post(String path, {dynamic data}) async {
    posts.add(path);
    body = data;
    return Response(
      requestOptions: RequestOptions(path: path),
      statusCode: 201,
      data: <String, dynamic>{'id': 9, 'name': 'Goa', 'status': 'UPCOMING'},
    );
  }
}

void main() {
  editTripTests();
  test('createTrip posts the trip as the API expects', () async {
    final FakeApi api = FakeApi();
    final trip = await TripRepository(api).createTrip(
      name: '  Goa  ',
      description: ' ',
      startDate: DateTime(2026, 12, 3),
      endDate: DateTime(2026, 12, 9),
      coverMediaId: 5,
      tags: <String>['beach'],
    );
    expect(api.posts, <String>['/trips']);
    expect(api.body, <String, dynamic>{
      'name': 'Goa',
      'description': null,
      'startDate': '2026-12-03',
      'endDate': '2026-12-09',
      'coverMediaId': 5,
      'tags': <String>['beach'],
    });
    expect(trip.id, 9);
  });

  test('parseTags trims, drops blanks and case-insensitive duplicates', () {
    expect(parseTags(' Food, food ,, beach '), <String>['Food', 'beach']);
  });

  testWidgets('the form blocks saving without a name', (WidgetTester tester) async {
    final FakeApi api = FakeApi();
    await tester.pumpWidget(ProviderScope(
      overrides: [
        tripRepositoryProvider.overrideWithValue(TripRepository(api)),
        myTagsProvider.overrideWith((Ref ref) async => <String>[]),
      ],
      child: const MaterialApp(home: CreateTripView()),
    ));
    await tester.tap(find.text('Create trip'));
    await tester.pump();
    expect(find.text('Trip name is required'), findsOneWidget);
    expect(api.posts, isEmpty);
  });
}

class _EditApi extends FakeApi {
  final List<String> puts = <String>[];
  Object? putBody;

  @override
  Future<Response> put(String path, {dynamic data}) async {
    puts.add(path);
    putBody = data;
    return Response(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
      data: <String, dynamic>{'id': 9, 'name': 'Goa', 'status': 'UPCOMING'},
    );
  }
}

void editTripTests() {
  test('updateTrip puts the full trip body', () async {
    final _EditApi api = _EditApi();
    await TripRepository(api).updateTrip(9, name: ' Goa ', startDate: DateTime(2026, 12, 3), coverMediaId: 5, tags: <String>['a']);
    expect(api.puts, <String>['/trips/9']);
    expect(api.putBody, <String, dynamic>{
      'name': 'Goa',
      'description': null,
      'startDate': '2026-12-03',
      'endDate': null,
      'coverMediaId': 5,
      'tags': <String>['a'],
    });
  });

  testWidgets('edit mode prefills the form', (WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        tripRepositoryProvider.overrideWithValue(TripRepository(_EditApi())),
        mediaUrlProvider.overrideWith((Ref ref, int id) async => null),
        myTagsProvider.overrideWith((Ref ref) async => <String>[]),
      ],
      child: MaterialApp(
        home: CreateTripView(
          trip: TripModel(id: 9, name: 'Goa', description: 'Sun', status: TripStatus.draft, coverMediaId: 5, tags: const <String>['beach']),
        ),
      ),
    ));
    await tester.pump();
    expect(find.text('Edit trip'), findsOneWidget);
    expect(find.text('Goa'), findsOneWidget);
    expect(find.text('beach'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
  });
}
