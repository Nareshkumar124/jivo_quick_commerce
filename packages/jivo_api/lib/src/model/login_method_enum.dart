// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

/// * `phone` - Phone number (SMS OTP) * `email` - Email address (email OTP)
enum LoginMethodEnum {
  @JsonValue(r'phone')
  phone(r'phone'),
  @JsonValue(r'email')
  email(r'email'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const LoginMethodEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
