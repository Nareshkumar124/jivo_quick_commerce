import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jivo_core/jivo_core.dart';
import 'package:rider_app/features/auth/presentation/rider_account_controller.dart';
import 'package:rider_app/features/onboarding/domain/image_compression.dart';
import 'package:rider_app/features/onboarding/domain/image_picking.dart';
import 'package:rider_app/features/onboarding/domain/kyc_document.dart';
import 'package:rider_app/features/onboarding/presentation/onboarding_controllers.dart';
import 'package:rider_app/features/onboarding/presentation/onboarding_providers.dart';

import '../../../helpers/onboarding_fixtures.dart';
import '../../../helpers/rider_app_harness.dart';

void main() {
  late RiderTestHarness h;
  late ProviderContainer c;

  /// Signed in as a `PENDING_KYC` rider with nothing uploaded, the profile
  /// loaded (as when the status screen is open).
  setUp(() async {
    h = RiderTestHarness();
    h.onboarding.seed(pendingPhone, pendingProfile());
    await h.signedInBefore(pendingPhone);
    c = await h.container();
    await c.read(riderAccountControllerProvider.notifier).load();
    c.listen(riderProfileControllerProvider, (_, _) {});
    await c.read(riderProfileControllerProvider.future);
  });

  ({DocumentCaptureController notifier, CaptureState Function() state}) capture(
    KycDocumentType type,
  ) {
    final provider = documentCaptureControllerProvider(type);
    c.listen(provider, (_, _) {});
    return (notifier: c.read(provider.notifier), state: () => c.read(provider));
  }

  test('camera: compressed preview; the original file is deleted and the '
      'pending marker is set only while the camera is open', () async {
    final pan = capture(KycDocumentType.pan);
    KycDocumentType? markerWhileOpen;
    h.picker.whilePicking = () async =>
        markerWhileOpen = await h.pendingCapture.read();

    await pan.notifier.pick(ImagePickSource.camera);

    expect(pan.state().step, CaptureStep.preview);
    expect(pan.state().image!.length, lessThanOrEqualTo(kKycImageMaxBytes));
    expect(h.picker.picks.single, (ImagePickSource.camera, false));
    expect(h.picker.discarded, ['/cache/picked_0.jpg']);
    expect(markerWhileOpen, KycDocumentType.pan);
    expect(await h.pendingCapture.read(), isNull);
  });

  test(
    'the selfie opens the front camera; the gallery sets no marker',
    () async {
      final photo = capture(KycDocumentType.photo);
      KycDocumentType? marker;
      h.picker.whilePicking = () async =>
          marker = await h.pendingCapture.read();

      await photo.notifier.pick(ImagePickSource.camera);
      expect(h.picker.picks.last, (ImagePickSource.camera, true));

      photo.notifier.retake();
      await photo.notifier.pick(ImagePickSource.gallery);
      expect(h.picker.picks.last, (ImagePickSource.gallery, true));
      expect(marker, isNull);
    },
  );

  test('cancelling keeps the photo already taken', () async {
    final pan = capture(KycDocumentType.pan);
    await pan.notifier.pick(ImagePickSource.camera);
    final image = pan.state().image;

    h.picker.cancelNext = true;
    await pan.notifier.pick(ImagePickSource.camera);

    expect(pan.state().step, CaptureStep.preview);
    expect(pan.state().image, same(image));
  });

  test('camera unavailable, unreadable file, too large: a problem to show, '
      'and the file is still deleted', () async {
    final pan = capture(KycDocumentType.pan);

    h.picker.failNext = true;
    await pan.notifier.pick(ImagePickSource.camera);
    expect(pan.state().step, CaptureStep.choose);
    expect(pan.state().problem, CaptureProblem.pickerUnavailable);
    expect(await h.pendingCapture.read(), isNull);

    h.codec.unreadable = true;
    await pan.notifier.pick(ImagePickSource.gallery);
    expect(pan.state().problem, CaptureProblem.unreadable);
    expect(h.picker.discarded, hasLength(1));

    h.codec
      ..unreadable = false
      ..result = Uint8List(kKycImageMaxBytes + 1);
    await pan.notifier.pick(ImagePickSource.gallery);
    expect(pan.state().problem, CaptureProblem.tooLarge);
    expect(h.codec.calls.length, greaterThan(kKycCompressionLadder.length));
    expect(h.picker.discarded, hasLength(2));
  });

  test('retake drops the photo', () async {
    final pan = capture(KycDocumentType.pan);
    await pan.notifier.pick(ImagePickSource.camera);

    pan.notifier.retake();

    expect(pan.state().step, CaptureStep.choose);
    expect(pan.state().image, isNull);
  });

  test('upload: the profile shows the document in review with the masked '
      'number; the full number is not kept anywhere', () async {
    final pan = capture(KycDocumentType.pan);
    await pan.notifier.pick(ImagePickSource.camera);

    expect(await pan.notifier.upload(number: 'abcde 1234f'), isTrue);

    expect(pan.state().step, CaptureStep.done);
    final document = c
        .read(riderProfileControllerProvider)
        .value!
        .documentOf(KycDocumentType.pan)!;
    expect(document.status, DocumentReviewStatus.pending);
    expect(document.numberMasked, 'XXXXXX234F');
    expect(h.onboarding.calls, contains('uploadDocument PAN'));
    expect(h.onboarding.calls.join(), isNot(contains('1234F')));
    expect(pan.state().toString(), isNot(contains('1234')));
  });

  test('a failed upload keeps the photo and shows the error; retry works '
      'without a new photo', () async {
    final pan = capture(KycDocumentType.pan);
    await pan.notifier.pick(ImagePickSource.camera);

    h.onboarding.failNext = const ApiError(code: ApiErrorCode.network);
    expect(await pan.notifier.upload(number: 'ABCDE1234F'), isFalse);
    expect(pan.state().step, CaptureStep.preview);
    expect(pan.state().uploadError?.code, ApiErrorCode.network);
    expect(pan.state().image, isNotNull);

    expect(await pan.notifier.upload(number: 'ABCDE1234F'), isTrue);
    expect(pan.state().step, CaptureStep.done);
    expect(h.picker.picks, hasLength(1));
  });

  test('426 on upload goes to the update screen, not inline', () async {
    final pan = capture(KycDocumentType.pan);
    await pan.notifier.pick(ImagePickSource.camera);

    h.onboarding.failNext = const ApiError(
      code: ApiErrorCode.appUpdateRequired,
      statusCode: 426,
    );
    await pan.notifier.upload(number: 'ABCDE1234F');

    expect(pan.state().uploadError, isNull);
    expect(h.signals.current, isA<AppUpdateRequired>());
  });

  test('a recovered photo (app stopped while the camera was open) is '
      'processed like a new one', () async {
    final pan = capture(KycDocumentType.pan);
    await pan.notifier.recover(const PickedImage('/cache/lost.jpg'));

    expect(pan.state().step, CaptureStep.preview);
    expect(h.picker.discarded, ['/cache/lost.jpg']);
  });
}
