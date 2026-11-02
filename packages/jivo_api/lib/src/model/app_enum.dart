// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

/// * `customer` - Customer app * `rider` - Rider app
enum AppEnum {
  @JsonValue(r'customer')
  customer(r'customer'),
  @JsonValue(r'rider')
  rider(r'rider'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const AppEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
