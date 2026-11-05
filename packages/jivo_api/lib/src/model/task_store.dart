// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'task_store.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class TaskStore {
  /// Returns a new [TaskStore] instance.
  TaskStore({
    required this.id,

    required this.name,

    required this.address,

    required this.phone,

    required this.lat,

    required this.lng,
  });

  @JsonKey(name: r'id', required: true, includeIfNull: false)
  final int id;

  @JsonKey(name: r'name', required: true, includeIfNull: false)
  final String name;

  @JsonKey(name: r'address', required: true, includeIfNull: false)
  final String address;

  @JsonKey(name: r'phone', required: true, includeIfNull: false)
  final String phone;

  /// Latitude (WGS84), decimal degrees.
  // minimum: -90
  // maximum: 90
  @JsonKey(name: r'lat', required: true, includeIfNull: false)
  final double lat;

  /// Longitude (WGS84), decimal degrees.
  // minimum: -180
  // maximum: 180
  @JsonKey(name: r'lng', required: true, includeIfNull: false)
  final double lng;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskStore &&
          other.id == id &&
          other.name == name &&
          other.address == address &&
          other.phone == phone &&
          other.lat == lat &&
          other.lng == lng;

  @override
  int get hashCode =>
      id.hashCode +
      name.hashCode +
      address.hashCode +
      phone.hashCode +
      lat.hashCode +
      lng.hashCode;

  factory TaskStore.fromJson(Map<String, dynamic> json) =>
      _$TaskStoreFromJson(json);

  Map<String, dynamic> toJson() => _$TaskStoreToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
