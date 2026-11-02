// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

/// * `ok` - ok
enum HealthStatusEnum {
  @JsonValue(r'ok')
  ok(r'ok'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const HealthStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
