import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_app_frontend/features/community/data/community_repository.dart';
import 'package:travel_app_frontend/features/community/domain/community_models.dart';
import 'package:travel_app_frontend/features/community/presentation/traveler_view.dart';

class _Repo implements CommunityRepository {
  final List<String> calls = <String>[];

  @override
  Future<TravelerCard> fetchTraveler(int id) async => const TravelerCard(id: 7, displayName: 'Asha', bio: 'Hiker', followers: 2, posts: 1);

  @override
  Future<FeedPage> fetchTravelerPosts(int id, {int page = 0, int size = 20}) async => const FeedPage(posts: <PostModel>[], page: 0, hasMore: false);

  @override
  Future<TravelerCard> setFollow(int id, {required bool follow}) async {
    calls.add('follow $id $follow');
    return TravelerCard(id: id, displayName: 'Asha', followers: follow ? 3 : 2, following: follow);
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  test('traveler card parses', () {
    final TravelerCard c = TravelerCard.fromJson(<String, dynamic>{
      'id': 7, 'displayName': 'Asha', 'bio': 'Hi', 'followers': 4, 'followingCount': 5, 'posts': 6, 'following': true, 'followsYou': true,
    });
    expect((c.followers, c.followingCount, c.posts, c.following, c.followsYou), (4, 5, 6, true, true));
  });

  testWidgets('profile shows counts and follows', (WidgetTester tester) async {
    final _Repo repo = _Repo();
    await tester.pumpWidget(ProviderScope(
      overrides: [communityRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: TravelerView(travelerId: 7)),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Asha'), findsOneWidget);
    expect(find.text('Hiker'), findsOneWidget);
    expect(find.text('No posts yet.'), findsOneWidget);
    await tester.tap(find.text('Follow'));
    await tester.pumpAndSettle();
    expect(repo.calls, <String>['follow 7 true']);
    expect(find.text('Following'), findsNWidgets(2));
    expect(find.text('3'), findsOneWidget);
  });
}
