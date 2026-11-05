// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

/// * `PENDING` - Waiting for the customer to pay * `PAID` - Paid (confirmed by the server) * `EXPIRED` - Expired * `CANCELLED` - Closed (cash was taken instead)
enum CodQrStatusEnum {
  @JsonValue(r'PENDING')
  PENDING(r'PENDING'),
  @JsonValue(r'PAID')
  PAID(r'PAID'),
  @JsonValue(r'EXPIRED')
  EXPIRED(r'EXPIRED'),
  @JsonValue(r'CANCELLED')
  CANCELLED(r'CANCELLED'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const CodQrStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
