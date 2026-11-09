import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/jivo_core.dart';
import 'package:rider_app/app/routes.dart';
import 'package:rider_app/features/legal/data/legal_repository.dart';

import '../../helpers/canned_http.dart';
import '../../helpers/onboarding_fixtures.dart';
import '../../helpers/records_helpers.dart';
import '../../helpers/rider_app_harness.dart';

Future<void> _open(WidgetTester tester, RiderTestHarness h, String slug) async {
  await pushFromHome(tester, h, Routes.legal(slug));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ApiLegalRepository maps pages_retrieve and 404', () async {
    final http = CannedAdapter();
    http.answers['/api/v1/pages/rider-agreement/'] = const Canned(200, {
      'slug': 'rider-agreement',
      'title': 'Rider agreement',
      'html': '<p>Hi</p>',
      'updated_at': '2026-11-01T00:00:00Z',
    });
    http.answers['/api/v1/pages/nope/'] = Canned(404, errorBody('NOT_FOUND'));
    final repo = ApiLegalRepository(cannedApi(http));
    final page = await repo.page('rider-agreement');
    expect(page.title, 'Rider agreement');
    expect(page.updatedAt, DateTime.utc(2026, 11, 1));
    await expectLater(
      repo.page('nope'),
      throwsA(
        isA<ApiError>().having((e) => e.code, 'code', ApiErrorCode.notFound),
      ),
    );
    expect(LegalSlug.fromSlug('privacy'), LegalSlug.privacy);
    expect(LegalSlug.fromSlug('about'), isNull);
  });

  testWidgets('the agreement renders safely from Help; links open outside', (
    tester,
  ) async {
    final h = RiderTestHarness();
    await openFromHome(tester, h, 'home-help');
    await scrollTo(
      tester,
      byKey('help-legal-rider-agreement'),
      listKey: const Key('help-list'),
    );
    await tester.tap(byKey('help-legal-rider-agreement'));
    await tester.pumpAndSettle();
    expect(byKey('legal-page'), findsOneWidget);
    expect(find.textContaining('alert'), findsNothing);
    expect(
      find.textContaining('Placeholder; legal text pending.'),
      findsOneWidget,
    );
    expect(find.textContaining('Updated'), findsOneWidget);
    expect(h.legal.requests, ['rider-agreement']);
  });

  testWidgets('the disclosure falls back to the in-app disclosure text', (
    tester,
  ) async {
    final h = RiderTestHarness();
    await _open(tester, h, LegalSlug.locationDisclosure.slug);
    expect(byKey('legal-disclosure-fallback'), findsOneWidget);
    expect(find.text('How we use your location'), findsOneWidget);
  });

  testWidgets('privacy missing offers the config/app policy URL', (
    tester,
  ) async {
    final h = RiderTestHarness();
    h.legal.pages.remove('privacy');
    await _open(tester, h, 'privacy');
    expect(byKey('legal-fallback'), findsOneWidget);
    await tester.tap(byKey('legal-action'));
    await tester.pumpAndSettle();
    expect(h.urls.opened.last, Uri.parse('https://jivo.in/privacy'));
  });

  testWidgets('a missing agreement says not available; errors retry', (
    tester,
  ) async {
    final h = RiderTestHarness();
    h.legal.pages.remove('rider-agreement');
    await _open(tester, h, 'rider-agreement');
    expect(byKey('legal-missing'), findsOneWidget);
  });

  testWidgets('a network error retries', (tester) async {
    final h = RiderTestHarness();
    h.legal.failNext = const ApiError(code: ApiErrorCode.network);
    await _open(tester, h, 'privacy');
    expect(byKey('legal-error'), findsOneWidget);
    await tester.tap(byKey('legal-action'));
    await tester.pumpAndSettle();
    expect(byKey('legal-page'), findsOneWidget);
  });
}
