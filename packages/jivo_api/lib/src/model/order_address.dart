// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'order_address.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class OrderAddress {
  /// Returns a new [OrderAddress] instance.
  OrderAddress({
    required this.label,

    required this.customLabel,

    required this.receiverName,

    required this.receiverPhone,

    required this.house,

    required this.buildingStreet,

    required this.landmark,

    required this.area,

    required this.city,

    required this.state,

    required this.pincode,

    required this.lat,

    required this.lng,
  });

  /// home / work / other.
  @JsonKey(name: r'label', required: true, includeIfNull: false)
  final String label;

  @JsonKey(name: r'custom_label', required: true, includeIfNull: false)
  final String customLabel;

  @JsonKey(name: r'receiver_name', required: true, includeIfNull: false)
  final String receiverName;

  @JsonKey(name: r'receiver_phone', required: true, includeIfNull: false)
  final String receiverPhone;

  @JsonKey(name: r'house', required: true, includeIfNull: false)
  final String house;

  @JsonKey(name: r'building_street', required: true, includeIfNull: false)
  final String buildingStreet;

  @JsonKey(name: r'landmark', required: true, includeIfNull: false)
  final String landmark;

  @JsonKey(name: r'area', required: true, includeIfNull: false)
  final String area;

  @JsonKey(name: r'city', required: true, includeIfNull: false)
  final String city;

  @JsonKey(name: r'state', required: true, includeIfNull: false)
  final String state;

  @JsonKey(name: r'pincode', required: true, includeIfNull: false)
  final String pincode;

  @JsonKey(name: r'lat', required: true, includeIfNull: false)
  final double lat;

  @JsonKey(name: r'lng', required: true, includeIfNull: false)
  final double lng;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrderAddress &&
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

  factory OrderAddress.fromJson(Map<String, dynamic> json) =>
      _$OrderAddressFromJson(json);

  Map<String, dynamic> toJson() => _$OrderAddressToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
