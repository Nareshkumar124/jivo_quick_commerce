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
    await tester.scrollUntilVisible(row, 100);
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

  testWidgets('a missing page shows the error with retry', (tester) async {
    cms.pages.remove(CmsSlugs.privacy);
    await openAccount(tester, app());
    await openPage(tester, CmsSlugs.privacy);
    expect(find.text('Retry'), findsOneWidget);
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
