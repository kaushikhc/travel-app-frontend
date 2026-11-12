import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/auth_redirect.dart';
import '../data/trip_repository.dart';
import '../domain/itinerary.dart';
import '../domain/trip_detail_model.dart';

/// Read-only, day-by-day itinerary of a trip, built from the trip's places, stays, transport
/// and visits (no extra API calls beyond [tripDetailProvider]).
class TripItineraryView extends ConsumerWidget {
  final int tripId;

  const TripItineraryView({super.key, required this.tripId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<TripDetail> detail = ref.watch(tripDetailProvider(tripId));
    return Scaffold(
      appBar: AppBar(title: const Text('Itinerary')),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text('Could not load the itinerary.'),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => ref.invalidate(tripDetailProvider(tripId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (TripDetail d) => _content(context, d),
      ),
    );
  }

  Widget _content(BuildContext context, TripDetail d) {
    final ThemeData theme = Theme.of(context);
    final Itinerary it = buildItinerary(d);
    if (it.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Nothing on the itinerary yet. Add places, stays or transport to this trip.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    final DateTime? start = d.trip.startDate;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: <Widget>[
        for (final ItineraryDay day in it.days) ...<Widget>[
          const SizedBox(height: 12),
          Text(
            <String>[
              if (start != null &&
                  !DateUtils.isSameDay(day.date, start) &&
                  day.date.isAfter(start))
                'Day ${DateUtils.dateOnly(day.date).difference(DateUtils.dateOnly(start)).inDays + 1}'
              else if (start != null && DateUtils.isSameDay(day.date, start))
                'Day 1',
              DateFormat.MMMEd().format(day.date),
            ].join(' · '),
            style: theme.textTheme.titleMedium,
          ),
          if (day.entries.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Nothing planned.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.hintColor,
                ),
              ),
            )
          else
            for (final ItineraryEntry e in day.entries) _row(context, e),
        ],
        if (it.unscheduled.isNotEmpty) ...<Widget>[
          const SizedBox(height: 20),
          Text('No date yet', style: theme.textTheme.titleMedium),
          for (final ItineraryEntry e in it.unscheduled) _row(context, e),
        ],
      ],
    );
  }

  Widget _row(BuildContext context, ItineraryEntry e) => ListTile(
    contentPadding: EdgeInsets.zero,
    dense: true,
    leading: Icon(_icon(e.kind)),
    title: Text(e.title.isEmpty ? 'Untitled' : e.title),
    subtitle: e.subtitle.isEmpty ? null : Text(e.subtitle),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (e.time != null) Text(DateFormat.jm().format(e.time!)),
        if (e.placeId != null)
          IconButton(
            tooltip: 'Memories',
            icon: const Icon(Icons.photo_library_outlined),
            onPressed: () =>
                context.push(AppRoutes.placeMemories(tripId, e.placeId!, e.title)),
          ),
      ],
    ),
  );

  static IconData _icon(ItineraryKind k) => switch (k) {
    ItineraryKind.place => Icons.place_outlined,
    ItineraryKind.checkIn => Icons.login,
    ItineraryKind.checkOut => Icons.logout,
    ItineraryKind.transport => Icons.directions_transit_outlined,
    ItineraryKind.visit => Icons.check_circle_outline,
  };
}
