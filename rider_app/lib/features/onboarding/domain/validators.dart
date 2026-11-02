import '../../auth/domain/indian_mobile.dart';
import 'kyc_document.dart';
import 'vehicle_type.dart';

/// Why a field value is not accepted. The screens map these to ARB strings
/// (`fieldErrorText`); the server re-validates everything.
enum FieldError {
  required,
  nameInvalid,
  dobInFuture,
  dobUnderage,
  phoneIncomplete,
  phoneInvalid,
  phoneSameAsRider,
  vehicleNumberInvalid,
  accountNumberInvalid,
  accountNumbersMismatch,
  ifscInvalid,
  upiInvalid,
  aadhaarInvalid,
  panInvalid,
  drivingLicenceInvalid,
}

/// Riders must be at least this old on the day they register.
///
/// Open question for Jivo: the docs do not state an age rule. 18 is the
/// minimum age for a contract and for a motorcycle licence in India.
const kMinimumRiderAge = 18;

/// Today's date in India (IST, UTC+5:30) as a UTC-midnight date, from
/// [now]. The age rule uses the Indian calendar date wherever the phone's
/// clock zone is set.
DateTime istToday(DateTime now) {
  final ist = now.toUtc().add(const Duration(hours: 5, minutes: 30));
  return DateTime.utc(ist.year, ist.month, ist.day);
}

/// [value] as a UTC-midnight date (drops the time and the zone).
DateTime dateOnly(DateTime value) =>
    DateTime.utc(value.year, value.month, value.day);

/// The day someone born on [dob] turns [years]. A 29 February birthday
/// falls on 1 March in other years (Dart normalises 29 Feb to 1 Mar).
DateTime birthdayAt(DateTime dob, int years) =>
    DateTime.utc(dob.year + years, dob.month, dob.day);

/// The latest date of birth that is old enough on [today]: the date
/// picker's `lastDate`.
DateTime latestAllowedDateOfBirth(DateTime today) {
  final year = today.year - kMinimumRiderAge;
  final candidate = DateTime.utc(year, today.month, today.day);
  // 29 Feb today but not a leap year then: the last day of February.
  if (candidate.month != today.month) {
    return DateTime.utc(year, today.month + 1, 0);
  }
  return candidate;
}

FieldError? validateDateOfBirth(DateTime? dob, {required DateTime today}) {
  if (dob == null) return FieldError.required;
  final birth = dateOnly(dob);
  final day = dateOnly(today);
  if (birth.isAfter(day)) return FieldError.dobInFuture;
  if (day.isBefore(birthdayAt(birth, kMinimumRiderAge))) {
    return FieldError.dobUnderage;
  }
  return null;
}

final _nameChars = RegExp(r"^[\p{L}\p{M} .'-]+$", unicode: true);

/// Trims and collapses inner whitespace.
String normaliseName(String input) =>
    input.trim().replaceAll(RegExp(r'\s+'), ' ');

/// A person's name: 2 to 120 characters (07 `name` is char(120)), letters
/// in any script, spaces, `.`, `'` and `-`.
FieldError? validatePersonName(String input) {
  final name = normaliseName(input);
  if (name.isEmpty) return FieldError.required;
  if (name.length < 2 || name.length > 120 || !_nameChars.hasMatch(name)) {
    return FieldError.nameInvalid;
  }
  return null;
}

/// An emergency contact's mobile number. It must not be the rider's own
/// number ([riderPhoneE164]), or nobody can be reached when the rider
/// can't.
FieldError? validateEmergencyPhone(String input, {String? riderPhoneE164}) {
  switch (IndianMobile.validate(input)) {
    case PhoneInputError.empty:
      return FieldError.required;
    case PhoneInputError.incomplete:
      return FieldError.phoneIncomplete;
    case PhoneInputError.invalid:
      return FieldError.phoneInvalid;
    case null:
      break;
  }
  if (riderPhoneE164 != null && IndianMobile.toE164(input) == riderPhoneE164) {
    return FieldError.phoneSameAsRider;
  }
  return null;
}

/// Upper case, letters and digits only: `dl 3c ab-1234` → `DL3CAB1234`.
String normaliseRegistrationNumber(String input) =>
    input.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');

// State series (`DL3CAB1234`, `MH12AB1234`, `KA01A1234`) and the BH series
// (`22BH1234AB`).
final _stateSeries = RegExp(r'^[A-Z]{2}[0-9]{1,2}[A-Z]{0,3}[0-9]{4}$');
final _bhSeries = RegExp(r'^[0-9]{2}BH[0-9]{4}[A-Z]{1,2}$');

bool isValidVehicleNumber(String input) {
  final number = normaliseRegistrationNumber(input);
  return _stateSeries.hasMatch(number) || _bhSeries.hasMatch(number);
}

/// The vehicle number is required for motorised vehicles only, and ignored
/// otherwise (null [vehicle] = not chosen yet).
FieldError? validateVehicleNumber(
  String input, {
  required VehicleType? vehicle,
}) {
  if (vehicle == null || !vehicle.isMotorised) return null;
  if (normaliseRegistrationNumber(input).isEmpty) return FieldError.required;
  if (!isValidVehicleNumber(input)) return FieldError.vehicleNumberInvalid;
  return null;
}

/// Digits only.
String normaliseAccountNumber(String input) =>
    input.replaceAll(RegExp(r'\D'), '');

/// Indian bank account numbers have 9 to 18 digits.
///
/// Open question for Jivo / Finance: the range is the common rule, not from
/// the docs.
FieldError? validateAccountNumber(String input) {
  final digits = normaliseAccountNumber(input);
  if (digits.isEmpty) return FieldError.required;
  if (!RegExp(r'^\d{9,18}$').hasMatch(digits) ||
      // Spaces are allowed while typing; anything else is a typo.
      RegExp(r'[^\d\s]').hasMatch(input)) {
    return FieldError.accountNumberInvalid;
  }
  return null;
}

/// The confirm field must repeat the account number exactly.
FieldError? validateAccountConfirmation(String account, String confirm) {
  if (normaliseAccountNumber(confirm).isEmpty) return FieldError.required;
  if (normaliseAccountNumber(account) != normaliseAccountNumber(confirm)) {
    return FieldError.accountNumbersMismatch;
  }
  return null;
}

String normaliseIfsc(String input) => input.trim().toUpperCase();

/// IFSC: 4 letters (bank), `0`, then 6 letters or digits (branch).
FieldError? validateIfsc(String input) {
  final ifsc = normaliseIfsc(input);
  if (ifsc.isEmpty) return FieldError.required;
  if (!RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$').hasMatch(ifsc)) {
    return FieldError.ifscInvalid;
  }
  return null;
}

/// Optional UPI ID (VPA): `name@handle`.
FieldError? validateUpiId(String input) {
  final upi = input.trim();
  if (upi.isEmpty) return null;
  if (!RegExp(r'^[A-Za-z0-9._-]{2,256}@[A-Za-z][A-Za-z0-9]{1,63}$')
      .hasMatch(upi)) {
    return FieldError.upiInvalid;
  }
  return null;
}

/// Upper case, no spaces or dashes.
String normaliseDocumentNumber(String input) =>
    input.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');

/// Format checks only: Jivo ops verify the documents (04 §2.2).
FieldError? validateDocumentNumber(KycDocumentType type, String input) {
  if (!type.hasNumber) return null;
  final number = normaliseDocumentNumber(input);
  if (number.isEmpty) return FieldError.required;
  return switch (type) {
    KycDocumentType.aadhaarFront =>
      isValidAadhaar(number) ? null : FieldError.aadhaarInvalid,
    KycDocumentType.pan =>
      RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$').hasMatch(number)
          ? null
          : FieldError.panInvalid,
    // Formats differ by state and age; two letters (state) then 8–14
    // letters or digits.
    KycDocumentType.drivingLicence =>
      RegExp(r'^[A-Z]{2}[0-9A-Z]{8,14}$').hasMatch(number)
          ? null
          : FieldError.drivingLicenceInvalid,
    KycDocumentType.vehicleRc =>
      isValidVehicleNumber(number) ? null : FieldError.vehicleNumberInvalid,
    KycDocumentType.photo || KycDocumentType.aadhaarBack => null,
  };
}

/// 12 digits, not starting with 0 or 1, with a valid Verhoeff check digit
/// (UIDAI). Catches most typos before upload.
bool isValidAadhaar(String input) {
  final digits = normaliseDocumentNumber(input);
  if (!RegExp(r'^[2-9][0-9]{11}$').hasMatch(digits)) return false;
  return verhoeffIsValid(digits);
}

const _verhoeffD = [
  [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
  [1, 2, 3, 4, 0, 6, 7, 8, 9, 5],
  [2, 3, 4, 0, 1, 7, 8, 9, 5, 6],
  [3, 4, 0, 1, 2, 8, 9, 5, 6, 7],
  [4, 0, 1, 2, 3, 9, 5, 6, 7, 8],
  [5, 9, 8, 7, 6, 0, 4, 3, 2, 1],
  [6, 5, 9, 8, 7, 1, 0, 4, 3, 2],
  [7, 6, 5, 9, 8, 2, 1, 0, 4, 3],
  [8, 7, 6, 5, 9, 3, 2, 1, 0, 4],
  [9, 8, 7, 6, 5, 4, 3, 2, 1, 0],
];

const _verhoeffP = [
  [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
  [1, 5, 7, 6, 2, 8, 3, 0, 9, 4],
  [5, 8, 0, 3, 7, 9, 6, 1, 4, 2],
  [8, 9, 1, 6, 0, 4, 3, 5, 2, 7],
  [9, 4, 5, 3, 1, 2, 6, 8, 7, 0],
  [4, 2, 8, 6, 5, 7, 3, 9, 0, 1],
  [2, 7, 9, 3, 8, 0, 6, 4, 1, 5],
  [7, 0, 4, 6, 9, 1, 3, 2, 5, 8],
];

/// Whether [digits] (check digit last) passes the Verhoeff checksum.
bool verhoeffIsValid(String digits) {
  var c = 0;
  final reversed = digits.split('').reversed.toList();
  for (var i = 0; i < reversed.length; i++) {
    final n = int.parse(reversed[i]);
    c = _verhoeffD[c][_verhoeffP[i % 8][n]];
  }
  return c == 0;
}
