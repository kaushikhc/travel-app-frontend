import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../trip/data/trip_repository.dart';
import '../../trip/domain/trip_model.dart';
import '../data/memory_repository.dart';
import '../domain/memory_model.dart';
import '../domain/memory_stack.dart';
import 'widgets/memory_grid_card.dart';

/// The memories of one trip (an opened stack) as a grid, newest first. [tripId] null shows the
/// memories that are not linked to a trip.
class TripMemoriesView extends ConsumerWidget {
  final int? tripId;

  const TripMemoriesView({super.key, required this.tripId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<MemoryModel>> memories = ref.watch(memoriesProvider);
    String title = 'Other memories';
    if (tripId != null) {
      title = 'Trip';
      for (final TripModel t in ref.watch(tripsProvider).value ?? const <TripModel>[]) {
        if (t.id == tripId) title = t.name;
      }
    }
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: memories.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text('Could not load the memories.'),
              const SizedBox(height: 12),
              FilledButton(onPressed: () => ref.invalidate(memoriesProvider), child: const Text('Retry')),
            ],
          ),
        ),
        data: (List<MemoryModel> all) {
          final List<MemoryModel> list = sortMemoriesNewestFirst(all.where((MemoryModel m) => m.tripId == tripId));
          if (list.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No memories in this trip yet.', textAlign: TextAlign.center),
              ),
            );
          }
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 300,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.8,
            ),
            itemCount: list.length,
            itemBuilder: (BuildContext c, int i) => MemoryGridCard(memory: list[i]),
          );
        },
      ),
    );
  }
}
