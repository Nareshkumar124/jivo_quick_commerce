import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/jivo_core.dart';
import 'package:rider_app/features/onboarding/data/fake_rider_onboarding_backend.dart';
import 'package:rider_app/features/onboarding/domain/kyc_document.dart';
import 'package:rider_app/features/onboarding/domain/vehicle_type.dart';

import '../../../helpers/onboarding_fixtures.dart';
import '../../../helpers/rider_app_harness.dart';

Finder byKey(String key) => find.byKey(Key(key));

void main() {
  late RiderTestHarness h;

  setUp(() => h = RiderTestHarness()..surface = const Size(1080, 3200));

  Future<void> openAs(WidgetTester tester, String phone) async {
    await h.signedInBefore(phone);
    await h.pump(tester);
  }

  group('application incomplete', () {
    testWidgets('nothing uploaded: checklist and "Upload documents"', (
      tester,
    ) async {
      h.onboarding.seed(
        pendingPhone,
        pendingProfile(vehicle: VehicleType.scooter),
      );
      await openAs(tester, pendingPhone);

      expect(find.text('Finish your application'), findsOneWidget);
      expect(find.text('Personal and vehicle details'), findsOneWidget);
      expect(find.text('0 of 6 uploaded'), findsOneWidget);
      expect(find.text('Needed'), findsOneWidget, reason: 'bank details');
      expect(
        tester.widget<FilledButton>(byKey('status-next-step')).child,
        isA<Text>().having((t) => t.data, 'label', 'Upload documents'),
      );
      expect(
        tester.getSize(byKey('status-next-step')).height,
        greaterThanOrEqualTo(56),
      );

      await tester.tap(byKey('status-next-step'));
      await tester.pumpAndSettle();
      expect(find.text('Step 2 of 3'), findsOneWidget);
    });

    testWidgets('documents done, bank missing: "Add bank details"', (
      tester,
    ) async {
      h.onboarding.seed(
        pendingPhone,
        pendingProfile(documents: allBicycleDocuments),
      );
      await openAs(tester, pendingPhone);

      expect(find.text('Finish your application'), findsOneWidget);
      expect(find.text('Add bank details'), findsOneWidget);

      await tester.tap(byKey('status-next-step'));
      await tester.pumpAndSettle();
      expect(find.text('Step 3 of 3'), findsOneWidget);
      expect(find.text('Bank details'), findsWidgets);
    });
  });

  group('pending review', () {
    testWidgets('everything submitted: under review, Check status reloads', (
      tester,
    ) async {
      await openAs(tester, pendingPhone);

      expect(find.text('Documents under review'), findsOneWidget);
      expect(find.text('Account XXXXXXXX6789'), findsOneWidget);
      expect(h.onboarding.calls, ['fetchProfile']);

      await tester.tap(byKey('status-check'));
      await tester.pumpAndSettle();
      expect(h.onboarding.calls, ['fetchProfile', 'fetchProfile']);
      expect(find.text('Documents under review'), findsOneWidget);
    });

    testWidgets('a failed check keeps the screen and shows the error', (
      tester,
    ) async {
      await openAs(tester, pendingPhone);

      h.onboarding.failNext = const ApiError(code: ApiErrorCode.network);
      await tester.tap(byKey('status-check'));
      await tester.pumpAndSettle();

      expect(find.text('Documents under review'), findsOneWidget);
      expect(find.textContaining('internet'), findsOneWidget);
    });

    testWidgets('View documents lists each document with its status and '
        'masked number', (tester) async {
      await openAs(tester, pendingPhone);
      await tester.tap(byKey('status-view-documents'));
      await tester.pumpAndSettle();

      expect(find.text('In review'), findsNWidgets(6));
      expect(find.text('XXXX XXXX 4321'), findsOneWidget);
      expect(find.text('XXXXXX234F'), findsOneWidget);
    });
  });

  group('rejected', () {
    testWidgets('reason, rejected document with the note, and the re-upload '
        'path back to review', (tester) async {
      await openAs(tester, rejectedPhone);

      expect(find.text('Documents not approved'), findsOneWidget);
      expect(
        find.text(FakeRiderOnboardingBackend.rejectionReason),
        findsOneWidget,
      );
      expect(find.text('PAN card'), findsOneWidget);
      expect(
        find.text(FakeRiderOnboardingBackend.rejectedPanNote),
        findsOneWidget,
      );

      await tester.tap(byKey('status-fix'));
      await tester.pumpAndSettle();
      expect(byKey('doc-PAN-status'), findsOneWidget);
      expect(
        tester.widget<Text>(byKey('doc-PAN-status')).data,
        'Not accepted: upload again',
      );

      await tester.tap(byKey('doc-PAN'));
      await tester.pumpAndSettle();
      await tester.tap(byKey('capture-camera'));
      await tester.pumpAndSettle();
      await tester.enterText(byKey('capture-number'), 'ABCDE1234F');
      await tester.tap(byKey('capture-upload'));
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(byKey('doc-PAN-status')).data, 'In review');

      await tester.tap(byKey('documents-continue'));
      await tester.pumpAndSettle();
      expect(find.text('Documents under review'), findsOneWidget);
    });

    testWidgets('support can be called', (tester) async {
      await openAs(tester, rejectedPhone);
      await tester.tap(byKey('call-support'));
      expect(h.urls.opened.single, Uri(scheme: 'tel', path: '+911800123456'));
    });
  });

  group('approved', () {
    testWidgets('after the review, "You\'re approved" and one tap to home', (
      tester,
    ) async {
      await openAs(tester, pendingPhone);

      await tester.tap(byKey('dev-review'));
      await tester.pumpAndSettle();
      await tester.tap(byKey('dev-review-approve'));
      await tester.pumpAndSettle();

      expect(find.text("You're approved!"), findsOneWidget);
      expect(find.textContaining('Jivo Sector 18, Noida'), findsOneWidget);
      expect(byKey('home-flavor'), findsNothing);

      await tester.tap(byKey('status-start'));
      await tester.pumpAndSettle();
      expect(byKey('home-flavor'), findsOneWidget);
    });

    testWidgets('a review rejection shows up on the next check', (
      tester,
    ) async {
      await openAs(tester, pendingPhone);
      await tester.tap(byKey('dev-review'));
      await tester.pumpAndSettle();
      await tester.tap(byKey('dev-review-reject'));
      await tester.pumpAndSettle();

      expect(find.text('Documents not approved'), findsOneWidget);
    });

    testWidgets('no fake review controls outside the dev flavor', (
      tester,
    ) async {
      h = RiderTestHarness(flavor: Flavor.prod);
      await openAs(tester, pendingPhone);

      expect(find.text('Documents under review'), findsOneWidget);
      expect(byKey('dev-review'), findsNothing);
    });
  });

  testWidgets('loading fails: error with Retry', (tester) async {
    h.onboarding.failNext = const ApiError(code: ApiErrorCode.timeout);
    await openAs(tester, pendingPhone);

    expect(find.text("Couldn't load your application"), findsOneWidget);
    await tester.tap(byKey('status-retry'));
    await tester.pumpAndSettle();
    expect(find.text('Documents under review'), findsOneWidget);
  });

  testWidgets('suspended riders get the static screen (no application steps)', (
    tester,
  ) async {
    await openAs(tester, suspendedPhone);

    expect(find.text('Account suspended'), findsOneWidget);
    expect(h.onboarding.calls, isEmpty);
  });

  testWidgets('approved documents are locked', (tester) async {
    h.onboarding.seed(
      pendingPhone,
      pendingProfile(
        documents: {
          ...allBicycleDocuments,
          KycDocumentType.photo: DocumentReviewStatus.approved,
        },
        bank: bankSummary,
      ),
    );
    await openAs(tester, pendingPhone);
    await tester.tap(byKey('status-view-documents'));
    await tester.pumpAndSettle();

    expect(tester.widget<Text>(byKey('doc-PHOTO-status')).data, 'Approved');
    await tester.tap(byKey('doc-PHOTO'));
    await tester.pumpAndSettle();
    expect(byKey('capture-camera'), findsNothing);
  });
}
