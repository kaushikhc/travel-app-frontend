import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../profile/presentation/profile_state.dart';
import '../data/community_repository.dart';
import '../domain/community_models.dart';
import 'community_feed.dart';

/// Another traveler's public profile: name, bio, counts, follow button and their posts.
class TravelerView extends ConsumerStatefulWidget {
  final int travelerId;

  const TravelerView({super.key, required this.travelerId});

  @override
  ConsumerState<TravelerView> createState() => _TravelerViewState();
}

class _TravelerViewState extends ConsumerState<TravelerView> {
  /// The card after a follow or unfollow, until the provider is next reloaded.
  TravelerCard? _updated;
  bool _busy = false;
  final Map<int, PostModel> _likes = <int, PostModel>{};

  Future<void> _toggleFollow(TravelerCard card) async {
    setState(() => _busy = true);
    String? error;
    try {
      final TravelerCard next = await ref.read(communityRepositoryProvider).setFollow(card.id, follow: !card.following);
      if (mounted) _updated = next;
    } catch (e) {
      final dynamic data = e is DioException ? e.response?.data : null;
      error = data is Map<String, dynamic> && data['message'] is String ? data['message'] as String : 'Could not update. Please try again.';
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (error != null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }

  Future<void> _like(PostModel post) async {
    try {
      final PostModel p = await ref.read(communityRepositoryProvider).setLike(post.id, liked: !post.likedByMe);
      if (mounted) setState(() => _likes[p.id] = p);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not update the like. Please try again.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<TravelerCard> card = ref.watch(travelerProvider(widget.travelerId));
    final bool isMe = ref.watch(profileNotifierProvider).profile?.travelerId == widget.travelerId;
    return Scaffold(
      appBar: AppBar(title: const Text('Traveler')),
      body: card.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(e is DioException && e.response?.statusCode == 404 ? 'This traveler was not found.' : 'Could not load this profile.'),
              const SizedBox(height: 12),
              FilledButton(onPressed: () => ref.invalidate(travelerProvider(widget.travelerId)), child: const Text('Retry')),
            ],
          ),
        ),
        data: (TravelerCard loaded) => _content(context, _updated ?? loaded, isMe),
      ),
    );
  }

  Widget _content(BuildContext context, TravelerCard c, bool isMe) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<FeedPage> posts = ref.watch(travelerPostsProvider(widget.travelerId));
    final String? photo = c.photoUrl;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Row(
          children: <Widget>[
            CircleAvatar(
              radius: 36,
              backgroundImage: photo == null || photo.isEmpty ? null : NetworkImage(photo),
              child: photo == null || photo.isEmpty ? const Icon(Icons.person_outline, size: 36) : null,
            ),
            const SizedBox(width: 16),
            Expanded(child: Text(c.displayName.isEmpty ? 'Traveler' : c.displayName, style: theme.textTheme.headlineSmall)),
          ],
        ),
        if (c.bio?.isNotEmpty == true) ...<Widget>[const SizedBox(height: 12), Text(c.bio!)],
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[_count('${c.posts}', 'Posts'), _count('${c.followers}', 'Followers'), _count('${c.followingCount}', 'Following')],
        ),
        if (!isMe) ...<Widget>[
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: c.following
                    ? OutlinedButton(onPressed: _busy ? null : () => _toggleFollow(c), child: const Text('Following'))
                    : FilledButton(onPressed: _busy ? null : () => _toggleFollow(c), child: Text(c.followsYou ? 'Follow back' : 'Follow')),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        Text('Posts', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        ...posts.when(
          loading: () => <Widget>[const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()))],
          error: (Object e, StackTrace _) => <Widget>[const Text('Could not load their posts.')],
          data: (FeedPage p) => p.posts.isEmpty
              ? <Widget>[Text('No posts yet.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor))]
              : <Widget>[for (final PostModel post in p.posts) PostCard(post: _likes[post.id] ?? post, onLike: () => _like(_likes[post.id] ?? post))],
        ),
      ],
    );
  }

  static Widget _count(String n, String label) => Column(children: <Widget>[Text(n, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), Text(label)]);
}
