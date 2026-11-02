import 'package:customer_app/features/search/data/recent_searches_store.dart';
import 'package:customer_app/features/search/presentation/search_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_app.dart';

Future<TestApp> openSearch(WidgetTester tester) async {
  final app = TestApp(tokens: signedInTokens);
  await app.pump(tester);
  await tester.tap(find.byKey(const Key('home-search')));
  await tester.pumpAndSettle();
  return app;
}

Iterable<String> typed(TestApp app) =>
    app.catalog.calls.where((c) => c.startsWith('suggest:') && c != 'suggest:');

Future<void> submit(WidgetTester tester, String query) async {
  await tester.enterText(find.byKey(const Key('search-field')), query);
  await tester.testTextInput.receiveAction(TextInputAction.search);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('suggestions wait for 300 ms of quiet typing', (tester) async {
    final app = await openSearch(tester);
    final field = find.byKey(const Key('search-field'));

    await tester.enterText(field, 'o');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(field, 'ol');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(field, 'oli');
    await tester.pump(kSearchDebounce - const Duration(milliseconds: 1));
    expect(typed(app), isEmpty);

    await tester.pump(const Duration(milliseconds: 1));
    expect(typed(app), ['suggest:oli']);
    await tester.pumpAndSettle();
    expect(find.text('Jivo Extra Light Olive Oil'), findsOneWidget);
    expect(find.text('Olive Oil'), findsNothing); // a sub-category
  });

  testWidgets('trending searches come from a blank suggest', (tester) async {
    final app = await openSearch(tester);
    expect(app.catalog.calls, contains('suggest:'));
    expect(find.text('Trending'), findsOneWidget);
    await tester.tap(find.text('olive oil'));
    await tester.pumpAndSettle();
    expect(app.catalog.calls, contains('search:olive oil:1'));
    expect(find.text('Jivo Pomace Olive Oil'), findsOneWidget);
  });

  testWidgets('submitted searches are remembered locally and clearable', (
    tester,
  ) async {
    await openSearch(tester);
    await submit(tester, 'ghee');
    expect(find.text('Jivo Desi Ghee'), findsOneWidget);
    await submit(tester, 'olive');

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList(RecentSearchesStore.key), ['olive', 'ghee']);

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    expect(find.text('Recent searches'), findsOneWidget);
    expect(find.widgetWithText(ActionChip, 'ghee'), findsOneWidget);

    await tester.tap(find.byKey(const Key('clear-recent')));
    await tester.pumpAndSettle();
    expect(find.text('Recent searches'), findsNothing);
    expect(prefs.getStringList(RecentSearchesStore.key), isNull);
  });

  testWidgets('no results shows trending suggestions', (tester) async {
    await openSearch(tester);
    await submit(tester, 'xyz');
    expect(find.text('No results for "xyz"'), findsOneWidget);
    expect(find.text('Try one of these:'), findsOneWidget);
  });

  test('recent searches: newest first, no duplicates, at most 10', () async {
    SharedPreferences.setMockInitialValues({});
    final store = RecentSearchesStore(await SharedPreferences.getInstance());
    await store.add('Ghee');
    await store.add('  ');
    await store.add('oil');
    expect(await store.add('ghee'), ['ghee', 'oil']);
    for (var i = 0; i < 12; i++) {
      await store.add('q$i');
    }
    expect(store.read(), hasLength(RecentSearchesStore.limit));
    expect(store.read().first, 'q11');
    await store.clear();
    expect(store.read(), isEmpty);
  });
}
