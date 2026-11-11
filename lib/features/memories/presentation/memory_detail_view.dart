import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/auth_redirect.dart';
import '../../../core/time/api_time.dart';
import '../../trip/data/trip_repository.dart';
import '../../trip/domain/trip_model.dart';
import '../data/memory_repository.dart';
import '../domain/memory_model.dart';
import 'widgets/memory_photo.dart';

class MemoryDetailView extends ConsumerWidget {
  final int memoryId;

  const MemoryDetailView({super.key, required this.memoryId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<MemoryModel> memory = ref.watch(memoryDetailProvider(memoryId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Memory'),
        actions: <Widget>[
          if (memory.hasValue)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete memory',
              onPressed: () => _confirmDelete(context, ref),
            ),
        ],
      ),
      body: memory.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text('Could not load this memory.'),
              const SizedBox(height: 12),
              FilledButton(onPressed: () => ref.invalidate(memoryDetailProvider(memoryId)), child: const Text('Retry')),
            ],
          ),
        ),
        data: (MemoryModel m) => _content(context, ref, m),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext c) => AlertDialog(
        title: const Text('Delete this memory?'),
        content: const Text('The memory and its photos will be removed. This cannot be undone.'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await ref.read(memoryRepositoryProvider).deleteMemory(memoryId);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Could not delete the memory. Please try again.')));
      }
      return;
    }
    ref.invalidate(memoriesProvider);
    ref.invalidate(travelStatsProvider);
    ref.invalidate(homeOverviewProvider);
    if (context.mounted) context.go(AppRoutes.memories);
  }

  Widget _content(BuildContext context, WidgetRef ref, MemoryModel m) {
    final ThemeData theme = Theme.of(context);
    final DateTime? date = m.date;
    final String? tripName = ref.watch(tripsProvider).value?.cast<TripModel?>().firstWhere(
          (TripModel? t) => t?.id == m.tripId,
          orElse: () => null,
        )?.name;
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: <Widget>[
        for (final MemoryMedia photo in m.media)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AspectRatio(
              aspectRatio: (photo.width != null && photo.height != null && photo.height! > 0)
                  ? photo.width! / photo.height!
                  : 4 / 3,
              child: MemoryPhoto(media: photo, fit: BoxFit.contain),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(m.displayTitle, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 4),
              Text(
                <String>[
                  ?tripName,
                  if (date != null) ApiTime.formatDateTime(date),
                  m.visibility.label,
                ].join(' · '),
                style: theme.textTheme.bodySmall,
              ),
              if (m.note != null && m.note!.trim().isNotEmpty) ...<Widget>[
                const SizedBox(height: 16),
                Text(m.note!, style: theme.textTheme.bodyLarge),
              ],
              if (m.tags.isNotEmpty) ...<Widget>[
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: <Widget>[for (final String t in m.tags) Chip(label: Text(t))],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
