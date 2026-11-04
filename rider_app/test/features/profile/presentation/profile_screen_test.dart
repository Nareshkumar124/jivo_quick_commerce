import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_api/jivo_api.dart' show RiderStatusEnum;
import 'package:jivo_core/jivo_core.dart';
import 'package:rider_app/features/onboarding/data/fake_rider_onboarding_backend.dart';

import '../../../helpers/onboarding_fixtures.dart';
import '../../../helpers/records_helpers.dart';
import '../../../helpers/rider_app_harness.dart';

void main() {
  late RiderTestHarness h;

  setUp(() => h = RiderTestHarness());

  testWidgets('photo, name, phone, store, vehicle, KYC, rating; documents '
      'read-only', (tester) async {
    await openFromHome(tester, h, 'home-profile');

    expect(textOf(tester, 'profile-name'), 'Ravi Kumar');
    expect(textOf(tester, 'profile-phone'), '+91 98111 22231');
    expect(find.text('Jivo Sector 18, Noida'), findsOneWidget);
    expect(find.text('Motorbike · DL3CAB1234'), findsOneWidget);
    expect(find.text('Verified'), findsOneWidget);
    expect(find.text('4.8 ★'), findsOneWidget);
    expect(byKey('profile-photo'), findsOneWidget);

    await tester.tap(byKey('profile-documents'));
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(byKey('doc-PAN-status')).data, 'Approved');
    expect(find.text('XXXXXX234F'), findsOneWidget);
    expect(byKey('documents-continue'), findsNothing, reason: 'read-only');
    await tester.tap(byKey('doc-PAN'));
    await tester.pumpAndSettle();
    expect(byKey('capture-camera'), findsNothing);
  });

  testWidgets('a failed load offers Retry', (tester) async {
    await pumpActiveHome(tester, h);
    h.onboarding.failNext = const ApiError(code: ApiErrorCode.network);
    await tester.tap(byKey('home-profile'));
    await tester.pumpAndSettle();

    expect(byKey('profile-retry'), findsOneWidget);
    await tester.tap(byKey('profile-retry'));
    await tester.pumpAndSettle();
    expect(textOf(tester, 'profile-name'), 'Ravi Kumar');
  });

  group('documents (04 §2.9)', () {
    Future<void> openDocuments(WidgetTester tester) async {
      await scrollTo(
        tester,
        byKey('profile-documents'),
        listKey: const Key('profile-list'),
      );
      await tester.tap(byKey('profile-documents'));
      await tester.pumpAndSettle();
    }

    testWidgets('all approved: no banner, nothing to upload', (tester) async {
      await openFromHome(tester, h, 'home-profile');
      expect(textOf(tester, 'profile-documents-status'), 'All approved');

      await openDocuments(tester);
      expect(byKey('documents-attention'), findsNothing);
      expect(find.textContaining('Approved documents can'), findsOneWidget);
      expect(find.text('Step 2 of 3'), findsNothing);
    });

    testWidgets('ops rejects the driving licence: the profile flags it, the '
        'rider re-uploads it and it goes back to review', (tester) async {
      await openFromHome(tester, h, 'home-profile');

      // Dev control standing in for the ops panel.
      await scrollTo(
        tester,
        byKey('dev-reject-document'),
        listKey: const Key('profile-list'),
      );
      await tester.tap(byKey('dev-reject-document'));
      await tester.pumpAndSettle();
      expect(
        textOf(tester, 'profile-documents-status'),
        '1 needs a new upload',
      );
      expect(byKey('dev-reject-document'), findsNothing);

      await openDocuments(tester);
      expect(byKey('documents-attention'), findsOneWidget);
      expect(find.text('1 document needs a new upload.'), findsOneWidget);
      await scrollTo(
        tester,
        byKey('doc-DL'),
        listKey: const Key('documents-list'),
      );
      expect(textOf(tester, 'doc-DL-status'), 'Not accepted: upload again');
      expect(
        find.text(FakeRiderOnboardingBackend.expiredDlNote),
        findsOneWidget,
      );

      await tester.tap(byKey('doc-DL'));
      await tester.pumpAndSettle();
      await tester.tap(byKey('capture-camera'));
      await tester.pumpAndSettle();
      await tester.enterText(byKey('capture-number'), 'DL0420110012399');
      await tester.pumpAndSettle();
      await tester.tap(byKey('capture-upload'));
      await tester.pumpAndSettle();

      expect(h.onboarding.calls, contains('uploadDocument DL'));
      expect(find.text('Driving licence uploaded'), findsOneWidget);
      expect(byKey('documents-attention'), findsNothing);
      await scrollTo(
        tester,
        byKey('doc-DL'),
        listKey: const Key('documents-list'),
      );
      expect(textOf(tester, 'doc-DL-status'), 'In review');
      expect(find.text('XXXXXXXXXXX2399'), findsOneWidget);
      expect(
        h.onboarding.profileOf(activeRiderPhone)!.status,
        RiderStatusEnum.ACTIVE,
        reason: 'a re-upload does not change the rider status',
      );

      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(textOf(tester, 'profile-documents-status'), 'In review');
    });

    testWidgets('an approved document stays locked', (tester) async {
      await openFromHome(tester, h, 'home-profile');
      await openDocuments(tester);
      await tester.tap(byKey('doc-PAN'));
      await tester.pumpAndSettle();
      expect(byKey('capture-camera'), findsNothing);
    });
  });

  testWidgets('call support dials the number from the app config', (
    tester,
  ) async {
    await openFromHome(tester, h, 'home-profile');
    await scrollTo(
      tester,
      byKey('profile-call-support'),
      listKey: const Key('profile-list'),
    );
    await tester.tap(byKey('profile-call-support'));
    await tester.pumpAndSettle();
    expect(h.urls.opened.single, Uri(scheme: 'tel', path: '+911800123456'));
  });

  testWidgets('log out from the profile: offline with no task signs out', (
    tester,
  ) async {
    await openFromHome(tester, h, 'home-profile');
    await scrollTo(
      tester,
      byKey('profile-logout'),
      listKey: const Key('profile-list'),
    );
    await tester.tap(byKey('profile-logout'));
    await tester.pumpAndSettle();
    expect(find.text('Log in to Jivo Rider'), findsOneWidget);
  });

  testWidgets('log out while online is refused with the reason', (
    tester,
  ) async {
    await openFromHome(tester, h, 'home-profile');
    h.location.running = true;
    await scrollTo(
      tester,
      byKey('profile-logout'),
      listKey: const Key('profile-list'),
    );
    await tester.tap(byKey('profile-logout'));
    await tester.pumpAndSettle();
    expect(find.text('Go offline before logging out.'), findsOneWidget);
    expect(h.session.isSignedIn, isTrue);
  });
}
