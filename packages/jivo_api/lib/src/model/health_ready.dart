// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/health_checks.dart';
import 'package:jivo_api/src/model/health_status_enum.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'health_ready.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class HealthReady {
  /// Returns a new [HealthReady] instance.
  HealthReady({required this.status, required this.checks});

  @JsonKey(
    name: r'status',
    required: true,
    includeIfNull: false,
    unknownEnumValue: HealthStatusEnum.unknownDefaultOpenApi,
  )
  final HealthStatusEnum status;

  @JsonKey(name: r'checks', required: true, includeIfNull: false)
  final HealthChecks checks;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HealthReady && other.status == status && other.checks == checks;

  @override
  int get hashCode => status.hashCode + checks.hashCode;

  factory HealthReady.fromJson(Map<String, dynamic> json) =>
      _$HealthReadyFromJson(json);

  Map<String, dynamic> toJson() => _$HealthReadyToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
