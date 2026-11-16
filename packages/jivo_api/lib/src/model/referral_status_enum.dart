// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

/// * `PENDING` - Waiting for the first delivered order * `REWARDED` - Rewarded (both coupons given) * `VOID` - No reward (program off at the first delivery)
enum ReferralStatusEnum {
  @JsonValue(r'PENDING')
  PENDING(r'PENDING'),
  @JsonValue(r'REWARDED')
  REWARDED(r'REWARDED'),
  @JsonValue(r'VOID')
  VOID(r'VOID'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const ReferralStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
