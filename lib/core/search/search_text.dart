/// Shared matching rules for every search and picker field, mirroring the backend's `SearchText`:
/// case, accents and punctuation are ignored ("sao paulo" finds "São Paulo").
library;

/// Suggestions start after this many characters (the backend rejects shorter queries too).
const int minSearchLength = 2;

/// How long typing must pause before a suggestion search runs.
const Duration searchDebounce = Duration(milliseconds: 300);

const Map<String, String> _folds = <String, String>{
  'ø': 'o',
  'Ø': 'o',
  'ł': 'l',
  'Ł': 'l',
  'đ': 'd',
  'Đ': 'd',
  'ß': 'ss',
  'æ': 'ae',
  'Æ': 'ae',
  'œ': 'oe',
  'Œ': 'oe',
  'þ': 'th',
  'Þ': 'th',
  'ı': 'i',
  'à': 'a',
  'á': 'a',
  'â': 'a',
  'ã': 'a',
  'ä': 'a',
  'å': 'a',
  'ā': 'a',
  'ă': 'a',
  'ą': 'a',
  'ç': 'c',
  'ć': 'c',
  'č': 'c',
  'ď': 'd',
  'è': 'e',
  'é': 'e',
  'ê': 'e',
  'ë': 'e',
  'ē': 'e',
  'ė': 'e',
  'ę': 'e',
  'ě': 'e',
  'ğ': 'g',
  'ì': 'i',
  'í': 'i',
  'î': 'i',
  'ï': 'i',
  'ī': 'i',
  'į': 'i',
  'ñ': 'n',
  'ń': 'n',
  'ň': 'n',
  'ò': 'o',
  'ó': 'o',
  'ô': 'o',
  'õ': 'o',
  'ö': 'o',
  'ō': 'o',
  'ő': 'o',
  'ř': 'r',
  'ś': 's',
  'š': 's',
  'ş': 's',
  'ș': 's',
  'ť': 't',
  'ţ': 't',
  'ț': 't',
  'ù': 'u',
  'ú': 'u',
  'û': 'u',
  'ü': 'u',
  'ū': 'u',
  'ů': 'u',
  'ű': 'u',
  'ų': 'u',
  'ý': 'y',
  'ÿ': 'y',
  'ź': 'z',
  'ż': 'z',
  'ž': 'z',
};

final RegExp _separators = RegExp(r'[^\p{L}\p{N}]+', unicode: true);

/// Lower case, accents removed, apostrophes dropped, other punctuation and runs of spaces become one space.
String normalizeSearch(String text) {
  final StringBuffer out = StringBuffer();
  for (final int rune in text.toLowerCase().runes) {
    final String ch = String.fromCharCode(rune);
    if (ch == "'" || ch == '’') continue;
    out.write(_folds[ch] ?? ch);
  }
  return out.toString().replaceAll(_separators, ' ').trim();
}

/// 0 exact, 1 starts with, 2 a word starts with, 3 contains, null no match. Both arguments are normalized.
int? _matchRank(String text, String query) {
  if (text == query) return 0;
  if (text.startsWith(query)) return 1;
  if (text.contains(' $query')) return 2;
  if (text.contains(query)) return 3;
  return null;
}

/// The items whose [textOf] matches [query], best first (exact, prefix, word prefix, contains; shorter
/// names first, then A to Z). A blank query keeps everything in its original order. Same ranking the
/// backend uses, for lists that are already loaded (countries, trips, tags, a trip's places).
List<T> rankMatches<T>(
  Iterable<T> items,
  String query,
  String Function(T) textOf, {
  int? limit,
}) {
  final String q = normalizeSearch(query);
  if (q.isEmpty) {
    return limit == null ? items.toList(growable: false) : items.take(limit).toList(growable: false);
  }
  final List<({T item, int rank, String text})> hits =
      <({T item, int rank, String text})>[];
  for (final T item in items) {
    final String text = normalizeSearch(textOf(item));
    final int? rank = _matchRank(text, q);
    if (rank != null) hits.add((item: item, rank: rank, text: text));
  }
  hits.sort((a, b) {
    final int byRank = a.rank.compareTo(b.rank);
    if (byRank != 0) return byRank;
    final int byLength = a.text.length.compareTo(b.text.length);
    return byLength != 0 ? byLength : a.text.compareTo(b.text);
  });
  final Iterable<T> ranked = hits.map((h) => h.item);
  return (limit == null ? ranked : ranked.take(limit)).toList(growable: false);
}
