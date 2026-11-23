// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

/// * `CONFIRMED` - Order confirmed * `PREPARING` - Preparing your order * `PACKED` - Packed * `RIDER_ASSIGNED` - Rider assigned * `PICKED_UP` - Picked up * `ON_THE_WAY` - On the way * `ARRIVING` - Arriving * `DELIVERED` - Delivered
enum TrackingStepEnum {
  @JsonValue(r'CONFIRMED')
  CONFIRMED(r'CONFIRMED'),
  @JsonValue(r'PREPARING')
  PREPARING(r'PREPARING'),
  @JsonValue(r'PACKED')
  PACKED(r'PACKED'),
  @JsonValue(r'RIDER_ASSIGNED')
  RIDER_ASSIGNED(r'RIDER_ASSIGNED'),
  @JsonValue(r'PICKED_UP')
  PICKED_UP(r'PICKED_UP'),
  @JsonValue(r'ON_THE_WAY')
  ON_THE_WAY(r'ON_THE_WAY'),
  @JsonValue(r'ARRIVING')
  ARRIVING(r'ARRIVING'),
  @JsonValue(r'DELIVERED')
  DELIVERED(r'DELIVERED'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const TrackingStepEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
