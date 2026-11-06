// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

/// * `cash` - Cash * `upi` - UPI QR
enum CodModeEnum {
  @JsonValue(r'cash')
  cash(r'cash'),
  @JsonValue(r'upi')
  upi(r'upi'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const CodModeEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
