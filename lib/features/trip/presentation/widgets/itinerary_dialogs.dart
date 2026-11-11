import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/network/api_errors.dart';
import '../../../../core/time/api_time.dart';
import '../../../explore/domain/place_model.dart';
import '../../data/trip_repository.dart';
import '../../domain/trip_detail_model.dart';
import 'place_picker.dart';

/// Date, then time; returns a local DateTime, or null if either step is dismissed.
Future<DateTime?> pickDateTime(BuildContext context, DateTime initial) async {
  final DateTime? d = await showDatePicker(context: context, initialDate: initial, firstDate: DateTime(1990), lastDate: DateTime(2100));
  if (d == null || !context.mounted) return null;
  final TimeOfDay? t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(initial));
  if (t == null) return null;
  return DateTime(d.year, d.month, d.day, t.hour, t.minute);
}

/// Adds a planned place (when [existing] is null) or edits one. Returns true if saved or deleted-free.
Future<bool> showTripPlaceDialog(BuildContext context, {required int tripId, TripPlaceItem? existing}) async =>
    await showDialog<bool>(context: context, builder: (BuildContext c) => _TripPlaceDialog(tripId: tripId, existing: existing)) ?? false;

class _TripPlaceDialog extends ConsumerStatefulWidget {
  final int tripId;
  final TripPlaceItem? existing;

  const _TripPlaceDialog({required this.tripId, this.existing});

  @override
  ConsumerState<_TripPlaceDialog> createState() => _TripPlaceDialogState();
}

class _TripPlaceDialogState extends ConsumerState<_TripPlaceDialog> {
  late final TextEditingController _notes = TextEditingController(text: widget.existing?.notes ?? '');
  late DateTime? _date = widget.existing?.plannedDate;
  late String _status = widget.existing?.status == 'SKIPPED' ? 'SKIPPED' : 'PLANNED';
  PlaceModel? _place;
  bool _saving = false;

  bool get _editing => widget.existing != null;
  bool get _visited => widget.existing?.status == 'VISITED';

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final int? placeId = _place?.id;
    if (!_editing && placeId == null) return;
    setState(() => _saving = true);
    try {
      final TripRepository repo = ref.read(tripRepositoryProvider);
      if (_editing) {
        await repo.updateTripPlace(widget.tripId, widget.existing!.id, plannedDate: _date, notes: _notes.text, status: _visited ? null : _status);
      } else {
        await repo.addTripPlace(widget.tripId, placeId: placeId!, plannedDate: _date, notes: _notes.text);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e, 'Could not save. Please try again.'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_editing ? 'Edit place' : 'Add a place'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (_editing)
              Text(widget.existing!.name, style: Theme.of(context).textTheme.titleMedium)
            else
              OutlinedButton.icon(
                icon: const Icon(Icons.search),
                label: Text(_place?.name ?? 'Choose a place'),
                onPressed: () async {
                  final PlaceModel? p = await pickPlace(context);
                  if (p != null && mounted) setState(() => _place = p);
                },
              ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.event),
                    label: Text(_date == null ? 'Planned date (optional)' : DateFormat.yMMMd().format(_date!)),
                    onPressed: () async {
                      final DateTime? d = await showDatePicker(
                          context: context, initialDate: _date ?? DateTime.now(), firstDate: DateTime(1990), lastDate: DateTime(2100));
                      if (d != null && mounted) setState(() => _date = d);
                    },
                  ),
                ),
                if (_date != null) IconButton(tooltip: 'Clear date', icon: const Icon(Icons.clear), onPressed: () => setState(() => _date = null)),
              ],
            ),
            const SizedBox(height: 12),
            TextField(controller: _notes, decoration: const InputDecoration(labelText: 'Notes'), maxLines: 3, minLines: 1),
            if (_editing && !_visited) ...<Widget>[
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: const <ButtonSegment<String>>[
                  ButtonSegment<String>(value: 'PLANNED', label: Text('Planned')),
                  ButtonSegment<String>(value: 'SKIPPED', label: Text('Skipped')),
                ],
                selected: <String>{_status},
                onSelectionChanged: (Set<String> s) => setState(() => _status = s.first),
              ),
            ],
            if (_visited) const Padding(padding: EdgeInsets.only(top: 12), child: Text('Visited: its status follows its visit.')),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: _saving || (!_editing && _place == null) ? null : _save, child: const Text('Save')),
      ],
    );
  }
}

/// Logs a visit (when [existing] is null) or edits one. The place is chosen from the trip's planned
/// places ([planned]) or searched; when editing it is fixed.
Future<bool> showVisitDialog(BuildContext context, {required int tripId, required List<TripPlaceItem> planned, VisitItem? existing}) async =>
    await showDialog<bool>(context: context, builder: (BuildContext c) => _VisitDialog(tripId: tripId, planned: planned, existing: existing)) ?? false;

class _VisitDialog extends ConsumerStatefulWidget {
  final int tripId;
  final List<TripPlaceItem> planned;
  final VisitItem? existing;

  const _VisitDialog({required this.tripId, required this.planned, this.existing});

  @override
  ConsumerState<_VisitDialog> createState() => _VisitDialogState();
}

class _VisitDialogState extends ConsumerState<_VisitDialog> {
  late final TextEditingController _notes = TextEditingController(text: widget.existing?.notes ?? '');
  late DateTime _visitedAt = (widget.existing?.visitedAt ?? DateTime.now()).toLocal();
  late DateTime? _leftAt = widget.existing?.leftAt?.toLocal();
  TripPlaceItem? _planned;
  PlaceModel? _other;
  bool _saving = false;

  bool get _editing => widget.existing != null;
  bool get _hasPlace => _editing || _planned != null || _other != null;

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(tripRepositoryProvider).saveVisit(
            widget.tripId,
            id: widget.existing?.id,
            tripPlaceId: _planned?.id,
            placeId: _editing ? widget.existing!.placeId : _other?.id,
            visitedAt: _visitedAt,
            leftAt: _leftAt,
            notes: _notes.text,
          );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e, 'Could not save. Please try again.'))));
    }
  }

  Widget _timeButton(String label, DateTime? value, void Function(DateTime) onPicked) => OutlinedButton.icon(
        icon: const Icon(Icons.schedule),
        label: Text(value == null ? label : ApiTime.formatDateTime(value.toUtc())),
        onPressed: () async {
          final DateTime? d = await pickDateTime(context, value ?? DateTime.now());
          if (d != null && mounted) setState(() => onPicked(d));
        },
      );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_editing ? 'Edit visit' : 'Log a visit'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (_editing)
              Text(widget.existing!.name, style: Theme.of(context).textTheme.titleMedium)
            else ...<Widget>[
              if (widget.planned.isNotEmpty)
                DropdownButtonFormField<TripPlaceItem>(
                  initialValue: _planned,
                  decoration: const InputDecoration(labelText: 'Planned place'),
                  items: <DropdownMenuItem<TripPlaceItem>>[
                    for (final TripPlaceItem p in widget.planned) DropdownMenuItem<TripPlaceItem>(value: p, child: Text(p.name)),
                  ],
                  onChanged: (TripPlaceItem? p) => setState(() {
                    _planned = p;
                    _other = null;
                  }),
                ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.search),
                label: Text(_other?.name ?? 'Or search another place'),
                onPressed: () async {
                  final PlaceModel? p = await pickPlace(context);
                  if (p != null && mounted) {
                    setState(() {
                      _other = p;
                      _planned = null;
                    });
                  }
                },
              ),
            ],
            const SizedBox(height: 12),
            _timeButton('Arrived', _visitedAt, (DateTime d) => _visitedAt = d),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(child: _timeButton('Left (optional)', _leftAt, (DateTime d) => _leftAt = d)),
                if (_leftAt != null) IconButton(tooltip: 'Clear', icon: const Icon(Icons.clear), onPressed: () => setState(() => _leftAt = null)),
              ],
            ),
            const SizedBox(height: 12),
            TextField(controller: _notes, decoration: const InputDecoration(labelText: 'Notes'), maxLines: 3, minLines: 1),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: _saving || !_hasPlace ? null : _save, child: const Text('Save')),
      ],
    );
  }
}

/// Confirms deleting [what]; true if the user agreed.
Future<bool> confirmDelete(BuildContext context, String what) async =>
    await showDialog<bool>(
      context: context,
      builder: (BuildContext c) => AlertDialog(
        title: Text('Delete $what?'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete')),
        ],
      ),
    ) ??
    false;
