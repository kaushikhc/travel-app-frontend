import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../explore/data/explore_repository.dart';
import '../../../explore/domain/place_model.dart';
import '../../../explore/presentation/explore_view.dart' show minSearchLength;
import '../../../places/presentation/add_city_dialog.dart';

/// Shows a search dialog and returns the chosen place, or null if dismissed. The backend searches
/// names from 2 characters.
Future<PlaceModel?> pickPlace(BuildContext context) => showDialog<PlaceModel>(context: context, builder: (BuildContext c) => const _PlacePicker());

class _PlacePicker extends ConsumerStatefulWidget {
  const _PlacePicker();

  @override
  ConsumerState<_PlacePicker> createState() => _PlacePickerState();
}

class _PlacePickerState extends ConsumerState<_PlacePicker> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<PlaceModel>> results =
        _query.length >= minSearchLength ? ref.watch(placeSearchProvider(_query)) : const AsyncData<List<PlaceModel>>(<PlaceModel>[]);
    return AlertDialog(
      title: const Text('Choose a place'),
      content: SizedBox(
        width: 400,
        height: 360,
        child: Column(
          children: <Widget>[
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search places (2+ letters)'),
              textInputAction: TextInputAction.search,
              onSubmitted: (String v) => setState(() => _query = v.trim()),
              onChanged: (String v) {
                if (v.trim().length < minSearchLength) setState(() => _query = '');
              },
            ),
            const SizedBox(height: 8),
            Expanded(
              child: results.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (Object e, StackTrace _) => const Center(child: Text('Search failed. Please try again.')),
                data: (List<PlaceModel> list) => _query.length < minSearchLength
                    ? const Center(child: Text('Type a name and press search.'))
                    : list.isEmpty
                        ? const Center(child: Text('No places found.'))
                        : ListView(
                            children: <Widget>[
                              for (final PlaceModel p in list)
                                ListTile(
                                  dense: true,
                                  title: Text(p.name),
                                  subtitle: p.type == null ? null : Text(p.type!),
                                  onTap: () => Navigator.pop(context, p),
                                ),
                            ],
                          ),
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton.icon(
          onPressed: () async {
            final PlaceModel? city = await addCity(context, initialName: _query);
            if (city != null && context.mounted) Navigator.pop(context, city);
          },
          icon: const Icon(Icons.add_location_alt_outlined),
          label: const Text('Add a city'),
        ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
      ],
    );
  }
}
