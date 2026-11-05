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

    required this.activeSampleSeconds,

    required this.idleSampleSeconds,

    required this.maxBatch,
  });

  /// Upload a batch this often while on a task (default 10 s, 04 §3).
  @JsonKey(
    name: r'active_interval_seconds',
    required: true,
    includeIfNull: false,
  )
  final int activeIntervalSeconds;

  /// Upload a batch this often while online and idle (default 30 s).
  @JsonKey(name: r'idle_interval_seconds', required: true, includeIfNull: false)
  final int idleIntervalSeconds;

  /// Take a GPS fix this often while on a task (default 5 s; <= the upload interval).
  @JsonKey(name: r'active_sample_seconds', required: true, includeIfNull: false)
  final int activeSampleSeconds;

  /// Take a GPS fix this often while idle (default 30 s; <= the upload interval).
  @JsonKey(name: r'idle_sample_seconds', required: true, includeIfNull: false)
  final int idleSampleSeconds;

  /// Most points per `POST /rider/locations/` (default 50). Buffered points beyond it go in the next request, oldest first.
  @JsonKey(name: r'max_batch', required: true, includeIfNull: false)
  final int maxBatch;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RiderLocationSettings &&
          other.activeIntervalSeconds == activeIntervalSeconds &&
          other.idleIntervalSeconds == idleIntervalSeconds &&
          other.activeSampleSeconds == activeSampleSeconds &&
          other.idleSampleSeconds == idleSampleSeconds &&
          other.maxBatch == maxBatch;

  @override
  int get hashCode =>
      activeIntervalSeconds.hashCode +
      idleIntervalSeconds.hashCode +
      activeSampleSeconds.hashCode +
      idleSampleSeconds.hashCode +
      maxBatch.hashCode;

  factory RiderLocationSettings.fromJson(Map<String, dynamic> json) =>
      _$RiderLocationSettingsFromJson(json);

  Map<String, dynamic> toJson() => _$RiderLocationSettingsToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
