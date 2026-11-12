import 'package:flutter/foundation.dart';

import 'memory_model.dart';

/// Sorts memories newest first by [MemoryModel.date] (captured time, else saved time).
/// Memories without any date go last; ties fall back to the id, newest first.
List<MemoryModel> sortMemoriesNewestFirst(Iterable<MemoryModel> memories) {
  final List<MemoryModel> sorted = memories.toList();
  sorted.sort((MemoryModel a, MemoryModel b) {
    final DateTime? da = a.date;
    final DateTime? db = b.date;
    if (da == null && db != null) return 1;
    if (da != null && db == null) return -1;
    final int byDate = (da != null && db != null) ? db.compareTo(da) : 0;
    return byDate != 0 ? byDate : b.id.compareTo(a.id);
  });
  return sorted;
}

/// All memories of one trip, shown as a single stack on the Memories page.
/// [tripId] is null for memories that are not linked to a trip.
@immutable
class MemoryStack {
  final int? tripId;

  /// Newest first.
  final List<MemoryModel> memories;

  const MemoryStack({required this.tripId, required this.memories});

  int get count => memories.length;

  /// The newest memory with a photo (else the newest memory), used as the stack's cover.
  MemoryModel get coverMemory => memories.firstWhere(
        (MemoryModel m) => m.cover != null,
        orElse: () => memories.first,
      );

  DateTime? get newest => memories.first.date;

  DateTime? get oldest {
    for (final MemoryModel m in memories.reversed) {
      if (m.date != null) return m.date;
    }
    return null;
  }
}

/// Groups [memories] into one stack per trip. Memories inside a stack are newest first, and the
/// stacks are ordered by their newest memory, newest first.
List<MemoryStack> groupMemoriesByTrip(Iterable<MemoryModel> memories) {
  final Map<int?, List<MemoryModel>> byTrip = <int?, List<MemoryModel>>{};
  for (final MemoryModel m in memories) {
    byTrip.putIfAbsent(m.tripId, () => <MemoryModel>[]).add(m);
  }
  final List<MemoryStack> stacks = <MemoryStack>[
    for (final MapEntry<int?, List<MemoryModel>> e in byTrip.entries)
      MemoryStack(tripId: e.key, memories: List<MemoryModel>.unmodifiable(sortMemoriesNewestFirst(e.value))),
  ];
  final List<MemoryModel> heads = sortMemoriesNewestFirst(stacks.map((MemoryStack s) => s.memories.first));
  final Map<int, int> rank = <int, int>{for (int i = 0; i < heads.length; i++) heads[i].id: i};
  stacks.sort((MemoryStack a, MemoryStack b) => rank[a.memories.first.id]!.compareTo(rank[b.memories.first.id]!));
  return stacks;
}
