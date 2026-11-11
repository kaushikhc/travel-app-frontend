import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/country_repository.dart';
import '../domain/country_model.dart';

/// Searchable country dropdown backed by `GET /api/places/countries`.
class CountryPicker extends ConsumerWidget {
  final int? selectedId;
  final ValueChanged<CountryModel> onSelected;
  final String label;

  const CountryPicker({super.key, required this.selectedId, required this.onSelected, this.label = 'Home country'});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<CountryModel>> countries = ref.watch(countriesProvider);
    return countries.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(12),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (Object error, StackTrace _) => TextButton.icon(
        onPressed: () => ref.invalidate(countriesProvider),
        icon: const Icon(Icons.refresh),
        label: const Text('Could not load countries. Tap to retry.'),
      ),
      data: (List<CountryModel> list) => LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) => DropdownMenu<int>(
          width: constraints.maxWidth,
          initialSelection: selectedId,
          enableFilter: true,
          requestFocusOnTap: true,
          menuHeight: 320,
          label: Text(label),
          leadingIcon: const Icon(Icons.public_rounded),
          dropdownMenuEntries: <DropdownMenuEntry<int>>[
            for (final CountryModel c in list)
              DropdownMenuEntry<int>(value: c.id, label: c.flag.isEmpty ? c.name : '${c.flag}  ${c.name}'),
          ],
          onSelected: (int? id) {
            if (id == null) return;
            onSelected(list.firstWhere((CountryModel c) => c.id == id));
          },
        ),
      ),
    );
  }
}

/// The name of a country id, or null while loading or if unknown.
String? countryName(WidgetRef ref, int? id) {
  if (id == null) return null;
  final List<CountryModel>? list = ref.watch(countriesProvider).value;
  for (final CountryModel c in list ?? const <CountryModel>[]) {
    if (c.id == id) return c.flag.isEmpty ? c.name : '${c.flag} ${c.name}';
  }
  return null;
}
