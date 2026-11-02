import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../app/providers.dart';
import '../../auth/presentation/rider_account_controller.dart';
import '../domain/image_compression.dart';
import '../domain/image_picking.dart';
import '../domain/kyc_document.dart';
import '../domain/onboarding_inputs.dart';
import '../domain/validators.dart';
import 'onboarding_providers.dart';

/// A submit in progress and the last server error, for the registration and
/// bank forms. 426/503 never land in [error]: they switch to the blocking
/// update or maintenance screen.
@immutable
class SubmitState {
  const SubmitState({this.submitting = false, this.error});

  final bool submitting;
  final ApiError? error;
}

// ------------------------------------------------------------ registration

final registrationControllerProvider =
    NotifierProvider.autoDispose<RegistrationController, SubmitState>(
      RegistrationController.new,
    );

/// `POST /rider/register/`. On success the account moves to the returned
/// status (`PENDING_KYC`), and the router opens the status screen with the
/// next step.
class RegistrationController extends Notifier<SubmitState> {
  @override
  SubmitState build() => const SubmitState();

  Future<bool> submit(RiderRegistration registration) async {
    if (state.submitting) return false;
    state = const SubmitState(submitting: true);
    try {
      final profile = await ref
          .read(riderOnboardingRepositoryProvider)
          .register(registration);
      state = const SubmitState();
      unawaited(
        ref
            .read(analyticsProvider)
            .logEvent(
              'rider_registered',
              parameters: {'vehicle_type': registration.vehicleType.wireValue},
            ),
      );
      ref
          .read(riderAccountControllerProvider.notifier)
          .riderStatusChanged(profile.status);
      return true;
    } on Object catch (e) {
      final error = ApiError.from(e);
      final blocking = reportAppControlError(ref, error);
      state = SubmitState(error: blocking ? null : error);
      return false;
    }
  }

  void clearError() {
    if (state.error != null) state = const SubmitState();
  }
}

// ------------------------------------------------------------ bank details

final bankDetailsControllerProvider =
    NotifierProvider.autoDispose<BankDetailsController, SubmitState>(
      BankDetailsController.new,
    );

/// `PUT /rider/bank-account/`.
class BankDetailsController extends Notifier<SubmitState> {
  @override
  SubmitState build() => const SubmitState();

  Future<bool> save(BankAccountInput input) async {
    if (state.submitting) return false;
    state = const SubmitState(submitting: true);
    try {
      final summary = await ref
          .read(riderOnboardingRepositoryProvider)
          .saveBankAccount(input);
      state = const SubmitState();
      ref
          .read(riderProfileControllerProvider.notifier)
          .bankAccountSaved(summary);
      unawaited(ref.read(analyticsProvider).logEvent('rider_bank_saved'));
      return true;
    } on Object catch (e) {
      final error = ApiError.from(e);
      final blocking = reportAppControlError(ref, error);
      state = SubmitState(error: blocking ? null : error);
      return false;
    }
  }

  void clearError() {
    if (state.error != null) state = const SubmitState();
  }
}

// --------------------------------------------------------- document capture

enum CaptureStep {
  /// Nothing picked yet: choose camera or gallery.
  choose,

  /// Picking or compressing.
  processing,

  /// A compressed photo is ready: check it, type the number, upload.
  preview,

  uploading,

  /// Uploaded; the screen closes.
  done,
}

/// Why a photo could not be used.
enum CaptureProblem {
  /// The camera or photo picker could not open.
  pickerUnavailable,

  /// Not an image, or a corrupt file.
  unreadable,

  /// Still over 1 MB at the smallest size (very unusual).
  tooLarge,
}

@immutable
class CaptureState {
  const CaptureState({
    this.step = CaptureStep.choose,
    this.image,
    this.problem,
    this.uploadError,
    this.uploaded,
  });

  final CaptureStep step;

  /// The compressed JPEG, kept while the rider checks it and across a
  /// failed upload (a retry does not need a new photo).
  final CompressedImage? image;
  final CaptureProblem? problem;
  final ApiError? uploadError;
  final RiderDocument? uploaded;
}

final documentCaptureControllerProvider = NotifierProvider.autoDispose
    .family<DocumentCaptureController, CaptureState, KycDocumentType>(
      DocumentCaptureController.new,
    );

/// Take or choose a photo of one document, compress it to <= 1 MB, let the
/// rider check it (retake), then `POST /rider/documents/`.
///
/// The original photo (with EXIF) is deleted right after compression; the
/// compressed copy lives only in memory and is dropped when the screen
/// closes. The document number is passed to [upload] and never stored here.
class DocumentCaptureController extends Notifier<CaptureState> {
  DocumentCaptureController(this.type);

  final KycDocumentType type;

  @override
  CaptureState build() => const CaptureState();

  Future<void> pick(ImagePickSource source) async {
    if (state.step == CaptureStep.processing ||
        state.step == CaptureStep.uploading) {
      return;
    }
    final before = state;
    state = const CaptureState(step: CaptureStep.processing);
    final pending = ref.read(pendingCaptureStoreProvider);
    PickedImage? picked;
    try {
      if (source == ImagePickSource.camera) await pending.write(type);
      picked = await ref
          .read(kycImagePickerProvider)
          .pick(source, selfie: type.isSelfie);
    } on PlatformException catch (error) {
      debugPrint('DocumentCaptureController.pick: ${error.code}');
      if (!ref.mounted) return;
      state = const CaptureState(problem: CaptureProblem.pickerUnavailable);
      return;
    } finally {
      await pending.clear();
    }
    if (!ref.mounted) return;
    if (picked == null) {
      // Cancelled: keep the earlier photo, if any.
      state = CaptureState(step: before.step, image: before.image);
      return;
    }
    await _process(picked);
  }

  /// A photo recovered after Android stopped the app while the camera was
  /// open ([KycImagePicker.retrieveLost]).
  Future<void> recover(PickedImage picked) async {
    state = const CaptureState(step: CaptureStep.processing);
    await _process(picked);
  }

  Future<void> _process(PickedImage picked) async {
    final picker = ref.read(kycImagePickerProvider);
    try {
      final image = await compressToLimit(
        codec: ref.read(imageCodecProvider),
        sourcePath: picked.path,
      );
      if (!ref.mounted) return;
      state = CaptureState(step: CaptureStep.preview, image: image);
    } on ImageTooLargeException {
      if (ref.mounted) {
        state = const CaptureState(problem: CaptureProblem.tooLarge);
      }
    } on Object catch (error) {
      debugPrint('DocumentCaptureController: ${error.runtimeType}');
      if (ref.mounted) {
        state = const CaptureState(problem: CaptureProblem.unreadable);
      }
    } finally {
      await picker.discard(picked);
    }
  }

  /// Drop the photo and choose again.
  void retake() {
    if (state.step == CaptureStep.uploading) return;
    state = const CaptureState();
  }

  /// Uploads the photo with [number] (already validated and normalised, or
  /// null for documents without one).
  Future<bool> upload({String? number}) async {
    final image = state.image;
    if (image == null || state.step != CaptureStep.preview) return false;
    state = CaptureState(step: CaptureStep.uploading, image: image);
    try {
      final document = await ref
          .read(riderOnboardingRepositoryProvider)
          .uploadDocument(
            DocumentUpload(
              type: type,
              image: image.bytes,
              number: number == null ? null : normaliseDocumentNumber(number),
            ),
          );
      if (!ref.mounted) return true;
      state = CaptureState(step: CaptureStep.done, uploaded: document);
      ref
          .read(riderProfileControllerProvider.notifier)
          .documentUploaded(document);
      unawaited(
        ref
            .read(analyticsProvider)
            .logEvent(
              'rider_document_uploaded',
              parameters: documentEventParameters(type),
            ),
      );
      return true;
    } on Object catch (e) {
      final error = ApiError.from(e);
      final blocking = reportAppControlError(ref, error);
      if (ref.mounted) {
        state = CaptureState(
          step: CaptureStep.preview,
          image: image,
          uploadError: blocking ? null : error,
        );
      }
      return false;
    }
  }
}
