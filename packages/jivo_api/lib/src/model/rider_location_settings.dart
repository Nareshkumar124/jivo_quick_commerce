// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'rider_location_settings.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class RiderLocationSettings {
  /// Returns a new [RiderLocationSettings] instance.
  RiderLocationSettings({
    required this.activeIntervalSeconds,

    required this.idleIntervalSeconds,
  });

  /// Location upload interval on an active task (5-10 s, 04 §3).
  @JsonKey(
    name: r'active_interval_seconds',
    required: true,
    includeIfNull: false,
  )
  final int activeIntervalSeconds;

  /// Location upload interval while online and idle (30 s).
  @JsonKey(name: r'idle_interval_seconds', required: true, includeIfNull: false)
  final int idleIntervalSeconds;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RiderLocationSettings &&
          other.activeIntervalSeconds == activeIntervalSeconds &&
          other.idleIntervalSeconds == idleIntervalSeconds;

  @override
  int get hashCode =>
      activeIntervalSeconds.hashCode + idleIntervalSeconds.hashCode;

  factory RiderLocationSettings.fromJson(Map<String, dynamic> json) =>
      _$RiderLocationSettingsFromJson(json);

  Map<String, dynamic> toJson() => _$RiderLocationSettingsToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
