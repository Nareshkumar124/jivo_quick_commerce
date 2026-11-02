// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/health_status_enum.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'health_live.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class HealthLive {
  /// Returns a new [HealthLive] instance.
  HealthLive({required this.status});

  @JsonKey(
    name: r'status',
    required: true,
    includeIfNull: false,
    unknownEnumValue: HealthStatusEnum.unknownDefaultOpenApi,
  )
  final HealthStatusEnum status;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is HealthLive && other.status == status;

  @override
  int get hashCode => status.hashCode;

  factory HealthLive.fromJson(Map<String, dynamic> json) =>
      _$HealthLiveFromJson(json);

  Map<String, dynamic> toJson() => _$HealthLiveToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
