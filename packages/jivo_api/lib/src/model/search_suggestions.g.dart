// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'search_suggestions.dart';

// **************************************************************************
// CopyWithGenerator
// **************************************************************************

abstract class _$SearchSuggestionsCWProxy {
  SearchSuggestions query(String query);

  SearchSuggestions suggestions(List<SearchSuggestion> suggestions);

  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SearchSuggestions(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SearchSuggestions(...).copyWith(id: 12, name: "My name")
  /// ````
  SearchSuggestions call({String query, List<SearchSuggestion> suggestions});
}

/// Proxy class for `copyWith` functionality. This is a callable class and can be used as follows: `instanceOfSearchSuggestions.copyWith(...)`. Additionally contains functions for specific fields e.g. `instanceOfSearchSuggestions.copyWith.fieldName(...)`
class _$SearchSuggestionsCWProxyImpl implements _$SearchSuggestionsCWProxy {
  const _$SearchSuggestionsCWProxyImpl(this._value);

  final SearchSuggestions _value;

  @override
  SearchSuggestions query(String query) => this(query: query);

  @override
  SearchSuggestions suggestions(List<SearchSuggestion> suggestions) =>
      this(suggestions: suggestions);

  @override
  /// This function **does support** nullification of nullable fields. All `null` values passed to `non-nullable` fields will be ignored. You can also use `SearchSuggestions(...).copyWith.fieldName(...)` to override fields one at a time with nullification support.
  ///
  /// Usage
  /// ```dart
  /// SearchSuggestions(...).copyWith(id: 12, name: "My name")
  /// ````
  SearchSuggestions call({
    Object? query = const $CopyWithPlaceholder(),
    Object? suggestions = const $CopyWithPlaceholder(),
  }) {
    return SearchSuggestions(
      query: query == const $CopyWithPlaceholder()
          ? _value.query
          // ignore: cast_nullable_to_non_nullable
          : query as String,
      suggestions: suggestions == const $CopyWithPlaceholder()
          ? _value.suggestions
          // ignore: cast_nullable_to_non_nullable
          : suggestions as List<SearchSuggestion>,
    );
  }
}

extension $SearchSuggestionsCopyWith on SearchSuggestions {
  /// Returns a callable class that can be used as follows: `instanceOfSearchSuggestions.copyWith(...)` or like so:`instanceOfSearchSuggestions.copyWith.fieldName(...)`.
  // ignore: library_private_types_in_public_api
  _$SearchSuggestionsCWProxy get copyWith =>
      _$SearchSuggestionsCWProxyImpl(this);
}

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SearchSuggestions _$SearchSuggestionsFromJson(Map<String, dynamic> json) =>
    $checkedCreate('SearchSuggestions', json, ($checkedConvert) {
      $checkKeys(json, requiredKeys: const ['query', 'suggestions']);
      final val = SearchSuggestions(
        query: $checkedConvert('query', (v) => v as String),
        suggestions: $checkedConvert(
          'suggestions',
          (v) => (v as List<dynamic>)
              .map((e) => SearchSuggestion.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
      );
      return val;
    });

Map<String, dynamic> _$SearchSuggestionsToJson(SearchSuggestions instance) =>
    <String, dynamic>{
      'query': instance.query,
      'suggestions': instance.suggestions.map((e) => e.toJson()).toList(),
    };
