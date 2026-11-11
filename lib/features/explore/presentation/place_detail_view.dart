import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/explore_repository.dart';
import '../domain/place_model.dart';
import 'widgets/wishlist_button.dart';

class PlaceDetailView extends ConsumerWidget {
  final int placeId;

  const PlaceDetailView({super.key, required this.placeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<PlaceModel> place = ref.watch(placeDetailProvider(placeId));
    return Scaffold(
      appBar: AppBar(title: const Text('Place'), actions: <Widget>[WishlistButton(placeId: placeId)]),
      body: place.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text('Could not load this place.'),
              const SizedBox(height: 12),
              FilledButton(onPressed: () => ref.invalidate(placeDetailProvider(placeId)), child: const Text('Retry')),
            ],
          ),
        ),
        data: (PlaceModel p) => ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Text(p.name, style: Theme.of(context).textTheme.headlineSmall),
            if (p.type != null) ...<Widget>[const SizedBox(height: 4), Text(p.type!)],
            if (p.address != null && p.address!.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 16),
              ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.place_outlined), title: Text(p.address!)),
            ],
            if (p.latitude != null && p.longitude != null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.my_location),
                title: Text('${p.latitude!.toStringAsFixed(5)}, ${p.longitude!.toStringAsFixed(5)}'),
              ),
          ],
        ),
      ),
    );
  }
}
