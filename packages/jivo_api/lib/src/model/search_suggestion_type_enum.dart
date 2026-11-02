// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:json_annotation/json_annotation.dart';

/// * `product` - A product: open its detail page (slug) * `category` - A category: open its product list (slug) * `keyword` - A search term (typed match or trending): run the search with `query`
enum SearchSuggestionTypeEnum {
  @JsonValue(r'product')
  product(r'product'),
  @JsonValue(r'category')
  category(r'category'),
  @JsonValue(r'keyword')
  keyword(r'keyword'),
  @JsonValue(r'unknown_default_open_api')
  unknownDefaultOpenApi(r'unknown_default_open_api');

  const SearchSuggestionTypeEnum(this.value);

  final String value;

  @override
  String toString() => value;
}
