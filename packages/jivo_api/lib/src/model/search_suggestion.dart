// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/search_suggestion_type_enum.dart';
import 'package:jivo_api/src/model/image_set.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'search_suggestion.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class SearchSuggestion {
  /// Returns a new [SearchSuggestion] instance.
  SearchSuggestion({
    required this.type,

    required this.text,

    required this.query,

    required this.id,

    required this.slug,

    required this.image,
  });

  @JsonKey(
    name: r'type',
    required: true,
    includeIfNull: false,
    unknownEnumValue: SearchSuggestionTypeEnum.unknownDefaultOpenApi,
  )
  final SearchSuggestionTypeEnum type;

  /// What to show in the suggestion row.
  @JsonKey(name: r'text', required: true, includeIfNull: false)
  final String text;

  /// The search term to run (and save in recent searches) when tapped.
  @JsonKey(name: r'query', required: true, includeIfNull: false)
  final String query;

  /// Product or category id; null for keywords.
  @JsonKey(name: r'id', required: true, includeIfNull: true)
  final int? id;

  /// Product or category slug to open; null for keywords.
  @JsonKey(name: r'slug', required: true, includeIfNull: true)
  final String? slug;

  /// Product or category image, if any.
  @JsonKey(name: r'image', required: true, includeIfNull: true)
  final ImageSet? image;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SearchSuggestion &&
          other.type == type &&
          other.text == text &&
          other.query == query &&
          other.id == id &&
          other.slug == slug &&
          other.image == image;

  @override
  int get hashCode =>
      type.hashCode +
      text.hashCode +
      query.hashCode +
      (id == null ? 0 : id.hashCode) +
      (slug == null ? 0 : slug.hashCode) +
      (image == null ? 0 : image.hashCode);

  factory SearchSuggestion.fromJson(Map<String, dynamic> json) =>
      _$SearchSuggestionFromJson(json);

  Map<String, dynamic> toJson() => _$SearchSuggestionToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
