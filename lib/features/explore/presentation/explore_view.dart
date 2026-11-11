import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/auth_redirect.dart';
import '../../trip/data/trip_repository.dart';
import '../../trip/domain/trip_model.dart';
import '../data/explore_repository.dart';
import '../domain/category_model.dart';
import '../domain/place_model.dart';
import '../domain/wishlist_item_model.dart';
import 'widgets/wishlist_button.dart';

/// The backend rejects searches shorter than this.
const int minSearchLength = 2;

enum _ExploreTab { discover, wishlist }

class ExploreView extends ConsumerStatefulWidget {
  /// How long typing must pause before the search runs.
  final Duration searchDelay;

  const ExploreView({super.key, this.searchDelay = const Duration(milliseconds: 400)});

  @override
  ConsumerState<ExploreView> createState() => _ExploreViewState();
}

class _ExploreViewState extends ConsumerState<ExploreView> {
  _ExploreTab _tab = _ExploreTab.discover;
  String? _selectedCategory;
  String _query = '';
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(widget.searchDelay, () {
      if (mounted) setState(() => _query = value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Explore', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: SegmentedButton<_ExploreTab>(
              segments: const <ButtonSegment<_ExploreTab>>[
                ButtonSegment<_ExploreTab>(value: _ExploreTab.discover, icon: Icon(Icons.explore), label: Text('Discover')),
                ButtonSegment<_ExploreTab>(value: _ExploreTab.wishlist, icon: Icon(Icons.favorite), label: Text('Wishlist')),
              ],
              selected: <_ExploreTab>{_tab},
              onSelectionChanged: (Set<_ExploreTab> s) => setState(() => _tab = s.first),
            ),
          ),
          Expanded(child: _tab == _ExploreTab.discover ? _discover(context) : const _WishlistList()),
        ],
      ),
    );
  }

  Widget _discover(BuildContext context) {
    final bool searching = _query.length >= minSearchLength;
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Search places',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            textInputAction: TextInputAction.search,
            onChanged: _onSearchChanged,
          ),
        ),
        if (!searching) _categoryChips(),
        const SizedBox(height: 8),
        Expanded(
          child: searching
              ? _PlaceList(
                  placesProvider: placeSearchProvider(_query),
                  emptyText: 'No places match "$_query".',
                )
              : _selectedList(),
        ),
      ],
    );
  }

  Widget _categoryChips() {
    final AsyncValue<List<CategoryModel>> categories = ref.watch(categoriesProvider);
    return categories.when(
      loading: () => const Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator()),
      error: (Object e, StackTrace _) => Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('Could not load categories.'),
            TextButton(onPressed: () => ref.invalidate(categoriesProvider), child: const Text('Retry')),
          ],
        ),
      ),
      data: (List<CategoryModel> list) => SizedBox(
        height: 52,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: <Widget>[
            for (final CategoryModel c in list)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(c.name),
                  selected: c.name == (_selectedCategory ?? list.first.name),
                  onSelected: (_) => setState(() => _selectedCategory = c.name),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _selectedList() {
    final List<CategoryModel>? categories = ref.watch(categoriesProvider).value;
    if (categories == null) return const SizedBox.shrink();
    if (categories.isEmpty) return const Center(child: Text('No categories yet.'));
    final String name = _selectedCategory ?? categories.first.name;
    return _PlaceList(placesProvider: placesByCategoryProvider(name), emptyText: 'No places in $name yet.');
  }
}

class _PlaceList extends ConsumerWidget {
  final FutureProvider<List<PlaceModel>> placesProvider;
  final String emptyText;

  const _PlaceList({required this.placesProvider, required this.emptyText});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<PlaceModel>> places = ref.watch(placesProvider);
    return places.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object e, StackTrace _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text('Could not load places.'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => ref.invalidate(placesProvider),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (List<PlaceModel> list) => list.isEmpty
          ? Center(child: Text(emptyText))
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              itemCount: list.length,
              separatorBuilder: (BuildContext _, int i) => const SizedBox(height: 8),
              itemBuilder: (BuildContext context, int i) {
                final PlaceModel p = list[i];
                return Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    leading: const Icon(Icons.place_outlined),
                    title: Text(p.name),
                    subtitle: p.subtitle.isEmpty ? null : Text(p.subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
                    trailing: WishlistButton(placeId: p.id),
                    onTap: () => context.push(AppRoutes.placeDetail(p.id)),
                  ),
                );
              },
            ),
    );
  }
}

class _WishlistList extends ConsumerWidget {
  const _WishlistList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<WishlistItemModel>> wishlist = ref.watch(wishlistProvider);
    return wishlist.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object e, StackTrace _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text('Could not load your wishlist.'),
            const SizedBox(height: 12),
            FilledButton(onPressed: () => ref.invalidate(wishlistProvider), child: const Text('Retry')),
          ],
        ),
      ),
      data: (List<WishlistItemModel> items) => items.isEmpty
          ? const Center(child: Text('Your wishlist is empty. Tap the heart on a place to save it.'))
          : RefreshIndicator(
              onRefresh: () => ref.refresh(wishlistProvider.future),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: items.length,
                separatorBuilder: (BuildContext _, int i) => const SizedBox(height: 8),
                itemBuilder: (BuildContext context, int i) => _WishlistTile(item: items[i]),
              ),
            ),
    );
  }
}

class _WishlistTile extends ConsumerWidget {
  final WishlistItemModel item;

  const _WishlistTile({required this.item});

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(exploreRepositoryProvider).removeFromWishlist(item.id);
      ref.invalidate(wishlistProvider);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(exploreError(e, 'Could not remove the place.'))));
    }
  }

  Future<void> _plan(BuildContext context, WidgetRef ref) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final List<TripModel> trips;
    try {
      trips = await ref.read(tripsProvider.future);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(exploreError(e, 'Could not load your trips.'))));
      return;
    }
    if (!context.mounted) return;
    if (trips.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Create a trip first, then plan this place into it.')));
      return;
    }
    final TripModel? trip = await showDialog<TripModel>(
      context: context,
      builder: (BuildContext c) => SimpleDialog(
        title: const Text('Plan into trip'),
        children: <Widget>[
          for (final TripModel t in trips)
            SimpleDialogOption(
              onPressed: item.plannedTripIds.contains(t.id) ? null : () => Navigator.pop(c, t),
              child: Text(item.plannedTripIds.contains(t.id) ? '${t.name} (already planned)' : t.name),
            ),
        ],
      ),
    );
    if (trip == null) return;
    try {
      await ref.read(exploreRepositoryProvider).planOnTrip(itemId: item.id, tripId: trip.id);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(exploreError(e, 'Could not plan this place.'))));
      return;
    }
    ref.invalidate(tripDetailProvider(trip.id));
    ref.invalidate(wishlistProvider);
    messenger.showSnackBar(SnackBar(content: Text('Added ${item.place.name} to ${trip.name}.')));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            InkWell(
              onTap: () => context.push(AppRoutes.placeDetail(item.place.id)),
              child: Text(item.place.name, style: Theme.of(context).textTheme.titleMedium),
            ),
            if (item.place.subtitle.isNotEmpty) Text(item.place.subtitle, style: Theme.of(context).textTheme.bodySmall),
            if (item.visited) const Text('Visited', style: TextStyle(color: Colors.green)),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                FilledButton.tonalIcon(
                  onPressed: () => _plan(context, ref),
                  icon: const Icon(Icons.add_location_alt_outlined),
                  label: const Text('Plan into trip'),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'Remove from wishlist',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _remove(context, ref),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
