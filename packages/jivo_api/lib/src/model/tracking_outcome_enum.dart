// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

/// * `DELIVERED` - Delivered * `CANCELLED` - Cancelled * `DELIVERY_FAILED` - Delivery unsuccessful * `RETURNED` - Returned
enum TrackingOutcomeEnum {
  @JsonValue(r'DELIVERED')
  DELIVERED(r'DELIVERED'),
  @JsonValue(r'CANCELLED')
  CANCELLED(r'CANCELLED'),
  @JsonValue(r'DELIVERY_FAILED')
  DELIVERY_FAILED(r'DELIVERY_FAILED'),
  @JsonValue(r'RETURNED')
  RETURNED(r'RETURNED'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const TrackingOutcomeEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
