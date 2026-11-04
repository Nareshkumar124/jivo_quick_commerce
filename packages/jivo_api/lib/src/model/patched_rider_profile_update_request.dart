// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/vehicle_type_enum.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'patched_rider_profile_update_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class PatchedRiderProfileUpdateRequest {
  /// Returns a new [PatchedRiderProfileUpdateRequest] instance.
  PatchedRiderProfileUpdateRequest({
    this.fullName,

    this.dob,

    this.emergencyContactName,

    this.emergencyContactPhone,

    this.preferredStoreId,

    this.vehicleType,

    this.vehicleNumber,
  });

  /// Legal name, as on the documents.
  @JsonKey(name: r'full_name', required: false, includeIfNull: false)
  final String? fullName;

  /// Date of birth. The rider must be 18 or older (IST).
  @JsonKey(name: r'dob', required: false, includeIfNull: false)
  final DateTime? dob;

  @JsonKey(
    name: r'emergency_contact_name',
    required: false,
    includeIfNull: false,
  )
  final String? emergencyContactName;

  /// Indian mobile number (E.164, +91...), not the rider's own number.
  @JsonKey(
    name: r'emergency_contact_phone',
    required: false,
    includeIfNull: false,
  )
  final String? emergencyContactPhone;

  /// From `GET /rider/stores/`.
  @JsonKey(name: r'preferred_store_id', required: false, includeIfNull: false)
  final int? preferredStoreId;

  @JsonKey(
    name: r'vehicle_type',
    required: false,
    includeIfNull: false,
    unknownEnumValue: VehicleTypeEnum.unknownDefaultOpenApi,
  )
  final VehicleTypeEnum? vehicleType;

  /// Required for MOTORBIKE and SCOOTER (e.g. HR26DQ1234; spaces and hyphens are ignored); must be empty or null for BICYCLE and E_BIKE.
  @JsonKey(name: r'vehicle_number', required: false, includeIfNull: false)
  final String? vehicleNumber;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PatchedRiderProfileUpdateRequest &&
          other.fullName == fullName &&
          other.dob == dob &&
          other.emergencyContactName == emergencyContactName &&
          other.emergencyContactPhone == emergencyContactPhone &&
          other.preferredStoreId == preferredStoreId &&
          other.vehicleType == vehicleType &&
          other.vehicleNumber == vehicleNumber;

  @override
  int get hashCode =>
      fullName.hashCode +
      dob.hashCode +
      emergencyContactName.hashCode +
      emergencyContactPhone.hashCode +
      preferredStoreId.hashCode +
      vehicleType.hashCode +
      (vehicleNumber == null ? 0 : vehicleNumber.hashCode);

  factory PatchedRiderProfileUpdateRequest.fromJson(
    Map<String, dynamic> json,
  ) => _$PatchedRiderProfileUpdateRequestFromJson(json);

  Map<String, dynamic> toJson() =>
      _$PatchedRiderProfileUpdateRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
