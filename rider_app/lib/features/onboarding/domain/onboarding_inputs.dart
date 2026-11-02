import 'dart:typed_data';

import 'kyc_document.dart';
import 'masking.dart';
import 'vehicle_type.dart';

/// `POST /rider/register/` (06 §3): personal and vehicle details and the
/// preferred store. Built only from a validated form.
///
/// TODO(api): field names are assumed from 07 §2.8 (`dob`,
/// `emergency_contact`, `vehicle_type`, `vehicle_number`, preferred store).
/// 07 has a single `emergency_contact` field; the app collects a name and a
/// phone (reported as an API gap).
class RiderRegistration {
  const RiderRegistration({
    required this.fullName,
    required this.dateOfBirth,
    required this.emergencyContactName,
    required this.emergencyContactPhone,
    required this.preferredStoreId,
    required this.vehicleType,
    this.vehicleNumber,
  });

  final String fullName;

  /// Date only (UTC midnight). Sent as `YYYY-MM-DD`.
  final DateTime dateOfBirth;
  final String emergencyContactName;

  /// E.164 (`+91XXXXXXXXXX`).
  final String emergencyContactPhone;
  final int preferredStoreId;
  final VehicleType vehicleType;

  /// Normalised (upper case, no spaces). Only for motorised vehicles.
  final String? vehicleNumber;

  @override
  String toString() =>
      'RiderRegistration(store: $preferredStoreId, '
      'vehicle: ${vehicleType.wireValue})';
}

/// `PUT /rider/bank-account/` (06 §3).
class BankAccountInput {
  const BankAccountInput({
    required this.holderName,
    required this.accountNumber,
    required this.ifsc,
    this.upiId,
  });

  final String holderName;

  /// Digits only. Never logged: [toString] masks it.
  final String accountNumber;

  /// Upper case.
  final String ifsc;
  final String? upiId;

  @override
  String toString() =>
      'BankAccountInput(${Masking.accountNumber(accountNumber)}, $ifsc)';
}

/// `POST /rider/documents/` (06 §3): multipart `type + file + number`.
class DocumentUpload {
  const DocumentUpload({required this.type, required this.image, this.number});

  final KycDocumentType type;

  /// The compressed JPEG (at most `kKycImageMaxBytes`).
  final Uint8List image;

  /// Normalised document number, for types where [KycDocumentType.hasNumber].
  /// Never logged: [toString] masks it.
  final String? number;

  /// Multipart file name. Random-free and number-free on purpose; the
  /// server stores files under random keys (09 §3.6).
  String get fileName => '${type.wireValue.toLowerCase()}.jpg';

  @override
  String toString() =>
      'DocumentUpload(${type.wireValue}, ${image.length} bytes, '
      'number: ${number == null ? null : Masking.trailing(number!)})';
}
