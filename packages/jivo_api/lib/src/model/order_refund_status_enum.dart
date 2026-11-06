// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

/// * `PENDING` - Refund in progress * `PROCESSED` - Refunded
enum OrderRefundStatusEnum {
  @JsonValue(r'PENDING')
  PENDING(r'PENDING'),
  @JsonValue(r'PROCESSED')
  PROCESSED(r'PROCESSED'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const OrderRefundStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
