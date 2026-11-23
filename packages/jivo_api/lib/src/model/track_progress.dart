// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/tracking_outcome_enum.dart';
import 'package:jivo_api/src/model/track_progress_step.dart';
import 'package:jivo_api/src/model/tracking_step_enum.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'track_progress.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class TrackProgress {
  /// Returns a new [TrackProgress] instance.
  TrackProgress({
    required this.current,

    required this.outcome,

    required this.steps,
  });

  /// The last step reached.  * `CONFIRMED` - Order confirmed * `PREPARING` - Preparing your order * `PACKED` - Packed * `RIDER_ASSIGNED` - Rider assigned * `PICKED_UP` - Picked up * `ON_THE_WAY` - On the way * `ARRIVING` - Arriving * `DELIVERED` - Delivered
  @JsonKey(
    name: r'current',
    required: true,
    includeIfNull: true,
    unknownEnumValue: TrackingStepEnum.unknownDefaultOpenApi,
  )
  final TrackingStepEnum? current;

  /// Null while the order is active.  * `DELIVERED` - Delivered * `CANCELLED` - Cancelled * `DELIVERY_FAILED` - Delivery unsuccessful * `RETURNED` - Returned
  @JsonKey(
    name: r'outcome',
    required: true,
    includeIfNull: true,
    unknownEnumValue: TrackingOutcomeEnum.unknownDefaultOpenApi,
  )
  final TrackingOutcomeEnum? outcome;

  /// Always the 8 steps, in order.
  @JsonKey(name: r'steps', required: true, includeIfNull: false)
  final List<TrackProgressStep> steps;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrackProgress &&
          other.current == current &&
          other.outcome == outcome &&
          other.steps == steps;

  @override
  int get hashCode =>
      (current == null ? 0 : current.hashCode) +
      (outcome == null ? 0 : outcome.hashCode) +
      steps.hashCode;

  factory TrackProgress.fromJson(Map<String, dynamic> json) =>
      _$TrackProgressFromJson(json);

  Map<String, dynamic> toJson() => _$TrackProgressToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
