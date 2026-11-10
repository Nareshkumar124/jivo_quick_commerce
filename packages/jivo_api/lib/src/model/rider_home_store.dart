// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'rider_home_store.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class RiderHomeStore {
  /// Returns a new [RiderHomeStore] instance.
  RiderHomeStore({
    required this.id,

    required this.name,

    required this.city,

    required this.lat,

    required this.lng,
  });

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final int id;

  /// e.g. \"Jivo Sector 14\".
  @JsonKey(name: r'name', required: true, includeIfNull: false)
  final String name;

  @JsonKey(name: r'city', required: true, includeIfNull: false)
  final String city;

  /// Store entrance latitude.
  // minimum: -90
  // maximum: 90
  @JsonKey(name: r'lat', required: true, includeIfNull: false)
  final double lat;

  /// Store entrance longitude.
  // minimum: -180
  // maximum: 180
  @JsonKey(name: r'lng', required: true, includeIfNull: false)
  final double lng;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RiderHomeStore &&
          other.id == id &&
          other.name == name &&
          other.city == city &&
          other.lat == lat &&
          other.lng == lng;

  @override
  int get hashCode =>
      id.hashCode + name.hashCode + city.hashCode + lat.hashCode + lng.hashCode;

  factory RiderHomeStore.fromJson(Map<String, dynamic> json) =>
      _$RiderHomeStoreFromJson(json);

  Map<String, dynamic> toJson() => _$RiderHomeStoreToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
