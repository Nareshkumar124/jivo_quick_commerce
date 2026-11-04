// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

/// * `PENDING` - In review * `APPROVED` - Approved * `REJECTED` - Rejected: upload a new copy
enum RiderDocumentStatusEnum {
  @JsonValue(r'PENDING')
  PENDING(r'PENDING'),
  @JsonValue(r'APPROVED')
  APPROVED(r'APPROVED'),
  @JsonValue(r'REJECTED')
  REJECTED(r'REJECTED'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const RiderDocumentStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
