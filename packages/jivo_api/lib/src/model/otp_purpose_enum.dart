// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

/// * `login` - Log in or sign up * `delete_account` - Confirm account deletion
enum OtpPurposeEnum {
  @JsonValue(r'login')
  login(r'login'),
  @JsonValue(r'delete_account')
  deleteAccount(r'delete_account'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const OtpPurposeEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
