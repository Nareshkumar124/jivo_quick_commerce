// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

/// * `ORDER_CANCELLED` - Order cancelled * `ITEMS_UNAVAILABLE` - Items not available * `DELIVERY_FAILED` - Delivery unsuccessful * `PAYMENT_ISSUE` - Extra or late payment returned * `GOODWILL` - Refund from customer support
enum OrderRefundReasonEnum {
  @JsonValue(r'ORDER_CANCELLED')
  ORDER_CANCELLED(r'ORDER_CANCELLED'),
  @JsonValue(r'ITEMS_UNAVAILABLE')
  ITEMS_UNAVAILABLE(r'ITEMS_UNAVAILABLE'),
  @JsonValue(r'DELIVERY_FAILED')
  DELIVERY_FAILED(r'DELIVERY_FAILED'),
  @JsonValue(r'PAYMENT_ISSUE')
  PAYMENT_ISSUE(r'PAYMENT_ISSUE'),
  @JsonValue(r'GOODWILL')
  GOODWILL(r'GOODWILL'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const OrderRefundReasonEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
