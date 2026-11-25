// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

/// * `EARNED` - Reward earned * `CLAIMED` - Reward put on an order * `USED` - Reward used (order delivered) * `EXPIRED` - Reward expired * `VOLUME_FREE` - Free cartons with a delivered order (volume offer)
enum RewardHistoryKindEnum {
  @JsonValue(r'EARNED')
  EARNED(r'EARNED'),
  @JsonValue(r'CLAIMED')
  CLAIMED(r'CLAIMED'),
  @JsonValue(r'USED')
  USED(r'USED'),
  @JsonValue(r'EXPIRED')
  EXPIRED(r'EXPIRED'),
  @JsonValue(r'VOLUME_FREE')
  VOLUME_FREE(r'VOLUME_FREE'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const RewardHistoryKindEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
