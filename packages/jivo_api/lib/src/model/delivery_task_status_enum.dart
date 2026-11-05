// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

/// * `SEARCHING` - Looking for a rider * `OFFERED` - Offered to a rider * `ASSIGNED` - Rider heading to the store * `AT_STORE` - Rider at the store * `PICKED_UP` - Picked up * `AT_CUSTOMER` - Rider at the drop location * `DELIVERED` - Delivered * `FAILED` - Delivery failed * `RETURNING` - Returning items to the store * `RETURNED` - Items returned to the store * `UNASSIGNED` - No rider found: ops to assign * `CANCELLED` - Cancelled
enum DeliveryTaskStatusEnum {
  @JsonValue(r'SEARCHING')
  SEARCHING(r'SEARCHING'),
  @JsonValue(r'OFFERED')
  OFFERED(r'OFFERED'),
  @JsonValue(r'ASSIGNED')
  ASSIGNED(r'ASSIGNED'),
  @JsonValue(r'AT_STORE')
  AT_STORE(r'AT_STORE'),
  @JsonValue(r'PICKED_UP')
  PICKED_UP(r'PICKED_UP'),
  @JsonValue(r'AT_CUSTOMER')
  AT_CUSTOMER(r'AT_CUSTOMER'),
  @JsonValue(r'DELIVERED')
  DELIVERED(r'DELIVERED'),
  @JsonValue(r'FAILED')
  FAILED(r'FAILED'),
  @JsonValue(r'RETURNING')
  RETURNING(r'RETURNING'),
  @JsonValue(r'RETURNED')
  RETURNED(r'RETURNED'),
  @JsonValue(r'UNASSIGNED')
  UNASSIGNED(r'UNASSIGNED'),
  @JsonValue(r'CANCELLED')
  CANCELLED(r'CANCELLED'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const DeliveryTaskStatusEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
