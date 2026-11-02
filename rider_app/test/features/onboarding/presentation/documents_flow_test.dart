import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/jivo_core.dart';
import 'package:rider_app/features/onboarding/domain/image_picking.dart';
import 'package:rider_app/features/onboarding/domain/kyc_document.dart';
import 'package:rider_app/features/onboarding/domain/vehicle_type.dart';

import '../../../helpers/onboarding_fixtures.dart';
import '../../../helpers/rider_app_harness.dart';

Finder byKey(String key) => find.byKey(Key(key));

String statusOf(WidgetTester tester, KycDocumentType type) =>
    tester.widget<Text>(byKey('doc-${type.wireValue}-status')).data!;

void main() {
  late RiderTestHarness h;

  setUp(() => h = RiderTestHarness());

  /// A PENDING_KYC rider with nothing uploaded, on the documents screen.
  Future<void> openDocuments(
    WidgetTester tester, {
    VehicleType vehicle = VehicleType.bicycle,
  }) async {
    h.onboarding.seed(pendingPhone, pendingProfile(vehicle: vehicle));
    await h.signedInBefore(pendingPhone);
    await h.pump(tester);
    await tester.tap(byKey('status-next-step'));
    await tester.pumpAndSettle();
  }

  Future<void> openCapture(WidgetTester tester, KycDocumentType type) async {
    await tester.tap(byKey('doc-${type.wireValue}'));
    await tester.pumpAndSettle();
  }

  Future<void> takePhoto(WidgetTester tester) async {
    await tester.tap(byKey('capture-camera'));
    await tester.pumpAndSettle();
  }

  Future<void> upload(WidgetTester tester) async {
    await tester.tap(byKey('capture-upload'));
    await tester.pumpAndSettle();
  }

  testWidgets('every required document starts as Needed; Continue waits for '
      'all of them', (tester) async {
    await openDocuments(tester, vehicle: VehicleType.motorbike);

    for (final type in requiredDocumentsFor(VehicleType.motorbike)) {
      expect(statusOf(tester, type), 'Needed', reason: '$type');
    }
    expect(find.text('Step 2 of 3'), findsOneWidget);
    expect(
      find.text('0 of 6 done. Upload every document to continue.'),
      findsOneWidget,
    );
    expect(
      tester.widget<FilledButton>(byKey('documents-continue')).onPressed,
      isNull,
    );
  });

  testWidgets('PAN: take photo, preview, number checked, masked once typed, '
      'upload, back to the list as In review', (tester) async {
    await openDocuments(tester);
    await openCapture(tester, KycDocumentType.pan);

    expect(find.text('Take photo'), findsOneWidget);
    expect(find.text('Choose from gallery'), findsOneWidget);
    expect(
      tester.getSize(byKey('capture-camera')).height,
      greaterThanOrEqualTo(56),
    );

    await takePhoto(tester);
    expect(byKey('capture-preview'), findsOneWidget);
    expect(byKey('capture-ready'), findsOneWidget);
    expect(h.picker.discarded, hasLength(1), reason: 'original deleted');

    await upload(tester);
    expect(find.text('This is required.'), findsOneWidget);
    await tester.enterText(byKey('capture-number'), 'ABCD1234F');
    await upload(tester);
    expect(
      find.text('Enter your PAN exactly as printed, like ABCDE1234F.'),
      findsOneWidget,
    );
    expect(h.onboarding.calls, isNot(contains('uploadDocument PAN')));

    await tester.enterText(byKey('capture-number'), 'abcde1234f');
    await tester.pump();
    final field = tester.widget<TextField>(byKey('capture-number'));
    expect(field.controller!.text, 'ABCDE1234F', reason: 'upper-cased');
    expect(field.enableSuggestions, isFalse);
    expect(field.autocorrect, isFalse);
    expect(field.obscureText, isFalse, reason: 'readable while typing');

    // Moving on hides the number and shows only the masked form.
    FocusManager.instance.primaryFocus!.unfocus();
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(byKey('capture-number')).obscureText,
      isTrue,
    );
    expect(find.text('Entered: XXXXXX234F'), findsOneWidget);

    await upload(tester);
    expect(find.text('PAN card uploaded'), findsOneWidget);
    expect(statusOf(tester, KycDocumentType.pan), 'In review');
    expect(find.text('XXXXXX234F'), findsOneWidget);
    expect(find.text('ABCDE1234F'), findsNothing);
    expect(
      find.text('1 of 4 done. Upload every document to continue.'),
      findsOneWidget,
    );
  });

  testWidgets('Retake drops the photo and goes back to camera / gallery', (
    tester,
  ) async {
    await openDocuments(tester);
    await openCapture(tester, KycDocumentType.aadhaarBack);
    await takePhoto(tester);
    expect(byKey('capture-number'), findsNothing, reason: 'no number');

    await tester.tap(byKey('capture-retake'));
    await tester.pumpAndSettle();
    expect(byKey('capture-preview'), findsNothing);
    expect(byKey('capture-camera'), findsOneWidget);

    await tester.tap(byKey('capture-gallery'));
    await tester.pumpAndSettle();
    expect(h.picker.picks.last.$1, ImagePickSource.gallery);
    await upload(tester);
    expect(statusOf(tester, KycDocumentType.aadhaarBack), 'In review');
  });

  testWidgets('a failed upload shows the error and keeps the photo for a '
      'retry', (tester) async {
    await openDocuments(tester);
    await openCapture(tester, KycDocumentType.photo);
    await takePhoto(tester);
    expect(h.picker.picks.single.$2, isTrue, reason: 'front camera');

    h.onboarding.failNext = const ApiError(code: ApiErrorCode.network);
    await upload(tester);
    expect(byKey('capture-upload-error'), findsOneWidget);
    expect(byKey('capture-preview'), findsOneWidget);

    await upload(tester);
    expect(statusOf(tester, KycDocumentType.photo), 'In review');
    expect(h.picker.picks, hasLength(1));
  });

  testWidgets('camera unavailable and unreadable photos explain what to do', (
    tester,
  ) async {
    await openDocuments(tester);
    await openCapture(tester, KycDocumentType.aadhaarFront);

    h.picker.failNext = true;
    await takePhoto(tester);
    expect(find.textContaining("Couldn't open the camera"), findsOneWidget);

    h.codec.unreadable = true;
    await tester.tap(byKey('capture-gallery'));
    await tester.pumpAndSettle();
    expect(
      find.text("That file can't be used. Take a new photo."),
      findsOneWidget,
    );
    expect(byKey('capture-preview'), findsNothing);
  });

  testWidgets('Aadhaar number: Verhoeff-checked, shown as XXXX XXXX 0124', (
    tester,
  ) async {
    await openDocuments(tester);
    await openCapture(tester, KycDocumentType.aadhaarFront);
    await takePhoto(tester);

    await tester.enterText(byKey('capture-number'), '234567890120');
    await upload(tester);
    expect(
      find.text('Enter your 12-digit Aadhaar number exactly as printed.'),
      findsOneWidget,
    );

    await tester.enterText(byKey('capture-number'), '234567890124');
    await upload(tester);
    expect(statusOf(tester, KycDocumentType.aadhaarFront), 'In review');
    expect(find.text('XXXX XXXX 0124'), findsOneWidget);
  });

  testWidgets('the RC number is prefilled with the registered vehicle '
      'number', (tester) async {
    await openDocuments(tester, vehicle: VehicleType.motorbike);
    await scrollTo(
      tester,
      byKey('doc-RC'),
      listKey: const Key('documents-list'),
    );
    await openCapture(tester, KycDocumentType.vehicleRc);
    await takePhoto(tester);

    expect(
      tester.widget<TextField>(byKey('capture-number')).controller!.text,
      'DL3CAB1234',
    );
  });

  testWidgets('all documents uploaded: Continue opens bank details', (
    tester,
  ) async {
    h.onboarding.seed(
      pendingPhone,
      pendingProfile(
        documents: {
          for (final MapEntry(:key, :value) in allBicycleDocuments.entries)
            if (key != KycDocumentType.photo) key: value,
        },
      ),
    );
    await h.signedInBefore(pendingPhone);
    await h.pump(tester);
    await tester.tap(byKey('status-next-step'));
    await tester.pumpAndSettle();

    await openCapture(tester, KycDocumentType.photo);
    await takePhoto(tester);
    await upload(tester);

    await tester.tap(byKey('documents-continue'));
    await tester.pumpAndSettle();
    expect(find.text('Step 3 of 3'), findsOneWidget);
    expect(byKey('bank-save'), findsOneWidget);
  });

  testWidgets('a photo taken before Android stopped the app is recovered '
      'into the right document', (tester) async {
    await h.pendingCapture.write(KycDocumentType.pan);
    h.picker.lost = const PickedImage('/cache/lost.jpg');
    await openDocuments(tester);

    expect(find.text('PAN card'), findsWidgets);
    expect(byKey('capture-preview'), findsOneWidget);
    expect(h.picker.discarded, ['/cache/lost.jpg']);
    expect(await h.pendingCapture.read(), isNull);
  });

  testWidgets('logout forgets an interrupted capture and deletes its photo, '
      'so the next rider never gets it', (tester) async {
    await h.pendingCapture.write(KycDocumentType.pan);
    h.picker.lost = const PickedImage('/cache/lost.jpg');
    h.onboarding.seed(pendingPhone, pendingProfile());
    await h.signedInBefore(pendingPhone);
    await h.pump(tester);

    await tester.tap(byKey('logout'));
    await tester.pumpAndSettle();

    expect(find.text('Log in to Jivo Rider'), findsOneWidget);
    expect(await h.pendingCapture.read(), isNull);
    expect(h.picker.discarded, ['/cache/lost.jpg']);
    expect(h.picker.lost, isNull);
  });
}
