import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/router/auth_redirect.dart';
import '../../../core/time/api_time.dart';
import '../data/journey_repository.dart';
import '../domain/journey_models.dart';
import 'world_map.dart';

/// "My travels": lifetime statistics and visited countries, a map, past trips and the timeline.
class JourneyView extends StatelessWidget {
  const JourneyView({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My travels'),
          bottom: const TabBar(tabs: <Tab>[Tab(text: 'Stats'), Tab(text: 'Map'), Tab(text: 'Past trips'), Tab(text: 'Timeline')]),
        ),
        body: const TabBarView(children: <Widget>[_StatsTab(), _MapTab(), _PastTripsTab(), TimelineTab()]),
      ),
    );
  }
}

Widget _error(String text, VoidCallback retry) => Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[Text(text), const SizedBox(height: 12), FilledButton(onPressed: retry, child: const Text('Retry'))],
      ),
    );

class _StatsTab extends ConsumerWidget {
  const _StatsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<LifetimeStats> stats = ref.watch(lifetimeStatsProvider);
    final AsyncValue<List<VisitedCountry>> countries = ref.watch(visitedCountriesProvider);
    final ThemeData theme = Theme.of(context);
    return stats.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (Object e, StackTrace _) => _error('Could not load your statistics.', () {
        ref.invalidate(lifetimeStatsProvider);
        ref.invalidate(visitedCountriesProvider);
      }),
      data: (LifetimeStats s) {
        final NumberFormat n = NumberFormat.decimalPattern();
        final List<(String, int)> tiles = <(String, int)>[
          ('Countries', s.countriesVisited),
          ('Continents', s.continentsVisited),
          ('Cities', s.citiesVisited),
          ('Places', s.placesVisited),
          ('Trips', s.tripsCompleted),
          ('Nights away', s.nights),
          ('Journeys', s.journeys),
          ('Flights', s.flights),
          ('Distance (km)', s.distanceKm),
          ('Memories', s.memories),
        ];
        return ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: <Widget>[
                for (final (String, int) t in tiles)
                  SizedBox(
                    width: 150,
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[Text(n.format(t.$2), style: theme.textTheme.headlineSmall), Text(t.$1)],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Countries visited', style: theme.textTheme.titleMedium),
            ...countries.when(
              loading: () => <Widget>[const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))],
              error: (Object e, StackTrace _) => <Widget>[const Text('Could not load the countries.')],
              data: (List<VisitedCountry> list) => list.isEmpty
                  ? <Widget>[Text('No countries yet.', style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor))]
                  : <Widget>[
                      for (final VisitedCountry c in list)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text(c.name),
                          subtitle: Text(<String>[
                            if (c.tripCount > 0) '${c.tripCount} ${c.tripCount == 1 ? 'trip' : 'trips'}',
                            if (c.regions.isNotEmpty) c.regions.join(', '),
                          ].join(' · ')),
                        ),
                    ],
            ),
          ],
        );
      },
    );
  }
}

class _MapTab extends ConsumerWidget {
  const _MapTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(journeyMapProvider).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object e, StackTrace _) => _error('Could not load the map.', () => ref.invalidate(journeyMapProvider)),
          data: (MapData d) => d.isEmpty
              ? const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No visited places with a location yet.', textAlign: TextAlign.center)))
              : Padding(padding: const EdgeInsets.all(16), child: ClipRRect(borderRadius: BorderRadius.circular(12), child: WorldMap(data: d))),
        );
  }
}

class _PastTripsTab extends ConsumerWidget {
  const _PastTripsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(pastTripsProvider).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object e, StackTrace _) => _error('Could not load your past trips.', () => ref.invalidate(pastTripsProvider)),
          data: (List<PastTrip> trips) => trips.isEmpty
              ? const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No finished trips yet.', textAlign: TextAlign.center)))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: <Widget>[
                    for (final PastTrip t in trips)
                      Card(
                        child: ListTile(
                          title: Text(t.name),
                          subtitle: Text(<String>[
                            if (t.startDate != null) DateFormat.yMMMd().format(t.startDate!),
                            '${t.placesVisited} places',
                            '${t.countriesVisited} countries',
                            '${t.memories} memories',
                          ].join(' · ')),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.push(AppRoutes.tripMemoryView(t.id)),
                        ),
                      ),
                  ],
                ),
        );
  }
}

/// The lifetime timeline, newest first, loaded 50 at a time.
class TimelineTab extends ConsumerStatefulWidget {
  const TimelineTab({super.key});

  @override
  ConsumerState<TimelineTab> createState() => _TimelineTabState();
}

class _TimelineTabState extends ConsumerState<TimelineTab> {
  final List<TimelineEntry> _entries = <TimelineEntry>[];
  String? _next;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load(first: true);
  }

  Future<void> _load({bool first = false}) async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final TimelinePage p = await ref.read(journeyRepositoryProvider).fetchTimeline(before: first ? null : _next);
      if (!mounted) return;
      setState(() {
        if (first) _entries.clear();
        _entries.addAll(p.entries);
        _next = p.nextBefore;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  static IconData _icon(String kind) => switch (kind) {
        'TRIP_START' => Icons.flag_outlined,
        'TRIP_END' => Icons.sports_score,
        'TRANSPORT' => Icons.directions_transit_outlined,
        'STAY' => Icons.hotel_outlined,
        'VISIT' => Icons.place_outlined,
        'MEMORY' => Icons.photo_outlined,
        _ => Icons.circle_outlined,
      };

  static String _label(String kind) => switch (kind) {
        'TRIP_START' => 'Trip started',
        'TRIP_END' => 'Trip ended',
        'TRANSPORT' => 'Journey',
        'STAY' => 'Stay',
        'VISIT' => 'Visit',
        'MEMORY' => 'Memory',
        _ => kind,
      };

  @override
  Widget build(BuildContext context) {
    if (_entries.isEmpty) {
      if (_loading) return const Center(child: CircularProgressIndicator());
      if (_failed) return _error('Could not load the timeline.', () => _load(first: true));
      return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Nothing on your timeline yet.', textAlign: TextAlign.center)));
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        for (final TimelineEntry e in _entries)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: Icon(_icon(e.kind)),
            title: Text(e.title.isEmpty ? _label(e.kind) : e.title),
            subtitle: Text(<String>[_label(e.kind), if (e.time != null) ApiTime.formatDateTime(e.time!)].join(' · ')),
            onTap: e.tripId == null ? null : () => context.push('/trips/${e.tripId}'),
          ),
        if (_next != null)
          Center(
            child: _loading
                ? const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator())
                : OutlinedButton(onPressed: _load, child: Text(_failed ? 'Retry' : 'Load more')),
          ),
      ],
    );
  }
}
