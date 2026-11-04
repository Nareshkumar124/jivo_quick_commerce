// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/date_only.dart';
import 'package:jivo_api/src/model/rider_cash.dart';
import 'package:jivo_api/src/model/rider_status_enum.dart';
import 'package:jivo_api/src/model/rider_store.dart';
import 'package:jivo_api/src/model/rider_bank_account.dart';
import 'package:jivo_api/src/model/vehicle_type_enum.dart';
import 'package:jivo_api/src/model/rider_document.dart';
import 'package:jivo_api/src/model/rider_document_type_enum.dart';
import 'package:jivo_api/src/model/rider_today.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'rider_profile.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class RiderProfile {
  /// Returns a new [RiderProfile] instance.
  RiderProfile({
    required this.id,

    required this.phone,

    required this.status,

    required this.rejectionReason,

    required this.suspensionReason,

    required this.fullName,

    required this.dob,

    required this.emergencyContactName,

    required this.emergencyContactPhone,

    required this.vehicleType,

    required this.vehicleNumber,

    required this.preferredStore,

    required this.homeStore,

    required this.photoUrl,

    required this.photoUrlExpiresAt,

    required this.ratingAvg,

    required this.documents,

    required this.requiredDocuments,

    required this.missingDocuments,

    required this.bankAccount,

    required this.readyForReview,

    required this.isOnline,

    required this.cash,

    required this.today,

    required this.createdAt,
  });

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final int id;

  /// Login phone (E.164).
  @JsonKey(name: r'phone', required: true, includeIfNull: false)
  final String phone;

  /// PENDING_KYC, ACTIVE, REJECTED or SUSPENDED (never NONE here). Same value as `rider_status` of `GET /me/`.  * `NONE` - No rider profile: show registration * `PENDING_KYC` - Registered, waiting for KYC approval * `ACTIVE` - Approved: can go online * `REJECTED` - KYC rejected: see the reason, re-submit * `SUSPENDED` - Suspended by ops
  @JsonKey(
    name: r'status',
    required: true,
    includeIfNull: false,
    unknownEnumValue: RiderStatusEnum.unknownDefaultOpenApi,
  )
  final RiderStatusEnum status;

  /// Shown on the status screen when REJECTED (\"\" otherwise).
  @JsonKey(name: r'rejection_reason', required: true, includeIfNull: false)
  final String rejectionReason;

  /// Shown when SUSPENDED (\"\" otherwise).
  @JsonKey(name: r'suspension_reason', required: true, includeIfNull: false)
  final String suspensionReason;

  @JsonKey(name: r'full_name', required: true, includeIfNull: false)
  final String fullName;

  /// Date of birth.
  @JsonKey(
    name: r'dob',
    toJson: jivoDateToJson,
    required: true,
    includeIfNull: false,
  )
  final DateTime dob;

  @JsonKey(
    name: r'emergency_contact_name',
    required: true,
    includeIfNull: false,
  )
  final String emergencyContactName;

  /// E.164.
  @JsonKey(
    name: r'emergency_contact_phone',
    required: true,
    includeIfNull: false,
  )
  final String emergencyContactPhone;

  @JsonKey(
    name: r'vehicle_type',
    required: true,
    includeIfNull: false,
    unknownEnumValue: VehicleTypeEnum.unknownDefaultOpenApi,
  )
  final VehicleTypeEnum vehicleType;

  /// e.g. \"HR26DQ1234\"; null for a bicycle or e-bike.
  @JsonKey(name: r'vehicle_number', required: true, includeIfNull: true)
  final String? vehicleNumber;

  /// The store chosen at registration.
  @JsonKey(name: r'preferred_store', required: true, includeIfNull: false)
  final RiderStore preferredStore;

  /// Set by ops on approval; offers come only from this store. Null before.
  @JsonKey(name: r'home_store', required: true, includeIfNull: true)
  final RiderStore? homeStore;

  /// Signed link to the rider's photo (the PHOTO document), valid until `photo_url_expires_at` (1 hour). Null without a photo. Do not cache past expiry.
  @JsonKey(name: r'photo_url', required: true, includeIfNull: true)
  final String? photoUrl;

  @JsonKey(name: r'photo_url_expires_at', required: true, includeIfNull: true)
  final DateTime? photoUrlExpiresAt;

  /// Average customer rating, one decimal (\"4.8\"); null until rated (Phase 7).
  @JsonKey(name: r'rating_avg', required: true, includeIfNull: true)
  final String? ratingAvg;

  /// Uploaded documents, any status.
  @JsonKey(name: r'documents', required: true, includeIfNull: false)
  final List<RiderDocument> documents;

  /// Documents this rider needs (D-14 default): PHOTO, AADHAAR_FRONT, AADHAAR_BACK, PAN; plus DL and RC for MOTORBIKE/SCOOTER. Follows `vehicle_type`.
  @JsonKey(
    name: r'required_documents',
    required: true,
    includeIfNull: false,
    unknownEnumValue: RiderDocumentTypeEnum.unknownDefaultOpenApi,
  )
  final List<RiderDocumentTypeEnum> requiredDocuments;

  /// Required documents not uploaded yet or REJECTED: the rider must upload these.
  @JsonKey(
    name: r'missing_documents',
    required: true,
    includeIfNull: false,
    unknownEnumValue: RiderDocumentTypeEnum.unknownDefaultOpenApi,
  )
  final List<RiderDocumentTypeEnum> missingDocuments;

  @JsonKey(name: r'bank_account', required: true, includeIfNull: true)
  final RiderBankAccount? bankAccount;

  /// True when nothing required is missing (documents and bank details): the application waits for ops. Show \"Documents under review\".
  @JsonKey(name: r'ready_for_review', required: true, includeIfNull: false)
  final bool readyForReview;

  @JsonKey(name: r'is_online', required: true, includeIfNull: false)
  final bool isOnline;

  @JsonKey(name: r'cash', required: true, includeIfNull: false)
  final RiderCash cash;

  @JsonKey(name: r'today', required: true, includeIfNull: false)
  final RiderToday today;

  @JsonKey(name: r'created_at', required: true, includeIfNull: false)
  final DateTime createdAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RiderProfile &&
          other.id == id &&
          other.phone == phone &&
          other.status == status &&
          other.rejectionReason == rejectionReason &&
          other.suspensionReason == suspensionReason &&
          other.fullName == fullName &&
          other.dob == dob &&
          other.emergencyContactName == emergencyContactName &&
          other.emergencyContactPhone == emergencyContactPhone &&
          other.vehicleType == vehicleType &&
          other.vehicleNumber == vehicleNumber &&
          other.preferredStore == preferredStore &&
          other.homeStore == homeStore &&
          other.photoUrl == photoUrl &&
          other.photoUrlExpiresAt == photoUrlExpiresAt &&
          other.ratingAvg == ratingAvg &&
          other.documents == documents &&
          other.requiredDocuments == requiredDocuments &&
          other.missingDocuments == missingDocuments &&
          other.bankAccount == bankAccount &&
          other.readyForReview == readyForReview &&
          other.isOnline == isOnline &&
          other.cash == cash &&
          other.today == today &&
          other.createdAt == createdAt;

  @override
  int get hashCode =>
      id.hashCode +
      phone.hashCode +
      status.hashCode +
      rejectionReason.hashCode +
      suspensionReason.hashCode +
      fullName.hashCode +
      dob.hashCode +
      emergencyContactName.hashCode +
      emergencyContactPhone.hashCode +
      vehicleType.hashCode +
      (vehicleNumber == null ? 0 : vehicleNumber.hashCode) +
      preferredStore.hashCode +
      (homeStore == null ? 0 : homeStore.hashCode) +
      (photoUrl == null ? 0 : photoUrl.hashCode) +
      (photoUrlExpiresAt == null ? 0 : photoUrlExpiresAt.hashCode) +
      (ratingAvg == null ? 0 : ratingAvg.hashCode) +
      documents.hashCode +
      requiredDocuments.hashCode +
      missingDocuments.hashCode +
      (bankAccount == null ? 0 : bankAccount.hashCode) +
      readyForReview.hashCode +
      isOnline.hashCode +
      cash.hashCode +
      today.hashCode +
      createdAt.hashCode;

  factory RiderProfile.fromJson(Map<String, dynamic> json) =>
      _$RiderProfileFromJson(json);

  Map<String, dynamic> toJson() => _$RiderProfileToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
