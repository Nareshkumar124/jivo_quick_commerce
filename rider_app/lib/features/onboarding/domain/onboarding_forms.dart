import 'package:jivo_core/helpers.dart';

import 'onboarding_inputs.dart';
import 'validators.dart';
import 'vehicle_type.dart';

enum RegistrationField {
  fullName,
  dateOfBirth,
  emergencyName,
  emergencyPhone,
  store,
  vehicleType,
  vehicleNumber,
}

/// What the registration form holds (04 §2.2). [validate] checks every
/// field; [toRegistration] is only valid when it returned no errors.
class RegistrationDraft {
  const RegistrationDraft({
    this.fullName = '',
    this.dateOfBirth,
    this.emergencyName = '',
    this.emergencyPhone = '',
    this.storeId,
    this.vehicleType,
    this.vehicleNumber = '',
  });

  final String fullName;
  final DateTime? dateOfBirth;
  final String emergencyName;
  final String emergencyPhone;
  final int? storeId;
  final VehicleType? vehicleType;
  final String vehicleNumber;

  /// [today] is the IST date ([istToday]). [riderPhoneE164] is the signed-in
  /// phone, which cannot be the emergency contact.
  Map<RegistrationField, FieldError> validate({
    required DateTime today,
    String? riderPhoneE164,
  }) => {
    RegistrationField.fullName: ?validatePersonName(fullName),
    RegistrationField.dateOfBirth: ?validateDateOfBirth(
      dateOfBirth,
      today: today,
    ),
    RegistrationField.emergencyName: ?validatePersonName(emergencyName),
    RegistrationField.emergencyPhone: ?validateEmergencyPhone(
      emergencyPhone,
      riderPhoneE164: riderPhoneE164,
    ),
    if (storeId == null) RegistrationField.store: FieldError.required,
    if (vehicleType == null) RegistrationField.vehicleType: FieldError.required,
    RegistrationField.vehicleNumber: ?validateVehicleNumber(
      vehicleNumber,
      vehicle: vehicleType,
    ),
  };

  /// The request. The vehicle number is dropped for non-motorised vehicles.
  RiderRegistration toRegistration() {
    final vehicle = vehicleType!;
    return RiderRegistration(
      fullName: normaliseName(fullName),
      dateOfBirth: dateOnly(dateOfBirth!),
      emergencyContactName: normaliseName(emergencyName),
      emergencyContactPhone: IndianMobile.toE164(emergencyPhone)!,
      preferredStoreId: storeId!,
      vehicleType: vehicle,
      vehicleNumber: vehicle.isMotorised
          ? normaliseRegistrationNumber(vehicleNumber)
          : null,
    );
  }
}

enum BankField { holderName, accountNumber, confirmAccountNumber, ifsc, upiId }

/// What the bank details form holds (04 §2.2).
class BankAccountDraft {
  const BankAccountDraft({
    this.holderName = '',
    this.accountNumber = '',
    this.confirmAccountNumber = '',
    this.ifsc = '',
    this.upiId = '',
  });

  final String holderName;
  final String accountNumber;
  final String confirmAccountNumber;
  final String ifsc;
  final String upiId;

  Map<BankField, FieldError> validate() => {
    BankField.holderName: ?validatePersonName(holderName),
    BankField.accountNumber: ?validateAccountNumber(accountNumber),
    BankField.confirmAccountNumber: ?validateAccountConfirmation(
      accountNumber,
      confirmAccountNumber,
    ),
    BankField.ifsc: ?validateIfsc(ifsc),
    BankField.upiId: ?validateUpiId(upiId),
  };

  BankAccountInput toInput() => BankAccountInput(
    holderName: normaliseName(holderName),
    accountNumber: normaliseAccountNumber(accountNumber),
    ifsc: normaliseIfsc(ifsc),
    upiId: upiId.trim().isEmpty ? null : upiId.trim(),
  );

  @override
  String toString() => 'BankAccountDraft';
}
