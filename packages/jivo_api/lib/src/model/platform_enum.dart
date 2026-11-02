// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

/// * `android` - Android * `ios` - iOS
enum PlatformEnum {
  @JsonValue(r'android')
  android(r'android'),
  @JsonValue(r'ios')
  ios(r'ios'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const PlatformEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
