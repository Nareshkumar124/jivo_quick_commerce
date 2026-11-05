// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

/// * `rider` - The rider * `system` - The server (no location) * `ops` - Ops
enum ShiftEndedByEnum {
  @JsonValue(r'rider')
  rider(r'rider'),
  @JsonValue(r'system')
  system(r'system'),
  @JsonValue(r'ops')
  ops(r'ops'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const ShiftEndedByEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
