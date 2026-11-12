import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_errors.dart';
import '../../../../core/time/api_time.dart';
import '../../../explore/domain/place_model.dart';
import '../../data/trip_repository.dart';
import '../../domain/trip_detail_model.dart';
import 'itinerary_dialogs.dart';
import 'place_picker.dart';

const List<String> stayTypes = <String>['HOTEL', 'HOSTEL', 'RESORT', 'RENTAL', 'CAMPING', 'FRIENDS_FAMILY', 'OTHER'];
const List<String> transportTypes = <String>['FLIGHT', 'TRAIN', 'BUS', 'FERRY', 'CRUISE', 'CAR', 'TAXI', 'METRO', 'WALK', 'BICYCLE', 'MOTORCYCLE', 'OTHER'];

String typeLabel(String t) => t[0] + t.substring(1).toLowerCase().replaceAll('_', ' / ');

/// A picked place: id plus the name to show.
typedef PlaceChoice = ({int id, String name});

class _TimeButton extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime> onPicked;
  final VoidCallback? onClear;

  const _TimeButton({required this.label, required this.value, required this.onPicked, this.onClear});

  @override
  Widget build(BuildContext context) => Row(
        children: <Widget>[
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.schedule),
              label: Text(value == null ? label : ApiTime.formatDateTime(value!.toUtc())),
              onPressed: () async {
                final DateTime? d = await pickDateTime(context, value ?? DateTime.now());
                if (d != null) onPicked(d);
              },
            ),
          ),
          if (value != null && onClear != null) IconButton(tooltip: 'Clear', icon: const Icon(Icons.clear), onPressed: onClear),
        ],
      );
}

class _PlaceButton extends StatelessWidget {
  final String label;
  final PlaceChoice? value;
  final ValueChanged<PlaceChoice> onPicked;
  final VoidCallback? onClear;

  const _PlaceButton({required this.label, required this.value, required this.onPicked, this.onClear});

  @override
  Widget build(BuildContext context) => Row(
        children: <Widget>[
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.search),
              label: Text(value?.name ?? label, overflow: TextOverflow.ellipsis),
              onPressed: () async {
                final PlaceModel? p = await pickPlace(context);
                if (p != null) onPicked((id: p.id, name: p.name));
              },
            ),
          ),
          if (value != null && onClear != null) IconButton(tooltip: 'Clear', icon: const Icon(Icons.clear), onPressed: onClear),
        ],
      );
}

/// Shared shell: title, scrollable fields, Cancel/Save with an error snackbar and a saving flag.
abstract class _EditorState<T extends ConsumerStatefulWidget> extends ConsumerState<T> {
  bool saving = false;

  String get title;
  bool get canSave;
  List<Widget> fields(BuildContext context);
  Future<void> doSave(TripRepository repo);

  Future<void> save() async {
    setState(() => saving = true);
    try {
      await doSave(ref.read(tripRepositoryProvider));
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(apiErrorMessage(e, 'Could not save. Please try again.'))));
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: SizedBox(width: 400, child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: fields(context))),
        ),
        actions: <Widget>[
          TextButton(onPressed: saving ? null : () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: saving || !canSave ? null : save, child: const Text('Save')),
        ],
      );
}

Widget _gap() => const SizedBox(height: 12);

Widget _typeDropdown(List<String> types, String value, ValueChanged<String> onChanged) => DropdownButtonFormField<String>(
      initialValue: value,
      decoration: const InputDecoration(labelText: 'Type'),
      items: <DropdownMenuItem<String>>[for (final String t in types) DropdownMenuItem<String>(value: t, child: Text(typeLabel(t)))],
      onChanged: (String? v) {
        if (v != null) onChanged(v);
      },
    );

/// Adds a stay or edits [existing]. True when saved.
Future<bool> showStayDialog(BuildContext context, {required int tripId, StayItem? existing}) async =>
    await showDialog<bool>(context: context, builder: (BuildContext c) => _StayDialog(tripId: tripId, existing: existing)) ?? false;

class _StayDialog extends ConsumerStatefulWidget {
  final int tripId;
  final StayItem? existing;

  const _StayDialog({required this.tripId, this.existing});

  @override
  ConsumerState<_StayDialog> createState() => _StayDialogState();
}

class _StayDialogState extends _EditorState<_StayDialog> {
  late final TextEditingController _name = TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _ref = TextEditingController(text: widget.existing?.bookingReference ?? '');
  late final TextEditingController _notes = TextEditingController(text: widget.existing?.notes ?? '');
  late String _type = stayTypes.contains(widget.existing?.type) ? widget.existing!.type! : 'HOTEL';
  late PlaceChoice? _place = widget.existing?.placeId == null ? null : (id: widget.existing!.placeId!, name: widget.existing!.name);
  late DateTime? _checkIn = widget.existing?.checkIn?.toLocal();
  late DateTime? _checkOut = widget.existing?.checkOut?.toLocal();

  @override
  void dispose() {
    _name.dispose();
    _ref.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  String get title => widget.existing == null ? 'Add a stay' : 'Edit stay';

  @override
  bool get canSave => _place != null && _checkIn != null && (_checkOut == null || !_checkOut!.isBefore(_checkIn!));

  @override
  List<Widget> fields(BuildContext context) => <Widget>[
        _typeDropdown(stayTypes, _type, (String v) => setState(() => _type = v)),
        _gap(),
        _PlaceButton(label: 'Choose a place', value: _place, onPicked: (PlaceChoice p) => setState(() => _place = p)),
        _gap(),
        TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name (optional, defaults to the place)')),
        _gap(),
        _TimeButton(label: 'Check-in', value: _checkIn, onPicked: (DateTime d) => setState(() => _checkIn = d)),
        const SizedBox(height: 8),
        _TimeButton(label: 'Check-out (optional)', value: _checkOut, onPicked: (DateTime d) => setState(() => _checkOut = d), onClear: () => setState(() => _checkOut = null)),
        if (_checkIn != null && _checkOut != null && _checkOut!.isBefore(_checkIn!))
          Text('Check-out is before check-in.', style: TextStyle(color: Theme.of(context).colorScheme.error)),
        _gap(),
        TextField(controller: _ref, decoration: const InputDecoration(labelText: 'Booking reference')),
        _gap(),
        TextField(controller: _notes, decoration: const InputDecoration(labelText: 'Notes'), maxLines: 3, minLines: 1),
      ];

  @override
  Future<void> doSave(TripRepository repo) => repo.saveStay(
        widget.tripId,
        id: widget.existing?.id,
        type: _type,
        placeId: _place!.id,
        name: _name.text,
        checkIn: _checkIn!,
        checkOut: _checkOut,
        bookingReference: _ref.text,
        notes: _notes.text,
        metadata: widget.existing?.metadata,
      );
}

/// Adds a transport leg or edits [existing]. True when saved.
Future<bool> showTransportDialog(BuildContext context, {required int tripId, TransportItem? existing}) async =>
    await showDialog<bool>(context: context, builder: (BuildContext c) => _TransportDialog(tripId: tripId, existing: existing)) ?? false;

class _TransportDialog extends ConsumerStatefulWidget {
  final int tripId;
  final TransportItem? existing;

  const _TransportDialog({required this.tripId, this.existing});

  @override
  ConsumerState<_TransportDialog> createState() => _TransportDialogState();
}

class _TransportDialogState extends _EditorState<_TransportDialog> {
  late final TextEditingController _provider = TextEditingController(text: widget.existing?.provider ?? '');
  late final TextEditingController _ref = TextEditingController(text: widget.existing?.referenceNumber ?? '');
  late final TextEditingController _notes = TextEditingController(text: widget.existing?.notes ?? '');
  late String _type = transportTypes.contains(widget.existing?.type) ? widget.existing!.type! : 'FLIGHT';
  late PlaceChoice? _from = widget.existing?.fromPlaceId == null ? null : (id: widget.existing!.fromPlaceId!, name: widget.existing!.from);
  late PlaceChoice? _to = widget.existing?.toPlaceId == null ? null : (id: widget.existing!.toPlaceId!, name: widget.existing!.to);
  late DateTime? _departure = widget.existing?.departure?.toLocal();
  late DateTime? _arrival = widget.existing?.arrival?.toLocal();

  @override
  void dispose() {
    _provider.dispose();
    _ref.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  String get title => widget.existing == null ? 'Add transport' : 'Edit transport';

  @override
  bool get canSave => _departure != null && (_arrival == null || !_arrival!.isBefore(_departure!));

  @override
  List<Widget> fields(BuildContext context) => <Widget>[
        _typeDropdown(transportTypes, _type, (String v) => setState(() => _type = v)),
        _gap(),
        _PlaceButton(label: 'From (optional)', value: _from, onPicked: (PlaceChoice p) => setState(() => _from = p), onClear: () => setState(() => _from = null)),
        const SizedBox(height: 8),
        _PlaceButton(label: 'To (optional)', value: _to, onPicked: (PlaceChoice p) => setState(() => _to = p), onClear: () => setState(() => _to = null)),
        _gap(),
        _TimeButton(label: 'Departure', value: _departure, onPicked: (DateTime d) => setState(() => _departure = d)),
        const SizedBox(height: 8),
        _TimeButton(label: 'Arrival (optional)', value: _arrival, onPicked: (DateTime d) => setState(() => _arrival = d), onClear: () => setState(() => _arrival = null)),
        if (_departure != null && _arrival != null && _arrival!.isBefore(_departure!))
          Text('Arrival is before departure.', style: TextStyle(color: Theme.of(context).colorScheme.error)),
        _gap(),
        TextField(controller: _provider, decoration: const InputDecoration(labelText: 'Provider (airline, operator)')),
        _gap(),
        TextField(controller: _ref, decoration: const InputDecoration(labelText: 'Reference (flight no., PNR)')),
        _gap(),
        TextField(controller: _notes, decoration: const InputDecoration(labelText: 'Notes'), maxLines: 3, minLines: 1),
      ];

  @override
  Future<void> doSave(TripRepository repo) => repo.saveTransport(
        widget.tripId,
        id: widget.existing?.id,
        type: _type,
        fromPlaceId: _from?.id,
        toPlaceId: _to?.id,
        departure: _departure!,
        arrival: _arrival,
        provider: _provider.text,
        referenceNumber: _ref.text,
        notes: _notes.text,
        metadata: widget.existing?.metadata,
      );
}
