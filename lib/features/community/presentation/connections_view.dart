import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/auth_redirect.dart';
import '../data/community_repository.dart';
import '../domain/community_models.dart';

/// The signed-in traveler's followers or following list; tap a row for that traveler's profile.
class ConnectionsView extends ConsumerWidget {
  final ConnectionKind kind;

  const ConnectionsView({super.key, required this.kind});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool followers = kind == ConnectionKind.followers;
    final AsyncValue<List<TravelerCard>> list = ref.watch(connectionsProvider(kind));
    return Scaffold(
      appBar: AppBar(title: Text(followers ? 'Followers' : 'Following')),
      body: list.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text('Could not load this list.'),
              TextButton(onPressed: () => ref.invalidate(connectionsProvider(kind)), child: const Text('Retry')),
            ],
          ),
        ),
        data: (List<TravelerCard> people) => people.isEmpty
            ? Center(child: Text(followers ? 'No followers yet.' : 'You are not following anyone yet.'))
            : ListView.builder(
                itemCount: people.length,
                itemBuilder: (BuildContext context, int i) {
                  final TravelerCard c = people[i];
                  final String? photo = c.photoUrl;
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: photo == null || photo.isEmpty ? null : NetworkImage(photo),
                      child: photo == null || photo.isEmpty ? const Icon(Icons.person_outline) : null,
                    ),
                    title: Text(c.displayName.isEmpty ? 'Traveler' : c.displayName),
                    subtitle: c.bio?.isNotEmpty == true ? Text(c.bio!, maxLines: 1, overflow: TextOverflow.ellipsis) : null,
                    trailing: c.followsYou && !c.following ? const Chip(label: Text('Follows you')) : null,
                    onTap: () => context.push(AppRoutes.traveler(c.id)),
                  );
                },
              ),
      ),
    );
  }
}
