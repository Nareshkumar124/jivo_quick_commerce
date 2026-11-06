// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

/// * `PREPAID` - Prepaid * `COD` - Cash on delivery
enum RiderPaymentTypeEnum {
  @JsonValue(r'PREPAID')
  PREPAID(r'PREPAID'),
  @JsonValue(r'COD')
  COD(r'COD'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const RiderPaymentTypeEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
