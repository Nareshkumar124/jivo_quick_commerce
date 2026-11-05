import 'package:flutter/widgets.dart';
import 'package:jivo_core/jivo_core.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/kyc_document.dart';
import '../domain/validators.dart';
import '../domain/vehicle_type.dart';
import '../../../shared/errors/rider_error_text.dart';

/// User-facing text for onboarding values. Server messages are never shown.

String fieldErrorText(AppLocalizations l10n, FieldError error) =>
    switch (error) {
      FieldError.required => l10n.fieldRequired,
      FieldError.nameInvalid => l10n.fieldNameInvalid,
      FieldError.dobInFuture => l10n.fieldDobInFuture,
      FieldError.dobUnderage => l10n.fieldDobUnderage(kMinimumRiderAge),
      FieldError.phoneIncomplete => l10n.loginPhoneIncomplete,
      FieldError.phoneInvalid => l10n.loginPhoneInvalid,
      FieldError.phoneSameAsRider => l10n.fieldPhoneSameAsRider,
      FieldError.vehicleNumberInvalid => l10n.fieldVehicleNumberInvalid,
      FieldError.accountNumberInvalid => l10n.fieldAccountNumberInvalid,
      FieldError.accountNumbersMismatch => l10n.fieldAccountNumbersMismatch,
      FieldError.ifscInvalid => l10n.fieldIfscInvalid,
      FieldError.upiInvalid => l10n.fieldUpiInvalid,
      FieldError.aadhaarInvalid => l10n.fieldAadhaarInvalid,
      FieldError.panInvalid => l10n.fieldPanInvalid,
      FieldError.drivingLicenceInvalid => l10n.fieldDrivingLicenceInvalid,
    };

String vehicleName(AppLocalizations l10n, VehicleType type) => switch (type) {
  VehicleType.bicycle => l10n.vehicleBicycle,
  VehicleType.eBike => l10n.vehicleEBike,
  VehicleType.motorbike => l10n.vehicleMotorbike,
  VehicleType.scooter => l10n.vehicleScooter,
};

String documentName(AppLocalizations l10n, KycDocumentType type) =>
    switch (type) {
      KycDocumentType.photo => l10n.docPhoto,
      KycDocumentType.aadhaarFront => l10n.docAadhaarFront,
      KycDocumentType.aadhaarBack => l10n.docAadhaarBack,
      KycDocumentType.pan => l10n.docPan,
      KycDocumentType.drivingLicence => l10n.docDrivingLicence,
      KycDocumentType.vehicleRc => l10n.docVehicleRc,
    };

/// Label of the number field, for types with a number.
String documentNumberLabel(AppLocalizations l10n, KycDocumentType type) =>
    switch (type) {
      KycDocumentType.aadhaarFront => l10n.numberAadhaar,
      KycDocumentType.pan => l10n.numberPan,
      KycDocumentType.drivingLicence => l10n.numberDrivingLicence,
      KycDocumentType.vehicleRc => l10n.numberVehicleRc,
      KycDocumentType.photo || KycDocumentType.aadhaarBack => '',
    };

String documentStatusLabel(
  AppLocalizations l10n,
  DocumentReviewStatus? status,
) => switch (status) {
  null => l10n.docStatusNeeded,
  DocumentReviewStatus.pending => l10n.docStatusPending,
  DocumentReviewStatus.approved => l10n.docStatusApproved,
  DocumentReviewStatus.rejected => l10n.docStatusRejected,
};

/// A server or network error on an onboarding call.
String onboardingErrorText(BuildContext context, ApiError error) {
  if (error.code == ApiErrorCode.validationError) {
    return AppLocalizations.of(context).onboardingCheckDetails;
  }
  return riderApiErrorMessage(context, error);
}
