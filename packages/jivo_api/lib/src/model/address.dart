// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/address_label_enum.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'address.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class Address {
  /// Returns a new [Address] instance.
  Address({
    required this.id,

    required this.label,

    this.customLabel,

    this.receiverName,

    this.receiverPhone,

    required this.house,

    required this.buildingStreet,

    this.landmark,

    this.area,

    required this.city,

    required this.state,

    required this.pincode,

    required this.lat,

    required this.lng,

    required this.isDefault,

    required this.isServiceable,

    required this.createdAt,

    required this.updatedAt,
  });

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final int id;

  @JsonKey(
    name: r'label',
    required: true,
    includeIfNull: false,
    unknownEnumValue: AddressLabelEnum.unknownDefaultOpenApi,
  )
  final AddressLabelEnum label;

  /// Shown instead of the label when set, e.g. \"Mom's place\".
  @JsonKey(name: r'custom_label', required: false, includeIfNull: false)
  final String? customLabel;

  /// Defaults to the user's name. Send an empty string to reset it to the user's own (copied when saved). Omit it to keep the current value; null is rejected.
  @JsonKey(name: r'receiver_name', required: false, includeIfNull: false)
  final String? receiverName;

  /// Defaults to the user's phone. Send an empty string to reset it to the user's own (copied when saved). Omit it to keep the current value; null is rejected.
  @JsonKey(name: r'receiver_phone', required: false, includeIfNull: false)
  final String? receiverPhone;

  /// House / flat / floor.
  @JsonKey(name: r'house', required: true, includeIfNull: false)
  final String house;

  /// Building and street.
  @JsonKey(name: r'building_street', required: true, includeIfNull: false)
  final String buildingStreet;

  @JsonKey(name: r'landmark', required: false, includeIfNull: false)
  final String? landmark;

  @JsonKey(name: r'area', required: false, includeIfNull: false)
  final String? area;

  @JsonKey(name: r'city', required: true, includeIfNull: false)
  final String city;

  @JsonKey(name: r'state', required: true, includeIfNull: false)
  final String state;

  @JsonKey(name: r'pincode', required: true, includeIfNull: false)
  final String pincode;

  /// Map pin latitude (WGS84). Required. Stored to 6 decimal places.
  // minimum: -90
  // maximum: 90
  @JsonKey(name: r'lat', required: true, includeIfNull: false)
  final double lat;

  /// Map pin longitude (WGS84). Required. Stored to 6 decimal places.
  // minimum: -180
  // maximum: 180
  @JsonKey(name: r'lng', required: true, includeIfNull: false)
  final double lng;

  /// Change it with `POST /addresses/{id}/set-default/`.
  @JsonKey(name: r'is_default', required: true, includeIfNull: false)
  final bool isDefault;

  /// True when the pin is inside an active store's service area (open or not), checked on every read. An unserviceable address can be saved but not used for an order: show it flagged (03 §2.4). Added in Phase 2.
  @JsonKey(name: r'is_serviceable', required: true, includeIfNull: false)
  final bool isServiceable;

  @JsonKey(name: r'created_at', required: true, includeIfNull: false)
  final DateTime createdAt;

  @JsonKey(name: r'updated_at', required: true, includeIfNull: false)
  final DateTime updatedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Address &&
          other.id == id &&
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
          other.lng == lng &&
          other.isDefault == isDefault &&
          other.isServiceable == isServiceable &&
          other.createdAt == createdAt &&
          other.updatedAt == updatedAt;

  @override
  int get hashCode =>
      id.hashCode +
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
      lng.hashCode +
      isDefault.hashCode +
      isServiceable.hashCode +
      createdAt.hashCode +
      updatedAt.hashCode;

  factory Address.fromJson(Map<String, dynamic> json) =>
      _$AddressFromJson(json);

  Map<String, dynamic> toJson() => _$AddressToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
