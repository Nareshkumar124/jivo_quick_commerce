// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

/// * `NONE` - Made by staff * `WELCOME` - Welcome reward (new account) * `REFERRAL_REFERRER` - Referral reward (you invited a friend) * `REFERRAL_REFERRED` - Referral reward (you joined with a friend's code)
enum CouponSourceEnum {
  @JsonValue(r'NONE')
  NONE(r'NONE'),
  @JsonValue(r'WELCOME')
  WELCOME(r'WELCOME'),
  @JsonValue(r'REFERRAL_REFERRER')
  REFERRAL_REFERRER(r'REFERRAL_REFERRER'),
  @JsonValue(r'REFERRAL_REFERRED')
  REFERRAL_REFERRED(r'REFERRAL_REFERRED'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const CouponSourceEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
