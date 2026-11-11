import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/auth_redirect.dart';
import '../../../core/time/api_time.dart';
import '../data/community_repository.dart';
import '../domain/community_models.dart';

/// Loaded posts of one feed and whether more pages exist.
@immutable
class FeedState {
  final List<PostModel> posts;
  final int nextPage;
  final bool hasMore;
  final bool loadingMore;

  const FeedState({required this.posts, required this.nextPage, required this.hasMore, this.loadingMore = false});

  FeedState copyWith({List<PostModel>? posts, int? nextPage, bool? hasMore, bool? loadingMore}) => FeedState(
        posts: posts ?? this.posts,
        nextPage: nextPage ?? this.nextPage,
        hasMore: hasMore ?? this.hasMore,
        loadingMore: loadingMore ?? this.loadingMore,
      );
}

class FeedNotifier extends AsyncNotifier<FeedState> {
  final FeedKind kind;

  FeedNotifier(this.kind);

  @override
  Future<FeedState> build() async {
    final FeedPage p = await ref.read(communityRepositoryProvider).fetchFeed(kind);
    return FeedState(posts: p.posts, nextPage: p.page + 1, hasMore: p.hasMore);
  }

  Future<void> loadMore() async {
    final FeedState? s = state.value;
    if (s == null || !s.hasMore || s.loadingMore) return;
    state = AsyncData<FeedState>(s.copyWith(loadingMore: true));
    try {
      final FeedPage p = await ref.read(communityRepositoryProvider).fetchFeed(kind, page: s.nextPage);
      state = AsyncData<FeedState>(FeedState(posts: <PostModel>[...s.posts, ...p.posts], nextPage: p.page + 1, hasMore: p.hasMore));
    } catch (_) {
      state = AsyncData<FeedState>(s.copyWith(loadingMore: false));
    }
  }

  /// Likes or unlikes [post]; the list shows the server's updated post. Throws on failure.
  Future<void> toggleLike(PostModel post) async {
    final PostModel updated = await ref.read(communityRepositoryProvider).setLike(post.id, liked: !post.likedByMe);
    final FeedState? s = state.value;
    if (s == null) return;
    state = AsyncData<FeedState>(s.copyWith(
      posts: <PostModel>[for (final PostModel p in s.posts) p.id == updated.id ? updated : p],
    ));
  }
}

final feedProvider = AsyncNotifierProvider.autoDispose.family<FeedNotifier, FeedState, FeedKind>(FeedNotifier.new);

/// The Community tab of Explore: posts from people I follow, or recent public posts.
class CommunityFeed extends ConsumerStatefulWidget {
  const CommunityFeed({super.key});

  @override
  ConsumerState<CommunityFeed> createState() => _CommunityFeedState();
}

class _CommunityFeedState extends ConsumerState<CommunityFeed> {
  FeedKind _kind = FeedKind.everyone;

  @override
  Widget build(BuildContext context) {
    final AsyncValue<FeedState> feed = ref.watch(feedProvider(_kind));
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<FeedKind>(
            segments: const <ButtonSegment<FeedKind>>[
              ButtonSegment<FeedKind>(value: FeedKind.everyone, label: Text('Everyone')),
              ButtonSegment<FeedKind>(value: FeedKind.following, label: Text('Following')),
            ],
            selected: <FeedKind>{_kind},
            onSelectionChanged: (Set<FeedKind> s) => setState(() => _kind = s.first),
          ),
        ),
        Expanded(
          child: feed.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (Object e, StackTrace _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Text('Could not load the feed.'),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: () => ref.invalidate(feedProvider(_kind)), child: const Text('Retry')),
                ],
              ),
            ),
            data: (FeedState s) => s.posts.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _kind == FeedKind.following
                            ? 'Nothing here yet. Follow travelers or share one of your memories.'
                            : 'No public posts yet. Share a memory from its detail screen.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(feedProvider(_kind));
                      await ref.read(feedProvider(_kind).future);
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: s.posts.length + (s.hasMore ? 1 : 0),
                      itemBuilder: (BuildContext c, int i) {
                        if (i == s.posts.length) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Center(
                              child: s.loadingMore
                                  ? const CircularProgressIndicator()
                                  : OutlinedButton(
                                      onPressed: () => ref.read(feedProvider(_kind).notifier).loadMore(),
                                      child: const Text('Load more'),
                                    ),
                            ),
                          );
                        }
                        return PostCard(post: s.posts[i], onLike: () => _like(s.posts[i]));
                      },
                    ),
                  ),
          ),
        ),
      ],
    );
  }

  Future<void> _like(PostModel post) async {
    try {
      await ref.read(feedProvider(_kind).notifier).toggleLike(post);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not update the like. Please try again.')));
      }
    }
  }
}

class PostCard extends StatelessWidget {
  final PostModel post;
  final VoidCallback onLike;

  const PostCard({super.key, required this.post, required this.onLike});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String? photo = post.photoUrls.isEmpty ? null : post.photoUrls.first;
    final String? photoUrl = post.author.photoUrl;
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ListTile(
            leading: CircleAvatar(
              backgroundImage: photoUrl == null || photoUrl.isEmpty ? null : NetworkImage(photoUrl),
              child: photoUrl == null || photoUrl.isEmpty ? const Icon(Icons.person_outline) : null,
            ),
            onTap: post.author.id == 0 ? null : () => context.push(AppRoutes.traveler(post.author.id)),
            title: Text(post.author.displayName.isEmpty ? 'Traveler' : post.author.displayName),
            subtitle: post.createdAt == null ? null : Text(ApiTime.formatDate(post.createdAt!)),
          ),
          if (photo != null)
            AspectRatio(
              aspectRatio: 4 / 3,
              child: Image.network(
                photo,
                fit: BoxFit.cover,
                errorBuilder: (BuildContext c, Object e, StackTrace? s) => ColoredBox(color: theme.colorScheme.primaryContainer),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (post.memoryTitle.isNotEmpty) Text(post.memoryTitle, style: theme.textTheme.titleMedium),
                if (post.caption?.isNotEmpty == true) ...<Widget>[const SizedBox(height: 4), Text(post.caption!)],
                if (post.caption?.isNotEmpty != true && post.memoryNote?.isNotEmpty == true) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(post.memoryNote!, maxLines: 3, overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: Row(
              children: <Widget>[
                IconButton(
                  tooltip: post.likedByMe ? 'Unlike' : 'Like',
                  icon: Icon(post.likedByMe ? Icons.favorite : Icons.favorite_border, color: post.likedByMe ? Colors.redAccent : null),
                  onPressed: onLike,
                ),
                Text('${post.likeCount}'),
                const Spacer(),
                if (post.place != null)
                  TextButton.icon(
                    icon: const Icon(Icons.place_outlined),
                    label: Text(post.place!.name.isEmpty ? 'View place' : post.place!.name),
                    onPressed: () => context.push(AppRoutes.placeDetail(post.place!.id)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
