// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

/// * `processed` - Processed * `duplicate` - Already processed (same event id): nothing done * `ignored` - Event type not handled: nothing done
enum WebhookResultEnum {
  @JsonValue(r'processed')
  processed(r'processed'),
  @JsonValue(r'duplicate')
  duplicate(r'duplicate'),
  @JsonValue(r'ignored')
  ignored(r'ignored'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const WebhookResultEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
