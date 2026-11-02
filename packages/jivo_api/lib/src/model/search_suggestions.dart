// ignore_for_file: type=lint, unused_import, duplicate_ignore
//
// AUTO-GENERATED FILE, DO NOT MODIFY!
//

// ignore_for_file: unused_element
import 'package:jivo_api/src/model/search_suggestion.dart';
import 'package:copy_with_extension/copy_with_extension.dart';
import 'package:json_annotation/json_annotation.dart';

part 'search_suggestions.g.dart';

@CopyWith()
@JsonSerializable(
  checked: true,
  createToJson: true,
  disallowUnrecognizedKeys: false,
  explicitToJson: true,
)
class SearchSuggestions {
  /// Returns a new [SearchSuggestions] instance.
  SearchSuggestions({required this.query, required this.suggestions});

  /// The `q` these are for (match it to the latest keystroke).
  @JsonKey(name: r'query', required: true, includeIfNull: false)
  final String query;

  /// Up to 10, best first. For a blank `q`: the trending searches (`keyword`), possibly empty.
  @JsonKey(name: r'suggestions', required: true, includeIfNull: false)
  final List<SearchSuggestion> suggestions;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SearchSuggestions &&
          other.query == query &&
          other.suggestions == suggestions;

  @override
  int get hashCode => query.hashCode + suggestions.hashCode;

  factory SearchSuggestions.fromJson(Map<String, dynamic> json) =>
      _$SearchSuggestionsFromJson(json);

  Map<String, dynamic> toJson() => _$SearchSuggestionsToJson(this);

  @override
  String toString() {
    return toJson().toString();
  }
}
