import 'package:customer_app/app/repositories.dart';
import 'package:customer_app/features/cms/data/cms_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../helpers/test_app.dart';

/// The in-app CMS page viewer (`03 §2.11` Legal, P7 lookahead on fakes).
void main() {
  late FakeCmsRepository cms;

  setUp(() => cms = FakeCmsRepository());

  TestApp app({bool available = true}) => TestApp(
    tokens: signedInTokens,
    extraOverrides: [
      cmsAvailableProvider.overrideWithValue(available),
      cmsRepositoryProvider.overrideWithValue(cms),
    ],
  );

  Future<void> openAccount(WidgetTester tester, TestApp a) async {
    await a.pump(tester);
    await tester.tap(find.byTooltip('Account'));
    await tester.pumpAndSettle();
  }

  Future<void> openPage(WidgetTester tester, String slug) async {
    final row = find.byKey(Key('legal-$slug'));
    // The Account list (other tabs' lists are offstage in the shell).
    await tester.scrollUntilVisible(
      row,
      100,
      scrollable: find
          .ancestor(
            of: find.byKey(const Key('account-help')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    // Centre it: at the bottom edge the tab bar would take the tap.
    await Scrollable.ensureVisible(tester.element(row), alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();
  }

  testWidgets('terms render safely; only the safe link opens', (tester) async {
    final a = app();
    await openAccount(tester, a);
    await openPage(tester, CmsSlugs.terms);

    expect(cms.requests, [CmsSlugs.terms]);
    expect(find.byKey(const Key('cms-page')), findsOneWidget);
    expect(find.text('Terms of Service'), findsWidgets);
    expect(find.textContaining('alert'), findsNothing);
    expect(find.textContaining('Prices are set by Jivo.'), findsOneWidget);
    expect(find.text('1.'), findsOneWidget);

    // The `javascript:` link is plain text: tapping it opens nothing.
    await tester.scrollUntilVisible(find.textContaining('Do not follow'), 100);
    await tester.tapOnText(find.textRange.ofSubstring('Do not follow'));
    await tester.pumpAndSettle();
    expect(a.urls.opened, isEmpty);

    await tester.tapOnText(find.textRange.ofSubstring('read online'));
    await tester.pumpAndSettle();
    expect(a.urls.opened, [Uri.parse('https://jivo.in/terms')]);
  });

  testWidgets('a policy page the server lacks (404) offers the config/app '
      'policy URL', (tester) async {
    cms.pages.remove(CmsSlugs.privacy);
    final a = app();
    await openAccount(tester, a);
    await openPage(tester, CmsSlugs.privacy);
    expect(find.byKey(const Key('cms-fallback')), findsOneWidget);
    await tester.tap(find.text('Open in browser'));
    await tester.pumpAndSettle();
    expect(a.urls.opened.single.scheme, 'https');
    expect(a.urls.opened.single.path, contains('privacy'));
  });

  testWidgets('About missing (no fallback) or a network error: retry', (
    tester,
  ) async {
    cms.pages.remove(CmsSlugs.about);
    await openAccount(tester, app());
    await openPage(tester, CmsSlugs.about);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.byKey(const Key('cms-fallback')), findsNothing);

    cms.pages[CmsSlugs.about] = const CmsPage(
      slug: CmsSlugs.about,
      title: 'About Jivo',
      html: '<p>Back again</p>',
    );
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Back again'), findsOneWidget);
  });

  testWidgets('real-API build keeps the browser policy links', (tester) async {
    await openAccount(tester, app(available: false));
    expect(find.byKey(const Key('legal-${CmsSlugs.terms}')), findsNothing);
    expect(find.text('Terms of Service'), findsOneWidget);
  });

  test('unknown slug is NOT_FOUND', () async {
    expect(
      FakeCmsRepository().page('nope'),
      throwsA(
        isA<ApiError>().having((e) => e.code, 'code', ApiErrorCode.notFound),
      ),
    );
  });
}
