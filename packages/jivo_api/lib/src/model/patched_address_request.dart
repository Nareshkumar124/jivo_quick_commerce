// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/address_label_enum.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'patched_address_request.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class PatchedAddressRequest {
  /// Returns a new [PatchedAddressRequest] instance.
  PatchedAddressRequest({
    this.label,

    this.customLabel,

    this.receiverName,

    this.receiverPhone,

    this.house,

    this.buildingStreet,

    this.landmark,

    this.area,

    this.city,

    this.state,

    this.pincode,

    this.lat,

    this.lng,
  });

  @JsonKey(
    name: r'label',
    required: false,
    includeIfNull: false,
    unknownEnumValue: AddressLabelEnum.unknownDefaultOpenApi,
  )
  final AddressLabelEnum? label;

  /// Shown instead of the label when set, e.g. \"Mom's place\".
  @JsonKey(name: r'custom_label', required: false, includeIfNull: false)
  final String? customLabel;

  /// Defaults to the user's name.
  @JsonKey(name: r'receiver_name', required: false, includeIfNull: false)
  final String? receiverName;

  /// Defaults to the user's phone.
  @JsonKey(name: r'receiver_phone', required: false, includeIfNull: false)
  final String? receiverPhone;

  /// House / flat / floor.
  @JsonKey(name: r'house', required: false, includeIfNull: false)
  final String? house;

  /// Building and street.
  @JsonKey(name: r'building_street', required: false, includeIfNull: false)
  final String? buildingStreet;

  @JsonKey(name: r'landmark', required: false, includeIfNull: false)
  final String? landmark;

  @JsonKey(name: r'area', required: false, includeIfNull: false)
  final String? area;

  @JsonKey(name: r'city', required: false, includeIfNull: false)
  final String? city;

  @JsonKey(name: r'state', required: false, includeIfNull: false)
  final String? state;

  @JsonKey(name: r'pincode', required: false, includeIfNull: false)
  final String? pincode;

  /// Map pin latitude (WGS84). Required. Stored to 6 decimal places.
  // minimum: -90
  // maximum: 90
  @JsonKey(name: r'lat', required: false, includeIfNull: false)
  final double? lat;

  /// Map pin longitude (WGS84). Required. Stored to 6 decimal places.
  // minimum: -180
  // maximum: 180
  @JsonKey(name: r'lng', required: false, includeIfNull: false)
  final double? lng;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PatchedAddressRequest &&
          other.label == label &&
          other.customLabel == customLabel &&
          other.receiverName == receiverName &&
          other.receiverPhone == receiverPhone &&
          other.house == house &&
          other.buildingStreet == buildingStreet &&
          other.landmark == landmark &&
          other.area == area &&
          other.city == city &&
          other.state == state &&
          other.pincode == pincode &&
          other.lat == lat &&
          other.lng == lng;

  @override
  int get hashCode =>
      label.hashCode +
      customLabel.hashCode +
      receiverName.hashCode +
      receiverPhone.hashCode +
      house.hashCode +
      buildingStreet.hashCode +
      landmark.hashCode +
      area.hashCode +
      city.hashCode +
      state.hashCode +
      pincode.hashCode +
      lat.hashCode +
      lng.hashCode;

  factory PatchedAddressRequest.fromJson(Map<String, dynamic> json) =>
      _$PatchedAddressRequestFromJson(json);

  Map<String, dynamic> toJson() => _$PatchedAddressRequestToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
