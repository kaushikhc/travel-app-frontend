import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/router/auth_redirect.dart';
import '../../media/data/media_repository.dart';
import '../../memories/domain/memory_model.dart';
import '../../memories/presentation/widgets/memory_photo.dart';
import '../../trip/domain/trip_model.dart';
import '../data/journey_repository.dart';
import '../domain/trip_memory_view_model.dart';

/// Looking back at a finished trip: summary, photos, day-by-day timeline, places visited and memories.
class TripMemoryView extends ConsumerWidget {
  final int tripId;

  const TripMemoryView({super.key, required this.tripId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<TripMemoryViewData> data = ref.watch(tripMemoryViewProvider(tripId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip memories'),
        actions: <Widget>[
          TextButton(onPressed: () => context.push('/trips/$tripId'), child: const Text('Open trip')),
        ],
      ),
      body: data.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text('Could not load this trip.'),
              const SizedBox(height: 12),
              FilledButton(onPressed: () => ref.invalidate(tripMemoryViewProvider(tripId)), child: const Text('Retry')),
            ],
          ),
        ),
        data: (TripMemoryViewData d) => _content(context, ref, d),
      ),
    );
  }

  Widget _content(BuildContext context, WidgetRef ref, TripMemoryViewData d) {
    final ThemeData theme = Theme.of(context);
    final TripModel trip = d.trip;
    final int? coverId = trip.coverMediaId;
    final String? cover = coverId == null ? null : ref.watch(mediaUrlProvider(coverId)).value;
    final List<MemoryMedia> photos = d.photos;
    final List<(String, int)> stats = <(String, int)>[
      ('Places', d.summary['placesVisited'] ?? 0),
      ('Countries', d.summary['countriesVisited'] ?? 0),
      ('Memories', d.summary['memories'] ?? 0),
      ('Photos', d.summary['photos'] ?? 0),
      ('Nights', d.summary['nights'] ?? 0),
    ];
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: <Widget>[
        if (coverId != null)
          SizedBox(
            height: 180,
            child: cover == null
                ? ColoredBox(color: theme.colorScheme.primaryContainer)
                : Image.network(cover, fit: BoxFit.cover, errorBuilder: (BuildContext c, Object e, StackTrace? s) => ColoredBox(color: theme.colorScheme.primaryContainer)),
          ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(trip.name, style: theme.textTheme.headlineSmall),
              if (trip.startDate != null)
                Text(
                  trip.endDate == null
                      ? DateFormat.yMMMd().format(trip.startDate!)
                      : '${DateFormat.yMMMd().format(trip.startDate!)} – ${DateFormat.yMMMd().format(trip.endDate!)}',
                  style: theme.textTheme.bodyMedium,
                ),
              if (trip.description?.isNotEmpty == true) ...<Widget>[const SizedBox(height: 8), Text(trip.description!)],
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: <Widget>[for (final (String, int) s in stats) Chip(label: Text('${s.$2} ${s.$1}'))]),
            ],
          ),
        ),
        if (photos.isNotEmpty) ...<Widget>[
          _heading(theme, 'Photos'),
          SizedBox(
            height: 120,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: photos.length,
              separatorBuilder: (BuildContext c, int i) => const SizedBox(width: 8),
              itemBuilder: (BuildContext c, int i) => ClipRRect(borderRadius: BorderRadius.circular(8), child: SizedBox(width: 120, child: MemoryPhoto(media: photos[i]))),
            ),
          ),
        ],
        _heading(theme, 'Day by day'),
        if (d.days.isEmpty)
          _note(theme, 'Nothing was recorded for this trip.')
        else
          for (final MemoryViewDay day in d.days) ..._day(context, theme, d, day),
        _heading(theme, 'Places visited'),
        if (d.placesVisited.isEmpty)
          _note(theme, 'No visits were logged.')
        else
          for (final VisitedPlaceSummary p in d.placesVisited)
            ListTile(dense: true, leading: const Icon(Icons.place_outlined), title: Text(p.name), subtitle: p.visitCount > 1 ? Text('${p.visitCount} visits') : null),
      ],
    );
  }

  List<Widget> _day(BuildContext context, ThemeData theme, TripMemoryViewData d, MemoryViewDay day) {
    return <Widget>[
      Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 0), child: Text(DateFormat.MMMEd().format(day.date), style: theme.textTheme.titleSmall)),
      for (final TimelineRef r in day.entries)
        if (r.kind == 'MEMORY')
          if (d.memories[r.id] case final MemoryModel m)
            ListTile(
              dense: true,
              leading: SizedBox(width: 44, height: 44, child: ClipRRect(borderRadius: BorderRadius.circular(6), child: MemoryPhoto(media: m.media.isEmpty ? null : m.media.first))),
              title: Text(m.displayTitle),
              subtitle: Text(<String>['Memory', if (m.capturedAt != null) DateFormat.jm().format(m.capturedAt!.toLocal())].join(' · ')),
              onTap: () => context.push(AppRoutes.memoryDetail(m.id)),
            )
          else
            const SizedBox.shrink()
        else if (d.itinerary[TripMemoryViewData.key(r.kind, r.id)] case final MemoryViewItem i)
          ListTile(
            dense: true,
            leading: Icon(_icon(i.kind)),
            title: Text(i.title.isEmpty ? 'Untitled' : i.title),
            subtitle: i.subtitle.isEmpty ? null : Text(i.subtitle),
            trailing: i.startTime == null ? null : Text(DateFormat.jm().format(i.startTime!.toLocal())),
          )
        else
          const SizedBox.shrink(),
    ];
  }

  static Widget _heading(ThemeData theme, String t) => Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 8), child: Text(t, style: theme.textTheme.titleMedium));

  static Widget _note(ThemeData theme, String t) =>
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text(t, style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor)));

  static IconData _icon(String kind) => switch (kind) {
        'TRANSPORT' => Icons.directions_transit_outlined,
        'STAY' => Icons.hotel_outlined,
        'VISIT' => Icons.place_outlined,
        _ => Icons.circle_outlined,
      };
}
