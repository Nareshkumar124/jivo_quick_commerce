// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

/// * `customer` - Customer * `store` - Store staff * `rider` - Rider * `ops` - Ops / support * `system` - System
enum CancelledByEnum {
  @JsonValue(r'customer')
  customer(r'customer'),
  @JsonValue(r'store')
  store(r'store'),
  @JsonValue(r'rider')
  rider(r'rider'),
  @JsonValue(r'ops')
  ops(r'ops'),
  @JsonValue(r'system')
  system(r'system'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const CancelledByEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
