// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

/// * `TOO_FAR` - Too far * `VEHICLE_ISSUE` - Vehicle issue * `ON_BREAK` - On a break * `OTHER` - Other
enum OfferRejectReasonEnum {
  @JsonValue(r'TOO_FAR')
  TOO_FAR(r'TOO_FAR'),
  @JsonValue(r'VEHICLE_ISSUE')
  VEHICLE_ISSUE(r'VEHICLE_ISSUE'),
  @JsonValue(r'ON_BREAK')
  ON_BREAK(r'ON_BREAK'),
  @JsonValue(r'OTHER')
  OTHER(r'OTHER'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const OfferRejectReasonEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
