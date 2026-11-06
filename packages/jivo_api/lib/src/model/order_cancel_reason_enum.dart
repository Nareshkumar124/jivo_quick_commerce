// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

/// * `CHANGE_PAYMENT_METHOD` - I want to pay another way * `PAYMENT_PROBLEM` - The payment did not work * `ORDERED_BY_MISTAKE` - I ordered by mistake * `CHANGED_MIND` - I changed my mind * `DELIVERY_TOO_SLOW` - Delivery is taking too long * `OTHER` - Other * `ITEMS_UNAVAILABLE` - Items are not available at the store * `STORE_CLOSING` - The store had to close * `ADDRESS_ISSUE` - We could not deliver to this address * `CUSTOMER_REQUEST` - Cancelled at your request * `SUSPECTED_FRAUD` - The order could not be verified * `NO_RIDER` - No delivery partner was available * `OTHER_STAFF` - Cancelled by the store
enum OrderCancelReasonEnum {
  @JsonValue(r'CHANGE_PAYMENT_METHOD')
  CHANGE_PAYMENT_METHOD(r'CHANGE_PAYMENT_METHOD'),
  @JsonValue(r'PAYMENT_PROBLEM')
  PAYMENT_PROBLEM(r'PAYMENT_PROBLEM'),
  @JsonValue(r'ORDERED_BY_MISTAKE')
  ORDERED_BY_MISTAKE(r'ORDERED_BY_MISTAKE'),
  @JsonValue(r'CHANGED_MIND')
  CHANGED_MIND(r'CHANGED_MIND'),
  @JsonValue(r'DELIVERY_TOO_SLOW')
  DELIVERY_TOO_SLOW(r'DELIVERY_TOO_SLOW'),
  @JsonValue(r'OTHER')
  OTHER(r'OTHER'),
  @JsonValue(r'ITEMS_UNAVAILABLE')
  ITEMS_UNAVAILABLE(r'ITEMS_UNAVAILABLE'),
  @JsonValue(r'STORE_CLOSING')
  STORE_CLOSING(r'STORE_CLOSING'),
  @JsonValue(r'ADDRESS_ISSUE')
  ADDRESS_ISSUE(r'ADDRESS_ISSUE'),
  @JsonValue(r'CUSTOMER_REQUEST')
  CUSTOMER_REQUEST(r'CUSTOMER_REQUEST'),
  @JsonValue(r'SUSPECTED_FRAUD')
  SUSPECTED_FRAUD(r'SUSPECTED_FRAUD'),
  @JsonValue(r'NO_RIDER')
  NO_RIDER(r'NO_RIDER'),
  @JsonValue(r'OTHER_STAFF')
  OTHER_STAFF(r'OTHER_STAFF'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const OrderCancelReasonEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
