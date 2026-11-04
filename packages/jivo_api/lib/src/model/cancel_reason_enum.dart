// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

/// * `CHANGE_PAYMENT_METHOD` - I want to pay another way * `PAYMENT_PROBLEM` - The payment did not work * `ORDERED_BY_MISTAKE` - I ordered by mistake * `CHANGED_MIND` - I changed my mind * `DELIVERY_TOO_SLOW` - Delivery is taking too long * `OTHER` - Other
enum CancelReasonEnum {
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
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const CancelReasonEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
