// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

/// * `OUT_OF_STOCK` - Out of stock: remove it to continue. * `QUANTITY_UNAVAILABLE` - Not available in this quantity: reduce it to continue.
enum CartLineIssueCodeEnum {
  @JsonValue(r'OUT_OF_STOCK')
  OUT_OF_STOCK(r'OUT_OF_STOCK'),
  @JsonValue(r'QUANTITY_UNAVAILABLE')
  QUANTITY_UNAVAILABLE(r'QUANTITY_UNAVAILABLE'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const CartLineIssueCodeEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
