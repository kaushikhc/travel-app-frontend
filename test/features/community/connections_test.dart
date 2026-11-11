import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_app_frontend/features/community/data/community_repository.dart';
import 'package:travel_app_frontend/features/community/domain/community_models.dart';
import 'package:travel_app_frontend/features/community/presentation/connections_view.dart';

class _Repo implements CommunityRepository {
  final List<TravelerCard> people;
  _Repo(this.people);

  @override
  Future<List<TravelerCard>> fetchConnections(ConnectionKind kind, {int page = 0, int size = 50}) async => people;

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

Future<void> _pump(WidgetTester t, ConnectionKind kind, List<TravelerCard> people) async {
  await t.pumpWidget(ProviderScope(
    overrides: [communityRepositoryProvider.overrideWithValue(_Repo(people))],
    child: MaterialApp(home: ConnectionsView(kind: kind)),
  ));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('followers list shows people and follows-you chip', (WidgetTester t) async {
    await _pump(t, ConnectionKind.followers, const <TravelerCard>[
      TravelerCard(id: 1, displayName: 'Asha', bio: 'Hiker', followsYou: true),
      TravelerCard(id: 2, displayName: 'Ben', following: true, followsYou: true),
    ]);
    expect(find.text('Followers'), findsOneWidget);
    expect(find.text('Asha'), findsOneWidget);
    expect(find.text('Ben'), findsOneWidget);
    expect(find.text('Follows you'), findsOneWidget);
  });

  testWidgets('empty following list', (WidgetTester t) async {
    await _pump(t, ConnectionKind.following, const <TravelerCard>[]);
    expect(find.text('You are not following anyone yet.'), findsOneWidget);
  });
}
