import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_errors.dart';
import '../../../core/search/search_text.dart';
import '../../../core/widgets/suggest_dialog.dart';
import '../../explore/data/explore_repository.dart';
import '../../explore/domain/category_model.dart';
import '../../explore/domain/place_model.dart';
import '../data/country_repository.dart';
import '../domain/country_model.dart';
import 'add_city_dialog.dart';
import 'country_picker.dart';

/// Adds a place such as a zoo or temple: pick where it is (country, then optionally a region and a city),
/// name it and tag its kinds. Returns the new place, or null if dismissed.
Future<PlaceModel?> addPlace(BuildContext context, {String initialName = ''}) =>
    showDialog<PlaceModel>(context: context, builder: (BuildContext c) => _AddPlaceDialog(initialName: initialName));

class _AddPlaceDialog extends ConsumerStatefulWidget {
  final String initialName;
  const _AddPlaceDialog({required this.initialName});

  @override
  ConsumerState<_AddPlaceDialog> createState() => _AddPlaceDialogState();
}

class _AddPlaceDialogState extends ConsumerState<_AddPlaceDialog> {
  late final TextEditingController _name = TextEditingController(text: widget.initialName);
  final TextEditingController _address = TextEditingController();
  CountryModel? _country;
  PlaceModel? _region;
  PlaceModel? _city;
  final Set<String> _categories = <String>{};
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    super.dispose();
  }

  bool get _valid => _name.text.trim().isNotEmpty && (_country?.isoCode?.isNotEmpty ?? false);

  Future<PlaceModel?> _choose(String title, List<PlaceModel> items, {required String emptyText}) =>
      showSuggestDialog<PlaceModel>(
        context: context,
        title: title,
        hint: 'Search',
        minChars: 0,
        emptyText: emptyText,
        fetch: (String q) async => rankMatches<PlaceModel>(items, q, (PlaceModel p) => p.name),
        titleOf: (PlaceModel p) => p.name,
      );

  Future<void> _pickRegion() async {
    final List<PlaceModel> regions = await ref.read(regionsProvider(_country!.isoCode!).future);
    if (!mounted) return;
    final PlaceModel? r = await _choose('Choose a region', regions, emptyText: 'No regions found.');
    if (r != null && mounted) {
      setState(() {
        _region = r;
        _city = null;
      });
    }
  }

  Future<void> _pickCity() async {
    final List<PlaceModel> cities =
        await ref.read(citiesProvider((countryCode: _country!.isoCode!, regionCode: _region?.isoCode)).future);
    if (!mounted) return;
    final PlaceModel? c = await showSuggestDialog<PlaceModel>(
      context: context,
      title: 'Choose a city',
      hint: 'Search',
      minChars: 0,
      emptyText: _region == null ? 'No cities yet for this country.' : 'No cities in this region yet.',
      fetch: (String q) async => rankMatches<PlaceModel>(cities, q, (PlaceModel p) => p.name),
      titleOf: (PlaceModel p) => p.name,
      actionsBuilder: (BuildContext dialogContext, String query) => <Widget>[
        TextButton.icon(
          onPressed: () async {
            final PlaceModel? added = await addCity(dialogContext, initialName: query);
            if (added != null && dialogContext.mounted) Navigator.pop(dialogContext, added);
          },
          icon: const Icon(Icons.add_location_alt_outlined),
          label: const Text('Add a city'),
        ),
      ],
    );
    if (c != null && mounted) setState(() => _city = c);
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ExploreRepository repo = ref.read(exploreRepositoryProvider);
      // The closest level chosen is the parent: city, else country (+ region).
      final PlaceModel place = await repo.createPlace(
        name: _name.text,
        parentPlaceId: _city?.id,
        countryCode: _city == null ? _country!.isoCode : null,
        regionCode: _city == null ? _region?.isoCode : null,
        address: _address.text,
        categories: _categories.toList(growable: false),
      );
      if (mounted) Navigator.pop(context, place);
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = apiErrorMessage(e, 'Could not add the place. Please try again.');
        });
      }
    }
  }

  Widget _pickerButton({required IconData icon, required String label, required String? value, required VoidCallback? onTap, VoidCallback? onClear}) =>
      Row(children: <Widget>[
        Expanded(
          child: OutlinedButton.icon(
            icon: Icon(icon),
            label: Align(alignment: Alignment.centerLeft, child: Text(value ?? label, overflow: TextOverflow.ellipsis)),
            onPressed: onTap,
          ),
        ),
        if (value != null && onClear != null) IconButton(tooltip: 'Clear', icon: const Icon(Icons.clear), onPressed: onClear),
      ]);

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<CategoryModel>> categories = ref.watch(categoriesProvider);
    return AlertDialog(
      title: const Text('Add a place'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextField(
                controller: _name,
                autofocus: widget.initialName.isEmpty,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Place name', prefixIcon: Icon(Icons.place_outlined)),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              CountryPicker(
                label: 'Country',
                selectedId: _country?.id,
                onSelected: (CountryModel c) => setState(() {
                  if (_country?.id != c.id) {
                    _region = null;
                    _city = null;
                  }
                  _country = c;
                }),
              ),
              if (_country != null) ...<Widget>[
                const SizedBox(height: 8),
                _pickerButton(
                  icon: Icons.map_outlined,
                  label: 'Region or state (optional)',
                  value: _region?.name,
                  onTap: _pickRegion,
                  onClear: () => setState(() {
                    _region = null;
                    _city = null;
                  }),
                ),
                const SizedBox(height: 8),
                _pickerButton(
                  icon: Icons.location_city_rounded,
                  label: 'City (optional)',
                  value: _city?.name,
                  onTap: _pickCity,
                  onClear: () => setState(() => _city = null),
                ),
              ],
              const SizedBox(height: 12),
              TextField(controller: _address, decoration: const InputDecoration(labelText: 'Address (optional)')),
              const SizedBox(height: 16),
              Text('What kind of place is it?', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              categories.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (Object e, StackTrace _) => TextButton(onPressed: () => ref.invalidate(categoriesProvider), child: const Text('Could not load types. Retry')),
                data: (List<CategoryModel> list) => Wrap(
                  spacing: 8,
                  runSpacing: 0,
                  children: <Widget>[
                    for (final CategoryModel c in list)
                      FilterChip(
                        label: Text(c.name),
                        selected: _categories.contains(c.name),
                        onSelected: (bool on) => setState(() => on ? _categories.add(c.name) : _categories.remove(c.name)),
                      ),
                  ],
                ),
              ),
              if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error))),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _busy || !_valid ? null : _save, child: Text(_busy ? 'Adding...' : 'Add place')),
      ],
    );
  }
}
