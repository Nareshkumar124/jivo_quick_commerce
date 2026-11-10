// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

/// * `MISSING_ITEMS` - Missing items * `DAMAGED_ITEMS` - Damaged items * `WRONG_ITEMS` - Wrong items * `LATE_DELIVERY` - Late delivery * `PAYMENT_REFUND` - Payment or refund * `ACCOUNT` - Account * `OTHER` - Other * `TASK` - A delivery task * `PAYOUT` - Payout * `CASH` - Cash deposit
enum TicketCategoryEnum {
  @JsonValue(r'MISSING_ITEMS')
  MISSING_ITEMS(r'MISSING_ITEMS'),
  @JsonValue(r'DAMAGED_ITEMS')
  DAMAGED_ITEMS(r'DAMAGED_ITEMS'),
  @JsonValue(r'WRONG_ITEMS')
  WRONG_ITEMS(r'WRONG_ITEMS'),
  @JsonValue(r'LATE_DELIVERY')
  LATE_DELIVERY(r'LATE_DELIVERY'),
  @JsonValue(r'PAYMENT_REFUND')
  PAYMENT_REFUND(r'PAYMENT_REFUND'),
  @JsonValue(r'ACCOUNT')
  ACCOUNT(r'ACCOUNT'),
  @JsonValue(r'OTHER')
  OTHER(r'OTHER'),
  @JsonValue(r'TASK')
  TASK(r'TASK'),
  @JsonValue(r'PAYOUT')
  PAYOUT(r'PAYOUT'),
  @JsonValue(r'CASH')
  CASH(r'CASH'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const TicketCategoryEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
