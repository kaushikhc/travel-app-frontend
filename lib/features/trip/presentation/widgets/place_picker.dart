import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/suggest_dialog.dart';
import '../../../explore/data/explore_repository.dart';
import '../../../explore/domain/place_model.dart';
import '../../../places/presentation/add_city_dialog.dart';
import '../../../places/presentation/add_place_dialog.dart';

/// Type-ahead place search (2+ characters, debounced). The backend ignores case, accents and punctuation
/// and returns the best matches first. Returns the chosen place, or null if dismissed.
Future<PlaceModel?> pickPlace(BuildContext context) {
  final ExploreRepository repo = ProviderScope.containerOf(
    context,
  ).read(exploreRepositoryProvider);
  return showSuggestDialog<PlaceModel>(
    context: context,
    title: 'Choose a place',
    hint: 'Search places (2+ letters)',
    emptyText: 'No places found.',
    fetch: repo.searchPlaces,
    titleOf: (PlaceModel p) => p.name,
    subtitleOf: (PlaceModel p) => p.subtitle,
    actionsBuilder: (BuildContext dialogContext, String query) => <Widget>[
      TextButton.icon(
        onPressed: () async {
          final PlaceModel? place = await addPlace(dialogContext, initialName: query);
          if (place != null && dialogContext.mounted) {
            Navigator.pop(dialogContext, place);
          }
        },
        icon: const Icon(Icons.add_location_outlined),
        label: const Text('Add a place'),
      ),
      TextButton.icon(
        onPressed: () async {
          final PlaceModel? city = await addCity(
            dialogContext,
            initialName: query,
          );
          if (city != null && dialogContext.mounted) {
            Navigator.pop(dialogContext, city);
          }
        },
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Add a city'),
      ),
    ],
  );
}
