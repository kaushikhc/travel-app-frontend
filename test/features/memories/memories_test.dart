import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_app_frontend/core/network/api_client.dart';
import 'package:travel_app_frontend/features/capture/presentation/capture_view.dart';
import 'package:travel_app_frontend/features/media/data/media_repository.dart';
import 'package:travel_app_frontend/features/memories/data/memory_repository.dart';
import 'package:travel_app_frontend/features/memories/domain/memory_model.dart';
import 'package:travel_app_frontend/features/memories/domain/memory_stack.dart';
import 'package:travel_app_frontend/features/memories/presentation/memories_view.dart';
import 'package:travel_app_frontend/features/memories/presentation/trip_memories_view.dart';
import 'package:travel_app_frontend/features/trip/data/trip_repository.dart';
import 'package:travel_app_frontend/features/trip/domain/trip_model.dart';

const Map<String, dynamic> _json = <String, dynamic>{
  'id': 7,
  'tripId': 3,
  'title': 'Sunset',
  'note': 'Lovely',
  'capturedAt': '2026-11-11T12:00:00',
  'visibility': 'FRIENDS_ONLY',
  'tags': <String>['food', 'beach'],
  'media': <Map<String, dynamic>>[
    <String, dynamic>{'id': 2, 'type': 'PHOTO', 'displayOrder': 1, 'url': 'https://x/2'},
    <String, dynamic>{'id': 1, 'type': 'PHOTO', 'displayOrder': 0, 'url': 'https://x/1'},
  ],
};

class FakeApi extends ApiClient {
  FakeApi() : super(baseUrl: 'https://api.example/api');
  final List<String> calls = <String>[];
  Map<String, dynamic>? query;
  Object? body;

  Response<dynamic> _ok(String path, Object? data, [int code = 200]) =>
      Response<dynamic>(requestOptions: RequestOptions(path: path), statusCode: code, data: data);

  @override
  Future<Response> get(String path, {Map<String, dynamic>? queryParameters}) async {
    calls.add('GET $path');
    query = queryParameters;
    return _ok(path, path == '/memories' ? <Map<String, dynamic>>[_json] : _json);
  }

  @override
  Future<Response> post(String path, {dynamic data}) async {
    calls.add('POST $path');
    body = data;
    return _ok(path, _json, 201);
  }

  @override
  Future<Response> patch(String path, {dynamic data}) async {
    calls.add('PATCH $path');
    body = data;
    return _ok(path, _json);
  }

  @override
  Future<Response> delete(String path) async {
    calls.add('DELETE $path');
    return _ok(path, null, 204);
  }
}

void main() {
  test('MemoryModel.fromJson reads MemoryResponse', () {
    final MemoryModel m = MemoryModel.fromJson(_json);
    expect(m.id, 7);
    expect(m.tripId, 3);
    expect(m.visibility, MemoryVisibility.friendsOnly);
    expect(m.tags, <String>['beach', 'food']);
    expect(m.capturedAt, DateTime.utc(2026, 11, 11, 12));
    expect(m.media.map((MemoryMedia x) => x.id), <int>[1, 2]);
    expect(m.cover!.url, 'https://x/1');
  });

  test('createMemory posts JSON with media ids and a UTC time without offset', () async {
    final FakeApi api = FakeApi();
    await MemoryRepository(api).createMemory(
      tripId: 3,
      title: '  Sunset ',
      note: ' ',
      visibility: MemoryVisibility.friendsOnly,
      capturedAt: DateTime.utc(2026, 11, 11, 12, 30),
      tags: <String>['food'],
      mediaIds: <int>[5, 6],
    );
    expect(api.calls, <String>['POST /memories']);
    expect(api.body, <String, dynamic>{
      'tripId': 3,
      'placeId': null,
      'title': 'Sunset',
      'note': null,
      'visibility': 'FRIENDS_ONLY',
      'capturedAt': '2026-11-11T12:30:00.000',
      'tags': <String>['food'],
      'mediaIds': <int>[5, 6],
    });
  });

  test(
    'updateMemory patches only the editable fields and replaces mediaIds',
    () async {
      final FakeApi api = FakeApi();
      final MemoryModel m = await MemoryRepository(api).updateMemory(
        7,
        title: ' New ',
        note: '  ',
        visibility: MemoryVisibility.public,
        tags: <String>['a'],
        mediaIds: <int>[1, 9],
      );
      expect(m.id, 7);
      expect(api.calls, <String>['PATCH /memories/7']);
      // note '' clears it; no capturedAt, visitId or placeId keys (a null would clear visit/place).
      expect(api.body, <String, dynamic>{
        'title': 'New',
        'note': '',
        'visibility': 'PUBLIC',
        'tags': <String>['a'],
        'mediaIds': <int>[1, 9],
      });
    },
  );

  test('updateMemory sends capturedAt only when the traveler changed it', () async {
    final FakeApi api = FakeApi();
    await MemoryRepository(api).updateMemory(
      7,
      title: 'T',
      note: '',
      visibility: MemoryVisibility.private,
      tags: <String>[],
      mediaIds: <int>[1],
      capturedAt: DateTime.utc(2026, 3, 1, 8, 15),
    );
    expect((api.body as Map<String, dynamic>)['capturedAt'], '2026-03-01T08:15:00.000');
  });

  test('createMemory without a time sends null so the backend uses the photo time', () async {
    final FakeApi api = FakeApi();
    await MemoryRepository(api).createMemory(tripId: 3, title: 'x');
    expect((api.body as Map<String, dynamic>)['capturedAt'], isNull);
  });

  testWidgets('edit mode is prefilled with the saved memory', (
    WidgetTester tester,
  ) async {
    final MemoryModel m = MemoryModel.fromJson(<String, dynamic>{
      ..._json,
      'media': <Map<String, dynamic>>[
        <String, dynamic>{'id': 1, 'type': 'PHOTO', 'displayOrder': 0},
      ],
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          tripsProvider.overrideWith(
            (Ref ref) async => <TripModel>[
              const TripModel(id: 3, name: 'Kerala', status: TripStatus.active),
            ],
          ),
          mediaUrlProvider.overrideWith((Ref ref, int id) async => null),
        ],
        child: MaterialApp(home: CaptureView(memory: m)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Edit memory'), findsOneWidget);
    expect(find.text('Sunset'), findsOneWidget);
    expect(find.text('Lovely'), findsOneWidget);
    expect(find.text('beach, food'), findsOneWidget);
    expect(find.text('Friends only'), findsOneWidget);
    expect(find.text('Kerala'), findsOneWidget);
    expect(find.byTooltip('Remove photo'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    await tester.tap(find.byTooltip('Remove photo'));
    await tester.pump();
    expect(find.byTooltip('Remove photo'), findsNothing);
  });

  test(
    'fetch list passes the tag, detail and delete use the id path',
    () async {
      final FakeApi api = FakeApi();
      final MemoryRepository repo = MemoryRepository(api);
      expect((await repo.fetchMemories(tag: 'food')).single.id, 7);
      expect(api.query, <String, dynamic>{'tag': 'food'});
      await repo.fetchMemories();
      expect(api.query, isNull);
      expect((await repo.fetchMemory(7)).title, 'Sunset');
      await repo.deleteMemory(7);
      expect(api.calls, <String>[
        'GET /memories',
        'GET /memories',
        'GET /memories/7',
        'DELETE /memories/7',
      ]);
    },
  );

  Widget app(List<MemoryModel> list) => ProviderScope(
        overrides: [
          memoriesProvider.overrideWith((Ref ref) async => list),
          tripsProvider.overrideWith(
              (Ref ref) async => <TripModel>[const TripModel(id: 3, name: 'Kerala', status: TripStatus.active)]),
          mediaUrlProvider.overrideWith((Ref ref, int id) async => null),
        ],
        child: const MaterialApp(home: MemoriesView()),
      );

  testWidgets('memories stack up per trip and tag filter narrows the stacks', (WidgetTester tester) async {
    final List<MemoryModel> list = <MemoryModel>[
      MemoryModel.fromJson(<String, dynamic>{..._json, 'media': <Object>[]}),
      MemoryModel(id: 8, tripId: 3, title: 'Dinner', tags: const <String>['Food'], capturedAt: DateTime.utc(2026, 11, 12)),
      const MemoryModel(id: 9, tripId: 4, title: 'Hike', tags: <String>['trail']),
    ];
    await tester.pumpWidget(app(list));
    await tester.pumpAndSettle();
    // Two trips, so two stacks; individual memories are not cards on this page.
    expect(find.text('Kerala'), findsOneWidget);
    expect(find.text('Trip'), findsOneWidget);
    expect(find.textContaining('2 memories'), findsOneWidget);
    expect(find.textContaining('1 memory'), findsOneWidget);
    expect(find.text('Sunset'), findsNothing);
    await tester.tap(find.widgetWithText(FilterChip, 'trail'));
    await tester.pumpAndSettle();
    expect(find.text('Kerala'), findsNothing);
    expect(find.text('Trip'), findsOneWidget);
  });

  testWidgets('an opened stack shows that trip\'s memories as a sorted grid', (WidgetTester tester) async {
    final List<MemoryModel> list = <MemoryModel>[
      MemoryModel(id: 1, tripId: 3, title: 'Old', capturedAt: DateTime.utc(2026, 11, 1)),
      MemoryModel(id: 2, tripId: 3, title: 'New', capturedAt: DateTime.utc(2026, 11, 10)),
      const MemoryModel(id: 3, tripId: 4, title: 'Elsewhere'),
    ];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          memoriesProvider.overrideWith((Ref ref) async => list),
          tripsProvider.overrideWith(
              (Ref ref) async => <TripModel>[const TripModel(id: 3, name: 'Kerala', status: TripStatus.active)]),
          mediaUrlProvider.overrideWith((Ref ref, int id) async => null),
        ],
        child: const MaterialApp(home: TripMemoriesView(tripId: 3)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Kerala'), findsOneWidget);
    expect(find.text('Elsewhere'), findsNothing);
    expect(tester.getTopLeft(find.text('New')).dy < tester.getTopLeft(find.text('Old')).dy ||
        tester.getTopLeft(find.text('New')).dx < tester.getTopLeft(find.text('Old')).dx, isTrue);
  });

  test('groupMemoriesByTrip stacks per trip, newest first, trip-less memories together', () {
    final List<MemoryStack> stacks = groupMemoriesByTrip(<MemoryModel>[
      MemoryModel(id: 1, tripId: 3, capturedAt: DateTime.utc(2026, 11, 1)),
      MemoryModel(id: 2, tripId: 4, createdAt: DateTime.utc(2026, 11, 20)),
      MemoryModel(id: 3, tripId: 3, capturedAt: DateTime.utc(2026, 11, 5)),
      const MemoryModel(id: 4),
      const MemoryModel(id: 5),
    ]);
    expect(stacks.map((MemoryStack s) => s.tripId), <int?>[4, 3, null]);
    expect(stacks[1].memories.map((MemoryModel m) => m.id), <int>[3, 1]);
    expect(stacks[1].oldest, DateTime.utc(2026, 11, 1));
    expect(stacks[2].memories.map((MemoryModel m) => m.id), <int>[5, 4]);
  });

  testWidgets('shows the empty state', (WidgetTester tester) async {
    await tester.pumpWidget(app(const <MemoryModel>[]));
    await tester.pumpAndSettle();
    expect(find.textContaining('No memories yet'), findsOneWidget);
  });
}
