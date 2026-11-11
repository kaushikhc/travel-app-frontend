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

class MemoriesView extends ConsumerStatefulWidget {
  const MemoriesView({super.key});

  @override
  ConsumerState<MemoriesView> createState() => _MemoriesViewState();
}

class _MemoriesViewState extends ConsumerState<MemoriesView> {
  String? _tag;

  Future<void> _refresh() async {
    ref.invalidate(tripsProvider);
    ref.invalidate(memoriesProvider);
    try {
      await ref.read(memoriesProvider.future);
    } catch (_) {
      // The error state shows it.
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<MemoryModel>> memories = ref.watch(memoriesProvider);
    // Trip names are a nicety: if the trips fail to load the cards just omit them.
    final Map<int, String> tripNames = <int, String>{
      for (final TripModel t in ref.watch(tripsProvider).value ?? const <TripModel>[]) t.id: t.name,
    };
    return Scaffold(
      appBar: AppBar(
        title: const Text('Memories', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: <Widget>[
          TextButton.icon(
            icon: const Icon(Icons.public),
            label: const Text('My travels'),
            onPressed: () => context.push(AppRoutes.journey),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: memories.when(
          loading: () => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const <Widget>[SizedBox(height: 200), Center(child: CircularProgressIndicator())],
          ),
          error: (Object e, StackTrace _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            children: <Widget>[
              const SizedBox(height: 120),
              const Center(child: Text('Could not load your memories.')),
              const SizedBox(height: 12),
              Center(child: FilledButton(onPressed: _refresh, child: const Text('Retry'))),
            ],
          ),
          data: (List<MemoryModel> list) => _content(context, list, tripNames),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, List<MemoryModel> all, Map<int, String> tripNames) {
    if (all.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: <Widget>[
          const SizedBox(height: 120),
          const Icon(Icons.photo_library_outlined, size: 48),
          const SizedBox(height: 12),
          const Center(child: Text('No memories yet. Capture your first one.')),
          const SizedBox(height: 12),
          Center(
            child: FilledButton(onPressed: () => context.go(AppRoutes.capture), child: const Text('Capture a memory')),
          ),
        ],
      );
    }
    final Map<String, String> tags = <String, String>{};
    for (final MemoryModel m in all) {
      for (final String t in m.tags) {
        tags.putIfAbsent(t.toLowerCase(), () => t);
      }
    }
    final String? selected = _tag != null && tags.containsKey(_tag) ? _tag : null;
    final List<MemoryModel> shown = selected == null
        ? all
        : all.where((MemoryModel m) => m.tags.any((String t) => t.toLowerCase() == selected)).toList(growable: false);
    final List<String> tagKeys = tags.keys.toList()..sort();
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: <Widget>[
        if (tagKeys.isNotEmpty)
          SliverToBoxAdapter(
            child: SizedBox(
              height: 56,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                children: <Widget>[
                  for (final String key in tagKeys)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(tags[key]!),
                        selected: selected == key,
                        onSelected: (bool on) => setState(() => _tag = on ? key : null),
                      ),
                    ),
                ],
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 300,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.8,
            ),
            itemCount: shown.length,
            itemBuilder: (BuildContext c, int i) => _MemoryCard(
              memory: shown[i],
              tripName: tripNames[shown[i].tripId],
            ),
          ),
        ),
      ],
    );
  }
}

class _MemoryCard extends StatelessWidget {
  final MemoryModel memory;
  final String? tripName;

  const _MemoryCard({required this.memory, required this.tripName});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final DateTime? date = memory.date;
    final String subtitle = <String>[
      ?tripName,
      if (date != null) ApiTime.formatDate(date),
    ].join(' · ');
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(AppRoutes.memoryDetail(memory.id)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              child: memory.cover == null
                  ? ColoredBox(
                      color: theme.colorScheme.primaryContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Text(memory.note ?? '', maxLines: 6, overflow: TextOverflow.ellipsis),
                      ),
                    )
                  : MemoryPhoto(media: memory.cover),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(memory.displayTitle,
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall),
                  if (subtitle.isNotEmpty)
                    Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
