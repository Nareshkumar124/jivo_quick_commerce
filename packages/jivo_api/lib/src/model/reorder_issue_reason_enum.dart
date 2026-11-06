// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

/// * `OUT_OF_STOCK` - Out of stock * `LIMITED_STOCK` - Only part of the quantity is available * `NOT_AVAILABLE` - No longer sold at this store
enum ReorderIssueReasonEnum {
  @JsonValue(r'OUT_OF_STOCK')
  OUT_OF_STOCK(r'OUT_OF_STOCK'),
  @JsonValue(r'LIMITED_STOCK')
  LIMITED_STOCK(r'LIMITED_STOCK'),
  @JsonValue(r'NOT_AVAILABLE')
  NOT_AVAILABLE(r'NOT_AVAILABLE'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const ReorderIssueReasonEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
