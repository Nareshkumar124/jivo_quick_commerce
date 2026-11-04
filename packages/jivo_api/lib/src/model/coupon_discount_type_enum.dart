// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

/// * `FLAT` - Flat amount off * `PERCENT` - Percent off
enum CouponDiscountTypeEnum {
  @JsonValue(r'FLAT')
  FLAT(r'FLAT'),
  @JsonValue(r'PERCENT')
  PERCENT(r'PERCENT'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const CouponDiscountTypeEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
