import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/router/auth_redirect.dart';
import '../../../core/time/api_time.dart';
import '../../../core/network/api_errors.dart';
import '../../media/data/media_repository.dart';
import '../data/trip_repository.dart';
import '../domain/trip_detail_model.dart';
import '../domain/trip_model.dart';
import 'widgets/itinerary_dialogs.dart';

/// Read-only detail of one trip: header, then places, stays, transport and visits.
class TripDetailView extends ConsumerWidget {
  final int tripId;

  const TripDetailView({super.key, required this.tripId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<TripDetail> detail = ref.watch(tripDetailProvider(tripId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip'),
        actions: <Widget>[
          if (detail.hasValue) ...<Widget>[
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit trip',
              onPressed: () => context.push(AppRoutes.editTrip(tripId), extra: detail.requireValue.trip),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete trip',
              onPressed: () => _confirmDelete(context, ref),
            ),
          ],
        ],
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text('Could not load this trip.'),
              const SizedBox(height: 12),
              FilledButton(onPressed: () => ref.invalidate(tripDetailProvider(tripId)), child: const Text('Retry')),
            ],
          ),
        ),
        data: (TripDetail d) => _content(context, ref, d),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext c) => AlertDialog(
        title: const Text('Delete this trip?'),
        content: const Text('The trip and everything on it (places, stays, transport, visits, memories) will be removed. This cannot be undone.'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await ref.read(tripRepositoryProvider).deleteTrip(tripId);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not delete the trip. Please try again.')));
      }
      return;
    }
    ref.invalidate(homeOverviewProvider);
    ref.invalidate(travelStatsProvider);
    if (context.mounted) context.go(AppRoutes.home);
  }

  Widget _content(BuildContext context, WidgetRef ref, TripDetail d) {
    final ThemeData theme = Theme.of(context);
    final TripModel trip = d.trip;
    final int? coverId = trip.coverMediaId;
    final String? coverUrl = coverId == null ? null : ref.watch(mediaUrlProvider(coverId)).value;
    final DateTime now = DateTime.now();
    final int? day = trip.dayOfTrip(now);
    final int? total = trip.totalDays;
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: <Widget>[
        if (coverId != null)
          SizedBox(
            height: 200,
            child: coverUrl == null
                ? ColoredBox(color: theme.colorScheme.primaryContainer)
                : Image.network(coverUrl, fit: BoxFit.cover,
                    errorBuilder: (BuildContext c, Object e, StackTrace? s) =>
                        ColoredBox(color: theme.colorScheme.primaryContainer)),
          ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(trip.name, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  Chip(label: Text(_statusLabel(trip.status))),
                  if (_dateRange(trip) != null) Text(_dateRange(trip)!),
                ],
              ),
              if (trip.status == TripStatus.active && day != null && total != null) ...<Widget>[
                const SizedBox(height: 8),
                Text('Day $day of $total'),
                const SizedBox(height: 4),
                LinearProgressIndicator(value: day / total),
              ],
              if (trip.description?.isNotEmpty == true) ...<Widget>[
                const SizedBox(height: 12),
                Text(trip.description!),
              ],
              if (trip.tags.isNotEmpty) ...<Widget>[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: trip.tags.map((String t) => Chip(label: Text(t))).toList(growable: false),
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.event_note_outlined),
              label: const Text('Itinerary'),
              onPressed: () => context.push(AppRoutes.tripItinerary(tripId)),
            ),
          ),
        ),
        _section(theme, 'Places', 'No places planned yet.', d.places.map((TripPlaceItem p) {
          final List<String> parts = <String>[
            if (p.plannedDate != null) DateFormat.yMMMd().format(p.plannedDate!),
            if (p.status != null) _title(p.status!),
          ];
          return _row(p.name, parts.join(' · '),
              menu: _menu(
                onEdit: () => _edit(context, ref, () => showTripPlaceDialog(context, tripId: tripId, existing: p)),
                onDelete: () => _remove(context, ref, 'this place', () => ref.read(tripRepositoryProvider).deleteTripPlace(tripId, p.id)),
              ));
        }).toList(growable: false),
            onAdd: () => _edit(context, ref, () => showTripPlaceDialog(context, tripId: tripId)), addLabel: 'Add place'),
        _section(theme, 'Stays', 'No stays added yet.', d.stays.map((StayItem s) {
          return _row(s.name, _range(s.checkIn, s.checkOut));
        }).toList(growable: false)),
        _section(theme, 'Transport', 'No transport added yet.', d.transports.map((TransportItem t) {
          final String route = <String>[t.from, t.to].where((String x) => x.isNotEmpty).join(' → ');
          final String title = route.isNotEmpty ? route : (t.type == null ? 'Transport' : _title(t.type!));
          return _row(title, <String>[
            if (t.provider?.isNotEmpty == true) t.provider!,
            _range(t.departure, t.arrival),
          ].where((String x) => x.isNotEmpty).join(' · '));
        }).toList(growable: false)),
        _section(theme, 'Visits', 'No visits logged yet.', d.visits.map((VisitItem v) {
          return _row(v.name, v.visitedAt == null ? '' : ApiTime.formatDateTime(v.visitedAt!),
              menu: _menu(
                onEdit: () => _edit(context, ref, () => showVisitDialog(context, tripId: tripId, planned: d.places, existing: v)),
                onDelete: () => _remove(context, ref, 'this visit', () => ref.read(tripRepositoryProvider).deleteVisit(tripId, v.id)),
              ));
        }).toList(growable: false),
            onAdd: () => _edit(context, ref, () => showVisitDialog(context, tripId: tripId, planned: d.places)), addLabel: 'Log visit'),
      ],
    );
  }

  /// Runs [dialog] (which returns true when it changed something) and refreshes the trip.
  Future<void> _edit(BuildContext context, WidgetRef ref, Future<bool> Function() dialog) async {
    if (await dialog()) _refresh(ref);
  }

  Future<void> _remove(BuildContext context, WidgetRef ref, String what, Future<void> Function() delete) async {
    if (!await confirmDelete(context, what) || !context.mounted) return;
    try {
      await delete();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e, 'Could not delete. Please try again.'))));
      }
      return;
    }
    _refresh(ref);
  }

  void _refresh(WidgetRef ref) {
    ref.invalidate(tripDetailProvider(tripId));
    ref.invalidate(homeOverviewProvider);
    ref.invalidate(travelStatsProvider);
  }

  static Widget _menu({required VoidCallback onEdit, required VoidCallback onDelete}) => PopupMenuButton<String>(
        tooltip: 'Options',
        onSelected: (String v) => v == 'edit' ? onEdit() : onDelete(),
        itemBuilder: (BuildContext c) => const <PopupMenuEntry<String>>[
          PopupMenuItem<String>(value: 'edit', child: Text('Edit')),
          PopupMenuItem<String>(value: 'delete', child: Text('Delete')),
        ],
      );

  static Widget _section(ThemeData theme, String title, String empty, List<Widget> rows, {VoidCallback? onAdd, String addLabel = 'Add'}) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
                if (onAdd != null) TextButton.icon(icon: const Icon(Icons.add), label: Text(addLabel), onPressed: onAdd),
              ],
            ),
            const SizedBox(height: 4),
            if (rows.isEmpty) Text(empty, style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor)) else ...rows,
          ],
        ),
      );

  static Widget _row(String title, String subtitle, {Widget? menu}) => ListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        trailing: menu,
        title: Text(title.isEmpty ? 'Untitled' : title),
        subtitle: subtitle.isEmpty ? null : Text(subtitle),
      );

  static String _range(DateTime? a, DateTime? b) {
    if (a == null && b == null) return '';
    if (b == null) return ApiTime.formatDateTime(a!);
    if (a == null) return ApiTime.formatDateTime(b);
    return '${ApiTime.formatDateTime(a)} – ${ApiTime.formatDateTime(b)}';
  }

  static String? _dateRange(TripModel trip) {
    if (trip.startDate == null) return null;
    final String start = DateFormat.yMMMd().format(trip.startDate!);
    return trip.endDate == null ? start : '$start – ${DateFormat.yMMMd().format(trip.endDate!)}';
  }

  static String _statusLabel(TripStatus s) => switch (s) {
        TripStatus.draft => 'Draft',
        TripStatus.upcoming => 'Upcoming',
        TripStatus.active => 'Active',
        TripStatus.archived => 'Completed',
      };

  static String _title(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase().replaceAll('_', ' ');
}
