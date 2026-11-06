// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

/// * `order` - Order updates * `promo` - Offers * `system` - Account and app
enum InboxNotificationCategoryEnum {
  @JsonValue(r'order')
  order(r'order'),
  @JsonValue(r'promo')
  promo(r'promo'),
  @JsonValue(r'system')
  system(r'system'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const InboxNotificationCategoryEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
