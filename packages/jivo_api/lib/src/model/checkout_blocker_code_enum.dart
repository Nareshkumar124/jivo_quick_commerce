// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

/// * `CART_EMPTY` - Add items to your cart. * `ADDRESS_REQUIRED` - Select a delivery address. * `NOT_SERVICEABLE` - We do not deliver to this address from this store. * `STORE_CLOSED` - The store is not accepting orders right now. * `STOCK_UNAVAILABLE` - Some items are not available as chosen. * `MIN_ORDER_NOT_MET` - The minimum order value is not met. * `COUPON_INVALID` - The coupon is not valid. * `COUPON_EXPIRED` - The coupon has expired. * `COUPON_NOT_ELIGIBLE` - This cart is not eligible for the coupon. * `COUPON_USAGE_EXCEEDED` - The coupon usage limit is reached.
enum CheckoutBlockerCodeEnum {
  @JsonValue(r'CART_EMPTY')
  CART_EMPTY(r'CART_EMPTY'),
  @JsonValue(r'ADDRESS_REQUIRED')
  ADDRESS_REQUIRED(r'ADDRESS_REQUIRED'),
  @JsonValue(r'NOT_SERVICEABLE')
  NOT_SERVICEABLE(r'NOT_SERVICEABLE'),
  @JsonValue(r'STORE_CLOSED')
  STORE_CLOSED(r'STORE_CLOSED'),
  @JsonValue(r'STOCK_UNAVAILABLE')
  STOCK_UNAVAILABLE(r'STOCK_UNAVAILABLE'),
  @JsonValue(r'MIN_ORDER_NOT_MET')
  MIN_ORDER_NOT_MET(r'MIN_ORDER_NOT_MET'),
  @JsonValue(r'COUPON_INVALID')
  COUPON_INVALID(r'COUPON_INVALID'),
  @JsonValue(r'COUPON_EXPIRED')
  COUPON_EXPIRED(r'COUPON_EXPIRED'),
  @JsonValue(r'COUPON_NOT_ELIGIBLE')
  COUPON_NOT_ELIGIBLE(r'COUPON_NOT_ELIGIBLE'),
  @JsonValue(r'COUPON_USAGE_EXCEEDED')
  COUPON_USAGE_EXCEEDED(r'COUPON_USAGE_EXCEEDED'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const CheckoutBlockerCodeEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
