import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../explore/data/explore_repository.dart';
import '../../explore/domain/place_model.dart';
import '../domain/country_model.dart';
import 'country_picker.dart';

/// Asks for a city name and its country, adds the city and returns it (null if dismissed).
/// Major cities are already seeded, so this is for the ones that are missing.
Future<PlaceModel?> addCity(BuildContext context, {String initialName = ''}) =>
    showDialog<PlaceModel>(context: context, builder: (BuildContext c) => _AddCityDialog(initialName: initialName));

class _AddCityDialog extends ConsumerStatefulWidget {
  final String initialName;
  const _AddCityDialog({required this.initialName});

  @override
  ConsumerState<_AddCityDialog> createState() => _AddCityDialogState();
}

class _AddCityDialogState extends ConsumerState<_AddCityDialog> {
  late final TextEditingController _name = TextEditingController(text: widget.initialName);
  CountryModel? _country;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _valid => _name.text.trim().isNotEmpty && (_country?.isoCode?.isNotEmpty ?? false);

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final PlaceModel city = await ref.read(exploreRepositoryProvider).createCity(name: _name.text, countryCode: _country!.isoCode!);
      if (mounted) Navigator.pop(context, city);
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Could not add the city. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add a city'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'City name', prefixIcon: Icon(Icons.location_city_rounded)),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            CountryPicker(label: 'Country', selectedId: _country?.id, onSelected: (CountryModel c) => setState(() => _country = c)),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _busy || !_valid ? null : _save, child: Text(_busy ? 'Adding...' : 'Add city')),
      ],
    );
  }
}
