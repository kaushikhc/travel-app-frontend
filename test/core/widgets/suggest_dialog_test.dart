import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_app_frontend/core/widgets/suggest_dialog.dart';

void main() {
  testWidgets(
    'suggests after 2 characters, debounced, and returns the tapped item',
    (WidgetTester tester) async {
      final List<String> calls = <String>[];
      String? picked;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (BuildContext context) => TextButton(
              onPressed: () async => picked = await showSuggestDialog<String>(
                context: context,
                title: 'Pick',
                hint: 'Search',
                fetch: (String q) async {
                  calls.add(q);
                  return <String>['$q one', '$q two'];
                },
                titleOf: (String s) => s,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(find.textContaining('at least 2'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'p');
      await tester.pump(const Duration(seconds: 1));
      expect(calls, isEmpty);

      await tester.enterText(find.byType(TextField), 'pa');
      await tester.enterText(find.byType(TextField), 'par');
      await tester.pump(const Duration(milliseconds: 100));
      expect(calls, isEmpty);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(calls, <String>['par']);

      await tester.tap(find.text('par two'));
      await tester.pumpAndSettle();
      expect(picked, 'par two');
    },
  );

  testWidgets('shows an empty message when nothing matches', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (BuildContext context) => TextButton(
            onPressed: () => showSuggestDialog<String>(
              context: context,
              title: 'Pick',
              hint: 'Search',
              emptyText: 'No places found.',
              fetch: (String q) async => <String>[],
              titleOf: (String s) => s,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'zz');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text('No places found.'), findsOneWidget);
  });
}
