import 'vehicle_type.dart';

/// KYC document types (07 §2.8 `RiderDocument.doc_type`, D-14).
enum KycDocumentType {
  photo('PHOTO'),
  aadhaarFront('AADHAAR_FRONT'),
  aadhaarBack('AADHAAR_BACK'),
  pan('PAN'),
  drivingLicence('DL'),
  vehicleRc('RC');

  const KycDocumentType(this.wireValue);

  final String wireValue;

  /// Whether the rider types the document's number with the image
  /// (`POST /rider/documents/` takes `type + file + number`, 06 §3). The
  /// Aadhaar number is asked once, on the front.
  bool get hasNumber => switch (this) {
    KycDocumentType.aadhaarFront ||
    KycDocumentType.pan ||
    KycDocumentType.drivingLicence ||
    KycDocumentType.vehicleRc => true,
    KycDocumentType.photo || KycDocumentType.aadhaarBack => false,
  };

  /// The selfie opens the front camera.
  bool get isSelfie => this == KycDocumentType.photo;

  static KycDocumentType? fromWire(String? value) {
    for (final type in values) {
      if (type.wireValue == value) return type;
    }
    return null;
  }
}

/// The documents a rider must upload for [vehicle] (04 §2.2, D-14): photo,
/// Aadhaar front and back, PAN, plus DL and RC for motorised vehicles.
List<KycDocumentType> requiredDocumentsFor(VehicleType vehicle) => [
  KycDocumentType.photo,
  KycDocumentType.aadhaarFront,
  KycDocumentType.aadhaarBack,
  KycDocumentType.pan,
  if (vehicle.isMotorised) ...[
    KycDocumentType.drivingLicence,
    KycDocumentType.vehicleRc,
  ],
];

/// Review status of an uploaded document (07 §2.8 `RiderDocument.status`).
enum DocumentReviewStatus {
  pending('PENDING'),
  approved('APPROVED'),
  rejected('REJECTED');

  const DocumentReviewStatus(this.wireValue);

  final String wireValue;
}

/// An uploaded KYC document as the server reports it. The number is only
/// ever the server's masked form (`doc_number_masked`).
class RiderDocument {
  const RiderDocument({
    required this.type,
    required this.status,
    this.numberMasked,
    this.reviewNote,
    this.uploadedAt,
  });

  final KycDocumentType type;
  final DocumentReviewStatus status;

  /// `doc_number_masked`, e.g. `XXXX XXXX 1234`. Null for documents without
  /// a number.
  final String? numberMasked;

  /// The reviewer's note, shown when the document was rejected.
  final String? reviewNote;

  final DateTime? uploadedAt;

  /// The rider can replace a document until it is approved.
  bool get canReplace => status != DocumentReviewStatus.approved;

  @override
  String toString() =>
      'RiderDocument(${type.wireValue}, ${status.wireValue}, '
      'number: $numberMasked)';
}
