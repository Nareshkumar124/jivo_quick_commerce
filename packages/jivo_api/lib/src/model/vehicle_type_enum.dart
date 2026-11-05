// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

/// * `BICYCLE` - Bicycle * `E_BIKE` - E-bike * `MOTORBIKE` - Motorbike * `SCOOTER` - Scooter
enum VehicleTypeEnum {
  @JsonValue(r'BICYCLE')
  BICYCLE(r'BICYCLE'),
  @JsonValue(r'E_BIKE')
  E_BIKE(r'E_BIKE'),
  @JsonValue(r'MOTORBIKE')
  MOTORBIKE(r'MOTORBIKE'),
  @JsonValue(r'SCOOTER')
  SCOOTER(r'SCOOTER'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const VehicleTypeEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
