// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'task_geofence.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class TaskGeofence {
  /// Returns a new [TaskGeofence] instance.
  TaskGeofence({required this.storeRadiusM, required this.customerRadiusM});

  /// `arrived-store` allowed within this.
  @JsonKey(name: r'store_radius_m', required: true, includeIfNull: false)
  final int storeRadiusM;

  /// `arrived-customer` allowed within this (or with `override_reason`).
  @JsonKey(name: r'customer_radius_m', required: true, includeIfNull: false)
  final int customerRadiusM;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TaskGeofence &&
          other.storeRadiusM == storeRadiusM &&
          other.customerRadiusM == customerRadiusM;

  @override
  int get hashCode => storeRadiusM.hashCode + customerRadiusM.hashCode;

  factory TaskGeofence.fromJson(Map<String, dynamic> json) =>
      _$TaskGeofenceFromJson(json);

  Map<String, dynamic> toJson() => _$TaskGeofenceToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
