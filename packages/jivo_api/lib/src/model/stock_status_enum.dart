// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

/// * `IN_STOCK` - In stock * `LOW_STOCK` - In stock, only a few left: show 'Only {units_left} left' * `OUT_OF_STOCK` - Out of stock: grey the tile out, no ADD button
enum StockStatusEnum {
  @JsonValue(r'IN_STOCK')
  IN_STOCK(r'IN_STOCK'),
  @JsonValue(r'LOW_STOCK')
  LOW_STOCK(r'LOW_STOCK'),
  @JsonValue(r'OUT_OF_STOCK')
  OUT_OF_STOCK(r'OUT_OF_STOCK'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const StockStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
