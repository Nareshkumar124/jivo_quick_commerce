import 'package:customer_app/app/repositories.dart';
import 'package:customer_app/features/cms/data/cms_repository.dart';
import 'package:customer_app/features/launch/domain/launch_config.dart';
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
    // Below the fold since the Refer & earn row (2026-11-13).
    await tester.scrollUntilVisible(
      find.text('Terms of Service'),
      100,
      scrollable: find
          .ancestor(
            of: find.byKey(const Key('account-help')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.byKey(const Key('legal-${CmsSlugs.terms}')), findsNothing);
    expect(find.text('Terms of Service'), findsOneWidget);
  });

  testWidgets('Account lists every launch policy page in the app', (
    tester,
  ) async {
    await openAccount(tester, app());
    for (final slug in [
      CmsSlugs.terms,
      CmsSlugs.privacy,
      CmsSlugs.refund,
      CmsSlugs.deliveryPolicy,
      CmsSlugs.contact,
      CmsSlugs.deleteAccount,
    ]) {
      expect(find.byKey(Key('legal-$slug')), findsOneWidget, reason: slug);
    }
    await openPage(tester, CmsSlugs.deliveryPolicy);
    expect(cms.requests, [CmsSlugs.deliveryPolicy]);
    expect(find.text('Delivery Policy'), findsWidgets);
  });

  testWidgets('a launch page the server lacks offers its /legal/ URL', (
    tester,
  ) async {
    cms.pages.remove(CmsSlugs.contact);
    final a = app();
    a.config.config = LaunchConfig(
      maintenance: false,
      termsVersion: '2026-11-28',
      policies: PolicyLinks(
        terms: Uri.parse('https://quick.jivo.in/legal/terms/'),
        privacy: Uri.parse('https://quick.jivo.in/legal/privacy/'),
        refund: Uri.parse('https://quick.jivo.in/legal/refund-policy/'),
      ),
    );
    await openAccount(tester, a);
    await openPage(tester, CmsSlugs.contact);
    expect(find.byKey(const Key('cms-fallback')), findsOneWidget);
    await tester.tap(find.text('Open in browser'));
    await tester.pumpAndSettle();
    expect(a.urls.opened, [Uri.parse('https://quick.jivo.in/legal/contact/')]);
  });

  testWidgets('delete-account screen links the deletion policy page', (
    tester,
  ) async {
    // Tall enough for the whole Account list: no scrolling needed.
    tester.view.physicalSize = const Size(800, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await openAccount(tester, app());
    final row = find.text('Delete account');
    await Scrollable.ensureVisible(tester.element(row), alignment: 0.5);
    await tester.pumpAndSettle();
    await tester.tap(row);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('delete-account-policy')));
    await tester.pumpAndSettle();
    expect(cms.requests, [CmsSlugs.deleteAccount]);
    expect(find.byKey(const Key('cms-page')), findsOneWidget);
  });

  group('PolicyLinks.forSlug', () {
    final legal = PolicyLinks(
      terms: Uri.parse('https://quick.jivo.in/legal/terms/'),
      privacy: Uri.parse('https://quick.jivo.in/legal/privacy/'),
      refund: Uri.parse('https://quick.jivo.in/legal/refund-policy/'),
    );

    test('config URLs for terms, privacy and refund', () {
      expect(legal.forSlug(CmsSlugs.terms), legal.terms);
      expect(legal.forSlug(CmsSlugs.privacy), legal.privacy);
      expect(legal.forSlug(CmsSlugs.refund), legal.refund);
    });

    test('siblings of a /legal/ terms URL for the other pages', () {
      expect(
        legal.forSlug(CmsSlugs.deliveryPolicy),
        Uri.parse('https://quick.jivo.in/legal/delivery-policy/'),
      );
      expect(
        legal.forSlug(CmsSlugs.deleteAccount),
        Uri.parse('https://quick.jivo.in/legal/delete-account/'),
      );
      expect(legal.forSlug('../x'), isNull);
    });

    test('no sibling when the terms URL is not a /legal/ page', () {
      final other = PolicyLinks(
        terms: Uri.parse('https://jivo.in/terms'),
        privacy: Uri.parse('https://jivo.in/privacy'),
        refund: Uri.parse('https://jivo.in/refund'),
      );
      expect(other.forSlug(CmsSlugs.contact), isNull);
      expect(other.forSlug(CmsSlugs.terms), other.terms);
    });
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
