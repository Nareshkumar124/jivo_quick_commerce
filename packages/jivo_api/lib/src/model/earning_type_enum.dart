// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

/// * `BASE` - Base pay * `DISTANCE` - Distance pay * `TIP` - Customer tip * `INCENTIVE` - Incentive * `PENALTY` - Penalty
enum EarningTypeEnum {
  @JsonValue(r'BASE')
  BASE(r'BASE'),
  @JsonValue(r'DISTANCE')
  DISTANCE(r'DISTANCE'),
  @JsonValue(r'TIP')
  TIP(r'TIP'),
  @JsonValue(r'INCENTIVE')
  INCENTIVE(r'INCENTIVE'),
  @JsonValue(r'PENALTY')
  PENALTY(r'PENALTY'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const EarningTypeEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
