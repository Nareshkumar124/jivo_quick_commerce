// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

/// * `category` - Product list of the category whose slug is link_value * `collection` - Collection page whose slug is link_value * `product` - Product detail whose slug is link_value * `url` - External https URL in link_value (open in the browser) * `none` - Not tappable
enum BannerLinkTypeEnum {
  @JsonValue(r'category')
  category(r'category'),
  @JsonValue(r'collection')
  collection(r'collection'),
  @JsonValue(r'product')
  product(r'product'),
  @JsonValue(r'url')
  url(r'url'),
  @JsonValue(r'none')
  none(r'none'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const BannerLinkTypeEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
