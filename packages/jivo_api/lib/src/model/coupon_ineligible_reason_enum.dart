// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

/// * `MIN_ORDER_VALUE` - The item total is below the coupon's minimum. * `FIRST_ORDER_ONLY` - Only for your first order. * `NO_ELIGIBLE_ITEMS` - No items in the cart qualify for this coupon. * `STORE` - Not valid at this store. * `MIN_ORDER_UNITS` - A free-carton reward needs the order's minimum paid cartons. * `FREE_VARIANT_UNAVAILABLE` - The size chosen for the free carton is not available here (not sold at this store, not of the category of a paid line, or out of stock).
enum CouponIneligibleReasonEnum {
  @JsonValue(r'MIN_ORDER_VALUE')
  MIN_ORDER_VALUE(r'MIN_ORDER_VALUE'),
  @JsonValue(r'FIRST_ORDER_ONLY')
  FIRST_ORDER_ONLY(r'FIRST_ORDER_ONLY'),
  @JsonValue(r'NO_ELIGIBLE_ITEMS')
  NO_ELIGIBLE_ITEMS(r'NO_ELIGIBLE_ITEMS'),
  @JsonValue(r'STORE')
  STORE(r'STORE'),
  @JsonValue(r'MIN_ORDER_UNITS')
  MIN_ORDER_UNITS(r'MIN_ORDER_UNITS'),
  @JsonValue(r'FREE_VARIANT_UNAVAILABLE')
  FREE_VARIANT_UNAVAILABLE(r'FREE_VARIANT_UNAVAILABLE'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const CouponIneligibleReasonEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
