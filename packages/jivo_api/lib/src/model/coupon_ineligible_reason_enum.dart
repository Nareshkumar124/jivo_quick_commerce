// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

/// * `MIN_ORDER_VALUE` - The item total is below the coupon's minimum. * `FIRST_ORDER_ONLY` - Only for your first order. * `NO_ELIGIBLE_ITEMS` - No items in the cart qualify for this coupon. * `STORE` - Not valid at this store.
enum CouponIneligibleReasonEnum {
  @JsonValue(r'MIN_ORDER_VALUE')
  MIN_ORDER_VALUE(r'MIN_ORDER_VALUE'),
  @JsonValue(r'FIRST_ORDER_ONLY')
  FIRST_ORDER_ONLY(r'FIRST_ORDER_ONLY'),
  @JsonValue(r'NO_ELIGIBLE_ITEMS')
  NO_ELIGIBLE_ITEMS(r'NO_ELIGIBLE_ITEMS'),
  @JsonValue(r'STORE')
  STORE(r'STORE'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const CouponIneligibleReasonEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
