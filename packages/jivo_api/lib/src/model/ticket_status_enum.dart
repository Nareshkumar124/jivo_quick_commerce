// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

/// * `OPEN` - Open * `IN_PROGRESS` - In progress * `RESOLVED` - Resolved * `CLOSED` - Closed
enum TicketStatusEnum {
  @JsonValue(r'OPEN')
  OPEN(r'OPEN'),
  @JsonValue(r'IN_PROGRESS')
  IN_PROGRESS(r'IN_PROGRESS'),
  @JsonValue(r'RESOLVED')
  RESOLVED(r'RESOLVED'),
  @JsonValue(r'CLOSED')
  CLOSED(r'CLOSED'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const TicketStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
