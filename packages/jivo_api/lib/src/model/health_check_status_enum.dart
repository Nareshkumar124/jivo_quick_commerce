// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

/// * `ok` - ok * `error` - error
enum HealthCheckStatusEnum {
  @JsonValue(r'ok')
  ok(r'ok'),
  @JsonValue(r'error')
  error(r'error'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const HealthCheckStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
