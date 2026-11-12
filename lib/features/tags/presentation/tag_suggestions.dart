import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/search/search_text.dart';
import '../data/tag_repository.dart';

/// Chips under a comma-separated tag field: once the tag being typed has 2+ characters, the traveler's
/// existing tags that match it (ignoring case and accents, best match first) are offered. Tapping one
/// replaces the half-typed tag. Shows nothing when there is no match or the tags cannot be loaded.
class TagSuggestions extends ConsumerWidget {
  final TextEditingController controller;
  final int limit;

  const TagSuggestions({super.key, required this.controller, this.limit = 6});

  /// The suggestions for [text]: tags matching its last comma-separated part, minus those already entered.
  static List<String> suggest(
    String text,
    List<String> known, {
    int limit = 6,
  }) {
    final int cut = text.lastIndexOf(',');
    final String typing = text.substring(cut + 1).trim();
    if (typing.length < minSearchLength) return const <String>[];
    final Set<String> entered = <String>{
      for (final String t in text.substring(0, cut < 0 ? 0 : cut).split(','))
        normalizeSearch(t),
    };
    final List<String> fresh = <String>[
      for (final String t in known)
        if (!entered.contains(normalizeSearch(t)) &&
            normalizeSearch(t) != normalizeSearch(typing))
          t,
    ];
    return rankMatches<String>(fresh, typing, (String t) => t, limit: limit);
  }

  /// [text] with its last comma-separated part replaced by [tag].
  static String complete(String text, String tag) {
    final int cut = text.lastIndexOf(',');
    final String head = cut < 0
        ? ''
        : '${text.substring(0, cut + 1).trimRight()} ';
    return '$head$tag, ';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<String> known =
        ref.watch(myTagsProvider).value ?? const <String>[];
    if (known.isEmpty) return const SizedBox.shrink();
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (BuildContext context, TextEditingValue value, Widget? _) {
        final List<String> tags = suggest(value.text, known, limit: limit);
        if (tags.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: <Widget>[
                for (final String t in tags)
                  ActionChip(
                    label: Text(t),
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      final String next = complete(controller.text, t);
                      controller.value = TextEditingValue(
                        text: next,
                        selection: TextSelection.collapsed(offset: next.length),
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
