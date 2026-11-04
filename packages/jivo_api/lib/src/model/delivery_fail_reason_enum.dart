// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

/// * `CUSTOMER_NOT_REACHABLE` - Customer not reachable * `CUSTOMER_REFUSED` - Customer refused the order * `WRONG_ADDRESS` - Wrong address * `OTHER` - Other
enum DeliveryFailReasonEnum {
  @JsonValue(r'CUSTOMER_NOT_REACHABLE')
  CUSTOMER_NOT_REACHABLE(r'CUSTOMER_NOT_REACHABLE'),
  @JsonValue(r'CUSTOMER_REFUSED')
  CUSTOMER_REFUSED(r'CUSTOMER_REFUSED'),
  @JsonValue(r'WRONG_ADDRESS')
  WRONG_ADDRESS(r'WRONG_ADDRESS'),
  @JsonValue(r'OTHER')
  OTHER(r'OTHER'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const DeliveryFailReasonEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
