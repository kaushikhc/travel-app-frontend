import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_app_frontend/features/community/data/community_repository.dart';
import 'package:travel_app_frontend/features/community/domain/community_models.dart';
import 'package:travel_app_frontend/features/community/presentation/community_feed.dart';

Map<String, dynamic> _post(int id, {bool liked = false, int likes = 0}) => <String, dynamic>{
      'id': id,
      'memoryId': id + 100,
      'author': <String, dynamic>{'id': 7, 'displayName': 'Asha', 'photoUrl': null},
      'caption': 'Great trip',
      'visibility': 'PUBLIC',
      'createdAt': '2026-11-10T12:00:00',
      'likeCount': likes,
      'likedByMe': liked,
      'memory': <String, dynamic>{
        'id': id + 100,
        'title': 'Beach day',
        'note': 'Sunny',
        'capturedAt': '2026-11-09T08:00:00',
        'place': <String, dynamic>{'id': 9, 'name': 'Varkala'},
        'media': <Map<String, dynamic>>[
          <String, dynamic>{'id': 1, 'type': 'VIDEO', 'url': 'https://x/v.mp4'},
          <String, dynamic>{'id': 2, 'type': 'IMAGE', 'url': 'https://x/p.jpg'},
        ],
      },
    };

class _FakeRepo implements CommunityRepository {
  final List<String> calls = <String>[];

  @override
  Future<FeedPage> fetchFeed(FeedKind kind, {int page = 0, int size = 20}) async {
    calls.add('feed ${kind.name} $page');
    return FeedPage(posts: <PostModel>[PostModel.fromJson(_post(1 + page))], page: page, hasMore: page == 0);
  }

  @override
  Future<PostModel> setLike(int postId, {required bool liked}) async {
    calls.add('like $postId $liked');
    return PostModel.fromJson(_post(postId, liked: liked, likes: liked ? 1 : 0));
  }

  @override
  Future<PostModel> shareMemory(int memoryId) async => PostModel.fromJson(_post(1));

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  test('post model parses the feed JSON and skips videos', () {
    final PostModel p = PostModel.fromJson(_post(1, liked: true, likes: 3));
    expect(p.author.displayName, 'Asha');
    expect(p.memoryTitle, 'Beach day');
    expect(p.place?.id, 9);
    expect(p.photoUrls, <String>['https://x/p.jpg']);
    expect(p.likedByMe, isTrue);
    expect(p.likeCount, 3);
    final FeedPage page = FeedPage.fromJson(<String, dynamic>{'posts': <Map<String, dynamic>>[_post(1)], 'page': 0, 'size': 20, 'hasMore': true});
    expect(page.hasMore, isTrue);
    expect(page.posts.single.id, 1);
  });

  testWidgets('feed shows posts, likes through the server and loads more', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final _FakeRepo repo = _FakeRepo();
    await tester.pumpWidget(ProviderScope(
      overrides: [communityRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: Scaffold(body: CommunityFeed())),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Asha'), findsOneWidget);
    expect(find.text('Beach day'), findsOneWidget);
    expect(find.text('Varkala'), findsOneWidget);
    expect(repo.calls, <String>['feed everyone 0']);

    await tester.tap(find.byTooltip('Like'));
    await tester.pumpAndSettle();
    expect(repo.calls.last, 'like 1 true');
    expect(find.text('1'), findsOneWidget);

    await tester.tap(find.text('Load more'));
    await tester.pumpAndSettle();
    expect(repo.calls.last, 'feed everyone 1');
    expect(find.text('Beach day'), findsNWidgets(2));

    await tester.tap(find.text('Following'));
    await tester.pumpAndSettle();
    expect(repo.calls.last, 'feed following 0');
  });
}
