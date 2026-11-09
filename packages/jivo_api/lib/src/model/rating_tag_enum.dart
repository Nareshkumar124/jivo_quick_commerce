// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

/// * `ON_TIME` - On time * `WELL_PACKED` - Well packed * `FRESH_PRODUCTS` - Fresh products * `POLITE_RIDER` - Polite rider * `LATE_DELIVERY` - Late delivery * `DAMAGED_ITEMS` - Damaged items * `MISSING_ITEMS` - Missing items * `RUDE_RIDER` - Rude rider
enum RatingTagEnum {
  @JsonValue(r'ON_TIME')
  ON_TIME(r'ON_TIME'),
  @JsonValue(r'WELL_PACKED')
  WELL_PACKED(r'WELL_PACKED'),
  @JsonValue(r'FRESH_PRODUCTS')
  FRESH_PRODUCTS(r'FRESH_PRODUCTS'),
  @JsonValue(r'POLITE_RIDER')
  POLITE_RIDER(r'POLITE_RIDER'),
  @JsonValue(r'LATE_DELIVERY')
  LATE_DELIVERY(r'LATE_DELIVERY'),
  @JsonValue(r'DAMAGED_ITEMS')
  DAMAGED_ITEMS(r'DAMAGED_ITEMS'),
  @JsonValue(r'MISSING_ITEMS')
  MISSING_ITEMS(r'MISSING_ITEMS'),
  @JsonValue(r'RUDE_RIDER')
  RUDE_RIDER(r'RUDE_RIDER'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const RatingTagEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
