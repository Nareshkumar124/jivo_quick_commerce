// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

/// * `TO_STORE` - Rider to the store * `TO_CUSTOMER` - Rider to the customer
enum RouteLegEnum {
  @JsonValue(r'TO_STORE')
  TO_STORE(r'TO_STORE'),
  @JsonValue(r'TO_CUSTOMER')
  TO_CUSTOMER(r'TO_CUSTOMER'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const RouteLegEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
