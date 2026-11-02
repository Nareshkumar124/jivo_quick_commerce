// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/health_check_status_enum.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'health_checks.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class HealthChecks {
  /// Returns a new [HealthChecks] instance.
  HealthChecks({required this.database, required this.redis});

  @JsonKey(
    name: r'database',
    required: true,
    includeIfNull: false,
    unknownEnumValue: HealthCheckStatusEnum.unknownDefaultOpenApi,
  )
  final HealthCheckStatusEnum database;

  @JsonKey(
    name: r'redis',
    required: true,
    includeIfNull: false,
    unknownEnumValue: HealthCheckStatusEnum.unknownDefaultOpenApi,
  )
  final HealthCheckStatusEnum redis;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HealthChecks &&
          other.database == database &&
          other.redis == redis;

  @override
  int get hashCode => database.hashCode + redis.hashCode;

  factory HealthChecks.fromJson(Map<String, dynamic> json) =>
      _$HealthChecksFromJson(json);

  Map<String, dynamic> toJson() => _$HealthChecksToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
