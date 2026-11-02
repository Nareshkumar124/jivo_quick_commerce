// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

/// * `home` - Home * `work` - Work * `other` - Other
enum AddressLabelEnum {
  @JsonValue(r'home')
  home(r'home'),
  @JsonValue(r'work')
  work(r'work'),
  @JsonValue(r'other')
  other(r'other'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const AddressLabelEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
