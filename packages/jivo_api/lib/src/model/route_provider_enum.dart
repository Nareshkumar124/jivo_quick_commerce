// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

/// * `google` - Google (road, traffic) * `haversine` - Straight-line estimate
enum RouteProviderEnum {
  @JsonValue(r'google')
  google(r'google'),
  @JsonValue(r'haversine')
  haversine(r'haversine'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const RouteProviderEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
