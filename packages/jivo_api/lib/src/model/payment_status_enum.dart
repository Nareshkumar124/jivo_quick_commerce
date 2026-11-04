// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

/// * `PENDING` - Awaiting payment * `PAID` - Paid * `FAILED` - Not paid * `REFUND_PENDING` - Refund in progress * `REFUNDED` - Refunded * `PARTIALLY_REFUNDED` - Partially refunded * `COD_PENDING` - Pay on delivery * `COD_COLLECTED` - Paid on delivery
enum PaymentStatusEnum {
  @JsonValue(r'PENDING')
  PENDING(r'PENDING'),
  @JsonValue(r'PAID')
  PAID(r'PAID'),
  @JsonValue(r'FAILED')
  FAILED(r'FAILED'),
  @JsonValue(r'REFUND_PENDING')
  REFUND_PENDING(r'REFUND_PENDING'),
  @JsonValue(r'REFUNDED')
  REFUNDED(r'REFUNDED'),
  @JsonValue(r'PARTIALLY_REFUNDED')
  PARTIALLY_REFUNDED(r'PARTIALLY_REFUNDED'),
  @JsonValue(r'COD_PENDING')
  COD_PENDING(r'COD_PENDING'),
  @JsonValue(r'COD_COLLECTED')
  COD_COLLECTED(r'COD_COLLECTED'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const PaymentStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
