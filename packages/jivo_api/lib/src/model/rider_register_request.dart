// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/date_only.dart';
import 'package:jivo_api/src/model/vehicle_type_enum.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'rider_register_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class RiderRegisterRequest {
  /// Returns a new [RiderRegisterRequest] instance.
  RiderRegisterRequest({
    required this.fullName,

    required this.dob,

    required this.emergencyContactName,

    required this.emergencyContactPhone,

    required this.preferredStoreId,

    required this.vehicleType,

    this.vehicleNumber,
  });

  /// Legal name, as on the documents.
  @JsonKey(name: r'full_name', required: true, includeIfNull: false)
  final String fullName;

  /// Date of birth. The rider must be 18 or older (IST).
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

  /// Indian mobile number (E.164, +91...), not the rider's own number.
  @JsonKey(
    name: r'emergency_contact_phone',
    required: true,
    includeIfNull: false,
  )
  final String emergencyContactPhone;

  /// From `GET /rider/stores/`.
  @JsonKey(name: r'preferred_store_id', required: true, includeIfNull: false)
  final int preferredStoreId;

  @JsonKey(
    name: r'vehicle_type',
    required: true,
    includeIfNull: false,
    unknownEnumValue: VehicleTypeEnum.unknownDefaultOpenApi,
  )
  final VehicleTypeEnum vehicleType;

  /// Required for MOTORBIKE and SCOOTER (e.g. HR26DQ1234; spaces and hyphens are ignored); must be empty or null for BICYCLE and E_BIKE.
  @JsonKey(name: r'vehicle_number', required: false, includeIfNull: false)
  final String? vehicleNumber;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RiderRegisterRequest &&
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

  factory RiderRegisterRequest.fromJson(Map<String, dynamic> json) =>
      _$RiderRegisterRequestFromJson(json);

  Map<String, dynamic> toJson() => _$RiderRegisterRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
