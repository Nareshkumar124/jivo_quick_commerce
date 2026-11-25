// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

/// * `AVAILABLE` - Can be used * `CLAIMED` - On an order that is not delivered yet * `USED` - Used on a delivered order * `EXPIRED` - Expired without being used
enum RewardStatusEnum {
  @JsonValue(r'AVAILABLE')
  AVAILABLE(r'AVAILABLE'),
  @JsonValue(r'CLAIMED')
  CLAIMED(r'CLAIMED'),
  @JsonValue(r'USED')
  USED(r'USED'),
  @JsonValue(r'EXPIRED')
  EXPIRED(r'EXPIRED'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const RewardStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
