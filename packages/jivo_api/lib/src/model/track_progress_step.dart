// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/tracking_step_enum.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'track_progress_step.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class TrackProgressStep {
  /// Returns a new [TrackProgressStep] instance.
  TrackProgressStep({
    required this.key,

    required this.label,

    required this.done,

    required this.at,
  });

  @JsonKey(
    name: r'key',
    required: true,
    includeIfNull: false,
    unknownEnumValue: TrackingStepEnum.unknownDefaultOpenApi,
  )
  final TrackingStepEnum key;

  /// Default English text; the app may use its own.
  @JsonKey(name: r'label', required: true, includeIfNull: false)
  final String label;

  @JsonKey(name: r'done', required: true, includeIfNull: false)
  final bool done;

  /// When it happened; null for derived steps or not yet.
  @JsonKey(name: r'at', required: true, includeIfNull: true)
  final DateTime? at;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrackProgressStep &&
          other.key == key &&
          other.label == label &&
          other.done == done &&
          other.at == at;

  @override
  int get hashCode =>
      key.hashCode +
      label.hashCode +
      done.hashCode +
      (at == null ? 0 : at.hashCode);

  factory TrackProgressStep.fromJson(Map<String, dynamic> json) =>
      _$TrackProgressStepFromJson(json);

  Map<String, dynamic> toJson() => _$TrackProgressStepToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
