import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/jivo_core.dart';
import 'package:rider_app/app/theme.dart';
import 'package:rider_app/l10n/app_localizations.dart';
import 'package:rider_app/shared/paged_list_controller.dart';
import 'package:rider_app/shared/widgets/error_line.dart';
import 'package:rider_app/shared/widgets/paged_list_view.dart';

import '../../helpers/semantics_helpers.dart';

/// UX audit RA-18: skeleton rows, an empty state with an icon and an
/// optional action, and a load-more error that is read out.
void main() {
  Future<void> pump(
    WidgetTester tester,
    PagedListState<String, void> state, {
    Widget? emptyAction,
  }) => tester.pumpWidget(
    MaterialApp(
      theme: buildRiderTheme(),
      localizationsDelegates: const [
        ...AppLocalizations.localizationsDelegates,
        JivoCoreLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: PagedListView<String, void>(
          state: state,
          itemBuilder: (context, item) => Text(item),
          onRefresh: () async {},
          onLoadMore: () async {},
          emptyText: 'Nothing here yet.',
          emptyIcon: Icons.history,
          emptyAction: emptyAction,
        ),
      ),
    ),
  );

  testWidgets('first load: three skeleton rows, no spinner', (tester) async {
    await pump(tester, const PagedListState(loading: true));

    expect(find.byKey(const Key('paged-loading')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.bySemanticsLabel('Loading'), findsOneWidget);
  });

  testWidgets('empty: a 48 dp icon, the text and the action', (tester) async {
    await pump(
      tester,
      const PagedListState(loaded: true),
      emptyAction: FilledButton(
        key: const Key('empty-action'),
        onPressed: () {},
        child: const Text('Raise a ticket'),
      ),
    );

    expect(find.text('Nothing here yet.'), findsOneWidget);
    final icon = tester.widget<Icon>(find.byKey(const Key('paged-empty-icon')));
    expect(icon.icon, Icons.history);
    expect(icon.size, 48);
    expect(find.byKey(const Key('empty-action')), findsOneWidget);
  });

  testWidgets('empty without an action shows no button', (tester) async {
    await pump(tester, const PagedListState(loaded: true));
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('a failed "Load more" is an error line in a live region', (
    tester,
  ) async {
    await pump(
      tester,
      const PagedListState(
        items: ['row 1'],
        loaded: true,
        nextPage: 2,
        error: ApiError(code: ApiErrorCode.network),
      ),
    );

    final error = find.byKey(const Key('paged-error'));
    expect(error, findsOneWidget);
    expect(
      find.ancestor(of: error, matching: find.byType(ErrorLine)),
      findsOneWidget,
    );
    expect(isInLiveRegion(tester, error), isTrue);
    expect(find.text('row 1'), findsOneWidget);
  });
}
