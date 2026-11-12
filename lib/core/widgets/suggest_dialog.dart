import 'dart:async';
import 'package:flutter/material.dart';
import '../search/search_text.dart';

/// A type-ahead picker used by every search field: suggestions load as the traveler types, after
/// [minChars] characters and a short pause, and a slow earlier answer never overwrites a newer one.
/// Returns the chosen item, or null if dismissed.
///
/// [fetch] receives the trimmed query. For remote search pass a call to the backend; for a list that is
/// already loaded pass `(q) async => rankMatches(items, q, (i) => i.name)` with `minChars: 0`.
Future<T?> showSuggestDialog<T>({
  required BuildContext context,
  required String title,
  required String hint,
  required Future<List<T>> Function(String query) fetch,
  required String Function(T) titleOf,
  String? Function(T)? subtitleOf,
  int minChars = minSearchLength,
  Duration debounce = searchDebounce,
  String initialQuery = '',
  String emptyText = 'Nothing found.',
  List<Widget> Function(BuildContext dialogContext, String query)?
  actionsBuilder,
}) => showDialog<T>(
  context: context,
  builder: (BuildContext c) => SuggestDialog<T>(
    title: title,
    hint: hint,
    fetch: fetch,
    titleOf: titleOf,
    subtitleOf: subtitleOf,
    minChars: minChars,
    debounce: debounce,
    initialQuery: initialQuery,
    emptyText: emptyText,
    actionsBuilder: actionsBuilder,
  ),
);

class SuggestDialog<T> extends StatefulWidget {
  final String title;
  final String hint;
  final Future<List<T>> Function(String query) fetch;
  final String Function(T) titleOf;
  final String? Function(T)? subtitleOf;
  final int minChars;
  final Duration debounce;
  final String initialQuery;
  final String emptyText;
  final List<Widget> Function(BuildContext dialogContext, String query)?
  actionsBuilder;

  const SuggestDialog({
    super.key,
    required this.title,
    required this.hint,
    required this.fetch,
    required this.titleOf,
    this.subtitleOf,
    this.minChars = minSearchLength,
    this.debounce = searchDebounce,
    this.initialQuery = '',
    this.emptyText = 'Nothing found.',
    this.actionsBuilder,
  });

  @override
  State<SuggestDialog<T>> createState() => _SuggestDialogState<T>();
}

class _SuggestDialogState<T> extends State<SuggestDialog<T>> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialQuery,
  );
  Timer? _timer;
  int _generation = 0;
  String _query = '';
  bool _loading = false;
  bool _failed = false;
  List<T> _results = <T>[];

  @override
  void initState() {
    super.initState();
    _query = widget.initialQuery.trim();
    if (_query.length >= widget.minChars) _run(_query);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _timer?.cancel();
    final String q = value.trim();
    setState(() => _query = q);
    if (q.length < widget.minChars) {
      _generation++;
      setState(() {
        _results = <T>[];
        _loading = false;
        _failed = false;
      });
      return;
    }
    _timer = Timer(widget.debounce, () => _run(q));
  }

  Future<void> _run(String q) async {
    final int mine = ++_generation;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final List<T> found = await widget.fetch(q);
      if (!mounted || mine != _generation) return;
      setState(() {
        _results = found;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || mine != _generation) return;
      setState(() {
        _results = <T>[];
        _loading = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool tooShort = _query.length < widget.minChars;
    Widget body;
    if (tooShort) {
      body = Center(
        child: Text(
          'Type at least ${widget.minChars} letters to see suggestions.',
        ),
      );
    } else if (_failed) {
      body = const Center(child: Text('Search failed. Please try again.'));
    } else if (_loading && _results.isEmpty) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_results.isEmpty) {
      body = Center(child: Text(widget.emptyText));
    } else {
      body = ListView(
        children: <Widget>[
          for (final T item in _results)
            ListTile(
              dense: true,
              title: Text(widget.titleOf(item)),
              subtitle: _subtitle(item),
              onTap: () => Navigator.pop(context, item),
            ),
        ],
      );
    }
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 400,
        height: 360,
        child: Column(
          children: <Widget>[
            TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: widget.hint,
                suffixIcon: _loading
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
              ),
              onChanged: _onChanged,
              onSubmitted: (String v) {
                _timer?.cancel();
                final String q = v.trim();
                if (q.length >= widget.minChars) _run(q);
              },
            ),
            const SizedBox(height: 8),
            Expanded(child: body),
          ],
        ),
      ),
      actions: <Widget>[
        ...?widget.actionsBuilder?.call(context, _query),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Widget? _subtitle(T item) {
    final String? s = widget.subtitleOf?.call(item);
    return s == null || s.isEmpty ? null : Text(s);
  }
}
