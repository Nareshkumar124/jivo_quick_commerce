// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

/// * `VOLUME_OFFER` - Volume offer * `REWARD` - Reward
enum FreeSourceEnum {
  @JsonValue(r'VOLUME_OFFER')
  VOLUME_OFFER(r'VOLUME_OFFER'),
  @JsonValue(r'REWARD')
  REWARD(r'REWARD'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const FreeSourceEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
