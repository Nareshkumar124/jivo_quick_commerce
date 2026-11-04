// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

/// * `PAYMENT_PENDING` - Completing payment… * `PLACED` - Order placed * `ACCEPTED` - Order confirmed * `PACKING` - Packing your order * `PACKED` - Packed, rider on the way to store * `OUT_FOR_DELIVERY` - On the way * `DELIVERED` - Delivered * `CANCELLED` - Cancelled * `PAYMENT_FAILED` - Payment failed * `DELIVERY_FAILED` - Delivery unsuccessful * `RETURNED` - Delivery unsuccessful
enum OrderStatusEnum {
  @JsonValue(r'PAYMENT_PENDING')
  PAYMENT_PENDING(r'PAYMENT_PENDING'),
  @JsonValue(r'PLACED')
  PLACED(r'PLACED'),
  @JsonValue(r'ACCEPTED')
  ACCEPTED(r'ACCEPTED'),
  @JsonValue(r'PACKING')
  PACKING(r'PACKING'),
  @JsonValue(r'PACKED')
  PACKED(r'PACKED'),
  @JsonValue(r'OUT_FOR_DELIVERY')
  OUT_FOR_DELIVERY(r'OUT_FOR_DELIVERY'),
  @JsonValue(r'DELIVERED')
  DELIVERED(r'DELIVERED'),
  @JsonValue(r'CANCELLED')
  CANCELLED(r'CANCELLED'),
  @JsonValue(r'PAYMENT_FAILED')
  PAYMENT_FAILED(r'PAYMENT_FAILED'),
  @JsonValue(r'DELIVERY_FAILED')
  DELIVERY_FAILED(r'DELIVERY_FAILED'),
  @JsonValue(r'RETURNED')
  RETURNED(r'RETURNED'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const OrderStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
