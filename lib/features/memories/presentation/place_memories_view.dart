import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/auth_redirect.dart';
import '../../../core/time/api_time.dart';
import '../data/memory_repository.dart';
import '../domain/memory_model.dart';
import 'widgets/memory_photo.dart';

/// The memories of one place on one trip, opened from the itinerary. For a city the server also
/// includes memories at places inside it.
class PlaceMemoriesView extends ConsumerWidget {
  final int tripId;
  final int placeId;
  final String placeName;

  const PlaceMemoriesView({super.key, required this.tripId, required this.placeId, required this.placeName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ({int tripId, int placeId}) key = (tripId: tripId, placeId: placeId);
    final AsyncValue<List<MemoryModel>> memories = ref.watch(placeMemoriesProvider(key));
    return Scaffold(
      appBar: AppBar(title: Text(placeName.isEmpty ? 'Memories' : 'Memories · $placeName')),
      body: memories.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text('Could not load the memories.'),
              const SizedBox(height: 12),
              FilledButton(onPressed: () => ref.invalidate(placeMemoriesProvider(key)), child: const Text('Retry')),
            ],
          ),
        ),
        data: (List<MemoryModel> list) => list.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No memories here yet.', textAlign: TextAlign.center),
                ),
              )
            : ListView.separated(
                itemCount: list.length,
                separatorBuilder: (BuildContext c, int i) => const Divider(height: 1),
                itemBuilder: (BuildContext c, int i) {
                  final MemoryModel m = list[i];
                  final DateTime? date = m.date;
                  return ListTile(
                    leading: SizedBox(width: 56, height: 56, child: m.cover == null ? const Icon(Icons.notes) : MemoryPhoto(media: m.cover)),
                    title: Text(m.displayTitle, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: date == null ? null : Text(ApiTime.formatDate(date)),
                    onTap: () => context.push(AppRoutes.memoryDetail(m.id)),
                  );
                },
              ),
      ),
    );
  }
}
