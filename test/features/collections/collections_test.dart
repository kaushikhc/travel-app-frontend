import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_app_frontend/features/collections/data/collection_repository.dart';
import 'package:travel_app_frontend/features/collections/domain/collection_models.dart';
import 'package:travel_app_frontend/features/collections/presentation/collections_view.dart';

class _Repo implements CollectionRepository {
  final List<String> calls = <String>[];

  @override
  Future<List<CollectionSummary>> fetchCollections() async => const <CollectionSummary>[
        CollectionSummary(id: 1, name: 'UNESCO sites', global: true, total: 10, visited: 2),
        CollectionSummary(id: 2, name: 'My list', description: 'Wants', total: 2, visited: 1),
      ];

  @override
  Future<CollectionDetail> fetchCollection(int id) async => CollectionDetail(
        collection: CollectionSummary(id: id, name: id == 1 ? 'UNESCO sites' : 'My list', global: id == 1, total: 2, visited: 1),
        items: const <CollectionItem>[
          CollectionItem(placeId: 5, name: 'Hampi', visited: true),
          CollectionItem(placeId: 6, name: 'Taj Mahal'),
        ],
      );

  @override
  Future<void> removePlace(int id, int placeId) async => calls.add('remove $id/$placeId');

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Widget _app(_Repo repo, Widget home) => ProviderScope(
      overrides: [collectionRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(home: home),
    );

void main() {
  test('models parse and the body is trimmed', () {
    final CollectionDetail d = CollectionDetail.fromJson(<String, dynamic>{
      'collection': <String, dynamic>{'id': 1, 'name': 'X', 'global': true, 'total': 3, 'visited': 1, 'percent': 33.3},
      'items': <Map<String, dynamic>>[
        <String, dynamic>{'place': <String, dynamic>{'id': 9, 'name': 'Y', 'type': 'CITY'}, 'visited': true},
      ],
    });
    expect(d.collection.global, isTrue);
    expect(d.items.single.placeId, 9);
    expect(d.items.single.visited, isTrue);
    expect(CollectionRepository.body(' A ', ' '), <String, dynamic>{'name': 'A', 'description': null});
  });

  testWidgets('list shows progress for global and own collections', (WidgetTester tester) async {
    await tester.pumpWidget(_app(_Repo(), const CollectionsView()));
    await tester.pumpAndSettle();
    expect(find.text('UNESCO sites'), findsOneWidget);
    expect(find.text('2 of 10 visited · shared'), findsOneWidget);
    expect(find.text('1 of 2 visited'), findsOneWidget);
    expect(find.text('New collection'), findsOneWidget);
  });

  testWidgets('a personal collection can be edited, a global one cannot', (WidgetTester tester) async {
    final _Repo repo = _Repo();
    await tester.pumpWidget(_app(repo, const CollectionDetailView(collectionId: 2)));
    await tester.pumpAndSettle();
    expect(find.text('Hampi'), findsOneWidget);
    expect(find.text('Add place'), findsOneWidget);
    await tester.tap(find.byTooltip('Remove from collection').first);
    await tester.pumpAndSettle();
    expect(repo.calls, <String>['remove 2/5']);

    await tester.pumpWidget(_app(repo, const CollectionDetailView(collectionId: 1)));
    await tester.pumpAndSettle();
    expect(find.text('Add place'), findsNothing);
    expect(find.byTooltip('Remove from collection'), findsNothing);
    expect(find.byTooltip('Delete collection'), findsNothing);
  });
}
