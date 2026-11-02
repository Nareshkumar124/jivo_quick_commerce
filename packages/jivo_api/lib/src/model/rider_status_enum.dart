// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

/// * `NONE` - No rider profile: show registration * `PENDING_KYC` - Registered, waiting for KYC approval * `ACTIVE` - Approved: can go online * `REJECTED` - KYC rejected: see the reason, re-submit * `SUSPENDED` - Suspended by ops
enum RiderStatusEnum {
  @JsonValue(r'NONE')
  NONE(r'NONE'),
  @JsonValue(r'PENDING_KYC')
  PENDING_KYC(r'PENDING_KYC'),
  @JsonValue(r'ACTIVE')
  ACTIVE(r'ACTIVE'),
  @JsonValue(r'REJECTED')
  REJECTED(r'REJECTED'),
  @JsonValue(r'SUSPENDED')
  SUSPENDED(r'SUSPENDED'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const RiderStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
