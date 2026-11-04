// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

/// * `COD_DISABLED` - The store does not offer cash on delivery. * `ABOVE_LIMIT` - The order is above the cash-on-delivery limit. * `NOT_ALLOWED` - Cash on delivery is not available for this account.
enum PaymentUnavailableReasonEnum {
  @JsonValue(r'COD_DISABLED')
  COD_DISABLED(r'COD_DISABLED'),
  @JsonValue(r'ABOVE_LIMIT')
  ABOVE_LIMIT(r'ABOVE_LIMIT'),
  @JsonValue(r'NOT_ALLOWED')
  NOT_ALLOWED(r'NOT_ALLOWED'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const PaymentUnavailableReasonEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
