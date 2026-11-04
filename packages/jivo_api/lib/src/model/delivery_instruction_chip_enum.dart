// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

/// * `DONT_RING_BELL` - Don't ring the bell * `LEAVE_AT_DOOR` - Leave at the door * `AVOID_CALLING` - Avoid calling
enum DeliveryInstructionChipEnum {
  @JsonValue(r'DONT_RING_BELL')
  DONT_RING_BELL(r'DONT_RING_BELL'),
  @JsonValue(r'LEAVE_AT_DOOR')
  LEAVE_AT_DOOR(r'LEAVE_AT_DOOR'),
  @JsonValue(r'AVOID_CALLING')
  AVOID_CALLING(r'AVOID_CALLING'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const DeliveryInstructionChipEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
