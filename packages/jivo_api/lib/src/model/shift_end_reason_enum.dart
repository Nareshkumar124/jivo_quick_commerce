// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

/// * `MANUAL` - Rider went offline * `AUTO_OFFLINE` - No location for too long * `ADMIN` - Set offline by ops
enum ShiftEndReasonEnum {
  @JsonValue(r'MANUAL')
  MANUAL(r'MANUAL'),
  @JsonValue(r'AUTO_OFFLINE')
  AUTO_OFFLINE(r'AUTO_OFFLINE'),
  @JsonValue(r'ADMIN')
  ADMIN(r'ADMIN'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const ShiftEndReasonEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
