import 'package:jivo_api/jivo_api.dart' show RiderStatusEnum;

import 'kyc_document.dart';
import 'vehicle_type.dart';

/// A dark store the rider can pick as preferred home store.
///
/// TODO(api): no endpoint lists stores for riders yet (06 §3). Reported as an
/// API gap; the fake returns a fixed list.
class StoreOption {
  const StoreOption({required this.id, required this.name, required this.city});

  final int id;
  final String name;
  final String city;

  @override
  bool operator ==(Object other) => other is StoreOption && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'StoreOption($id, $name)';
}

/// Saved payout details as the server reports them: the account number is
/// masked (07 §2.8 stores it encrypted; 09 §3.3).
class BankAccountSummary {
  const BankAccountSummary({
    required this.holderName,
    required this.accountNumberMasked,
    required this.ifsc,
    this.upiId,
  });

  final String holderName;

  /// e.g. `XXXXXXXX1234`.
  final String accountNumberMasked;
  final String ifsc;
  final String? upiId;

  @override
  String toString() => 'BankAccountSummary($accountNumberMasked, $ifsc)';
}

/// Where the rider is in onboarding, derived from the profile. Drives the
/// approval status screen (04 §2.2, screen 6).
enum OnboardingStage {
  /// Required documents are missing or were rejected.
  needsDocuments,

  /// Documents are in; payout details are missing.
  needsBankAccount,

  /// Everything is submitted: waiting for Jivo to review.
  inReview,

  /// `REJECTED`: show the reason and the re-upload path.
  rejected,

  /// `ACTIVE`: approved, can go online.
  approved,

  /// `SUSPENDED`.
  suspended,

  /// A status this app version does not know.
  unknown,
}

/// The rider profile from `GET /rider/me/` (06 §3, 07 §2.8 `Rider` and
/// `RiderDocument`), as far as onboarding needs it.
///
/// TODO(api): hand-written until the rider contract lands (end of P4). The
/// API repository will map the generated types to this class.
class RiderProfile {
  const RiderProfile({
    required this.status,
    required this.fullName,
    required this.dateOfBirth,
    required this.emergencyContactName,
    required this.emergencyContactPhone,
    required this.preferredStore,
    required this.vehicleType,
    this.vehicleNumber,
    this.homeStore,
    this.rejectionReason,
    this.documents = const [],
    this.bankAccount,
    this.photoUrl,
    this.rating,
  });

  final RiderStatusEnum status;
  final String fullName;

  /// Date only (UTC midnight).
  final DateTime dateOfBirth;
  final String emergencyContactName;

  /// E.164 (`+91XXXXXXXXXX`).
  final String emergencyContactPhone;

  /// The store the rider asked for at registration.
  final StoreOption preferredStore;

  /// The store ops assigned on approval (04 §2.2 "Admin approval"); null
  /// until then.
  final StoreOption? homeStore;
  final VehicleType vehicleType;
  final String? vehicleNumber;

  /// Why the application was rejected (`rejection_reason`).
  final String? rejectionReason;
  final List<RiderDocument> documents;
  final BankAccountSummary? bankAccount;

  /// The approved selfie, as a short-lived https URL (private bucket,
  /// 09 §3.3). Null before approval.
  final String? photoUrl;

  /// `rating_avg` as the server sends it (`"4.8"`), null without ratings.
  final String? rating;

  List<KycDocumentType> get requiredDocuments =>
      requiredDocumentsFor(vehicleType);

  RiderDocument? documentOf(KycDocumentType type) {
    for (final document in documents) {
      if (document.type == type) return document;
    }
    return null;
  }

  /// Required documents not uploaded yet.
  List<KycDocumentType> get missingDocuments =>
      requiredDocuments.where((t) => documentOf(t) == null).toList();

  /// Required documents the reviewer rejected.
  List<RiderDocument> get rejectedDocuments => [
    for (final type in requiredDocuments)
      if (documentOf(type) case final document?
          when document.status == DocumentReviewStatus.rejected)
        document,
  ];

  /// Required documents uploaded and not rejected.
  int get documentsDone =>
      requiredDocuments.length -
      missingDocuments.length -
      rejectedDocuments.length;

  bool get documentsComplete =>
      missingDocuments.isEmpty && rejectedDocuments.isEmpty;

  bool get hasBankAccount => bankAccount != null;

  OnboardingStage get stage => switch (status) {
    RiderStatusEnum.ACTIVE => OnboardingStage.approved,
    RiderStatusEnum.SUSPENDED => OnboardingStage.suspended,
    RiderStatusEnum.REJECTED => OnboardingStage.rejected,
    RiderStatusEnum.PENDING_KYC when !documentsComplete =>
      OnboardingStage.needsDocuments,
    RiderStatusEnum.PENDING_KYC when !hasBankAccount =>
      OnboardingStage.needsBankAccount,
    RiderStatusEnum.PENDING_KYC => OnboardingStage.inReview,
    RiderStatusEnum.NONE ||
    RiderStatusEnum.unknownDefaultOpenApi => OnboardingStage.unknown,
  };

  RiderProfile copyWith({
    RiderStatusEnum? status,
    StoreOption? homeStore,
    String? rejectionReason,
    bool clearRejectionReason = false,
    List<RiderDocument>? documents,
    BankAccountSummary? bankAccount,
  }) => RiderProfile(
    status: status ?? this.status,
    fullName: fullName,
    dateOfBirth: dateOfBirth,
    emergencyContactName: emergencyContactName,
    emergencyContactPhone: emergencyContactPhone,
    preferredStore: preferredStore,
    vehicleType: vehicleType,
    vehicleNumber: vehicleNumber,
    homeStore: homeStore ?? this.homeStore,
    rejectionReason: clearRejectionReason
        ? null
        : rejectionReason ?? this.rejectionReason,
    documents: documents ?? this.documents,
    bankAccount: bankAccount ?? this.bankAccount,
    photoUrl: photoUrl,
    rating: rating,
  );

  /// This profile with [document] added or replacing the one of its type.
  RiderProfile withDocument(RiderDocument document) => copyWith(
    documents: [
      for (final d in documents)
        if (d.type != document.type) d,
      document,
    ],
  );

  @override
  String toString() =>
      'RiderProfile(${status.value}, ${vehicleType.wireValue}, '
      'documents: $documents, bank: $bankAccount)';
}
