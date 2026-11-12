import 'package:flutter_test/flutter_test.dart';
import 'package:travel_app_frontend/core/search/search_text.dart';
import 'package:travel_app_frontend/features/tags/presentation/tag_suggestions.dart';

void main() {
  test('normalizeSearch ignores case, accents and punctuation', () {
    expect(normalizeSearch('São Paulo'), 'sao paulo');
    expect(normalizeSearch('  SAO-PAULO '), 'sao paulo');
    expect(normalizeSearch('St. Petersburg'), 'st petersburg');
    expect(normalizeSearch("Côte d'Ivoire"), 'cote divoire');
    expect(normalizeSearch('Łódź'), 'lodz');
    expect(normalizeSearch('🇫🇷  France'), 'france');
  });

  test(
    'rankMatches puts exact, prefix, word prefix and contains in that order',
    () {
      final List<String> names = <String>[
        'Grand Louvre Hotel',
        'Louvre Museum',
        'Musée du Louvre',
        'Louvre',
        'Cafe',
      ];
      expect(rankMatches<String>(names, 'LOUVRE', (String n) => n), <String>[
        'Louvre',
        'Louvre Museum',
        'Musée du Louvre',
        'Grand Louvre Hotel',
      ]);
      expect(rankMatches<String>(names, 'musee', (String n) => n), <String>[
        'Musée du Louvre',
      ]);
      expect(rankMatches<String>(names, 'zzz', (String n) => n), isEmpty);
      expect(rankMatches<String>(names, ' ', (String n) => n), names);
      expect(
        rankMatches<String>(names, 'lou', (String n) => n, limit: 2),
        hasLength(2),
      );
    },
  );

  test(
    'tag suggestions match the tag being typed and skip tags already entered',
    () {
      const List<String> known = <String>['beach', 'Beach Bar', 'food', 'Café'];
      expect(TagSuggestions.suggest('be', known), <String>[
        'beach',
        'Beach Bar',
      ]);
      expect(TagSuggestions.suggest('food, be', known), <String>[
        'beach',
        'Beach Bar',
      ]);
      expect(TagSuggestions.suggest('beach, be', known), <String>['Beach Bar']);
      expect(TagSuggestions.suggest('b', known), isEmpty);
      expect(
        TagSuggestions.suggest('cafe', known),
        isEmpty,
      ); // already exactly typed
      expect(TagSuggestions.complete('food, be', 'beach'), 'food, beach, ');
      expect(TagSuggestions.complete('be', 'beach'), 'beach, ');
    },
  );
}
