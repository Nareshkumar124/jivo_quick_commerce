// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'location_reject_reasons.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class LocationRejectReasons {
  /// Returns a new [LocationRejectReasons] instance.
  LocationRejectReasons({
    required this.tooOld,

    required this.future,

    required this.invalidPoint,

    required this.implausibleJump,
  });

  /// Recorded more than 24 hours ago.
  @JsonKey(name: r'too_old', required: true, includeIfNull: false)
  final int tooOld;

  /// More than 2 minutes ahead of the server clock.
  @JsonKey(name: r'future', required: true, includeIfNull: false)
  final int future;

  /// The (0, 0) point (no fix).
  @JsonKey(name: r'invalid_point', required: true, includeIfNull: false)
  final int invalidPoint;

  /// A GPS jump: faster than RIDER_LOCATION_MAX_SPEED_KMPH (150 km/h) from the previous good fix within 10 minutes.
  @JsonKey(name: r'implausible_jump', required: true, includeIfNull: false)
  final int implausibleJump;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocationRejectReasons &&
          other.tooOld == tooOld &&
          other.future == future &&
          other.invalidPoint == invalidPoint &&
          other.implausibleJump == implausibleJump;

  @override
  int get hashCode =>
      tooOld.hashCode +
      future.hashCode +
      invalidPoint.hashCode +
      implausibleJump.hashCode;

  factory LocationRejectReasons.fromJson(Map<String, dynamic> json) =>
      _$LocationRejectReasonsFromJson(json);

  Map<String, dynamic> toJson() => _$LocationRejectReasonsToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
